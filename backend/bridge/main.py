#!/usr/bin/env python3
"""
CLIProxy Quota Bridge - Main Entry Point (Production-Grade Modular Edition)
High-performance REST API Adapter between CLIProxy and CodexBar macOS.
"""

import sys
import os

# Ensure package modules can be imported
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from http.server import HTTPServer
from core.config import BRIDGE_PORT
from providers.claude import ClaudePoolProvider
from providers.antigravity import AntigravityProvider
from providers.keeper import KeeperProvider
from providers.gateway import GatewayProvider
from providers.system import SystemProvider
from api.handler import BridgeApiHandler

def main():
    claude_prov = ClaudePoolProvider()
    claude_prov._web.start()
    agy_prov = AntigravityProvider()
    keeper_prov = KeeperProvider()
    gateway_prov = GatewayProvider()
    system_prov = SystemProvider()

    BridgeApiHandler.claude_provider = claude_prov
    BridgeApiHandler.agy_provider = agy_prov
    BridgeApiHandler.keeper_provider = keeper_prov
    BridgeApiHandler.gateway_provider = gateway_prov
    BridgeApiHandler.system_provider = system_prov

    server = HTTPServer(("0.0.0.0", BRIDGE_PORT), BridgeApiHandler)
    print(f"🚀 CLIProxy Quota Bridge v2 running on port {BRIDGE_PORT}...")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server gracefully...")
        server.server_close()

if __name__ == "__main__":
    main()
