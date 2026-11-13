#!/usr/bin/env python3
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from http.server import ThreadingHTTPServer
from core.config import BRIDGE_PORT
from providers.system import SystemProvider
from providers.ops import OpsProvider
from api.handler import BridgeApiHandler

BIND = os.environ.get("BRIDGE_BIND", "127.0.0.1")


def main():
    BridgeApiHandler.system_provider = SystemProvider()
    BridgeApiHandler.ops_provider = OpsProvider()
    ThreadingHTTPServer.daemon_threads = True
    server = ThreadingHTTPServer((BIND, BRIDGE_PORT), BridgeApiHandler)
    print("Orbiter host telemetry bridge on %s:%d" % (BIND, BRIDGE_PORT), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()


if __name__ == "__main__":
    main()
