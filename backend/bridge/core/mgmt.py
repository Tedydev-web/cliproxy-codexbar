import json
import time
import urllib.error
import urllib.request

from core.config import MGMT_HOST, MGMT_PORT, MGMT_SECRET

ROUTES = {
    "credentials": ("/v8/management/credentials", "/v0/management/auth-files"),
    "credentials_fields": ("/v8/management/credentials/fields", "/v0/management/auth-files/fields"),
    "credentials_refresh": ("/v8/management/credentials/refresh", "/v0/management/auth-files/refresh"),
    "usage_queue": ("/v8/management/observability/usage/queue", "/v0/management/usage-queue"),
}
V8_RETRY_SEC = 3600
_legacy_until = {}


class MgmtError(Exception):
    def __init__(self, status, body):
        super().__init__(f"HTTP {status}: {body[:120]}")
        self.status = status
        self.body = body


def _is_json(body):
    try:
        json.loads(body)
        return True
    except ValueError:
        return False


def _call(path, method, body, timeout):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        f"http://{MGMT_HOST}:{MGMT_PORT}{path}",
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {MGMT_SECRET}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        raise MgmtError(e.code, e.read().decode("utf-8", "replace"))
    return json.loads(raw) if raw else {}


def request(kind, method="GET", body=None, timeout=3, query=""):
    v8, v0 = ROUTES[kind]
    suffix = f"?{query}" if query else ""
    now = time.time()
    if _legacy_until.get(kind, 0) <= now:
        try:
            return _call(v8 + suffix, method, body, timeout)
        except MgmtError as e:
            if e.status != 404 or _is_json(e.body):
                raise
            _legacy_until[kind] = now + V8_RETRY_SEC
    return _call(v0 + suffix, method, body, timeout)


def call_v0(path, method="GET", body=None, timeout=10):
    return _call("/v0/management" + path, method, body, timeout)


def call_v8(path, method="GET", body=None, timeout=10):
    return _call("/v8/management" + path, method, body, timeout)


def reset_state():
    _legacy_until.clear()
