"""
Configuration and constants for CLIProxy Quota Bridge.
Single Source of Truth for all paths, ports, and operational settings.
"""

import os

CLIPROXY_HOME = os.path.expanduser("~/.cliproxy")
AUTH_DIR = os.path.join(CLIPROXY_HOME, "auth")
ACCOUNTS_FILE = os.path.join(CLIPROXY_HOME, "accounts.json")

def get_agy_auth_file():
    # 1. Prefer dat.donghieu@gmail.com
    p1 = os.path.join(AUTH_DIR, "antigravity-dat.donghieu@gmail.com.json")
    if os.path.exists(p1):
        return p1
    # 2. Check any other antigravity file in AUTH_DIR
    if os.path.exists(AUTH_DIR):
        for f in os.listdir(AUTH_DIR):
            if f.startswith("antigravity-") and f.endswith(".json"):
                return os.path.join(AUTH_DIR, f)
    # 3. Fallback to CLI's local oauth token
    cli_token = os.path.expanduser("~/.gemini/antigravity-cli/antigravity-oauth-token")
    if os.path.exists(cli_token):
        return cli_token
    return os.path.join(AUTH_DIR, "antigravity-hieudat2310.bh@gmail.com.json")

AGY_AUTH_FILE = get_agy_auth_file()
LOG_FILE = os.path.join(CLIPROXY_HOME, "logs", "token-keeper.log")
VAULT_DIR = os.path.join(CLIPROXY_HOME, "backups", "auth-vault")

# Network & Ports
MGMT_HOST = os.environ.get("CLIPROXY_HOST", "127.0.0.1")
MGMT_PORT = int(os.environ.get("CLIPROXY_MGMT_PORT", 8317))
MGMT_SECRET = os.environ.get("CLIPROXY_MANAGEMENT_SECRET")
if not MGMT_SECRET:
    raise RuntimeError("CLIPROXY_MANAGEMENT_SECRET is not set (expected in ~/.cliproxy/bridge.env)")
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", 8318))
WIDGET_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "widgets")
WIDGET_FILES = ("OrbiterClaudeWidget.js", "OrbiterAGYWidget.js")
WIDGET_SECRET_PLACEHOLDER = "PASTE_CLIPROXY_BRIDGE_SECRET_HERE"

# Cache & Probe Policies
PROBE_CACHE_SEC = 60
EXHAUSTED_CACHE_SEC = 600       # 10m cache for weekly exhausted accounts
PASSIVE_FRESHNESS_SEC = 1800    # 30m maximum age for passive sniffing
HEADER_PROBE_SEC = 300          # 5m minimum gap between 1-token header probes per setup-token
AGY_CACHE_SEC = 60
PROBE_STAGGER_SEC = 0.35        # Delay between sequential probes
PROBE_USER_AGENT = "claude-cli/2.1.296 (external, cli)"
AGY_USER_AGENT = "antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)"
