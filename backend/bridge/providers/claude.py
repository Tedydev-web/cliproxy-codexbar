"""
Claude Account and Pool Provider
- Handles passive rate-limit sniffing from CLIProxy Management API
- Handles fallback staggered probe with official claude-cli headers
- Manages priority / drain order via native PATCH /fields API
"""

import os
import json
import time
import datetime
import urllib.request
import urllib.error

from core.config import (
    AUTH_DIR,
    ACCOUNTS_FILE,
    MGMT_HOST,
    MGMT_PORT,
    MGMT_SECRET,
    PROBE_CACHE_SEC,
    EXHAUSTED_CACHE_SEC,
    PASSIVE_FRESHNESS_SEC,
    PROBE_STAGGER_SEC,
    PROBE_USER_AGENT
)
from core.utils import fmt_relative_reset_from_ts, fmt_relative_reset_from_iso

class ClaudePoolProvider:
    def __init__(self):
        self._cache = []
        self._last_probe_time = 0
        self._account_probe_timestamps = {}
        self._plan_cache = {}

    def get_plan_tier(self, email):
        if email in self._plan_cache:
            return self._plan_cache[email]

        auth_file = os.path.join(AUTH_DIR, f"claude-{email}.json")
        if not os.path.exists(auth_file):
            return "Max"

        try:
            with open(auth_file, "r", encoding="utf-8") as f:
                d = json.load(f)
            token = d.get("access_token")
            if not token:
                return "Max"

            req = urllib.request.Request(
                "https://api.anthropic.com/api/oauth/profile",
                headers={
                    "Authorization": f"Bearer {token}",
                    "User-Agent": PROBE_USER_AGENT,
                    "Accept": "application/json"
                }
            )
            with urllib.request.urlopen(req, timeout=4) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                tier = data.get("organization", {}).get("rate_limit_tier", "")
                if "20x" in tier:
                    plan = "Max 20x"
                elif "5x" in tier:
                    plan = "Max 5x"
                elif "pro" in tier:
                    plan = "Pro"
                elif "team" in tier:
                    plan = "Team"
                else:
                    plan = "Max"
                self._plan_cache[email] = plan
                return plan
        except Exception:
            if "trthuhuyen" in email:
                return "Max 5x"
            elif "project" in email:
                return "Max 20x"
            return "Max"

    def fetch_passive_quota(self):
        """Fetch RateLimit signals captured passively by CLIProxy from real inferences."""
        url = f"http://{MGMT_HOST}:{MGMT_PORT}/v0/management/auth-files"
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {MGMT_SECRET}",
                "Content-Type": "application/json"
            }
        )
        try:
            with urllib.request.urlopen(req, timeout=2.5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            
            res = {}
            for f in data.get("files", []):
                if f.get("type") == "claude" or "claude-" in f.get("name", ""):
                    email = f.get("email") or f.get("account")
                    if not email and f.get("name", "").startswith("claude-") and f.get("name", "").endswith(".json"):
                        email = f.get("name")[len("claude-"):-len(".json")]

                    quota = f.get("quota") or {}
                    signals = quota.get("signals") or {}
                    if signals:
                        u_5h = int(round(float(signals.get("Anthropic-Ratelimit-Unified-5h-Utilization", "0.0")) * 100))
                        u_wk = int(round(float(signals.get("Anthropic-Ratelimit-Unified-7d-Utilization", "0.0")) * 100))
                        ts_5h = signals.get("Anthropic-Ratelimit-Unified-5h-Reset")
                        ts_wk = signals.get("Anthropic-Ratelimit-Unified-7d-Reset")

                        obs = quota.get("observed_at", "")
                        age_sec = 0
                        if obs:
                            try:
                                obs_dt = datetime.datetime.fromisoformat(obs)
                                age_sec = int((datetime.datetime.now(datetime.timezone.utc) - obs_dt).total_seconds())
                            except Exception:
                                pass

                        res[email] = {
                            "remaining_5h": max(0, 100 - u_5h),
                            "used_5h": u_5h,
                            "reset_5h": fmt_relative_reset_from_ts(ts_5h),
                            "reset_5h_ts": int(float(ts_5h)) if ts_5h else 0,
                            "remaining_weekly": max(0, 100 - u_wk),
                            "used_weekly": u_wk,
                            "reset_weekly": fmt_relative_reset_from_ts(ts_wk),
                            "reset_weekly_ts": int(float(ts_wk)) if ts_wk else 0,
                            "observed_at": obs,
                            "age_sec": age_sec,
                            "priority": f.get("priority", 0)
                        }
            return res
        except Exception:
            return {}

    def probe_single_account(self, task):
        email, token_file, nickname = task
        prev = next((a for a in self._cache if a.get("email") == email), None)
        now = time.time()

        # Smart Cache for weekly exhausted accounts
        if prev and prev.get("remaining_weekly") == 0 and not prev.get("is_probe_error"):
            last_t = self._account_probe_timestamps.get(email, 0)
            if now - last_t < EXHAUSTED_CACHE_SEC:
                return prev

        auth_path = os.path.join(AUTH_DIR, token_file)
        if not os.path.exists(auth_path):
            return {
                "email": email,
                "name": nickname or email,
                "is_available": False,
                "is_probe_error": True,
                "status_text": "Không tìm thấy file token",
                "error_hint": "Thiếu credential file",
                "remaining_5h": 0, "used_5h": 100, "reset_5h": "", "reset_5h_ts": 0,
                "remaining_weekly": 0, "used_weekly": 100, "reset_weekly": "", "reset_weekly_ts": 0,
                "plan": self.get_plan_tier(email)
            }

        try:
            with open(auth_path, "r", encoding="utf-8") as f:
                d = json.load(f)
            token = d.get("access_token")
            if not token:
                raise ValueError("No access token")

            req = urllib.request.Request(
                "https://api.anthropic.com/api/oauth/usage",
                headers={
                    "Authorization": f"Bearer {token}",
                    "User-Agent": PROBE_USER_AGENT,
                    "Accept": "application/json"
                }
            )
            with urllib.request.urlopen(req, timeout=4) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            fh = data.get("five_hour") or {}
            sd = data.get("seven_day") or {}

            fh_util = fh.get("utilization") or 0.0
            sd_util = sd.get("utilization") or 0.0

            u_5h = int(round(fh_util))
            rem_5h = max(0, 100 - u_5h)
            r_5h = fmt_relative_reset_from_iso(fh.get("resets_at"))

            u_wk = int(round(sd_util))
            rem_wk = max(0, 100 - u_wk)
            r_wk = fmt_relative_reset_from_iso(sd.get("resets_at"))

            is_avail = (rem_5h > 0 and rem_wk > 0)
            self._account_probe_timestamps[email] = now

            return {
                "email": email,
                "name": nickname or email,
                "is_available": is_avail,
                "is_probe_error": False,
                "status_text": "Khả dụng" if is_avail else "Hết hạn",
                "error_hint": "",
                "remaining_5h": rem_5h,
                "used_5h": u_5h,
                "reset_5h": r_5h,
                "reset_5h_ts": 0,
                "remaining_weekly": rem_wk,
                "used_weekly": u_wk,
                "reset_weekly": r_wk,
                "reset_weekly_ts": 0,
                "plan": self.get_plan_tier(email)
            }
        except Exception as e:
            is_429 = "429" in str(e)
            return {
                "email": email,
                "name": nickname or email,
                "is_available": prev["is_available"] if prev else False,
                "is_probe_error": True,
                "status_text": "Tạm nghẽn probe (429 upstream)" if is_429 else "Lỗi kết nối probe",
                "error_hint": "Anthropic usage API bị 429 tạm thời (Inference vẫn khả dụng)" if is_429 else str(e),
                "remaining_5h": prev["remaining_5h"] if prev else 0,
                "used_5h": prev["used_5h"] if prev else 100,
                "reset_5h": prev["reset_5h"] if prev else "",
                "reset_5h_ts": prev.get("reset_5h_ts", 0) if prev else 0,
                "remaining_weekly": prev["remaining_weekly"] if prev else 0,
                "used_weekly": prev["used_weekly"] if prev else 100,
                "reset_weekly": prev["reset_weekly"] if prev else "",
                "reset_weekly_ts": prev.get("reset_weekly_ts", 0) if prev else 0,
                "plan": self.get_plan_tier(email)
            }

    def get_pool_status(self):
        now = time.time()
        if now - self._last_probe_time < PROBE_CACHE_SEC and self._cache:
            return self._cache

        tasks = []
        if os.path.exists(ACCOUNTS_FILE):
            try:
                with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
                    acc_data = json.load(f)
                claude_info = acc_data.get("providers", {}).get("claude", {})
                ordered_ids = claude_info.get("drainOrder", {}).get("orderedIds", [])
                accounts_dict = claude_info.get("accounts", {})
                for em in ordered_ids:
                    acc = accounts_dict.get(em, {})
                    tf = acc.get("tokenFile", f"claude-{em}.json")
                    nick = acc.get("nickname", em)
                    tasks.append((em, tf, nick))
            except Exception:
                pass

        if not tasks and os.path.exists(AUTH_DIR):
            for fn in sorted(os.listdir(AUTH_DIR)):
                if fn.startswith("claude-") and fn.endswith(".json"):
                    em = fn[len("claude-"):-len(".json")]
                    tasks.append((em, fn, em))

        if not tasks:
            return self._cache

        # Step 1: Passive Sniffing
        passive = self.fetch_passive_quota()
        results = []
        probe_needed = []

        for task in tasks:
            em, tf, nick = task
            if em in passive:
                p = passive[em]
                if p["age_sec"] < PASSIVE_FRESHNESS_SEC or p["remaining_weekly"] == 0:
                    is_avail = (p["remaining_5h"] > 0 and p["remaining_weekly"] > 0)
                    results.append({
                        "email": em,
                        "name": nick or em,
                        "is_available": is_avail,
                        "is_probe_error": False,
                        "status_text": "Khả dụng" if is_avail else "Hết hạn",
                        "error_hint": "",
                        "remaining_5h": p["remaining_5h"],
                        "used_5h": p["used_5h"],
                        "reset_5h": p["reset_5h"],
                        "reset_5h_ts": p.get("reset_5h_ts", 0),
                        "remaining_weekly": p["remaining_weekly"],
                        "used_weekly": p["used_weekly"],
                        "reset_weekly": p["reset_weekly"],
                        "reset_weekly_ts": p.get("reset_weekly_ts", 0),
                        "plan": self.get_plan_tier(em)
                    })
                    continue
            probe_needed.append(task)

        # Step 2: Fallback direct probe
        for idx, task in enumerate(probe_needed):
            res = self.probe_single_account(task)
            results.append(res)
            if idx < len(probe_needed) - 1:
                time.sleep(PROBE_STAGGER_SEC)

        # Preserve intended drain order
        order_keys = [t[0] for t in tasks]
        results.sort(key=lambda x: order_keys.index(x["email"]) if x["email"] in order_keys else 999)

        self._cache = results
        self._last_probe_time = now
        return results

    def set_accounts_order(self, ordered_emails):
        if not ordered_emails or not isinstance(ordered_emails, list):
            return False

        # 1. Update accounts.json drainOrder
        try:
            if os.path.exists(ACCOUNTS_FILE):
                with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
                    acc_data = json.load(f)
                if "providers" in acc_data and "claude" in acc_data["providers"]:
                    if "drainOrder" not in acc_data["providers"]["claude"]:
                        acc_data["providers"]["claude"]["drainOrder"] = {"mode": "manual"}
                    acc_data["providers"]["claude"]["drainOrder"]["orderedIds"] = ordered_emails
                    with open(ACCOUNTS_FILE, "w", encoding="utf-8") as f:
                        json.dump(acc_data, f, indent=2)
        except Exception:
            pass

        # 2. Update priority via Management API
        total = len(ordered_emails)
        for idx, em in enumerate(ordered_emails):
            prio = max(1, total - idx + 1)
            fn = f"claude-{em}.json"
            try:
                req = urllib.request.Request(
                    f"http://{MGMT_HOST}:{MGMT_PORT}/v0/management/auth-files/fields",
                    data=json.dumps({"name": fn, "priority": prio}).encode("utf-8"),
                    headers={
                        "Authorization": f"Bearer {MGMT_SECRET}",
                        "Content-Type": "application/json"
                    },
                    method="PATCH"
                )
                with urllib.request.urlopen(req, timeout=3):
                    pass
            except Exception:
                # Fallback direct atomic disk update
                fpath = os.path.join(AUTH_DIR, fn)
                if os.path.exists(fpath):
                    try:
                        with open(fpath, "r", encoding="utf-8") as fp:
                            ad = json.load(fp)
                        ad["priority"] = prio
                        with open(fpath, "w", encoding="utf-8") as fp:
                            json.dump(ad, fp, indent=2)
                    except Exception:
                        pass

        self._last_probe_time = 0
        return True
