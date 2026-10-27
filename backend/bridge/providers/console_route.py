import os
import re
import shutil
import threading

from core.config import CLIPROXY_HOME

CONFIG_FILE = os.path.join(CLIPROXY_HOME, "config.yaml")
ENTRY_NAME = "anthropic-console-direct"
PRIMARY_PRIORITY = 100
FALLBACK_PRIORITY = 0
BLOCK = re.compile(
    r"(- name: " + re.escape(ENTRY_NAME) + r"\n(?:[ \t]+(?!priority:)[^\n]*\n)*?[ \t]+priority: )(-?\d+)"
)
KEY_LINE = re.compile(r"^\s*- api-key: \S+\s*$", re.M)


class ConsoleRouteProvider:
    def __init__(self):
        self._lock = threading.Lock()

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
