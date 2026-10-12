"""
RESTful HTTP API Handlers for CLIProxy CodexBar Bridge
"""

import json
from http.server import BaseHTTPRequestHandler

class BridgeApiHandler(BaseHTTPRequestHandler):
    claude_provider = None
    agy_provider = None
    keeper_provider = None

    def send_json(self, status_code, data):
        payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path.startswith("/v1/pool-status"):
            accounts = self.claude_provider.get_pool_status()
            self.send_json(200, {"accounts": accounts})
        elif self.path.startswith("/v1/antigravity-quota"):
            data = self.agy_provider.get_quota()
            if data:
                self.send_json(200, data)
            else:
                self.send_json(404, {"error": "Antigravity credentials not found or offline"})
        elif self.path.startswith("/v1/keeper-telemetry"):
            data = self.keeper_provider.get_telemetry()
            self.send_json(200, data)
        elif self.path == "/health":
            self.send_json(200, {"status": "healthy", "service": "cliproxy-quota-bridge"})
        else:
            # Default fallback for CodexBar clients
            accounts = self.claude_provider.get_pool_status()
            self.send_json(200, {"accounts": accounts})

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        try:
            req_data = json.loads(body.decode("utf-8")) if body else {}
        except Exception:
            self.send_json(400, {"error": "Invalid JSON body"})
            return

        if self.path.startswith("/v1/set-priority"):
            target_email = req_data.get("email")
            if not target_email:
                self.send_json(400, {"error": "Missing 'email' field"})
                return

            pool = self.claude_provider.get_pool_status()
            emails = [a["email"] for a in pool]
            if target_email in emails:
                emails.remove(target_email)
                new_order = [target_email] + emails
                self.claude_provider.set_accounts_order(new_order)
                self.send_json(200, {"ok": True, "target": target_email, "order": new_order})
            else:
                self.send_json(404, {"error": f"Account '{target_email}' not found in pool"})

        elif self.path.startswith("/v1/set-order"):
            new_order = req_data.get("order", [])
            if self.claude_provider.set_accounts_order(new_order):
                self.send_json(200, {"ok": True, "order": new_order})
            else:
                self.send_json(400, {"error": "Invalid order payload"})
        else:
            self.send_json(404, {"error": "Endpoint not found"})
