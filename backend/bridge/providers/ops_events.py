import json
import os
import re
import subprocess
import sys
import threading
import time
from collections import deque

HAPROXY_RE = re.compile(r"^\[WARNING\]\s+\(\d+\) : (Backup )?Server (\S+?)/(\S+) is (UP|DOWN)(?:, reason: ([^,]+))?")
STARTED_RE = re.compile(r"^Started (\S+\.service)")
STOPPED_RE = re.compile(r"^Stopped (\S+\.service)")
FAILED_RE = re.compile(r"^(\S+\.service): Failed with result '([^']+)'")
RESTART_RE = re.compile(r"^(\S+\.service): Scheduled restart job, restart counter is at (\d+)")
SSH_FAIL_RE = re.compile(r"(?:Failed password for|authentication failure)")
SSH_FROM_RE = re.compile(r"\bfrom (\d{1,3}(?:\.\d{1,3}){3})\b")
UPDATES_RE = re.compile(r"(\d+) updates? can be (?:applied|installed)")
SECURITY_RE = re.compile(r"(\d+) of these updates are (?:standard )?security")
MAX_EVENTS = 500
BACKFILL = "24 hours ago"


def log(message):
    print("ops-events: " + message, file=sys.stderr, flush=True)


def classify(msg, units):
    m = HAPROXY_RE.match(msg)
    if m:
        backup, proxy, server, state, reason = m.groups()
        up = state == "UP"
        level = "ok" if up else ("warn" if backup else "error")
        tier = "dự phòng " if backup else ""
        return "egress", level, "Tầng %s%s %s" % (tier, server, state), (reason or "").strip()
    m = STARTED_RE.match(msg)
    if m and m.group(1) in units:
        return "unit", "ok", "%s khởi động" % m.group(1), ""
    m = STOPPED_RE.match(msg)
    if m and m.group(1) in units:
        return "unit", "warn", "%s đã dừng" % m.group(1), ""
    m = FAILED_RE.match(msg)
    if m and m.group(1) in units:
        return "unit", "error", "%s lỗi" % m.group(1), "Kết quả: " + m.group(2)
    m = RESTART_RE.match(msg)
    if m and m.group(1) in units:
        return "unit", "warn", "%s tự khởi động lại" % m.group(1), "Lần thứ " + m.group(2)
    return None


