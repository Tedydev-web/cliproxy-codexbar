import json
import os
import re
import shutil
import threading
import time
import urllib.error
import urllib.request

from core.config import CLIPROXY_HOME

CONFIG_FILE = os.path.join(CLIPROXY_HOME, "config.yaml")
ENTRY_NAME = "anthropic-console-direct"
PRIMARY_PRIORITY = 100
FALLBACK_PRIORITY = 0
BLOCK = re.compile(
    r"(- name: " + re.escape(ENTRY_NAME) + r"\n(?:[ \t]+(?!priority:)[^\n]*\n)*?[ \t]+priority: )(-?\d+)"
)
KEY_LINE = re.compile(r"^\s*- api-key: \S+\s*$", re.M)
KEY_PAIR = re.compile(r'^\s*- api-key: (\S+)\s*\n\s*prefix: "([^"]+)"', re.M)
API = "https://api.anthropic.com/v1"
PROBE_INTERVAL_SEC = 600
PROBE_MODEL = "claude-haiku-4-5-20251001"


def _call(key, path, body=None):
    headers = {"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(urllib.request.Request(API + path, data=data, headers=headers), timeout=15) as r:
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
    if key not in org_cache and state != "invalid":
        s2, org = _call(key, "/organizations/me")
        if s2 == 200:
            org_cache[key] = org.get("name", "")
    return state, org_cache.get(key, "")


class ConsoleRouteProvider:
    def __init__(self):
        self._lock = threading.Lock()
        self._key_status = []
        self._org_cache = {}
        self._started = False

    def start(self):
        if self._started:
            return
        self._started = True
        threading.Thread(target=self._probe_loop, daemon=True).start()

    def _probe_loop(self):
        while True:
            try:
                self._probe_all()
            except Exception:
                pass
            time.sleep(PROBE_INTERVAL_SEC)

    def _probe_all(self):
        text = self._read()
        block = text.split("\nrequests:")[0]
        result = []
        for key, prefix in KEY_PAIR.findall(block):
            state, org = probe_key(key, self._org_cache)
            result.append({"prefix": prefix, "org": org, "state": state, "checked_at": int(time.time())})
        self._key_status = result

    def _read(self):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return f.read()

    def get_state(self):
        try:
            text = self._read()
        except OSError:
            return None
        m = BLOCK.search(text)
        if not m:
            return None
        priority = int(m.group(2))
        tail = text[m.end():]
        keys = len(KEY_LINE.findall(tail.split("\nrequests:")[0]))
        return {
            "name": ENTRY_NAME,
            "mode": "primary" if priority > FALLBACK_PRIORITY else "fallback",
            "priority": priority,
            "keys": keys,
            "key_status": list(self._key_status),
        }

    def set_mode(self, mode):
        if mode not in ("primary", "fallback"):
            return 400, {"error": "mode must be 'primary' or 'fallback'"}
        target = PRIMARY_PRIORITY if mode == "primary" else FALLBACK_PRIORITY
        with self._lock:
            try:
                text = self._read()
            except OSError as e:
                return 500, {"error": f"config unreadable: {e}"}
            if not BLOCK.search(text):
                return 404, {"error": f"entry '{ENTRY_NAME}' not found"}
            new = BLOCK.sub(lambda m: m.group(1) + str(target), text, count=1)
            if new != text:
                shutil.copy2(CONFIG_FILE, CONFIG_FILE + ".bak-console-route")
                tmp = CONFIG_FILE + ".tmp"
                fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                with os.fdopen(fd, "w", encoding="utf-8") as f:
                    f.write(new)
                    f.flush()
                    os.fsync(f.fileno())
                os.replace(tmp, CONFIG_FILE)
        return 200, {"ok": True, "console": self.get_state()}
