import re, time, email.utils
from curl_cffi import requests
from curl_cffi.requests.exceptions import RequestException
from cw_store import WebError, account_meta

BASE = "https://claude.ai/api"
IMPERSONATE = "chrome"
DEFAULT_COOLDOWN = 300


def parse_retry_after(value):
    if not value:
        return None
    value = value.strip()
    if value.isdigit():
        return time.time() + int(value)
    try:
        return email.utils.parsedate_to_datetime(value).timestamp()
    except (TypeError, ValueError):
        return None


def request(path, session_key):
    try:
        r = requests.get(
            f"{BASE}{path}",
            headers={"Cookie": f"sessionKey={session_key}", "Accept": "application/json"},
            impersonate=IMPERSONATE,
            timeout=20,
        )
    except RequestException as e:
        raise WebError("network", str(e)[:120])
    if r.status_code == 403 and (r.headers.get("cf-mitigated") or "Just a moment" in r.text[:2000]):
        raise WebError("cloudflare", "Cloudflare challenge")
    if r.status_code in (401, 403):
        raise WebError("unauthorized", f"session rejected (HTTP {r.status_code})")
    if r.status_code == 429:
        raise WebError("rate_limited", "HTTP 429", retry_after=parse_retry_after(r.headers.get("retry-after")))
    if r.status_code != 200:
        raise WebError("server", f"HTTP {r.status_code}")
    return r


def renewed_key(response, current):
    for value in response.headers.get_list("set-cookie"):
        m = re.match(r"sessionKey=([^;]+)", value)
        if m and m.group(1) != current:
            return m.group(1)
    return None


def verify_owner(email, session_key):
    meta = account_meta(email)
    orgs = request("/organizations", session_key).json()
    if not any(o.get("uuid") == meta["org_uuid"] for o in orgs):
        raise WebError("wrong_account", "session does not belong to this account's organization")
    got = (request("/account", session_key).json().get("email_address") or "").lower()
    if got and got != email.lower():
        raise WebError("wrong_account", f"session belongs to {got}")
    return meta["org_uuid"]
