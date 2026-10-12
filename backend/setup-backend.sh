#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

echo "=== Cài đặt CLIProxy Quota Bridge Backend ==="

mkdir -p "${BIN_DIR}" "${SYSTEMD_USER_DIR}"

echo "[1/4] Sao chép file thực thi daemon..."
cp "${SCRIPT_DIR}/cliproxy-quota-bridge" "${BIN_DIR}/cliproxy-quota-bridge"
chmod +x "${BIN_DIR}/cliproxy-quota-bridge"

echo "[2/4] Sao chép systemd user service..."
cp "${SCRIPT_DIR}/cliproxy-quota-bridge.service" "${SYSTEMD_USER_DIR}/cliproxy-quota-bridge.service"

echo "[3/4] Kích hoạt và khởi động systemd service..."
systemctl --user daemon-reload
systemctl --user enable cliproxy-quota-bridge.service
systemctl --user restart cliproxy-quota-bridge.service

echo "[4/4] Kiểm tra trạng thái service..."
sleep 1
if systemctl --user is-active --quiet cliproxy-quota-bridge.service; then
    echo "✅ CLIProxy Quota Bridge đã hoạt động thành công tại cổng :8318!"
    echo "API Endpoints khả dụng:"
    echo "  - http://localhost:8318/v1/pool-status"
    echo "  - http://localhost:8318/v1/keeper-telemetry"
    echo "  - http://localhost:8318/v1/antigravity-quota"
else
    echo "❌ Có lỗi khi khởi động service. Vui lòng kiểm tra: journalctl --user -u cliproxy-quota-bridge -e"
    exit 1
fi
