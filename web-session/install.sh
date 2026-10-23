#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE="${HOME}/.local/share/claude-web"
BIN="${HOME}/.local/bin"
UNITS="${HOME}/.config/systemd/user"

echo "=== Cài đặt claude-web-session (Ubuntu) ==="
mkdir -p "${SHARE}/lib" "${SHARE}/upstream" "${BIN}" "${UNITS}"

if [ ! -x "${SHARE}/venv/bin/python" ]; then
    echo "[1/5] Tạo venv riêng cho curl_cffi..."
    python3 -m venv "${SHARE}/venv"
fi
echo "[2/5] Cài phụ thuộc (curl_cffi giả vân tay TLS của Chrome để qua Cloudflare)..."
"${SHARE}/venv/bin/pip" install -q -r "${SRC}/requirements.txt"

echo "[3/5] Cài thư viện, script đọc cookie cho Mac và tài liệu..."
install -m 644 "${SRC}"/lib/*.py "${SHARE}/lib/"
install -m 644 "${SRC}/mac/mac_cookie_reader.py" "${SHARE}/mac_cookie_reader.py"
install -m 644 "${SRC}/THIRD_PARTY_NOTICES" "${SRC}/README.md" "${SHARE}/"
install -m 644 "${SRC}"/upstream/* "${SHARE}/upstream/"

echo "[4/5] Cài lệnh vào ${BIN}..."
install -m 755 "${SRC}/scripts/claude-web-sync" "${SRC}/scripts/claude-web-upstream-diff" "${BIN}/"
sed "1s|.*|#!${SHARE}/venv/bin/python|" "${SRC}/scripts/claude-web-session" > "${BIN}/claude-web-session"
chmod 755 "${BIN}/claude-web-session"

mkdir -p "${HOME}/.cliproxy/web-sessions"
chmod 700 "${HOME}/.cliproxy/web-sessions"

echo "[5/5] Cài timer systemd (làm mới cookie mỗi 2 giờ)..."
install -m 644 "${SRC}"/systemd/claude-web-sync.service "${SRC}"/systemd/claude-web-sync.timer "${UNITS}/"
systemctl --user daemon-reload
if [ "${NO_TIMER:-0}" != "1" ]; then
    systemctl --user enable --now claude-web-sync.timer
fi

echo "✅ Xong. Không đụng tới ${HOME}/.cliproxy/web-sessions (cookie đã lưu được giữ nguyên)."
echo "   Kiểm tra: claude-web-session list && claude-web-session check"
