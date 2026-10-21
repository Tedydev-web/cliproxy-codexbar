"""
Claude Account and Pool Provider
- Handles passive rate-limit sniffing from CLIProxy Management API
- Handles fallback staggered probe with official claude-cli headers
- Manages priority / drain order via native PATCH /fields API
"""

import os
import sys
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
    HEADER_PROBE_SEC,
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
        self._header_probe_cache = {}

    def get_plan_tier(self, email):
        if email in self._plan_cache:
            return self._plan_cache[email]

        token_file = f"claude-{email}.json"
        if os.path.exists(ACCOUNTS_FILE):
            try:
                with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
                    acc = json.load(f)
                info = acc.get("providers", {}).get("claude", {}).get("accounts", {}).get(email, {})
                token_file = info.get("tokenFile", token_file)
            except Exception:
                pass
        auth_file = os.path.join(AUTH_DIR, token_file)
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
                    fname = f.get("name", "")

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

                        res[fname] = {
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

    def _setup_token_meta(self, token_file):
        try:
            with open(os.path.join(AUTH_DIR, token_file), "r", encoding="utf-8") as f:
                d = json.load(f)
        except (OSError, ValueError):
            return None
        return None if d.get("refresh_token") else d

    def _oauth_reader_file(self, real_email, exclude):
        if not real_email or not os.path.isdir(AUTH_DIR):
            return None
        for fn in sorted(os.listdir(AUTH_DIR)):
            if not (fn.startswith("claude-") and fn.endswith(".json")) or fn == exclude:
                continue
            try:
                with open(os.path.join(AUTH_DIR, fn), "r", encoding="utf-8") as f:
                    d = json.load(f)
            except (OSError, ValueError):
                continue
            if d.get("refresh_token") and d.get("email") == real_email and not d.get("disabled"):
                return fn
        return None

    def _header_probe(self, token_file):
        now = time.time()
        cached = self._header_probe_cache.get(token_file)
        if cached and now - cached[0] < HEADER_PROBE_SEC:
            return cached[1]
        p = None
        try:
            with open(os.path.join(AUTH_DIR, token_file), "r", encoding="utf-8") as f:
                token = json.load(f).get("access_token")
            req = urllib.request.Request(
                "https://api.anthropic.com/v1/messages",
                data=json.dumps({
                    "model": "claude-haiku-4-5-20251001",
                    "max_tokens": 1,
                    "system": "You are Claude Code, Anthropic's official CLI for Claude.",
                    "messages": [{"role": "user", "content": "hi"}]
                }).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {token}",
                    "anthropic-version": "2023-06-01",
                    "anthropic-beta": "oauth-2025-04-20",
                    "Content-Type": "application/json",
                    "User-Agent": PROBE_USER_AGENT
                },
                method="POST"
            )
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    h = resp.headers
            except urllib.error.HTTPError as e:
                h = e.headers
            u_5h = h.get("anthropic-ratelimit-unified-5h-utilization")
            u_wk = h.get("anthropic-ratelimit-unified-7d-utilization")
            if u_5h is None or u_wk is None:
                raise ValueError("response has no unified rate-limit headers")
            ts_5h = h.get("anthropic-ratelimit-unified-5h-reset")
            ts_wk = h.get("anthropic-ratelimit-unified-7d-reset")
            p = {
                "used_5h": int(round(float(u_5h) * 100)),
                "reset_5h": fmt_relative_reset_from_ts(ts_5h),
                "reset_5h_ts": int(float(ts_5h)) if ts_5h else 0,
                "used_weekly": int(round(float(u_wk) * 100)),
                "reset_weekly": fmt_relative_reset_from_ts(ts_wk),
                "reset_weekly_ts": int(float(ts_wk)) if ts_wk else 0
            }
        except Exception as e:
            print(f"header probe failed for {token_file}: {e}", file=sys.stderr)
        self._header_probe_cache[token_file] = (now, p)
        return p

    def _setup_token_status(self, email, token_file, nickname, meta, passive):
        if passive and passive.get("age_sec", PASSIVE_FRESHNESS_SEC) < PASSIVE_FRESHNESS_SEC:
            return self._setup_token_result(email, nickname, passive)
        reader = self._oauth_reader_file(meta.get("email"), token_file)
        if reader:
            r = self.probe_single_account((email, reader, nickname))
            if not r.get("is_probe_error"):
                return r
        return self._setup_token_result(email, nickname, self._header_probe(token_file) or passive)

    def _setup_token_result(self, email, nickname, p):
        now = time.time()
        live_5h = bool(p) and p.get("reset_5h_ts", 0) > now
        live_wk = bool(p) and p.get("reset_weekly_ts", 0) > now
        u_5h = p["used_5h"] if live_5h else 0
        u_wk = p["used_weekly"] if live_wk else 0
        is_avail = u_5h < 100 and u_wk < 100
        return {
            "email": email,
            "name": nickname or email,
            "is_available": is_avail,
            "is_probe_error": False,
            "status_text": "Khả dụng" if is_avail else "Hết hạn",
            "error_hint": "" if p else "Setup-token: quota chỉ cập nhật khi có request đi qua proxy",
            "remaining_5h": 100 - u_5h,
            "used_5h": u_5h,
            "reset_5h": p["reset_5h"] if live_5h else "",
            "reset_5h_ts": p.get("reset_5h_ts", 0) if live_5h else 0,
            "remaining_weekly": 100 - u_wk,
            "used_weekly": u_wk,
            "reset_weekly": p["reset_weekly"] if live_wk else "",
            "reset_weekly_ts": p.get("reset_weekly_ts", 0) if live_wk else 0,
            "plan": self.get_plan_tier(email)
        }

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
        setup_expiry = {}

        for task in tasks:
            em, tf, nick = task
            meta = self._setup_token_meta(tf)
            if meta is not None:
                setup_expiry[em] = meta.get("expired") or ""
                results.append(self._setup_token_status(em, tf, nick, meta, passive.get(tf)))
                continue
            if tf in passive:
                p = passive[tf]
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

        # Step 3: Safely include paused / quarantined accounts for menubar visibility without probing
        paused_dir = os.path.expanduser("~/.cliproxy/auth-paused")
        if os.path.exists(paused_dir):
            for fn in sorted(os.listdir(paused_dir)):
                if fn.startswith("claude-") and fn.endswith(".json"):
                    em = fn[len("claude-"):-len(".json")]
                    if not any(r.get("email") == em for r in results):
                        results.append({
                            "email": em,
                            "name": em,
                            "is_available": False,
                            "is_paused": True,
                            "is_probe_error": False,
                            "status_text": "Tạm dừng (auth-paused)",
                            "error_hint": "OAuth token hết hạn. Cần đăng nhập lại để kích hoạt lại.",
                            "remaining_5h": 0,
                            "used_5h": 100,
                            "reset_5h": "",
                            "reset_5h_ts": 0,
                            "remaining_weekly": 0,
                            "used_weekly": 100,
                            "reset_weekly": "Cần login lại",
                            "reset_weekly_ts": 0,
                            "plan": "Paused"
                        })
        # Step 4: Enrich with 30-day OAuth lifecycle telemetry
        now_utc = datetime.datetime.now(datetime.timezone.utc)

        accounts_dict = {}
        if os.path.exists(ACCOUNTS_FILE):
            try:
                with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
                    acc_json = json.load(f)
                accounts_dict = acc_json.get("providers", {}).get("claude", {}).get("accounts", {})
            except Exception:
                pass

        for r in results:
            em = r.get("email")
            info = accounts_dict.get(em, {})
            created_str = info.get("authorizedAt") or info.get("lastUsedAt") or info.get("createdAt")
            created_dt = None
            if created_str:
                try:
                    created_dt = datetime.datetime.fromisoformat(created_str.replace("Z", "+00:00"))
                except Exception:
                    pass
            
            rt_exp_dt = None
            warn_days = 5
            if r.get("is_paused"):
                pass
            elif em in setup_expiry:
                try:
                    rt_exp_dt = datetime.datetime.fromisoformat(setup_expiry[em].replace("Z", "+00:00"))
                    if rt_exp_dt.tzinfo is None:
                        rt_exp_dt = rt_exp_dt.astimezone()
                except ValueError:
                    rt_exp_dt = None
                warn_days = 30
            elif created_dt:
                rt_exp_dt = created_dt + datetime.timedelta(days=30)

            if rt_exp_dt:
                diff = rt_exp_dt - now_utc
                days_left = diff.days
                hours_left = diff.seconds // 3600
                r["days_left_30d"] = max(0, days_left)
                r["hours_left_30d"] = max(0, hours_left)
                r["expiry_30d_str"] = rt_exp_dt.astimezone().strftime("%d/%m/%Y %H:%M")
                if diff.total_seconds() <= 0:
                    r["lifecycle_status"] = "expired"
                    r["lifecycle_label"] = "Đã quá hạn 30 ngày"
                elif days_left <= 3:
                    r["lifecycle_status"] = "critical"
                    r["lifecycle_label"] = f"Hết hạn sau {days_left}d {hours_left}h"
                elif days_left <= warn_days:
                    r["lifecycle_status"] = "warning"
                    r["lifecycle_label"] = f"Hết hạn sau {days_left}d"
                else:
                    r["lifecycle_status"] = "healthy"
                    r["lifecycle_label"] = f"Còn {days_left} ngày"
            else:
                r["days_left_30d"] = None
                r["hours_left_30d"] = None
                r["expiry_30d_str"] = ""
                r["lifecycle_status"] = "unknown"
                r["lifecycle_label"] = ""

        self._cache = results
        self._last_probe_time = now
        return results

    def set_accounts_order(self, ordered_emails):
        if not ordered_emails or not isinstance(ordered_emails, list):
            return False

        # 1. Update accounts.json drainOrder
        accounts_dict = {}
        try:
            if os.path.exists(ACCOUNTS_FILE):
                with open(ACCOUNTS_FILE, "r", encoding="utf-8") as f:
                    acc_data = json.load(f)
                if "providers" in acc_data and "claude" in acc_data["providers"]:
                    accounts_dict = acc_data["providers"]["claude"].get("accounts", {})
                    ordered_emails = [e for e in ordered_emails if accounts_dict.get(e, {}).get("status") != "paused"]
                    if "drainOrder" not in acc_data["providers"]["claude"]:
                        acc_data["providers"]["claude"]["drainOrder"] = {"mode": "manual"}
                    acc_data["providers"]["claude"]["drainOrder"]["orderedIds"] = ordered_emails
                    tmp_path = ACCOUNTS_FILE + ".tmp"
                    with open(tmp_path, "w", encoding="utf-8") as f:
                        json.dump(acc_data, f, indent=2)
                        f.flush()
                        os.fsync(f.fileno())
                    os.replace(tmp_path, ACCOUNTS_FILE)
        except Exception as e:
            print(f"set_accounts_order: accounts.json write failed: {e}", file=sys.stderr)

        # 2. Update priority via Management API
        total = len(ordered_emails)
        for idx, em in enumerate(ordered_emails):
            prio = max(1, total - idx + 1)
            fn = accounts_dict.get(em, {}).get("tokenFile", f"claude-{em}.json")
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
            except Exception as e:
                print(f"set_accounts_order: priority PATCH failed for {fn}: {e}", file=sys.stderr)

        self._last_probe_time = 0
        return True
