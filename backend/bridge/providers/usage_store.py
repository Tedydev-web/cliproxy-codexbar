import datetime
import hashlib
import json
import os
import re
import sqlite3
import sys
import threading
import time

from core import mgmt
from core.config import CLIPROXY_HOME

DB_FILE = os.path.join(CLIPROXY_HOME, "usage.db")
LABELS_FILE = os.path.join(CLIPROXY_HOME, "key-labels.json")
POLL_SEC = 15
BATCH = 200
MAX_BATCHES = 10
RETENTION_DAYS = 400
ERROR_LOG_EVERY_SEC = 300

SCHEMA = """
CREATE TABLE IF NOT EXISTS usage_daily (
    day TEXT NOT NULL,
    source TEXT NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    client TEXT NOT NULL,
    key_tag TEXT NOT NULL,
    requests INTEGER NOT NULL DEFAULT 0,
    failed INTEGER NOT NULL DEFAULT 0,
    input INTEGER NOT NULL DEFAULT 0,
    output INTEGER NOT NULL DEFAULT 0,
    cache_read INTEGER NOT NULL DEFAULT 0,
    cache_create INTEGER NOT NULL DEFAULT 0,
    reasoning INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (day, source, provider, model, client, key_tag)
)
"""
COUNTERS = ("requests", "failed", "input", "output", "cache_read", "cache_create", "reasoning")
FRACTION = re.compile(r"(\.\d{6})\d+")


def key_tag(api_key):
    return hashlib.sha256(api_key.encode("utf-8")).hexdigest()[:8] if api_key else ""


def ip_class(ip):
    ip = str(ip or "")
    if ip.startswith("127.") or ip in ("::1", ""):
        return "local"
    if ip.startswith("100."):
        return "tailscale"
    parts = ip.split(".")
    if len(parts) == 4 and parts[0] == "172" and parts[1].isdigit() and 16 <= int(parts[1]) <= 31:
        return "docker"
    return "other"


def client_label(ip, user_agent):
    family = re.split(r"[/\s(]", str(user_agent or "").strip(), maxsplit=1)[0].lower()[:24] or "unknown"
    return f"{ip_class(ip)}:{family}"


def day_of(timestamp):
    try:
        stamp = datetime.datetime.fromisoformat(FRACTION.sub(r"\1", str(timestamp)))
        return stamp.astimezone().date().isoformat()
    except ValueError:
        return datetime.date.today().isoformat()


def row_of(record):
    tokens = record.get("tokens") or {}
    key = (
        day_of(record.get("timestamp")),
        str(record.get("source") or "unknown")[:64],
        str(record.get("provider") or "unknown")[:32],
        str(record.get("model") or record.get("alias") or "unknown")[:64],
        client_label(record.get("resolved_client_ip") or record.get("client_ip"), record.get("user_agent")),
        key_tag(record.get("api_key")),
    )
    values = {
        "requests": 1,
        "failed": 1 if record.get("failed") else 0,
        "input": int(tokens.get("input_tokens") or 0),
        "output": int(tokens.get("output_tokens") or 0),
        "cache_read": int(tokens.get("cache_read_tokens") or 0),
        "cache_create": int(tokens.get("cache_creation_tokens") or 0),
        "reasoning": int(tokens.get("reasoning_tokens") or 0),
    }
    return key, values


