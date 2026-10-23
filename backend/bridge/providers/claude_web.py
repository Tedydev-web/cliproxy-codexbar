"""
Claude claude.ai web-session source.
Background cache over the claude-web-session CLI: the request path only reads memory and never blocks on the network.
Behaviour ported from CodexBar (MIT, Copyright (c) 2026 Peter Steinberger): web usage as a fallback and as
enrichment of the primary source, last-known data kept with its original capture time, background refresh.
"""

import os
import sys
import json
import time
import glob
import threading
import subprocess

from core.config import (
    CLIPROXY_HOME,
    WEB_SESSION_BIN,
    WEB_REFRESH_SEC,
    WEB_STAGGER_SEC,
    WEB_SUBPROCESS_TIMEOUT_SEC,
    WEB_USE_MAX_AGE_SEC,
)
from core.utils import parse_iso_datetime, fmt_relative_reset_from_ts

WEB_STORE = os.path.join(CLIPROXY_HOME, "web-sessions")
EXTRA_KEYS = ("scoped_weekly", "cloud_credits", "extra_usage")


def stored_emails():
    out = []
    for path in sorted(glob.glob(os.path.join(WEB_STORE, "*.json"))):
        try:
            with open(path, "r", encoding="utf-8") as f:
                out.append(json.load(f)["email"])
        except (OSError, ValueError, KeyError):
            continue
    return out


def run_check(email):
    try:
        proc = subprocess.run(
            [WEB_SESSION_BIN, "check", email, "--no-recover"],
            capture_output=True, text=True, timeout=WEB_SUBPROCESS_TIMEOUT_SEC,
        )
        line = next((l for l in proc.stdout.splitlines() if l.startswith("{")), "")
        return json.loads(line) if line else None
    except (subprocess.TimeoutExpired, OSError, ValueError) as e:
        print(f"web session check failed for {email}: {e}", file=sys.stderr)
        return None


def iso_ts(value):
    dt = parse_iso_datetime(value) if value else None
    return int(dt.timestamp()) if dt else 0


class WebSessionCache:
    def __init__(self, runner=run_check, lister=stored_emails, interval=WEB_REFRESH_SEC):
        self._runner = runner
        self._lister = lister
        self._interval = interval
        self._data = {}
        self._lock = threading.Lock()
        self._started = False

    def start(self):
        with self._lock:
            if self._started:
                return
            self._started = True
        threading.Thread(target=self._loop, daemon=True, name="claude-web-refresh").start()

    def _loop(self):
        while True:
            self.refresh_all()
            time.sleep(self._interval)

    def refresh_all(self):
        emails = self._lister()
        for idx, email in enumerate(emails):
            self.refresh(email)
            if idx < len(emails) - 1:
                time.sleep(WEB_STAGGER_SEC)
        with self._lock:
            for email in list(self._data):
                if email not in emails:
                    del self._data[email]

    def refresh(self, email):
        result = self._runner(email)
        if result is None:
            return
        with self._lock:
            self._data[email] = {"at": time.time(), "result": result}

    def get(self, email):
        with self._lock:
            entry = self._data.get(email)
        if not entry:
            return None
        out = dict(entry["result"])
        out["cache_age_sec"] = int(time.time() - entry["at"])
        return out


def usable_as_primary(web):
    if not web or web.get("error"):
        return False
    if web.get("used_5h") is None or web.get("used_weekly") is None:
        return False
    if web.get("stale"):
        stale_at = parse_iso_datetime(web.get("stale_since"))
        if not stale_at or time.time() - stale_at.timestamp() > WEB_USE_MAX_AGE_SEC:
            return False
    return True


def as_probe(web):
    ts_5h, ts_wk = iso_ts(web.get("reset_5h")), iso_ts(web.get("reset_weekly"))
    return {
        "used_5h": int(round(web["used_5h"])),
        "reset_5h": fmt_relative_reset_from_ts(ts_5h) if ts_5h else "",
        "reset_5h_ts": ts_5h,
        "used_weekly": int(round(web["used_weekly"])),
        "reset_weekly": fmt_relative_reset_from_ts(ts_wk) if ts_wk else "",
        "reset_weekly_ts": ts_wk,
    }


def extras(web):
    if not web or web.get("error"):
        return {}
    out = {k: web.get(k) for k in EXTRA_KEYS if web.get(k)}
    if web.get("stale"):
        out["web_stale"] = True
    return out
