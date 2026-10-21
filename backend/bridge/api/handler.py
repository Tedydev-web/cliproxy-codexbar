"""
RESTful HTTP API Handlers for CLIProxy CodexBar Bridge
"""

import os
import json
import hmac
import hashlib
import subprocess
from http.server import BaseHTTPRequestHandler
from core.config import MGMT_SECRET, WIDGET_DIR, WIDGET_FILES, WIDGET_SECRET_PLACEHOLDER

class BridgeApiHandler(BaseHTTPRequestHandler):
    claude_provider = None
    agy_provider = None
    keeper_provider = None
    gateway_provider = None
    system_provider = None

    def is_authorized(self):
        auth = self.headers.get("Authorization", "")
        token = auth[len("Bearer "):] if auth.startswith("Bearer ") else ""
        return hmac.compare_digest(token, MGMT_SECRET)

    def send_json(self, status_code, data):
        payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def send_widget(self, name, head=False):
        if name not in WIDGET_FILES:
            self.send_json(404, {"error": f"Unknown widget '{name}'"})
            return
        try:
            with open(os.path.join(WIDGET_DIR, name), "r", encoding="utf-8") as f:
                code = f.read()
        except OSError as e:
            self.send_json(404, {"error": f"Widget '{name}' not deployed: {e}"})
            return
        payload = code.replace(WIDGET_SECRET_PLACEHOLDER, MGMT_SECRET, 1).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/javascript; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("ETag", '"' + hashlib.sha256(payload).hexdigest()[:32] + '"')
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if not head:
            self.wfile.write(payload)

    def do_HEAD(self):
        if not self.is_authorized():
            self.send_response(401)
            self.end_headers()
            return
        if self.path.startswith("/v1/widget/"):
            self.send_widget(self.path[len("/v1/widget/"):].split("?")[0], head=True)
        else:
            self.send_response(405)
            self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "healthy", "service": "cliproxy-quota-bridge"})
            return
        if not self.is_authorized():
            self.send_json(401, {"error": "Unauthorized"})
            return
        if self.path.startswith("/v1/pool-status"):
            accounts = self.claude_provider.get_pool_status()
            gw_info = self.gateway_provider.get_gateway_info() if self.gateway_provider else None
            self.send_json(200, {"accounts": accounts, "gateway": gw_info})
        elif self.path.startswith("/v1/gateway-telemetry"):
            gw_info = self.gateway_provider.get_gateway_info() if self.gateway_provider else {}
            self.send_json(200, gw_info)
        elif self.path.startswith("/v1/antigravity-quota"):
            data = self.agy_provider.get_quota()
            if data:
                self.send_json(200, data)
            else:
                self.send_json(404, {"error": "Antigravity credentials not found or offline"})
        elif self.path.startswith("/v1/keeper-telemetry"):
            data = self.keeper_provider.get_telemetry()
            self.send_json(200, data)
        elif self.path.startswith("/v1/system-telemetry"):
            if not self.system_provider:
                self.send_json(503, {"error": "System provider not initialized"})
                return
            metrics = self.system_provider.get_system_metrics()
            ports = self.system_provider.get_listening_ports()
            services = self.system_provider.get_services_status()
            docker_list = self.system_provider.get_docker_containers()
            tunnels = self.system_provider.get_active_tunnels()
            self.send_json(200, {
                "metrics": metrics,
                "ports": ports,
                "services": services,
                "docker": docker_list,
                "tunnels": tunnels
            })
        elif self.path.startswith("/v1/system-metrics"):
            metrics = self.system_provider.get_system_metrics() if self.system_provider else {}
            self.send_json(200, metrics)
        elif self.path.startswith("/v1/widget/"):
            self.send_widget(self.path[len("/v1/widget/"):].split("?")[0])
        elif self.path.startswith("/v1/system-ports"):
            ports = self.system_provider.get_listening_ports() if self.system_provider else []
            self.send_json(200, {"ports": ports})
        else:
            # Default fallback for CodexBar clients
            accounts = self.claude_provider.get_pool_status()
            gw_info = self.gateway_provider.get_gateway_info() if self.gateway_provider else None
            self.send_json(200, {"accounts": accounts, "gateway": gw_info})

    def do_POST(self):
        if not self.is_authorized():
            self.send_json(401, {"error": "Unauthorized"})
            return
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

        elif self.path.startswith("/v1/set-enabled"):
            email = req_data.get("email")
            enabled = req_data.get("enabled")
            if not email or not isinstance(enabled, bool):
                self.send_json(400, {"error": "Need 'email' (string) and 'enabled' (bool)"})
                return
            status, result = self.claude_provider.set_account_enabled(email, enabled)
            self.send_json(status, result)

        elif self.path.startswith("/v1/kill-port"):
            if not self.system_provider:
                self.send_json(503, {"error": "System provider unavailable"})
                return
            port = req_data.get("port")
            pid = req_data.get("pid")
            if not port:
                self.send_json(400, {"error": "Missing 'port' field"})
                return
            res = self.system_provider.kill_port_process(int(port), pid=pid)
            self.send_json(200, res)

        elif self.path.startswith("/v1/tunnel-start"):
            if not self.system_provider:
                self.send_json(503, {"error": "System provider unavailable"})
                return
            port = req_data.get("port")
            if not port:
                self.send_json(400, {"error": "Missing 'port' field"})
                return
            res = self.system_provider.start_quick_tunnel(int(port))
            self.send_json(200, res)

        elif self.path.startswith("/v1/tunnel-stop"):
            if not self.system_provider:
                self.send_json(503, {"error": "System provider unavailable"})
                return
            tunnel_id = req_data.get("tunnel_id")
            if not tunnel_id:
                self.send_json(400, {"error": "Missing 'tunnel_id' field"})
                return
            res = self.system_provider.stop_quick_tunnel(tunnel_id)
            self.send_json(200, res)

        elif self.path.startswith("/v1/restart-service"):
            if not self.system_provider:
                self.send_json(503, {"error": "System provider unavailable"})
                return
            svc = req_data.get("service")
            res = self.system_provider.restart_service(svc)
            self.send_json(200, res)

        elif self.path.startswith("/v1/update-herdr"):
            if not self.system_provider:
                self.send_json(503, {"error": "System provider unavailable"})
                return
            res = self.system_provider.update_herdr()
            self.send_json(200, res)

        elif self.path.startswith("/v1/reauth-account"):
            email = req_data.get("email")
            if not email:
                self.send_json(400, {"error": "Missing 'email' field"})
                return
            import subprocess
            reauth_bin = os.path.expanduser("~/.local/bin/claude-reauth")
            subprocess.Popen(
                [reauth_bin, email],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            self.send_json(200, {
                "ok": True,
                "message": f"Đã khởi động quy trình xác thực lại cho {email}. Trình duyệt trên Mac sẽ tự động mở."
            })

        else:
            self.send_json(404, {"error": "Endpoint not found"})
