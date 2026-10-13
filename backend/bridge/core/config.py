"""
Configuration and constants for CLIProxy Quota Bridge.
Single Source of Truth for all paths, ports, and operational settings.
"""

import os

CLIPROXY_HOME = os.path.expanduser("~/.cliproxy")
AUTH_DIR = os.path.join(CLIPROXY_HOME, "auth")
ACCOUNTS_FILE = os.path.join(CLIPROXY_HOME, "accounts.json")
AGY_AUTH_FILE = os.path.join(AUTH_DIR, "antigravity-hieudat2310.bh@gmail.com.json")
LOG_FILE = os.path.join(CLIPROXY_HOME, "logs", "token-keeper.log")
VAULT_DIR = os.path.join(CLIPROXY_HOME, "backups", "auth-vault")

# Network & Ports
MGMT_HOST = os.environ.get("CLIPROXY_HOST", "127.0.0.1")
MGMT_PORT = int(os.environ.get("CLIPROXY_MGMT_PORT", 8317))
MGMT_SECRET = os.environ.get("CLIPROXY_MANAGEMENT_SECRET", "LklK2tDx5ECvF8mxWYAKRCbrWPZv3mpj32ZZzrbcQZY")
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", 8318))

# Cache & Probe Policies
PROBE_CACHE_SEC = 60
EXHAUSTED_CACHE_SEC = 600       # 10m cache for weekly exhausted accounts
PASSIVE_FRESHNESS_SEC = 1800    # 30m maximum age for passive sniffing
AGY_CACHE_SEC = 60
PROBE_STAGGER_SEC = 0.35        # Delay between sequential probes
PROBE_USER_AGENT = "claude-cli/2.1.296 (external, cli)"
AGY_USER_AGENT = "antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)"
