import re, json, os, hashlib, tarfile, tempfile, urllib.request

REPO = "router-for-me/CLIProxyAPI"
API = f"https://api.github.com/repos/{REPO}"
CATEGORIES = [
    ("Breaking, security, deprecations", re.compile(r"breaking|security|vuln|cve|leak|deprecat|migrat|remov", re.I)),
    ("Routing, cooldown, quota, credentials", re.compile(r"cooldown|quota|rate.?limit|routing|priority|session|affinity|prefix|request-scoped|credential|failover|retry|auth-files|management", re.I)),
    ("Claude and Anthropic", re.compile(r"claude|anthropic|cloak|thinking", re.I)),
]
KEEP = re.compile(r"^(feat|fix)\b", re.I)
NOISE = re.compile(r"Merge pull request|sponsor|README", re.I)
KEY_LINE = re.compile(r"^(\s*)(#\s*)?([a-z][a-z0-9_-]*):(\s|$)")


def http_json(url, timeout=30):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "cliproxy-update"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def http_bytes(url, timeout=300):
    req = urllib.request.Request(url, headers={"User-Agent": "cliproxy-update"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def parse_version(tag):
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", tag or "")
    return tuple(int(x) for x in m.groups()) if m else None


def fmt_version(v):
    return ".".join(str(x) for x in v)


def installed_version(banner):
    m = re.search(r"Version:\s*v?(\d+\.\d+\.\d+)", banner or "")
    return parse_version(m.group(1)) if m else None


def list_releases(limit=40):
    out = []
    for r in http_json(f"{API}/releases?per_page={limit}"):
        v = parse_version(r["tag_name"])
        if v and not r.get("prerelease") and not r.get("draft"):
            out.append({"version": v, "tag": r["tag_name"], "published_at": r["published_at"], "body": r.get("body") or "", "assets": r["assets"]})
    return sorted(out, key=lambda x: x["version"])


def changelog_items(body):
    part = body.split("## Changelog")[-1] if "## Changelog" in body else body
    return [re.sub(r"\s*\([0-9a-f]{7,}\)\s*$", "", l.strip()[2:]) for l in part.splitlines() if l.strip().startswith("- ")]


def summarize(releases):
    seen, buckets, other = set(), {name: [] for name, _ in CATEGORIES}, 0
    for r in releases:
        for item in changelog_items(r["body"]):
            if item in seen or NOISE.search(item) or not KEEP.search(item):
                continue
            seen.add(item)
            for name, rx in CATEGORIES:
                if rx.search(item):
                    buckets[name].append((fmt_version(r["version"]), item))
                    break
            else:
                other += 1
    return buckets, other


def pick_asset(release, flavor="default", arch="amd64"):
    suffix = f"_linux_{arch}{'' if flavor == 'default' else '_' + flavor}.tar.gz"
    return next((a for a in release["assets"] if a["name"].endswith(suffix)), None)


def sha256_of(data):
    return hashlib.sha256(data).hexdigest()


def expected_checksum(release, asset_name):
    asset = next((a for a in release["assets"] if a["name"] == "checksums.txt"), None)
    if not asset:
        return None
    for line in http_bytes(asset["browser_download_url"]).decode().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == asset_name:
            return parts[0]
    return None


def download_release(release, workdir, flavor="default", arch="amd64"):
    asset = pick_asset(release, flavor, arch)
    if not asset:
        raise RuntimeError(f"no linux_{arch} asset in {release['tag']}")
    data = http_bytes(asset["browser_download_url"])
    want = expected_checksum(release, asset["name"])
    if not want or sha256_of(data) != want:
        raise RuntimeError(f"checksum mismatch or missing for {asset['name']}")
    tgz = os.path.join(workdir, asset["name"])
    with open(tgz, "wb") as f:
        f.write(data)
    dest = os.path.join(workdir, "x")
    os.makedirs(dest, exist_ok=True)
    with tarfile.open(tgz) as t:
        for m in t.getmembers():
            if m.name in ("cli-proxy-api", "config.example.yaml"):
                t.extract(m, dest, filter="data")
    return os.path.join(dest, "cli-proxy-api"), os.path.join(dest, "config.example.yaml")


def option_keys(text):
    keys, section, docs, indents, order, buf = {}, "", {}, {}, [], []
    for line in text.splitlines():
        m = KEY_LINE.match(line)
        if m and not m.group(2) and not m.group(1):
            section = m.group(3)
        if m and (m.group(1) or m.group(2) or section):
            ident = (section, m.group(3))
            if ident not in keys:
                keys[ident] = line.strip()
                docs[ident] = [b for b in buf[-3:] if b]
                indents[ident] = len(m.group(1)) + len(m.group(2) or "")
                order.append(ident)
            buf = []
        elif line.strip().startswith("#"):
            buf.append(line.strip().lstrip("# ").strip())
        else:
            buf = []
    return keys, docs, indents, order


def new_options(old_text, new_text):
    old_keys = option_keys(old_text)[0]
    keys, docs, indents, order = option_keys(new_text)
    out, parent = [], None
    for ident in (k for k in order if k not in old_keys):
        entry = {"section": ident[0], "key": ident[1], "line": keys[ident], "doc": docs[ident], "children": [], "indent": indents[ident]}
        if parent and entry["indent"] > parent["indent"] and parent["line"].rstrip().endswith(":"):
            parent["children"].append(entry["key"])
            continue
        out.append(entry)
        parent = entry
    return out


def unset_options(options, config):
    flat = set()

    def walk(d, section):
        if isinstance(d, dict):
            for k, v in d.items():
                flat.add((section, str(k)))
                flat.add(("*", str(k)))
                walk(v, section or str(k))

    walk(config, "")
    return [o for o in options if (o["section"], o["key"]) not in flat and ("*", o["key"]) not in flat]
