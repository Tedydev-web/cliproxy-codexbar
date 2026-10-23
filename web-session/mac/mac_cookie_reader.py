import os, re, sys, json, glob, shutil, sqlite3, struct, subprocess, tempfile, hashlib, datetime

HOME = os.path.expanduser("~")
SUPPORT = f"{HOME}/Library/Application Support"
KEY_RE = re.compile(rb"sk-ant-sid\d+-[A-Za-z0-9_\-]+")
CHROMIUM = {
    "chrome": ("Google/Chrome", "Chrome Safe Storage", "Chrome"),
    "brave": ("BraveSoftware/Brave-Browser", "Brave Safe Storage", "Brave"),
    "edge": ("Microsoft Edge", "Microsoft Edge Safe Storage", "Microsoft Edge"),
    "arc": ("Arc/User Data", "Arc Safe Storage", "Arc"),
}
SAFARI_PATHS = [
    f"{HOME}/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies",
    f"{HOME}/Library/Cookies/Cookies.binarycookies",
]
APPLE_EPOCH = 978307200


def emit(browser, profile, key, expires):
    print(json.dumps({"browser": browser, "profile": profile, "session_key": key, "expires": expires}), flush=True)


def log(message):
    print(message, file=sys.stderr, flush=True)


def safari_cookies(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"cook":
        return
    pages = struct.unpack(">i", data[4:8])[0]
    sizes = struct.unpack(f">{pages}i", data[8:8 + 4 * pages])
    offset = 8 + 4 * pages
    for size in sizes:
        page = data[offset:offset + size]
        offset += size
        count = struct.unpack("<i", page[4:8])[0]
        for i in range(count):
            start = struct.unpack("<i", page[8 + 4 * i:12 + 4 * i])[0]
            rec = page[start:]
            url_off, name_off, _, value_off = struct.unpack("<4i", rec[16:32])
            expiry = struct.unpack("<d", rec[40:48])[0]

            def cstr(o):
                end = rec.index(b"\x00", o)
                return rec[o:end].decode("utf-8", "replace")

            yield cstr(url_off), cstr(name_off), cstr(value_off), expiry


def read_safari():
    path = next((p for p in SAFARI_PATHS if os.path.exists(p)), None)
    if not path:
        log("safari: cookie file not found")
        return
    try:
        for host, name, value, expiry in safari_cookies(path):
            if name == "sessionKey" and host.endswith("claude.ai") and value.startswith("sk-ant-"):
                exp = datetime.datetime.fromtimestamp(expiry + APPLE_EPOCH, datetime.timezone.utc).isoformat()
                emit("safari", "default", value, exp)
    except PermissionError:
        log("safari: permission denied (grant Full Disk Access to the SSH/terminal process)")


def keychain_password(service, account):
    try:
        r = subprocess.run(
            ["security", "find-generic-password", "-w", "-s", service, "-a", account],
            capture_output=True, text=True, timeout=int(os.environ.get("KEYCHAIN_TIMEOUT", "60")),
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"keychain prompt for {service} timed out")
    if r.returncode != 0:
        hint = r.stderr.strip()[:120] or "no message (the approval prompt cannot appear in an SSH session)"
        raise RuntimeError(f"keychain read failed for {service}, rc={r.returncode}: {hint}")
    return r.stdout.strip()


def decrypt_v10(blob, password):
    key = hashlib.pbkdf2_hmac("sha1", password.encode(), b"saltysalt", 1003, 16)
    r = subprocess.run(
        ["openssl", "enc", "-d", "-aes-128-cbc", "-K", key.hex(), "-iv", (b" " * 16).hex()],
        input=blob[3:], capture_output=True,
    )
    return r.stdout


def profile_names(root):
    try:
        with open(f"{root}/Local State", encoding="utf-8") as f:
            return {k: v.get("name", k) for k, v in json.load(f)["profile"]["info_cache"].items()}
    except Exception:
        return {}


def read_chromium(browser):
    rel, service, account = CHROMIUM[browser]
    root = f"{SUPPORT}/{rel}"
    dbs = sorted(glob.glob(f"{root}/*/Cookies") + glob.glob(f"{root}/*/Network/Cookies"))
    if not dbs:
        return
    names = profile_names(root)
    password = None
    for db in dbs:
        profile = db[len(root) + 1:].split("/")[0]
        tmp = tempfile.mktemp()
        try:
            shutil.copy(db, tmp)
            for ext in ("-wal", "-shm"):
                if os.path.exists(db + ext):
                    shutil.copy(db + ext, tmp + ext)
            conn = sqlite3.connect(f"file:{tmp}?mode=ro", uri=True)
            rows = conn.execute(
                "select value, encrypted_value, expires_utc from cookies "
                "where host_key like '%claude.ai' and name='sessionKey'"
            ).fetchall()
            for value, enc, expires in rows:
                token = value if value else None
                if not token and enc[:3] == b"v10":
                    if password is None:
                        password = keychain_password(service, account)
                    m = KEY_RE.search(decrypt_v10(bytes(enc), password))
                    token = m.group(0).decode() if m else None
                if token:
                    exp = (datetime.datetime(1601, 1, 1) + datetime.timedelta(microseconds=expires)).isoformat() if expires else None
                    emit(browser, names.get(profile, profile), token, exp)
        except Exception as e:
            log(f"{browser}/{profile}: {e}")
        finally:
            for ext in ("", "-wal", "-shm"):
                if os.path.exists(tmp + ext):
                    os.remove(tmp + ext)


def main():
    wanted = (sys.argv[sys.argv.index("--browsers") + 1] if "--browsers" in sys.argv else "safari,chrome").split(",")
    for b in wanted:
        if b == "safari":
            read_safari()
        elif b in CHROMIUM:
            read_chromium(b)
        else:
            log(f"unknown browser {b}")


main()
