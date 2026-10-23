#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE="${HOME}/.local/share/cliproxy-update"
BIN="${HOME}/.local/bin"
UNITS="${HOME}/.config/systemd/user"

echo "=== Cài đặt cliproxy-update ==="
mkdir -p "${SHARE}/lib" "${SHARE}/cache" "${BIN}" "${UNITS}" "${HOME}/.cliproxy/update-reports"
install -m 644 "${SRC}"/lib/*.py "${SHARE}/lib/"
install -m 644 "${SRC}/README.md" "${SHARE}/"
install -m 755 "${SRC}/scripts/cliproxy-update" "${BIN}/cliproxy-update"
install -m 644 "${SRC}"/systemd/cliproxy-update.service "${SRC}"/systemd/cliproxy-update.timer "${UNITS}/"
systemctl --user daemon-reload
if [ "${NO_TIMER:-0}" != "1" ]; then
    systemctl --user enable --now cliproxy-update.timer
fi
echo "✅ Xong. Kiểm tra: cliproxy-update status && cliproxy-update check"
