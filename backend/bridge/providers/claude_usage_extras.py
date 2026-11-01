import os
import re
import sys
import json
import time
import glob
import threading
import urllib.request
import urllib.error

from core.config import AUTH_DIR, CLIPROXY_HOME, PROBE_USER_AGENT
from core.utils import fmt_relative_reset_from_iso

REFRESH_SEC = 300
STAGGER_SEC = 4
MAX_AGE_SEC = 6 * 3600
SAMPLES_FILE = os.path.join(CLIPROXY_HOME, "cloud-credit-samples.jsonl")
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"


def num(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")


def scoped_weekly(limits):
    out, seen = [], set()
    for entry in limits if isinstance(limits, list) else []:
        if not isinstance(entry, dict) or entry.get("group") != "weekly" or entry.get("kind") != "weekly_scoped":
            continue
        pct = num(entry.get("percent"))
        scope = entry.get("scope") if isinstance(entry.get("scope"), dict) else {}
        model = scope.get("model") if isinstance(scope.get("model"), dict) else {}
        name = (model.get("display_name") or "").strip()
        ident = model.get("id") or name
        if pct is None or not name or "all-models" in slug(name) or slug(ident).endswith("all-models"):
            continue
        key = slug(ident)
        if key in seen:
            continue
        seen.add(key)
        reset = entry.get("resets_at")
        out.append({"model": name, "used": pct, "reset": reset, "reset_text": fmt_relative_reset_from_iso(reset) if reset else ""})
    return out


def cloud_credits(block):
    if not isinstance(block, dict):
        return None
    limit, used, remaining = num(block.get("limit_dollars")), num(block.get("used_dollars")), num(block.get("remaining_dollars"))
    if limit is None or limit <= 0:
        return None
    if remaining is None and used is not None:
        remaining = limit - used
    if remaining is None or remaining < 0 or remaining > limit:
        return None
    return {"limit": limit, "remaining": remaining, "used": limit - remaining,
            "expires_at": block.get("resets_at"), "locked": bool(block.get("locked_reason"))}


def parse_extras(data):
    extra = data.get("extra_usage") if isinstance(data.get("extra_usage"), dict) else {}
    out = {}
    scoped = scoped_weekly(data.get("limits"))
    if scoped:
        out["scoped_weekly"] = scoped
    credits = cloud_credits(data.get("iguana_necktie"))
    if credits:
        out["cloud_credits"] = credits
    if extra:
        out["extra_usage"] = {"enabled": bool(extra.get("is_enabled")), "limit_reached": bool(extra.get("spend_limit_reached"))}
    return out


def reader_files():
    out = []
    for path in sorted(glob.glob(os.path.join(AUTH_DIR, "claude-*.json"))):
        try:
            with open(path, "r", encoding="utf-8") as f:
                d = json.load(f)
        except (OSError, ValueError):
            continue
        if d.get("refresh_token") and not d.get("disabled"):
            out.append(os.path.basename(path))
    return out


def fetch_usage(token_file):
    try:
        with open(os.path.join(AUTH_DIR, token_file), "r", encoding="utf-8") as f:
            token = json.load(f).get("access_token")
        req = urllib.request.Request(USAGE_URL, headers={
            "Authorization": f"Bearer {token}",
            "User-Agent": PROBE_USER_AGENT,
            "Accept": "application/json",
        })
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (OSError, ValueError, urllib.error.URLError) as e:
        print(f"oauth usage extras failed for {token_file}: {e}", file=sys.stderr)
        return None


def log_sample(token_file, data):
    block = data.get("iguana_necktie")
    if not isinstance(block, dict) or num(block.get("used_dollars")) is None:
        return
    sd = data.get("seven_day") or {}
    row = {"t": int(time.time()), "file": token_file.replace(".json", ""), "used_dollars": block.get("used_dollars"),
           "limit_dollars": block.get("limit_dollars"), "resets_at": block.get("resets_at"), "weekly": sd.get("utilization")}
    try:
        last = None
        if os.path.exists(SAMPLES_FILE):
            with open(SAMPLES_FILE, "rb") as f:
                tail = f.read()[-4000:].decode("utf-8", "ignore").strip().splitlines()
            for line in reversed(tail):
                try:
                    prev = json.loads(line)
                except ValueError:
                    continue
                if prev.get("file") == row["file"]:
                    last = prev
                    break
        if last and last.get("used_dollars") == row["used_dollars"] and last.get("weekly") == row["weekly"]:
            return
        fd = os.open(SAMPLES_FILE, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
        with os.fdopen(fd, "a", encoding="utf-8") as f:
            f.write(json.dumps(row) + "\n")
    except OSError as e:
        print(f"cloud credit sample not saved: {e}", file=sys.stderr)


class UsageExtrasCache:
    def __init__(self, fetcher=fetch_usage, lister=reader_files, interval=REFRESH_SEC, sampler=log_sample):
        self._fetcher = fetcher
        self._lister = lister
        self._interval = interval
        self._sampler = sampler
        self._data = {}
        self._lock = threading.Lock()
        self._started = False

    def start(self):
        with self._lock:
            if self._started:
                return
            self._started = True
        threading.Thread(target=self._loop, daemon=True, name="claude-usage-extras").start()

    def _loop(self):
        while True:
            self.refresh_all()
            time.sleep(self._interval)

    def refresh_all(self):
        files = self._lister()
        for idx, name in enumerate(files):
            self.refresh(name)
            if idx < len(files) - 1:
                time.sleep(STAGGER_SEC)
        with self._lock:
            for name in list(self._data):
                if name not in files:
                    del self._data[name]

    def refresh(self, token_file):
        data = self._fetcher(token_file)
        if not isinstance(data, dict):
            return
        extras = parse_extras(data)
        with self._lock:
            self._data[token_file] = {"at": time.time(), "extras": extras}
        self._sampler(token_file, data)

    def get(self, token_file):
        if not token_file:
            return {}
        with self._lock:
            entry = self._data.get(token_file)
        if not entry:
            return {}
        age = time.time() - entry["at"]
        if age > MAX_AGE_SEC:
            return {}
        out = dict(entry["extras"])
        if age > 3 * self._interval:
            out["extras_stale"] = True
        return out
