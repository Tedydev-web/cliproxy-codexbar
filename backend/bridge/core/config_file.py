import os
import shutil
import threading

from core.config import CLIPROXY_HOME

CONFIG_FILE = os.path.join(CLIPROXY_HOME, "config.yaml")
LOCK = threading.RLock()


def read():
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return f.read()


def write_in_place(new, old, backup_suffix):
    if new == old:
        return
    shutil.copy2(CONFIG_FILE, CONFIG_FILE + backup_suffix)
    with open(CONFIG_FILE, "r+", encoding="utf-8") as f:
        f.seek(0)
        f.write(new)
        f.truncate()
        f.flush()
        os.fsync(f.fileno())
