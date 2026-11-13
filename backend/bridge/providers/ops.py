import csv
import io
import json
import os
import re
import socket
import subprocess
import time
import urllib.request
import xml.etree.ElementTree as ET

UNIT_RE = re.compile(r"^[A-Za-z0-9@._-]+\.(service|timer)$")
SHOW_PROPS = ("Id,Description,ActiveState,SubState,Result,NRestarts,MainPID,MemoryCurrent,"
              "ActiveEnterTimestamp,NextElapseUSecRealtime,LastTriggerUSec,UnitFileState")
REDACTIONS = (
    (re.compile(r"sk-[A-Za-z0-9_-]{16,}"), "[redacted]"),
    (re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}"), "[redacted]"),
    (re.compile(r"\b\d{8,10}:[A-Za-z0-9_-]{30,}\b"), "[redacted]"),
    (re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}"), "Bearer [redacted]"),
    (re.compile(r"(?i)((?:secret|token|passw(?:or)?d|api[_-]?key|authorization|cookie)[\"']?\s*[:=]\s*[\"']?)[^\s\"',;&]{6,}"), r"\1[redacted]"),
    (re.compile(r"\b[0-9a-fA-F]{40,}\b"), "[redacted]"),
    (re.compile(r"\b[A-Za-z0-9+/_-]{48,}={0,2}"), "[redacted]"),
)
MAX_LINE = 700
MAX_LINES = 1000


def redact(text):
    for pattern, repl in REDACTIONS:
        text = pattern.sub(repl, text)
    return text[:MAX_LINE]


def parse_units(raw):
    units = []
    for item in raw.split(","):
        item = item.strip()
        if not item:
            continue
        scope, _, name = item.partition(":")
        if scope not in ("system", "user") or not UNIT_RE.match(name):
            continue
        units.append((scope, name))
    return units


