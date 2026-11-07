import json
import os
import threading
import time
import urllib.parse
from datetime import datetime, timezone

from core import mgmt
from core.config import ACCOUNTS_FILE, AUTH_DIR, CLIPROXY_HOME

AUTH_PAUSED_DIR = os.path.join(CLIPROXY_HOME, "auth-paused")
STATE_TTL_SEC = 600
COMPLETE_WAIT_SEC = 12

_lock = threading.Lock()
_pending = {}


class ReauthError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def _claude_files():
    try:
        names = os.listdir(AUTH_DIR)
    except OSError:
        return {}
    out = {}
    for name in names:
        if name.startswith("claude-") and name.endswith(".json"):
            try:
                out[name] = os.stat(os.path.join(AUTH_DIR, name)).st_mtime_ns
            except OSError:
                continue
    return out


def _read_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _mgmt_call(path, method="GET", body=None, timeout=15):
    try:
        return mgmt.call_v0(path, method, body, timeout)
    except mgmt.MgmtError as e:
        status = e.status if 400 <= e.status < 500 else 502
        raise ReauthError(status, f"CLIProxy từ chối yêu cầu ({e.status}): {e.body[:160]}")
    except OSError as e:
        raise ReauthError(502, f"Không gọi được CLIProxy: {e}")


def _prune(now):
    for state in [s for s, job in _pending.items() if now - job["started"] > STATE_TTL_SEC]:
        del _pending[state]


def start(email=None):
    res = _mgmt_call("/anthropic-auth-url")
    state, url = res.get("state"), res.get("url")
    if not state or not url:
        raise ReauthError(502, "CLIProxy không trả về phiên OAuth")
    now = time.time()
    with _lock:
        _prune(now)
        _pending[state] = {"email": email, "started": now, "before": _claude_files(), "result": None}
    return {"ok": True, "state": state, "url": url, "email": email, "expiresInSec": STATE_TTL_SEC}


def callback_state(redirect_url):
    parts = urllib.parse.urlsplit((redirect_url or "").strip())
    query = urllib.parse.parse_qs(parts.query)
    if parts.path != "/callback" or not query.get("code") or not query.get("state"):
        raise ReauthError(400, "redirect_url phải có dạng http://localhost:54545/callback?code=...&state=...")
    return query["state"][0]


def complete(state, redirect_url):
    with _lock:
        _prune(time.time())
        job = _pending.get(state)
    if not job:
        raise ReauthError(404, "Phiên đăng nhập không tồn tại hoặc đã hết hạn")
    if callback_state(redirect_url) != state:
        raise ReauthError(400, "state trong redirect_url không khớp phiên")
    _mgmt_call("/oauth-callback", "POST", {"provider": "anthropic", "redirect_url": redirect_url.strip()})
    return status(state, wait=COMPLETE_WAIT_SEC)


def status(state, wait=0):
    with _lock:
        job = _pending.get(state)
    if not job:
        raise ReauthError(404, "Phiên đăng nhập không tồn tại hoặc đã hết hạn")
    deadline = time.time() + wait
    while True:
        with _lock:
            if job["result"]:
                return job["result"]
        res = _mgmt_call("/get-auth-status?state=" + urllib.parse.quote(state), timeout=10)
        state_name = res.get("status")
        if state_name == "ok":
            with _lock:
                if not job["result"]:
                    job["result"] = _finalize(job)
                return job["result"]
        if state_name == "error":
            with _lock:
                job["result"] = {"ok": False, "error": res.get("error") or "Đăng nhập thất bại"}
                return job["result"]
        if time.time() >= deadline:
            return {"ok": False, "pending": True}
        time.sleep(1)


def _locate_new_token(job):
    before = job["before"]
    after = _claude_files()
    changed = [n for n, m in after.items() if before.get(n) != m]
    fresh = [n for n in changed if n not in before]
    candidates = fresh
    if not candidates and job["email"]:
        want = job["email"].lower()
        candidates = [n for n in changed if str(_read_json(os.path.join(AUTH_DIR, n)).get("email", "")).lower() == want]
    candidates = [n for n in candidates if _read_json(os.path.join(AUTH_DIR, n)).get("refresh_token")]
    if len(candidates) != 1:
        raise ReauthError(500, "Không xác định được file token mới sau khi đăng nhập")
    return candidates[0]


def _write_accounts(data):
    tmp = ACCOUNTS_FILE + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, ACCOUNTS_FILE)


def _finalize(job):
    try:
        name = _locate_new_token(job)
        data = _read_json(os.path.join(AUTH_DIR, name))
        email = data.get("email")
        if not email:
            raise ReauthError(500, "File token mới không có email")
        accounts_doc = _read_json(ACCOUNTS_FILE)
        claude = accounts_doc.setdefault("providers", {}).setdefault("claude", {})
        accounts = claude.setdefault("accounts", {})
        info = accounts.get(email)
        target = name
        if info:
            token_file = info.get("tokenFile")
            primary = _read_json(os.path.join(AUTH_DIR, token_file)) if token_file else {}
            if token_file and not primary.get("refresh_token"):
                siblings = [
                    n for n in sorted(_claude_files())
                    if n != name and n != token_file
                    and str(_read_json(os.path.join(AUTH_DIR, n)).get("email", "")).lower() == email.lower()
                    and _read_json(os.path.join(AUTH_DIR, n)).get("refresh_token")
                ]
                target = siblings[0] if siblings else name
            else:
                target = token_file or name
            if target != name:
                os.replace(os.path.join(AUTH_DIR, name), os.path.join(AUTH_DIR, target))
            info["status"] = "active"
            info["authorizedAt"] = datetime.now(timezone.utc).isoformat()
            info.setdefault("tokenFile", target)
        else:
            stamp = datetime.now(timezone.utc).isoformat()
            accounts[email] = {
                "email": email,
                "nickname": email.split("@")[0],
                "tokenFile": name,
                "createdAt": stamp,
                "authorizedAt": stamp,
                "status": "active",
            }
        ordered = claude.setdefault("drainOrder", {}).setdefault("orderedIds", [])
        if email not in ordered:
            ordered.append(email)
        _write_accounts(accounts_doc)
        for paused in {name, target, (info or {}).get("tokenFile")}:
            if paused:
                try:
                    os.remove(os.path.join(AUTH_PAUSED_DIR, paused))
                except OSError:
                    pass
        wanted = (job["email"] or "").lower()
        return {
            "ok": True,
            "email": email,
            "tokenFile": target,
            "status": "active",
            "newAccount": info is None,
            "emailMismatch": bool(wanted and wanted != email.lower()),
        }
    except ReauthError as e:
        return {"ok": False, "error": e.message}
    except OSError as e:
        return {"ok": False, "error": f"Không ghi được credential: {e}"}
