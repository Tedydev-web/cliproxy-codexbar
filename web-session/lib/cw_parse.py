import re

SOURCE = "web-session"


def num(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")


def scoped_weekly(limits):
    out, seen = [], set()
    for entry in limits if isinstance(limits, list) else []:
        if not isinstance(entry, dict) or entry.get("group") != "weekly" or entry.get("kind") != "weekly_scoped":
            continue
        pct = num(entry.get("percent"))
        scope = entry.get("scope") if isinstance(entry.get("scope"), dict) else {}
        model = scope.get("model") if isinstance(scope.get("model"), dict) else {}
        name = (model.get("display_name") or "").strip()
        ident = model.get("id") or name
        if pct is None or not name or "all-models" in slug(name) or slug(ident).endswith("all-models"):
            continue
        key = slug(ident)
        if key in seen:
            continue
        seen.add(key)
        out.append({"model": name, "used": pct, "reset": entry.get("resets_at")})
    return out


def cloud_credits(block):
    if not isinstance(block, dict):
        return None
    limit, used, remaining = num(block.get("limit_dollars")), num(block.get("used_dollars")), num(block.get("remaining_dollars"))
    if limit is None or limit <= 0:
        return None
    if remaining is None and used is not None:
        remaining = limit - used
    if remaining is None or remaining < 0 or remaining > limit:
        return None
    return {"limit": limit, "remaining": remaining, "used": limit - remaining,
            "expires_at": block.get("resets_at"), "locked": bool(block.get("locked_reason"))}


def parse_usage(email, d):
    fh, sd = d.get("five_hour") or {}, d.get("seven_day") or {}
    legacy = d.get("seven_day_sonnet") or d.get("seven_day_opus") or {}
    extra = d.get("extra_usage") if isinstance(d.get("extra_usage"), dict) else {}
    return {
        "email": email,
        "source": SOURCE,
        "used_5h": num(fh.get("utilization")),
        "reset_5h": fh.get("resets_at"),
        "used_weekly": num(sd.get("utilization")),
        "reset_weekly": sd.get("resets_at"),
        "used_model_weekly": num(legacy.get("utilization")),
        "scoped_weekly": scoped_weekly(d.get("limits")),
        "cloud_credits": cloud_credits(d.get("iguana_necktie")),
        "extra_usage": {"enabled": bool(extra.get("is_enabled")), "limit_reached": bool(extra.get("spend_limit_reached"))} if extra else None,
    }
