#!/usr/bin/env bash
set -euo pipefail

: "${UBUNTU_HOST:?UBUNTU_HOST chưa được set (dạng user@host, ví dụ tedydev@100.127.1.234)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_HOME="${REMOTE_HOME:-/home/${UBUNTU_HOST%@*}}"
PYTHON3="${PYTHON3:-$(command -v python3)}"
LABEL="com.tedydev.claude-web-push"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

echo "=== Cài LaunchAgent đẩy cookie claude.ai (macOS) ==="
[ -x "${PYTHON3}" ] || { echo "❌ Không tìm thấy python3"; exit 1; }
/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=8 "${UBUNTU_HOST}" "test -f ${REMOTE_HOME}/.local/bin/claude-web-session" \
    || { echo "❌ Không SSH được vào ${UBUNTU_HOST} hoặc claude-web-session chưa được cài ở đó (chạy web-session/install.sh trên Ubuntu trước)"; exit 1; }

mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs"
sed -e "s|__UBUNTU_HOST__|${UBUNTU_HOST}|g" \
    -e "s|__REMOTE_HOME__|${REMOTE_HOME}|g" \
    -e "s|__PYTHON3__|${PYTHON3}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "${SCRIPT_DIR}/${LABEL}.plist.template" > "${PLIST}"
chmod 644 "${PLIST}"
plutil -lint "${PLIST}" >/dev/null

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST}"
echo "✅ Đã cài ${LABEL} (chạy khi đăng nhập và mỗi 2 giờ). Nhật ký: ${HOME}/Library/Logs/claude-web-push.log"
echo "   Lần đầu chạy, macOS có thể hỏi quyền Keychain cho 'Chrome Safe Storage': bấm Always Allow trong phiên đồ họa."
