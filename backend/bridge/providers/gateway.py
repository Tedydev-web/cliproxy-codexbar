"""
Gateway Provider for CLIProxy CodexBar Bridge
Manages and monitors external AI gateways and direct upstream API integrations.
Exposes Anthropic Console Direct API metrics, model catalogs, and one-click commands.
"""

import os
import json
import datetime

class GatewayProvider:
    def __init__(self, config_path=None):
        self.config_path = config_path or os.path.expanduser("~/.cliproxy/config.yaml")
        self.console_api_key = "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"

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

        now_str = datetime.datetime.now().strftime("%H:%M:%S")

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
            "is_active_now": True,
            "last_active": datetime.datetime.utcnow().isoformat(),
            "last_active_time": now_str,
            "last_active_human": "Trực tuyến / Sẵn sàng",
            "models": models_list,
            "quick_commands": commands_list,
            "error": ""
        }
