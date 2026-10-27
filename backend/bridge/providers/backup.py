import json
import os
import re
import threading
import time
import urllib.request

from core import config_file
from core.config import CLIPROXY_HOME, PROBE_CACHE_SEC

STATE_FILE = os.path.join(CLIPROXY_HOME, "backup-state.json")
ENTRY = re.compile(r"^        - name: (aperture(?:-backup-[a-z]+)?)\n(.*?)(?=^        - name: |^    \S|^\S)", re.M | re.S)
BASE_URL = re.compile(r"^\s+base-url: (\S+)\s*$", re.M)
DISABLED = re.compile(r"^(\s+disabled: )(true|false)$", re.M)
MODELS = {
    "deepseek": {"id": "deepseek-v4.1-flash", "upstream": "deepseek/deepseek-v4.1-flash", "label": "DeepSeek v4.1 Flash"},
    "luna": {"id": "gpt-5.6-luna", "upstream": "openai/gpt-5.6-luna", "label": "GPT-5.6 Luna"},
}
DEFAULT_MODEL = "deepseek"


class BackupProvider:
    def __init__(self):
        self._probe_lock = threading.Lock()
        self._probe = {"online": False, "latency_ms": 0, "listed": set(), "checked_at": 0}
        self._last_probe = 0.0

    def _entries(self, text):
        out = {}
        for m in ENTRY.finditer(text):
            body = m.group(2)
            bm = BASE_URL.search(body)
            dm = DISABLED.search(body)
            out[m.group(1)] = {"base_url": bm.group(1) if bm else "", "disabled": (dm.group(2) == "true") if dm else False}
        return out

    def _selected(self):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                key = json.load(f).get("model")
            return key if key in MODELS else DEFAULT_MODEL
        except (OSError, ValueError):
            return DEFAULT_MODEL

    def _save_selected(self, key):
        tmp = STATE_FILE + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump({"model": key}, f)
        os.replace(tmp, STATE_FILE)

    def _refresh_probe(self, base_url):
        if time.time() - self._last_probe < PROBE_CACHE_SEC and self._probe["checked_at"]:
            return
        if not base_url or not self._probe_lock.acquire(blocking=False):
            return
        try:
            started = time.time()
            try:
                with urllib.request.urlopen(urllib.request.Request(base_url.rstrip("/") + "/models"), timeout=4) as r:
                    data = json.loads(r.read().decode("utf-8"))
                listed = {m.get("id") for m in data.get("data", [])}
                self._probe = {"online": True, "latency_ms": int((time.time() - started) * 1000), "listed": listed, "checked_at": int(started)}
            except Exception:
                self._probe = {"online": False, "latency_ms": 0, "listed": set(), "checked_at": int(started)}
            self._last_probe = time.time()
        finally:
            self._probe_lock.release()

    def get_state(self):
        try:
            entries = self._entries(config_file.read())
        except OSError:
            return None
        main = entries.get("aperture")
        if not main:
            return None
        self._refresh_probe(main["base_url"])
        active = next((k for k in MODELS if k in {n.replace("aperture-backup-", "") for n, e in entries.items() if n.startswith("aperture-backup-") and not e["disabled"]}), None)
        selected = active or self._selected()
        probe = self._probe
        return {
            "name": "Aperture",
            "base_url": main["base_url"],
            "online": probe["online"],
            "latency_ms": probe["latency_ms"],
            "checked_at": probe["checked_at"],
            "fallback": {"enabled": active is not None, "model": selected},
            "models": [
                {"key": k, "id": v["id"], "label": v["label"], "usable": probe["online"] and v["upstream"] in probe["listed"], "selected": k == selected}
                for k, v in MODELS.items()
            ],
        }

    def set_fallback(self, enabled=None, model=None):
        if model is not None and model not in MODELS:
            return 400, {"error": f"model must be one of {sorted(MODELS)}"}
        state = self.get_state()
        if not state:
            return 404, {"error": "aperture entry not found"}
        target_model = model or state["fallback"]["model"]
        want = state["fallback"]["enabled"] if enabled is None else bool(enabled)
        if want:
            usable = next((m["usable"] for m in state["models"] if m["key"] == target_model), False)
            if not usable:
                return 409, {"error": "Aperture không kết nối được hoặc model này không khả dụng"}
        with config_file.LOCK:
            text = config_file.read()
            new = text

            def apply(m):
                name = m.group(1)
                if not name.startswith("aperture-backup-"):
                    return m.group(0)
                key = name.replace("aperture-backup-", "")
                disabled = not (want and key == target_model)
                return DISABLED.sub(lambda d: d.group(1) + ("true" if disabled else "false"), m.group(0), count=1)

            new = ENTRY.sub(apply, text)
            config_file.write_in_place(new, text, ".bak-backup")
        self._save_selected(target_model)
        return 200, {"ok": True, "backup": self.get_state()}
