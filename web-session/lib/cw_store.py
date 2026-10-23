import os, json, glob, fcntl, datetime, contextlib

HOME = os.path.expanduser("~/.cliproxy")
AUTH_DIR = f"{HOME}/auth"
STORE = f"{HOME}/web-sessions"


class WebError(Exception):
    def __init__(self, code, message, retry_after=None):
        super().__init__(message)
        self.code = code
        self.retry_after = retry_after


def nick_of(email):
    return email.split("@")[0]


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def session_path(email):
    return f"{STORE}/{nick_of(email)}.json"


@contextlib.contextmanager
def locked():
    os.makedirs(STORE, mode=0o700, exist_ok=True)
    os.chmod(STORE, 0o700)
    fd = os.open(f"{STORE}/.lock", os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def read_session(email):
    path = session_path(email)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_session(email, data):
    path = session_path(email)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def load_session(email):
    s = read_session(email)
    if s is None:
        raise WebError("no_session", f"no web session stored for {email}")
    return s


def update_session(email, mutate):
    with locked():
        s = read_session(email) or {}
        mutate(s)
        write_session(email, s)
        return s


def stored_emails():
    out = []
    for path in sorted(glob.glob(f"{STORE}/*.json")):
        with open(path, encoding="utf-8") as f:
            out.append(json.load(f)["email"])
    return out


def pool_emails():
    out = {}
    for path in glob.glob(f"{AUTH_DIR}/claude-*-setup-token.json"):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        if d.get("email"):
            out[d["email"].lower()] = d["email"]
    return out


def account_meta(email):
    path = f"{AUTH_DIR}/claude-{nick_of(email)}-setup-token.json"
    if not os.path.exists(path):
        raise WebError("unknown_account", f"no setup-token file for {email}")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return {"org_uuid": d.get("organization_uuid"), "email": d.get("email")}