class UsageCollector:
    def __init__(self, db_path=None, labels_path=None):
        self.db_path = db_path or DB_FILE
        self.labels_path = labels_path or LABELS_FILE
        self._lock = threading.Lock()
        self._last_error_log = 0.0
        self._last_purge_day = ""
        self._started = False
        self._init_db()

    def _connect(self):
        conn = sqlite3.connect(self.db_path, timeout=10)
        conn.execute("PRAGMA journal_mode=WAL")
        return conn

    def _init_db(self):
        if not os.path.exists(self.db_path):
            os.close(os.open(self.db_path, os.O_CREAT | os.O_WRONLY, 0o600))
        with self._lock, self._connect() as conn:
            conn.execute(SCHEMA)

    def _labels(self):
        try:
            with open(self.labels_path, "r", encoding="utf-8") as f:
                return {str(k): str(v) for k, v in json.load(f).items()}
        except (OSError, ValueError):
            return {}

    def store(self, records):
        buckets = {}
        for record in records:
            if not isinstance(record, dict):
                continue
            key, values = row_of(record)
            bucket = buckets.setdefault(key, dict.fromkeys(COUNTERS, 0))
            for name, amount in values.items():
                bucket[name] += amount
        if not buckets:
            return 0
        sets = ", ".join(f"{c} = {c} + excluded.{c}" for c in COUNTERS)
        sql = (
            "INSERT INTO usage_daily (day, source, provider, model, client, key_tag, " + ", ".join(COUNTERS) + ") "
            "VALUES (?, ?, ?, ?, ?, ?, " + ", ".join("?" for _ in COUNTERS) + ") "
            "ON CONFLICT(day, source, provider, model, client, key_tag) DO UPDATE SET " + sets
        )
        with self._lock, self._connect() as conn:
            conn.executemany(sql, [key + tuple(values[c] for c in COUNTERS) for key, values in buckets.items()])
        return sum(v["requests"] for v in buckets.values())

    def poll_once(self):
        stored = 0
        for _ in range(MAX_BATCHES):
            records = mgmt.request("usage_queue", query=f"count={BATCH}", timeout=5)
            if not isinstance(records, list) or not records:
                break
            stored += self.store(records)
            if len(records) < BATCH:
                break
        self._purge_old()
        return stored

    def _purge_old(self):
        today = datetime.date.today().isoformat()
        if today == self._last_purge_day:
            return
        self._last_purge_day = today
        cutoff = (datetime.date.today() - datetime.timedelta(days=RETENTION_DAYS)).isoformat()
        with self._lock, self._connect() as conn:
            conn.execute("DELETE FROM usage_daily WHERE day < ?", (cutoff,))

    def _loop(self):
        while True:
            try:
                self.poll_once()
            except Exception as e:
                now = time.time()
                if now - self._last_error_log > ERROR_LOG_EVERY_SEC:
                    self._last_error_log = now
                    print(f"usage collector: {e}", file=sys.stderr)
            time.sleep(POLL_SEC)

    def start(self):
        if self._started:
            return
        self._started = True
        threading.Thread(target=self._loop, daemon=True, name="usage-collector").start()

    def summary(self, days=7):
        days = max(1, min(int(days), 90))
        since = (datetime.date.today() - datetime.timedelta(days=days - 1)).isoformat()
        labels = self._labels()
        cols = ", ".join(f"SUM({c})" for c in COUNTERS)

        def rows(group_by):
            with self._lock, self._connect() as conn:
                return conn.execute(
                    f"SELECT {group_by}, {cols} FROM usage_daily WHERE day >= ? GROUP BY {group_by}", (since,)
                ).fetchall()

        def pack(head, row):
            counts = dict(zip(COUNTERS, (int(v or 0) for v in row[len(head):])))
            counts["tokens"] = counts["input"] + counts["output"] + counts["cache_read"] + counts["cache_create"]
            return counts

        def listing(group_by, names, order="tokens"):
            out = []
            for row in rows(group_by):
                head = row[: len(names)]
                item = dict(zip(names, head))
                if "key" in item:
                    item["key"] = labels.get(item["key"], item["key"] or "-")
                item.update(pack(names, row))
                out.append(item)
            return sorted(out, key=lambda i: (-i[order], str(i[names[0]])))

        by_day = listing("day", ["day"])
        by_day.sort(key=lambda i: i["day"])
        totals = dict.fromkeys(COUNTERS, 0)
        for item in by_day:
            for name in COUNTERS:
                totals[name] += item[name]
        totals["tokens"] = totals["input"] + totals["output"] + totals["cache_read"] + totals["cache_create"]
        return {
            "days": days,
            "since": since,
            "generated_at": int(time.time()),
            "totals": totals,
            "by_day": by_day,
            "by_source": listing("source", ["source"]),
            "by_client": listing("client, key_tag", ["client", "key"]),
            "by_model": listing("provider, model", ["provider", "model"]),
        }
