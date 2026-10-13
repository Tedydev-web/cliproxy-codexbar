"""
System Provider for CLIProxy CodexBar Bridge
Monitors Ubuntu system metrics (CPU, RAM, Disk), listening ports, services, Docker containers, and active tunnels.
Supports terminating processes on listening ports and creating/stopping quick Cloudflared tunnels.
"""

import os
import re
import json
import time
import signal
import psutil
import subprocess
import threading

class SystemProvider:
    def __init__(self):
        # Store dynamically launched quick tunnels: {tunnel_id: {"port": int, "url": str, "pid": int, "started_at": str}}
        self.active_quick_tunnels = {}
        self.lock = threading.Lock()

    def get_system_metrics(self):
        """Fetch real-time CPU, RAM, Disk and Host uptime."""
        try:
            mem = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            cpu = psutil.cpu_percent(interval=0.1)
            load = os.getloadavg()
            uptime_seconds = int(time.time() - psutil.boot_time())
            
            hours = uptime_seconds // 3600
            days = hours // 24
            rem_hours = hours % 24
            if days > 0:
                uptime_str = f"{days}d {rem_hours}h"
            else:
                uptime_str = f"{hours}h {(uptime_seconds % 3600) // 60}m"

            return {
                "cpu_percent": round(cpu, 1),
                "cpu_count": psutil.cpu_count(),
                "load_avg": [round(x, 2) for x in load],
                "ram_total_gb": round(mem.total / (1024**3), 1),
                "ram_used_gb": round(mem.used / (1024**3), 1),
                "ram_percent": round(mem.percent, 1),
                "disk_total_gb": round(disk.total / (1024**3), 1),
                "disk_used_gb": round(disk.used / (1024**3), 1),
                "disk_percent": round(disk.percent, 1),
                "uptime": uptime_str
            }
        except Exception as e:
            return {"error": str(e)}

    def get_listening_ports(self):
        """
        List all actively listening TCP ports on the Ubuntu host,
        resolving process name, PID, command line, and working directory.
        """
        ports_dict = {}
        try:
            # lsof gives accurate PID mapping without requiring root for user processes
            out = subprocess.check_output(
                ['lsof', '-iTCP', '-sTCP:LISTEN', '-n', '-P', '+c', '0'],
                timeout=4
            ).decode()
            for line in out.strip().split('\n')[1:]:
                parts = line.split()
                if len(parts) >= 9:
                    cmd_name, pid_str, user = parts[0], parts[1], parts[2]
                    name_field = parts[8]
                    if ':' in name_field:
                        host, port_s = name_field.rsplit(':', 1)
                        port_s = port_s.split('(')[0].strip()
                        if port_s.isdigit():
                            port = int(port_s)
                            pid = int(pid_str) if pid_str.isdigit() else None
                            
                            cmd_full = cmd_name
                            cwd_str = ""
                            display_process = cmd_name
                            project_hint = ""
                            is_ide_internal = False
                            
                            if pid:
                                try:
                                    p = psutil.Process(pid)
                                    cmdline = p.cmdline()
                                    exe = p.exe()
                                    cwd_str = p.cwd()
                                    if cmdline:
                                        cmd_full = " ".join(cmdline)
                                    
                                    # Detect IDE internal background listener
                                    if "cursor-server" in exe or "cursor-server" in cmd_full or ".vscode-server" in exe:
                                        is_ide_internal = True
                                        display_process = "Cursor / IDE Internal"
                                    elif "agy" in exe or "agy" in cmd_full:
                                        is_ide_internal = True
                                        display_process = "Antigravity CLI"
                                    elif "node" in exe or "node" in cmd_name.lower():
                                        # Check framework in cmd_full or script args
                                        if "react-router" in cmd_full:
                                            display_process = "React Router (Dev)"
                                        elif "next" in cmd_full:
                                            display_process = "Next.js (Dev)"
                                        elif "vite" in cmd_full:
                                            display_process = "Vite (Dev)"
                                        elif "remix" in cmd_full:
                                            display_process = "Remix (Dev)"
                                        elif "nuxt" in cmd_full:
                                            display_process = "Nuxt (Dev)"
                                        elif "astro" in cmd_full:
                                            display_process = "Astro (Dev)"
                                        else:
                                            # Find script name
                                            script_name = ""
                                            for arg in cmdline[1:]:
                                                if not arg.startswith("-") and ("/" in arg or arg.endswith(".js")):
                                                    script_name = os.path.basename(arg)
                                                    break
                                            display_process = f"node ({script_name})" if script_name else "Node.js"
                                    elif "python" in exe or "python" in cmd_name.lower():
                                        py_script = ""
                                        for arg in cmdline[1:]:
                                            if not arg.startswith("-") and arg.endswith(".py"):
                                                py_script = os.path.basename(arg)
                                                break
                                        display_process = f"python ({py_script})" if py_script else "Python"
                                    elif "cli-proxy" in exe or "cli-proxy" in cmd_name:
                                        display_process = "CLIProxy API"
                                    elif "workerd" in exe:
                                        display_process = "Cloudflare Worker"
                                    elif "ssh" in exe:
                                        display_process = "SSH Tunnel"

                                    # Extract clean project workspace relative path
                                    if cwd_str:
                                        if "/Documents/workspace/" in cwd_str:
                                            project_hint = cwd_str.split("/Documents/workspace/")[-1]
                                        elif "/opt/" in cwd_str:
                                            project_hint = cwd_str.split("/opt/")[-1]
                                        elif cwd_str == "/home/tedydev":
                                            project_hint = "~"
                                        else:
                                            project_hint = os.path.basename(cwd_str)
                                except Exception:
                                    pass

                            ports_dict[port] = {
                                "port": port,
                                "host": host,
                                "pid": pid,
                                "process": display_process,
                                "raw_process": cmd_name,
                                "project": project_hint,
                                "command": cmd_full[:140],
                                "cwd": cwd_str,
                                "user": user,
                                "is_docker": "docker" in cmd_name or "containerd" in cmd_name,
                                "is_internal": is_ide_internal
                            }
        except Exception:
            pass

        # Sort ports ascending
        return sorted(ports_dict.values(), key=lambda x: x["port"])

    def kill_port_process(self, port, pid=None):
        """
        Stop/Kill process listening on a specific port.
        """
        killed = False
        target_pid = pid

        if not target_pid:
            # find pid for this port
            for p_info in self.get_listening_ports():
                if p_info["port"] == port:
                    target_pid = p_info["pid"]
                    break

        if target_pid:
            try:
                os.kill(target_pid, signal.SIGTERM)
                time.sleep(0.3)
                # If still alive, force kill
                try:
                    os.kill(target_pid, signal.SIGKILL)
                except OSError:
                    pass
                killed = True
            except Exception as e:
                # If permission error, try through fuser or sudo
                try:
                    subprocess.run(["fuser", "-k", f"{port}/tcp"], timeout=2)
                    killed = True
                except Exception:
                    pass
        return {"ok": killed, "port": port, "pid": target_pid}

    def get_services_status(self):
        """Check status and versions of key services (Herdr, CLIProxy, Cloudflared)."""
        services = []

        # 1. CLIProxy
        cliproxy_active = False
        cliproxy_version = "8.0.27"
        try:
            res = subprocess.run(["systemctl", "--user", "is-active", "cliproxy.service"], capture_output=True, text=True)
            cliproxy_active = (res.stdout.strip() == "active")
        except Exception:
            pass
        services.append({
            "name": "CLIProxy API",
            "unit": "cliproxy.service",
            "active": cliproxy_active,
            "version": cliproxy_version,
            "port": 8317,
            "can_restart": True
        })

        # 2. Herdr Workspace Manager
        herdr_active = False
        herdr_version = "0.9.3"
        try:
            # Herdr runs server in background or user process
            for p in psutil.process_iter(['name', 'cmdline']):
                if 'herdr' in p.info['name'] and any('server' in arg for arg in (p.info['cmdline'] or [])):
                    herdr_active = True
                    break
        except Exception:
            pass
        services.append({
            "name": "Herdr AI Manager",
            "unit": "herdr server",
            "active": herdr_active,
            "version": herdr_version,
            "can_restart": False,
            "can_update": True
        })

        # 3. Cloudflared System Daemon
        cf_active = False
        try:
            res = subprocess.run(["systemctl", "is-active", "cloudflared"], capture_output=True, text=True)
            cf_active = (res.stdout.strip() == "active")
        except Exception:
            pass
        services.append({
            "name": "Cloudflared System Daemon",
            "unit": "cloudflared.service",
            "active": cf_active,
            "version": "2026.8.3",
            "can_restart": True
        })

        return services

    def restart_service(self, service_name):
        """Restart a managed service."""
        if service_name in ["cliproxy", "cliproxy.service"]:
            res = subprocess.run(["systemctl", "--user", "restart", "cliproxy.service"])
            return {"ok": res.returncode == 0, "service": "cliproxy"}
        elif service_name in ["cloudflared", "cloudflared.service"]:
            res = subprocess.run(["sudo", "-n", "systemctl", "restart", "cloudflared"])
            return {"ok": res.returncode == 0, "service": "cloudflared"}
        return {"ok": False, "error": f"Unknown or unrestartable service: {service_name}"}

    def update_herdr(self):
        """Trigger 'herdr update' in background."""
        try:
            res = subprocess.run(["herdr", "update", "--handoff"], capture_output=True, text=True, timeout=30)
            return {"ok": res.returncode == 0, "output": res.stdout + res.stderr}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def get_docker_containers(self):
        """List running Docker containers."""
        containers = []
        try:
            out = subprocess.check_output(['docker', 'ps', '--format', '{{json .}}'], timeout=3).decode()
            for line in out.strip().split('\n'):
                if not line: continue
                c = json.loads(line)
                containers.append({
                    "id": c.get("ID", "")[:12],
                    "name": c.get("Names", ""),
                    "status": c.get("Status", ""),
                    "image": c.get("Image", ""),
                    "ports": c.get("Ports", "")
                })
        except Exception:
            pass
        return containers

    def get_active_tunnels(self):
        """Get running tunnels (both system named tunnel and on-demand trycloudflare tunnels)."""
        tunnels = []
        
        # 1. System Cloudflared
        try:
            res = subprocess.run(["systemctl", "is-active", "cloudflared"], capture_output=True, text=True)
            if res.stdout.strip() == "active":
                tunnels.append({
                    "id": "sys-cloudflared",
                    "type": "System Named Tunnel",
                    "target": "Host Ingress",
                    "url": "motcaigido.xyz / Private DNS",
                    "is_active": True,
                    "is_quick": False
                })
        except Exception:
            pass

        # 2. Check and clean quick tunnels
        with self.lock:
            stale_keys = []
            for tid, t_data in self.active_quick_tunnels.items():
                pid = t_data.get("pid")
                if pid:
                    try:
                        p = psutil.Process(pid)
                        if not p.is_running():
                            stale_keys.append(tid)
                    except Exception:
                        stale_keys.append(tid)
            for k in stale_keys:
                del self.active_quick_tunnels[k]

            for tid, t_data in self.active_quick_tunnels.items():
                tunnels.append({
                    "id": tid,
                    "type": "Quick Cloudflare Tunnel",
                    "target": f"http://127.0.0.1:{t_data['port']}",
                    "url": t_data["url"],
                    "is_active": True,
                    "is_quick": True,
                    "port": t_data["port"],
                    "pid": t_data.get("pid"),
                    "started_at": t_data.get("started_at", "")
                })

        return tunnels

    def start_quick_tunnel(self, port):
        """Launch an on-demand Cloudflared quick tunnel for the specified port."""
        try:
            port = int(port)
            proc = subprocess.Popen(
                ["cloudflared", "tunnel", "--url", f"http://127.0.0.1:{port}"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )

            url = None
            start_time = time.time()
            # Read until URL is captured or timeout 15s
            while time.time() - start_time < 15:
                line = proc.stdout.readline()
                if not line: break
                m = re.search(r'(https://[a-zA-Z0-9.-]+\.trycloudflare\.com)', line)
                if m:
                    url = m.group(1)
                    break

            if url and proc.pid:
                tid = f"tunnel-{port}-{int(time.time())}"
                t_info = {
                    "port": port,
                    "url": url,
                    "pid": proc.pid,
                    "started_at": datetime.datetime.now().strftime("%H:%M:%S")
                }
                with self.lock:
                    self.active_quick_tunnels[tid] = t_info
                return {"ok": True, "tunnel": t_info, "id": tid}
            else:
                if proc.pid:
                    try: os.kill(proc.pid, signal.SIGTERM)
                    except: pass
                return {"ok": False, "error": "Could not obtain trycloudflare.com URL within 15s"}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def stop_quick_tunnel(self, tunnel_id):
        """Stop an on-demand Cloudflared quick tunnel."""
        with self.lock:
            if tunnel_id in self.active_quick_tunnels:
                t_info = self.active_quick_tunnels[tunnel_id]
                pid = t_info.get("pid")
                if pid:
                    try:
                        os.kill(pid, signal.SIGTERM)
                        time.sleep(0.3)
                        try: os.kill(pid, signal.SIGKILL)
                        except: pass
                    except:
                        pass
                del self.active_quick_tunnels[tunnel_id]
                return {"ok": True, "tunnel_id": tunnel_id}
            return {"ok": False, "error": "Tunnel ID not found"}
