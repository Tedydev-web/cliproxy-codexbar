"""
Token Keeper Provider
Parses Token Keeper telemetry, cycle progress, and vault backups.
"""

import os
import re
import datetime

from core.config import LOG_FILE, VAULT_DIR

class KeeperProvider:
    def get_telemetry(self):
        timer_info = {
            "status": "active",
            "schedule": "Mỗi 4 giờ (Proactive Refresh)",
            "next_run": "00:00:00",
            "last_run": "00:00:00"
        }
        logs = []
        last_dt = None

        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, "r", encoding="utf-8", errors="ignore") as lf:
                    lines = lf.readlines()
                logs = [l.strip() for l in lines[-25:] if l.strip()]
                for l in reversed(logs):
                    m = re.search(r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]", l)
                    if m:
                        try:
                            last_dt = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
                            timer_info["last_run"] = last_dt.strftime("%H:%M:%S")
                            next_dt = last_dt + datetime.timedelta(hours=4)
                            timer_info["next_run"] = next_dt.strftime("%H:%M:%S")
                            break
                        except Exception:
                            pass
            except Exception:
                pass

        now_dt = datetime.datetime.now()
        if not last_dt:
            last_dt = now_dt - datetime.timedelta(minutes=5)
            timer_info["last_run"] = last_dt.strftime("%H:%M:%S")
            next_dt = last_dt + datetime.timedelta(hours=4)
            timer_info["next_run"] = next_dt.strftime("%H:%M:%S")
        else:
            next_dt = last_dt + datetime.timedelta(hours=4)

        elapsed_sec = max(0, (now_dt - last_dt).total_seconds())
        cycle_sec = 4 * 3600
        cycle_percent = min(100.0, max(0.0, (elapsed_sec / cycle_sec) * 100.0))

        rem_sec = max(0, int((next_dt - now_dt).total_seconds()))
        rem_h = rem_sec // 3600
        rem_m = (rem_sec % 3600) // 60
        if rem_h > 0:
            time_left_str = f"còn {rem_h}h {rem_m}m"
        elif rem_m > 0:
            time_left_str = f"còn {rem_m}m"
        else:
            time_left_str = "đang chạy..."

        timer_info["cycle_percent"] = round(cycle_percent, 1)
        timer_info["time_left"] = time_left_str

        backup_count = len(os.listdir(VAULT_DIR)) if os.path.exists(VAULT_DIR) else 0

        return {
            "timer": timer_info,
            "service": "claude-token-keeper.service",
            "description": "Bảo vệ phiên, tự động refresh OAuth access_token trước khi hết hạn",
            "backup_count": backup_count,
            "logs": logs
        }
