"""
Gateway Provider for CLIProxy CodexBar Bridge
Manages and monitors external AI gateways and direct upstream API integrations.
Exposes Anthropic Console Direct API metrics, model catalogs, and one-click commands.
"""

import os
import json
import time
import datetime
import urllib.request
import urllib.error
import yaml

class GatewayProvider:
    def __init__(self, config_path=None):
        self.config_path = config_path or os.path.expanduser("~/.cliproxy/config.yaml")
        self.console_api_key = self._load_console_api_key()
        self._last_probe_time = 0
        self._cached_health = None

    def _load_console_api_key(self):
        """Read the Console API key from CLIProxy's own config.yaml (single source of truth)."""
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                cfg = yaml.safe_load(f)
            return cfg["api-keys"]["claude"][0]["keys"][0]["api-key"]
        except Exception:
            return None

    def check_health(self, force=False):
        """
        Probe api.anthropic.com/v1/models using the private Console API Key.
        - Zero token spend ($0.00).
        - Caches result for 120s to ensure sub-millisecond bridge responses.
        - Returns dict with is_healthy, status_label, latency_ms, models_count, error.
        """
        now = time.time()
        if not force and self._cached_health and (now - self._last_probe_time < 120):
            return self._cached_health

        url = "https://api.anthropic.com/v1/models"
        headers = {
            "x-api-key": self.console_api_key,
            "anthropic-version": "2023-06-01",
            "User-Agent": "CLIProxy-Quota-Bridge/2.0"
        }
        req = urllib.request.Request(url, headers=headers, method="GET")

        start = time.time()
        try:
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                elapsed_ms = int((time.time() - start) * 1000)
                body = resp.read().decode("utf-8")
                data = json.loads(body)
                models_cnt = len(data.get("data", []))
                self._cached_health = {
                    "is_healthy": True,
                    "status": "online",
                    "status_label": f"Trực tuyến ({elapsed_ms}ms)",
                    "latency_ms": elapsed_ms,
                    "models_count": models_cnt,
                    "error": "",
                    "last_checked": datetime.datetime.now().strftime("%H:%M:%S")
                }
        except urllib.error.HTTPError as e:
            elapsed_ms = int((time.time() - start) * 1000)
            err_label = f"Lỗi HTTP {e.code}"
            if e.code == 401:
                err_label = "Lỗi xác thực (401)"
            elif e.code == 403:
                err_label = "Từ chối truy cập (403)"
            elif e.code == 429:
                err_label = "Hạn mức (429)"
            self._cached_health = {
                "is_healthy": False,
                "status": "error",
                "status_label": err_label,
                "latency_ms": elapsed_ms,
                "models_count": 0,
                "error": f"HTTP {e.code}: {e.reason}",
                "last_checked": datetime.datetime.now().strftime("%H:%M:%S")
            }
        except Exception as e:
            elapsed_ms = int((time.time() - start) * 1000)
            self._cached_health = {
                "is_healthy": False,
                "status": "offline",
                "status_label": "Mất kết nối",
                "latency_ms": elapsed_ms,
                "models_count": 0,
                "error": str(e),
                "last_checked": datetime.datetime.now().strftime("%H:%M:%S")
            }

        self._last_probe_time = now
        return self._cached_health

    def get_gateway_info(self):
        """Return status and execution commands for the Anthropic Console Direct API."""
        models_list = [
            {
                "name": "claude-sonnet-5-5",
                "alias": "api/sonnet-5-5",
                "command": 'ANTHROPIC_MODEL="api/sonnet-5-5" cx'
            },
            {
                "name": "claude-opus-5-5",
                "alias": "api/opus-5-5",
                "command": 'ANTHROPIC_MODEL="api/opus-5-5" cx'
            },
            {
                "name": "claude-fable-5-1",
                "alias": "api/fable-5-1",
                "command": 'ANTHROPIC_MODEL="api/fable-5-1" cx'
            },
            {
                "name": "claude-haiku-5-5",
                "alias": "api/haiku-5-5",
                "command": 'ANTHROPIC_MODEL="api/haiku-5-5" cx'
            },
            {
                "name": "claude-sonnet-5",
                "alias": "api/sonnet-5",
                "command": 'ANTHROPIC_MODEL="api/sonnet-5" cx'
            },
            {
                "name": "claude-opus-5",
                "alias": "api/opus-5",
                "command": 'ANTHROPIC_MODEL="api/opus-5" cx'
            }
        ]

        commands_list = [
            {
                "title": "Chạy Claude Code với Console API (Bypass Quota)",
                "description": "Bypass hoàn toàn giới hạn 5h OAuth, chạy trực tiếp Console API (1,000 RPM, 2.4M TPM)",
                "command": "capi"
            },
            {
                "title": "Chạy Sonnet 5.5 Direct API (qua CLIProxy)",
                "description": "Chạy Sonnet 5.5 từ Console API qua CLIProxy port 8317",
                "command": 'ANTHROPIC_MODEL="api/sonnet-5-5" cx'
            },
            {
                "title": "Chạy Opus 5.5 Direct API (qua CLIProxy)",
                "description": "Chạy Opus 5.5 từ Console API qua CLIProxy port 8317",
                "command": 'ANTHROPIC_MODEL="api/opus-5-5" cx'
            },
            {
                "title": "Chạy Fable 5.1 Direct API (qua CLIProxy)",
                "description": "Chạy Fable 5.1 từ Console API qua CLIProxy port 8317",
                "command": 'ANTHROPIC_MODEL="api/fable-5-1" cx'
            },
            {
                "title": "Chạy Haiku 5.5 Direct API (qua CLIProxy)",
                "description": "Chạy Haiku 5.5 từ Console API qua CLIProxy port 8317",
                "command": 'ANTHROPIC_MODEL="api/haiku-5-5" cx'
            },
            {
                "title": "Kiểm tra Console API qua curl",
                "description": "Gửi request kiểm tra nhanh tới api.anthropic.com",
                "command": f'curl -s -X POST https://api.anthropic.com/v1/messages -H "x-api-key: {self.console_api_key}" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d \'{{"model":"claude-haiku-4-5-20251001","max_tokens":10,"messages":[{{"role":"user","content":"ping"}}]}}\' | jq .'
            }
        ]

        health = self.check_health()

        return {
            "enabled": True,
            "provider_name": "Anthropic Console Direct (Personal Workspace)",
            "base_url": "https://api.anthropic.com",
            "key_alias": "Personal Workspace (1,000 RPM, 2.4M TPM)",
            "spend": 0.0,
            "spend_formatted": "$0.00 (Console Billed)",
            "max_budget": 0.0,
            "max_budget_formatted": "Không giới hạn",
            "spend_percent": 0.0,
            "is_active_now": health["is_healthy"],
            "last_active": datetime.datetime.utcnow().isoformat(),
            "last_active_time": health["last_checked"],
            "last_active_human": health["status_label"],
            "latency_ms": health["latency_ms"],
            "models_count": health["models_count"],
            "models": models_list,
            "quick_commands": commands_list,
            "error": health["error"]
        }