class OpsEvents:
    def __init__(self, ops):
        self.ops = ops
        self.buffer = deque(maxlen=MAX_EVENTS)
        self.lock = threading.Lock()
        self.seq = 0
        self.cursors = {}
        self.health = None
        self.egress_active = None
        self.peers = None
        self.sync_peers = None
        self.sync_pct = {}
        self.sync_errors = {}
        self.last_errors = set()

    def start(self):
        threading.Thread(target=self.run, daemon=True).start()

    def warn_once(self, key, message):
        if key not in self.last_errors:
            self.last_errors.add(key)
            log(message)

    def add(self, ts_ms, kind, level, title, detail=""):
        with self.lock:
            self.seq += 1
            self.buffer.append({"id": self.seq, "ts": ts_ms, "kind": kind, "level": level, "title": title, "detail": detail})

    def now_ms(self):
        return int(time.time() * 1000)

    def get_events(self, after=0, limit=200):
        with self.lock:
            items = [e for e in self.buffer if e["id"] > after]
            return {"events": items[-max(1, min(limit, MAX_EVENTS)):], "last": self.seq}

    def scan_journal(self, scope):
        names = [n for s, n in self.ops.units if s == scope and n.endswith(".service")]
        if not names:
            return
        cmd = ["journalctl"] + (["--user"] if scope == "user" else []) + ["--no-pager", "-o", "json"]
        for n in names:
            cmd += ["-u", n]
        cursor = self.cursors.get(scope)
        cmd += ["--after-cursor", cursor] if cursor else ["--since", BACKFILL]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
        except Exception as e:
            self.warn_once("journal-" + scope, "journalctl %s failed: %s" % (scope, type(e).__name__))
            return
        if res.returncode != 0 and not res.stdout:
            self.warn_once("journal-" + scope, "journalctl %s exit %d" % (scope, res.returncode))
            return
        units = set(names)
        for line in res.stdout.splitlines():
            try:
                j = json.loads(line)
            except ValueError:
                continue
            self.cursors[scope] = j.get("__CURSOR", self.cursors.get(scope))
            msg = j.get("MESSAGE")
            if not isinstance(msg, str):
                continue
            hit = classify(msg, units)
            if hit:
                self.add(int(j.get("__REALTIME_TIMESTAMP", "0")) // 1000, *hit)

    def poll_egress(self):
        eg = self.ops.get_egress()
        if not eg or not eg.get("ok"):
            return
        active = eg.get("active")
        if self.egress_active is not None and active != self.egress_active:
            if active is None:
                self.add(self.now_ms(), "egress", "error", "Không còn tầng egress nào sống", "Mọi tầng đều DOWN")
            else:
                level = "ok" if not any(s["backup"] for s in eg["servers"] if s["name"] == active) else "warn"
                self.add(self.now_ms(), "egress", level, "Đổi đường hầm: %s thành %s" % (self.egress_active or "không có", active), "")
        self.egress_active = active

    def tailscale_peers(self):
        try:
            res = subprocess.run(["tailscale", "status", "--json"], capture_output=True, text=True, timeout=6)
        except FileNotFoundError:
            return None
        except Exception as e:
            self.warn_once("tailscale", "tailscale failed: %s" % type(e).__name__)
            return None
        if res.returncode != 0:
            self.warn_once("tailscale", "tailscale exit %d" % res.returncode)
            return None
        try:
            data = json.loads(res.stdout)
        except ValueError:
            return None
        return {(p.get("HostName") or p.get("DNSName") or "?"): bool(p.get("Online")) for p in (data.get("Peer") or {}).values()}

    def poll_peers(self):
        peers = self.tailscale_peers()
        if peers is None:
            return
        if self.peers is not None:
            for name, online in peers.items():
                before = self.peers.get(name)
                if before is None:
                    self.add(self.now_ms(), "net", "info", "Tailscale: thiết bị mới %s" % name, "online" if online else "offline")
                elif before != online:
                    self.add(self.now_ms(), "net", "ok" if online else "warn", "Tailscale: %s %s" % (name, "online" if online else "offline"), "")
        self.peers = peers

    def poll_sync(self):
        sync = self.ops.get_sync()
        if not sync or not sync.get("ok"):
            return
        peers = {p["name"]: p["connected"] for p in sync.get("peers", [])}
        if self.sync_peers is not None:
            for name, connected in peers.items():
                if name in self.sync_peers and self.sync_peers[name] != connected:
                    self.add(self.now_ms(), "sync", "ok" if connected else "warn", "Syncthing: %s %s" % (name, "đã kết nối" if connected else "mất kết nối"), "")
        self.sync_peers = peers
        for f in sync.get("folders", []):
            before = self.sync_pct.get(f["id"])
            if before is not None and before < 99.9 <= f["pct"]:
                self.add(self.now_ms(), "sync", "ok", "Thư mục %s đồng bộ xong" % f["id"], "")
            if f["errors"] > 0 and self.sync_errors.get(f["id"], 0) == 0 and before is not None:
                self.add(self.now_ms(), "sync", "error", "Thư mục %s có %d lỗi sync" % (f["id"], f["errors"]), "")
            self.sync_pct[f["id"]] = f["pct"]
            self.sync_errors[f["id"]] = f["errors"]

    def compute_health(self):
        health = {}
        backups = []
        for scope, name in self.ops.units:
            if name.endswith(".timer") and "backup" in name:
                svc = name[:-6] + ".service"
                try:
                    res = self.ops._systemctl(scope, "show", "-p", "Result,ExecMainExitTimestamp,ActiveState", "--", svc)
                except Exception:
                    continue
                props = dict(line.split("=", 1) for line in res.stdout.splitlines() if "=" in line)
                last = props.get("ExecMainExitTimestamp", "")
                backups.append({"unit": svc, "scope": scope, "ok": props.get("Result") == "success" and bool(last),
                                "result": props.get("Result", ""), "last": last})
        health["backups"] = backups
        health["reboot_required"] = os.path.exists("/var/run/reboot-required")
        updates = None
        try:
            with open("/var/lib/update-notifier/updates-available", encoding="utf-8") as f:
                text = f.read()
            total, sec = UPDATES_RE.search(text), SECURITY_RE.search(text)
            updates = {"total": int(total.group(1)) if total else 0, "security": int(sec.group(1)) if sec else 0}
        except OSError:
            pass
        health["updates"] = updates
        ssh = None
        try:
            res = subprocess.run(["journalctl", "--no-pager", "-o", "cat", "--since", "24 hours ago", "-u", "ssh.service", "-u", "sshd.service"],
                                 capture_output=True, text=True, timeout=20)
            if res.returncode == 0:
                lines = [l for l in res.stdout.splitlines() if SSH_FAIL_RE.search(l)]
                ips = {m.group(1) for m in (SSH_FROM_RE.search(l) for l in lines) if m}
                ssh = {"failed": len(lines), "sources": len(ips)}
        except Exception as e:
            self.warn_once("ssh", "ssh journal failed: %s" % type(e).__name__)
        health["ssh"] = ssh
        peers = self.peers
        health["tailscale"] = None if peers is None else {
            "online": sum(1 for v in peers.values() if v), "total": len(peers),
            "offline": sorted(n for n, v in peers.items() if not v)}
        self.health = health

    def run(self):
        tick = 0
        while True:
            try:
                for scope in ("system", "user"):
                    self.scan_journal(scope)
                self.poll_egress()
                self.poll_peers()
                if tick % 3 == 0:
                    self.poll_sync()
                if tick % 12 == 0:
                    self.compute_health()
            except Exception as e:
                self.warn_once("loop-" + type(e).__name__, "loop error: %s" % type(e).__name__)
            tick += 1
            time.sleep(5)
