"""
Shared utilities for formatting, timestamps, and data transformations.
"""

import datetime

def parse_iso_datetime(iso_str):
    if not iso_str:
        return None
    try:
        return datetime.datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    except Exception:
        return None

def fmt_relative_reset_from_dt(target_dt):
    if not target_dt:
        return ""
    now = datetime.datetime.now(datetime.timezone.utc)
    diff = target_dt - now
    total_sec = int(diff.total_seconds())
    if total_sec <= 0:
        return "now"
    days = total_sec // 86400
    hours = (total_sec % 86400) // 3600
    mins = (total_sec % 3600) // 60
    if days > 0:
        return f"{days}d {hours}h"
    elif hours > 0:
        return f"{hours}h {mins}m"
    else:
        return f"{mins}m"

def fmt_relative_reset_from_ts(ts):
    if not ts:
        return ""
    try:
        target_dt = datetime.datetime.fromtimestamp(float(ts), datetime.timezone.utc)
        return fmt_relative_reset_from_dt(target_dt)
    except Exception:
        return ""

def fmt_relative_reset_from_iso(iso_str):
    dt = parse_iso_datetime(iso_str)
    return fmt_relative_reset_from_dt(dt) if dt else ""

def fmt_local_datetime(iso_str, tz_offset_hours=7):
    dt = parse_iso_datetime(iso_str)
    if not dt:
        return "Sẵn sàng"
    try:
        local_dt = dt.astimezone(datetime.timezone(datetime.timedelta(hours=tz_offset_hours)))
        return local_dt.strftime("%d/%m %H:%M")
    except Exception:
        return iso_str or "Sẵn sàng"