class OpsProvider:
    def __init__(self):
        self.label = os.environ.get("ORBITER_OPS_HOST_LABEL", socket.gethostname())
        self.units = parse_units(os.environ.get("ORBITER_OPS_UNITS", ""))
        self.haproxy_sock = os.environ.get("ORBITER_OPS_HAPROXY_SOCK", "")
        self.syncthing_config = os.environ.get("ORBITER_OPS_SYNCTHING_CONFIG", "")
        self.use_sudo = os.environ.get("ORBITER_OPS_SUDO", "") == "1"
        self.allowed = set(self.units)

    def _systemctl(self, scope, *args, timeout=10):
        cmd = ["systemctl"] + (["--user"] if scope == "user" else []) + list(args)
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)

    def _show(self, scope, names):
        res = self._systemctl(scope, "show", "-p", SHOW_PROPS, "--", *names)
        blocks = res.stdout.strip().split("\n\n")
        out = []
        for block in blocks:
            props = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
            if props.get("Id"):
                out.append(props)
        return out

    def get_units(self):
        result = []
        for scope in ("system", "user"):
            names = [n for s, n in self.units if s == scope]
            if not names:
                continue
            try:
                shown = self._show(scope, names)
            except Exception:
                shown = []
            by_id = {p["Id"]: p for p in shown}
            for name in names:
                p = by_id.get(name)
                if not p:
                    result.append({"unit": name, "scope": scope, "state": "unknown", "kind": name.rsplit(".", 1)[1]})
                    continue
                mem = p.get("MemoryCurrent", "")
                result.append({
                    "unit": name,
                    "scope": scope,
                    "kind": name.rsplit(".", 1)[1],
                    "description": p.get("Description", ""),
                    "state": p.get("ActiveState", "unknown"),
                    "sub": p.get("SubState", ""),
                    "result": p.get("Result", ""),
                    "restarts": int(p["NRestarts"]) if p.get("NRestarts", "").isdigit() else 0,
                    "pid": int(p["MainPID"]) if p.get("MainPID", "").isdigit() else 0,
                    "memory": int(mem) if mem.isdigit() else 0,
                    "since": p.get("ActiveEnterTimestamp", ""),
                    "next": p.get("NextElapseUSecRealtime", ""),
                    "last": p.get("LastTriggerUSec", ""),
                    "enabled": p.get("UnitFileState", ""),
                })
        return result

    def get_failed(self):
        failed = []
        for scope in ("system", "user"):
            try:
                res = self._systemctl(scope, "--failed", "--no-legend", "--plain", "--no-pager")
            except Exception:
                continue
            for line in res.stdout.splitlines():
                parts = line.split()
                if parts and UNIT_RE.match(parts[0]):
                    failed.append({"unit": parts[0], "scope": scope})
        return failed

    def get_egress(self):
        if not self.haproxy_sock:
            return None
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(3)
                s.connect(self.haproxy_sock)
                s.sendall(b"show stat\n")
                chunks = []
                while True:
                    data = s.recv(65536)
                    if not data:
                        break
                    chunks.append(data)
        except Exception as e:
            return {"ok": False, "error": str(e)}
        text = b"".join(chunks).decode("utf-8", "replace").lstrip("# ")
        rows = list(csv.DictReader(io.StringIO(text)))
        servers = []
        for r in rows:
            if r.get("pxname") != "egress" or r.get("svname") in ("FRONTEND", "BACKEND"):
                continue
            servers.append({
                "name": r["svname"],
                "status": r.get("status", ""),
                "backup": r.get("bck", "0") == "1",
                "check": r.get("check_status", ""),
                "sessions": int(r["scur"]) if (r.get("scur") or "").isdigit() else 0,
                "changed_sec": int(r["lastchg"]) if (r.get("lastchg") or "").isdigit() else 0,
            })
        up = [s for s in servers if s["status"].startswith("UP")]
        active = next((s for s in up if not s["backup"]), None) or (up[0] if up else None)
        return {"ok": True, "servers": servers, "active": active["name"] if active else None}

    def get_sync(self):
        if not self.syncthing_config:
            return None
        try:
            gui = ET.parse(self.syncthing_config).getroot().find("gui")
            key = gui.findtext("apikey")
            addr = gui.findtext("address") or "127.0.0.1:8384"
            base = "http://" + addr

            def call(path):
                req = urllib.request.Request(base + path, headers={"X-API-Key": key})
                with urllib.request.urlopen(req, timeout=5) as r:
                    return json.loads(r.read().decode("utf-8"))

            cfg = call("/rest/config")
            conns = call("/rest/system/connections").get("connections", {})
            me = call("/rest/system/status").get("myID", "")
            folders = []
            for f in cfg.get("folders", []):
                st = call("/rest/db/status?folder=" + f["id"])
                total = st.get("globalBytes", 0)
                need = st.get("needBytes", 0)
                folders.append({
                    "id": f["id"],
                    "state": st.get("state", ""),
                    "need_files": st.get("needFiles", 0),
                    "need_bytes": need,
                    "errors": st.get("errors", 0),
                    "pct": 100.0 if total == 0 else round(100.0 * (total - need) / total, 1),
                })
            peers = [{"name": d.get("name", d["deviceID"][:7]), "connected": bool(conns.get(d["deviceID"], {}).get("connected"))}
                     for d in cfg.get("devices", []) if d["deviceID"] != me]
            return {"ok": True, "folders": folders, "peers": peers}
        except Exception as e:
            return {"ok": False, "error": type(e).__name__}

    def get_status(self):
        return {
            "host": self.label,
            "time": int(time.time()),
            "units": self.get_units(),
            "failed": self.get_failed(),
            "egress": self.get_egress(),
            "sync": self.get_sync(),
        }

    def get_logs(self, unit, scope, lines=200, cursor="", priority="", query=""):
        if (scope, unit) not in self.allowed:
            return 403, {"error": "unit not allowed"}
        lines = max(1, min(int(lines), MAX_LINES))
        cmd = ["journalctl"] + (["--user"] if scope == "user" else []) + ["-u", unit, "--no-pager", "-o", "json"]
        if cursor:
            cmd += ["--after-cursor", cursor]
        else:
            cmd += ["-n", str(lines)]
        if priority in ("0", "1", "2", "3", "4", "5", "6", "7"):
            cmd += ["-p", priority]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        except Exception as e:
            return 500, {"error": type(e).__name__}
        q = query.lower()[:80]
        entries = []
        last = cursor
        for line in res.stdout.splitlines():
            try:
                j = json.loads(line)
            except ValueError:
                continue
            last = j.get("__CURSOR", last)
            msg = j.get("MESSAGE", "")
            if not isinstance(msg, str):
                msg = "[binary]"
            msg = redact(msg)
            if q and q not in msg.lower():
                continue
            entries.append({
                "ts": int(j.get("__REALTIME_TIMESTAMP", "0")) // 1000,
                "prio": int(j["PRIORITY"]) if str(j.get("PRIORITY", "")).isdigit() else 6,
                "msg": msg,
            })
        if res.returncode != 0 and not entries:
            return 502, {"error": redact(res.stderr.strip())[:200] or "journalctl failed"}
        return 200, {"unit": unit, "entries": entries[-lines:], "cursor": last}

    def restart(self, unit, scope):
        if (scope, unit) not in self.allowed or unit.endswith(".timer"):
            return 403, {"ok": False, "error": "unit not allowed"}
        res = self._systemctl(scope, "restart", unit, timeout=60)
        if res.returncode != 0 and scope == "system" and self.use_sudo:
            res = subprocess.run(["sudo", "-n", "systemctl", "restart", unit], capture_output=True, text=True, timeout=60)
        return (200 if res.returncode == 0 else 500), {"ok": res.returncode == 0, "unit": unit}
