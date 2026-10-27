import hashlib
import json
import os
import re
import shutil
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from core.config import CLIPROXY_HOME, PROBE_CACHE_SEC

CONFIG_FILE = os.path.join(CLIPROXY_HOME, "config.yaml")
API = "https://api.anthropic.com/v1"
PROBE_MODEL = "claude-haiku-4-5-20251001"
ID_PATTERN = re.compile(r"^capi\d+$")
ENTRY = re.compile(r"^        - name: console-(capi\d+)\n(.*?)(?=^        - name: |^\S)", re.M | re.S)
PRIORITY = re.compile(r"^(\s+priority: )(-?\d+)$", re.M)
KEY = re.compile(r"^\s+- api-key: (\S+)\s*$", re.M)
EXCLUDE_ALL = '          excluded-models:\n            - "*"\n'
EXCLUDE_BLOCK = re.compile(r"          excluded-models:\n(?:            - [^\n]*\n)+")


def is_console_id(value):
    return bool(ID_PATTERN.match(str(value or "")))


def _call(key, path, body=None):
    headers = {"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(urllib.request.Request(API + path, data=data, headers=headers), timeout=8) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode() or "{}")
        except Exception:
            return e.code, {}
    except Exception:
        return 0, {}


def probe_key(key, org_cache):
    status, body = _call(key, "/messages", {"model": PROBE_MODEL, "max_tokens": 1, "messages": [{"role": "user", "content": "hi"}]})
    message = ((body.get("error") or {}).get("message") or "").lower()
    if status == 200:
        state = "ok"
    elif "credit balance" in message:
        state = "no_credit"
    elif status in (401, 403):
        state = "invalid"
    elif status == 429:
        state = "rate_limited"
    else:
        state = "error"
    tag = hashlib.sha256(key.encode()).hexdigest()
    if tag not in org_cache and state != "invalid":
        s2, org = _call(key, "/organizations/me")
        if s2 == 200:
            org_cache[tag] = org.get("name", "")
    return state, org_cache.get(tag, "")


class ConsoleRouteProvider:
    def __init__(self):
        self._lock = threading.Lock()
        self._probe_lock = threading.Lock()
        self._status = {}
        self._org_cache = {}
        self._last_probe = 0.0

    def _read(self):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return f.read()

    def _entries(self, text):
        out = []
        for m in ENTRY.finditer(text):
            body = m.group(2)
            pm = PRIORITY.search(body)
            km = KEY.search(body)
            out.append({
                "id": m.group(1),
                "priority": int(pm.group(2)) if pm else 0,
                "enabled": not EXCLUDE_BLOCK.search(body),
                "key": km.group(1) if km else "",
            })
        return sorted(out, key=lambda e: int(e["id"][4:]))

    def _refresh_status(self, entries):
        now = time.time()
        if now - self._last_probe < PROBE_CACHE_SEC and self._status:
            return
        if not self._probe_lock.acquire(blocking=False):
            return
        try:
            live = [e for e in entries if e["enabled"] and e["key"]]
            with ThreadPoolExecutor(max_workers=max(1, len(live))) as pool:
                results = list(pool.map(lambda e: probe_key(e["key"], self._org_cache), live))
            fresh = {}
            for e, (state, org) in zip(live, results):
                fresh[e["id"]] = {"state": state, "org": org, "checked_at": int(now)}
            self._status = fresh
            self._last_probe = now
        finally:
            self._probe_lock.release()

    def get_keys(self):
        try:
            entries = self._entries(self._read())
        except OSError:
            return []
        self._refresh_status(entries)
        keys = []
        for e in entries:
            st = self._status.get(e["id"], {})
            keys.append({
                "id": e["id"],
                "priority": e["priority"],
                "enabled": e["enabled"],
                "state": st.get("state", "disabled" if not e["enabled"] else "unknown"),
                "org": st.get("org", ""),
                "checked_at": st.get("checked_at", 0),
            })
        return keys

    def _write(self, new, old):
        if new == old:
            return
        shutil.copy2(CONFIG_FILE, CONFIG_FILE + ".bak-console-route")
        tmp = CONFIG_FILE + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, CONFIG_FILE)

    def _edit(self, edits):
        with self._lock:
            try:
                text = self._read()
            except OSError as e:
                return 500, {"error": f"config unreadable: {e}"}
            known = {e["id"] for e in self._entries(text)}
            missing = [i for i in edits if i not in known]
            if missing:
                return 404, {"error": f"unknown console key: {missing[0]}"}

            def apply(m):
                fn = edits.get(m.group(1))
                return m.group(0) if not fn else fn(m.group(0))

            self._write(ENTRY.sub(apply, text), text)
        self._last_probe = 0.0
        return 200, {"ok": True}

    def set_priorities(self, mapping):
        if not mapping:
            return 200, {"ok": True}
        edits = {i: (lambda block, p=p: PRIORITY.sub(lambda m: m.group(1) + str(p), block, count=1)) for i, p in mapping.items()}
        return self._edit(edits)

    def set_enabled(self, console_id, enabled):
        def fn(block):
            stripped = EXCLUDE_BLOCK.sub("", block)
            if enabled:
                return stripped
            return re.sub(r"(          base-url: [^\n]*\n)", lambda m: m.group(1) + EXCLUDE_ALL, stripped, count=1)

        return self._edit({console_id: fn})
