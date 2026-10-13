#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

echo "=== Cài đặt Claude Token Keeper & Vault (Systemd Service & Timer) ==="

mkdir -p "${BIN_DIR}" "${SYSTEMD_USER_DIR}"

# 1. Cài đặt file thực thi
echo "[1/3] Cài đặt claude-token-keeper vào ${BIN_DIR}..."
cp "${SCRIPT_DIR}/claude-token-keeper" "${BIN_DIR}/claude-token-keeper"
chmod +x "${BIN_DIR}/claude-token-keeper"

# 2. Cài đặt systemd units
echo "[2/3] Cài đặt systemd service và timer..."
cp "${SCRIPT_DIR}/claude-token-keeper.service" "${SYSTEMD_USER_DIR}/claude-token-keeper.service"
cp "${SCRIPT_DIR}/claude-token-keeper.timer" "${SYSTEMD_USER_DIR}/claude-token-keeper.timer"

# 3. Kích hoạt timer
echo "[3/3] Kích hoạt và khởi động timer..."
systemctl --user daemon-reload
systemctl --user enable --now claude-token-keeper.timer

echo "✅ Claude Token Keeper đã được thiết lập thành công!"
echo "   - Timer Status:"
systemctl --user status claude-token-keeper.timer --no-pager
