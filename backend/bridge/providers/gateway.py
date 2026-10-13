"""
Gateway Provider for CLIProxy CodexBar Bridge
Monitors external AI gateways (LiteLLM, OneAPI, DeepSeek Proxy endpoints),
tracks precise usage spend, budget limits, activity status, and provides 1-click execution commands.
"""

import os
import json
import urllib.request
import urllib.error
import datetime

class GatewayProvider:
    def __init__(self, config_path=None):
        self.config_path = config_path or os.path.expanduser("~/.cliproxy/config.yaml")

    def _extract_claude_api_keys(self):
        """Parse claude-api-key entries from config.yaml manually to avoid PyYAML dependency."""
        if not os.path.exists(self.config_path):
            return []

        keys = []
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            in_claude_api_key = False
            current_entry = None

            for line in lines:
                stripped = line.strip()
                if line.startswith("claude-api-key:"):
                    in_claude_api_key = True
                    continue
                if in_claude_api_key:
                    if line and not line.startswith(" ") and not line.startswith("\t") and not line.startswith("#"):
                        break  # exited section
                    if stripped.startswith("- api-key:"):
                        if current_entry:
                            keys.append(current_entry)
                        api_k = stripped.split("- api-key:", 1)[1].strip().strip('"').strip("'")
                        current_entry = {"api_key": api_k, "base_url": "", "models": []}
                    elif current_entry and stripped.startswith("base-url:"):
                        url = stripped.split("base-url:", 1)[1].strip().strip('"').strip("'")
                        current_entry["base_url"] = url
                    elif current_entry and stripped.startswith("- name:"):
                        m_name = stripped.split("- name:", 1)[1].strip().strip('"').strip("'")
                        current_entry["models"].append({"name": m_name, "alias": m_name})
                    elif current_entry and stripped.startswith("alias:"):
                        if current_entry["models"]:
                            m_alias = stripped.split("alias:", 1)[1].strip().strip('"').strip("'")
                            current_entry["models"][-1]["alias"] = m_alias

            if current_entry:
                keys.append(current_entry)
        except Exception:
            pass

        return keys

    def get_gateway_info(self):
        """Fetch real-time usage metrics and status from the upstream gateway."""
        gateways = self._extract_claude_api_keys()
        if not gateways:
            # Fallback default from known setup if config parsing yielded empty
            gateways = [{
                "api_key": "sk-PZ7fHHdBGeuHlkncgPH7Vw",
                "base_url": "https://luong-30005.motcaigido.xyz",
                "models": [
                    {"name": "claude-sonnet-5-5-high[1m]", "alias": "ds/sonnet-5-5[1m]"},
                    {"name": "claude-opus-5-5-high[1m]", "alias": "ds/opus-5-5[1m]"},
                    {"name": "claude-fable-5-1[1m]", "alias": "ds/fable-5-1[1m]"}
                ]
            }]

        gw = gateways[0]
        base_url = gw.get("base_url", "").rstrip("/")
        api_key = gw.get("api_key", "")
        models_cfg = gw.get("models", [])

        # Default fallback structure
        result = {
            "enabled": True,
            "provider_name": "LiteLLM / DeepSeek Gateway",
            "base_url": base_url,
            "key_alias": "HieuDat",
            "spend": 0.0,
            "spend_formatted": "$0.0000",
            "max_budget": 50.0,
            "max_budget_formatted": "$50.00",
            "spend_percent": 0.0,
            "is_active_now": False,
            "last_active": None,
            "last_active_human": "Chưa hoạt động",
            "models": [],
            "quick_commands": []
        }

        # Probe /key/info endpoint
        if base_url and api_key:
            try:
                req = urllib.request.Request(
                    f"{base_url}/key/info",
                    headers={"Authorization": f"Bearer {api_key}"}
                )
                with urllib.request.urlopen(req, timeout=3.5) as resp:
                    if resp.status == 200:
                        data = json.loads(resp.read().decode("utf-8"))
                        info = data.get("info", {})
                        spend = float(info.get("spend") or info.get("total_spend") or 0.0)
                        max_budget = float(info.get("max_budget") or 50.0)
                        key_alias = info.get("key_alias") or "DefaultKey"
                        last_active = info.get("last_active")

                        result["spend"] = spend
                        result["spend_formatted"] = f"${spend:.5f}"
                        result["max_budget"] = max_budget
                        result["max_budget_formatted"] = f"${max_budget:.2f}"
                        result["key_alias"] = key_alias
                        result["last_active"] = last_active

                        if max_budget > 0:
                            result["spend_percent"] = round((spend / max_budget) * 100, 2)

                        # Calculate relative time and active state
                        if last_active:
                            try:
                                # parse iso timestamp e.g. 2026-10-13T01:46:27.827000+00:00
                                clean_ts = last_active.split("+")[0].split(".")[0]
                                dt = datetime.datetime.strptime(clean_ts, "%Y-%m-%dT%H:%M:%S")
                                now_utc = datetime.datetime.utcnow()
                                diff_sec = max(0, int((now_utc - dt).total_seconds()))

                                # Local time for display (UTC+7)
                                dt_local = dt + datetime.timedelta(hours=7)
                                result["last_active_time"] = dt_local.strftime("%H:%M:%S")
                                result["budget_reset_at"] = info.get("budget_reset_at")

                                if diff_sec < 180: # active within last 3 mins
                                    result["is_active_now"] = True
                                    result["last_active_human"] = "Đang sử dụng (vừa xong)"
                                elif diff_sec < 3600:
                                    mins = diff_sec // 60
                                    result["is_active_now"] = (mins <= 5)
                                    result["last_active_human"] = f"{mins} phút trước ({result['last_active_time']})"
                                elif diff_sec < 86400:
                                    hours = diff_sec // 3600
                                    result["last_active_human"] = f"{hours} giờ trước ({result['last_active_time']})"
                                else:
                                    days = diff_sec // 86400
                                    result["last_active_human"] = f"{days} ngày trước"
                            except Exception:
                                result["last_active_human"] = last_active
            except Exception as e:
                result["error"] = str(e)
                result["last_active_human"] = "Không thể kết nối"

        # Construct Distinct Models & One-Click Copy Shell Commands
        models_list = []
        commands_list = [
            {
                "title": "Chạy Claude Team (Mặc định)",
                "description": "Kết nối qua endpoint motcaigido.xyz",
                "command": "cteam"
            },
            {
                "title": "Chạy Claude Opus 5.5",
                "description": "Sử dụng model suy luận cao qua DeepSeek proxy",
                "command": "ANTHROPIC_MODEL=\"ds/opus-5-5\" cteam"
            },
            {
                "title": "Chạy Claude Sonnet 5.5",
                "description": "Sử dụng model tốc độ cao qua DeepSeek proxy",
                "command": "ANTHROPIC_MODEL=\"ds/sonnet-5-5\" cteam"
            },
            {
                "title": "Chạy Claude Fable 5.1",
                "description": "Sử dụng model Fable qua DeepSeek proxy",
                "command": "ANTHROPIC_MODEL=\"ds/fable-5-1\" cteam"
            },
            {
                "title": "Kiểm tra chi phí trực tiếp qua curl",
                "description": "Xem chi tiết spend từ LiteLLM Gateway",
                "command": f'curl -s -H "Authorization: Bearer {api_key}" "{base_url}/key/info" | jq .info'
            }
        ]

        # Deduplicate configured model aliases
        seen_aliases = set()
        for m in models_cfg:
            alias = m.get("alias", "")
            if alias and alias not in seen_aliases:
                seen_aliases.add(alias)
                models_list.append({
                    "name": m.get("name", alias),
                    "alias": alias,
                    "command": f'ANTHROPIC_MODEL="{alias}" cteam'
                })

        result["models"] = models_list
        result["quick_commands"] = commands_list
        return result
