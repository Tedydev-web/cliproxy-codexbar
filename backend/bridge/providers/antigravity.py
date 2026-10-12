"""
Antigravity (Google Cloud Code) Provider
Handles Google CloudCode quota summary and available models endpoints.
"""

import os
import json
import time
import urllib.request
import urllib.error

from core.config import AGY_AUTH_FILE, AGY_CACHE_SEC, AGY_USER_AGENT
from core.utils import fmt_relative_reset_from_iso, fmt_local_datetime

class AntigravityProvider:
    def __init__(self):
        self._cache_data = None
        self._last_probe_time = 0

    def get_quota(self):
        now = time.time()
        if self._cache_data and (now - self._last_probe_time < AGY_CACHE_SEC):
            return self._cache_data

        if not os.path.exists(AGY_AUTH_FILE):
            return None

        try:
            with open(AGY_AUTH_FILE, "r", encoding="utf-8") as f:
                d = json.load(f)

            token = d.get("access_token")
            project = d.get("project_id")
            email = d.get("email", "hieudat2310.bh@gmail.com")

            req_headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "User-Agent": AGY_USER_AGENT
            }
            body = json.dumps({"project": project} if project else {}).encode("utf-8")

            gemini_5h_rem = 100
            gemini_5h_rel = ""
            gemini_wk_rem = 100
            gemini_wk_rel = ""
            claude_5h_rem = 100
            claude_5h_rel = "5h 0m"
            claude_wk_rem = 100
            claude_wk_rel = ""

            # 1. Quota Summary
            try:
                url_sum = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
                req_sum = urllib.request.Request(url_sum, data=body, headers=req_headers)
                with urllib.request.urlopen(req_sum, timeout=5) as resp:
                    summary_data = json.loads(resp.read().decode("utf-8"))

                for grp in summary_data.get("groups", []):
                    grp_name = grp.get("displayName", "").lower()
                    for b in grp.get("buckets", []):
                        b_id = b.get("bucketId", "")
                        rem_pct = int(round(b.get("remainingFraction", 1.0) * 100))
                        rel_time = fmt_relative_reset_from_iso(b.get("resetTime", ""))

                        if b_id == "gemini-5h" or ("gemini" in grp_name and b.get("window") == "5h"):
                            gemini_5h_rem = rem_pct
                            gemini_5h_rel = rel_time
                        elif b_id == "gemini-weekly" or ("gemini" in grp_name and b.get("window") == "weekly"):
                            gemini_wk_rem = rem_pct
                            gemini_wk_rel = rel_time
                        elif b_id == "3p-5h" or (("claude" in grp_name or "gpt" in grp_name) and b.get("window") == "5h"):
                            claude_5h_rem = rem_pct
                            claude_5h_rel = rel_time or "5h 0m"
                        elif b_id == "3p-weekly" or (("claude" in grp_name or "gpt" in grp_name) and b.get("window") == "weekly"):
                            claude_wk_rem = rem_pct
                            claude_wk_rel = rel_time
            except Exception:
                pass

            # 2. Detailed Models
            models_list = []
            try:
                url_models = "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"
                req_models = urllib.request.Request(url_models, data=body, headers=req_headers)
                with urllib.request.urlopen(req_models, timeout=5) as resp:
                    raw_models = json.loads(resp.read().decode("utf-8"))

                for m_id, m_data in raw_models.get("models", {}).items():
                    qi = m_data.get("quotaInfo")
                    if qi:
                        rem = qi.get("remainingFraction", 1.0)
                        used = int(round((1.0 - rem) * 100))
                        raw_reset = qi.get("resetTime", "")
                        models_list.append({
                            "id": m_id,
                            "name": m_data.get("displayName", m_id),
                            "used": used,
                            "remaining": int(round(rem * 100)),
                            "reset": fmt_local_datetime(raw_reset),
                            "reset_time": raw_reset
                        })
                models_list.sort(key=lambda x: x["id"])
            except Exception:
                pass

            result = {
                "email": email,
                "project_id": project or "",
                "tier": "Pro",
                "gemini": {
                    "group_title": "GEMINI MODELS",
                    "group_subtitle": "Models in this group: Gemini Flash, Gemini Pro",
                    "five_hour_remaining": gemini_5h_rem,
                    "five_hour_refresh": gemini_5h_rel,
                    "weekly_remaining": gemini_wk_rem,
                    "weekly_refresh": gemini_wk_rel
                },
                "claude_gpt": {
                    "group_title": "CLAUDE AND GPT MODELS",
                    "group_subtitle": "Models in this group: Claude Opus, Claude Sonnet, GPT-OSS",
                    "five_hour_text": "Quota available",
                    "five_hour_remaining": claude_5h_rem,
                    "five_hour_refresh": claude_5h_rel,
                    "weekly_remaining": claude_wk_rem,
                    "weekly_refresh": claude_wk_rel
                },
                "summary": {
                    "gemini_5h": 100 - gemini_5h_rem,
                    "gemini_5h_remaining": gemini_5h_rem,
                    "gemini_5h_reset": gemini_5h_rel,
                    "gemini_weekly": 100 - gemini_wk_rem,
                    "gemini_weekly_remaining": gemini_wk_rem,
                    "gemini_weekly_reset": gemini_wk_rel,
                    "claude_used": 100 - claude_wk_rem,
                    "claude_remaining": claude_wk_rem,
                    "claude_reset": claude_wk_rel
                },
                "models": models_list
            }

            self._cache_data = result
            self._last_probe_time = now
            return result
        except Exception:
            return None
