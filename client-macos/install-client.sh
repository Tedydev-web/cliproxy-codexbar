#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_TARGET="/usr/local/bin/CodexBarCustom"
PLIST_SRC="${SCRIPT_DIR}/com.tedydev.codexbarcustom.plist"
PLIST_TARGET="${HOME}/Library/LaunchAgents/com.tedydev.codexbarcustom.plist"

echo "=== Cài đặt CodexBarCustom trên macOS ==="

# 1. Biên dịch
"${SCRIPT_DIR}/build.sh"

# 2. Dừng tiến trình cũ nếu đang chạy
echo "[1/4] Dừng tiến trình CodexBarCustom cũ (nếu có)..."
pkill -f CodexBarCustom || true
sleep 1

# 3. Cài đặt file nhị phân vào /usr/local/bin
echo "[2/4] Cài đặt file thực thi vào ${BIN_TARGET}..."
if [ -w "/usr/local/bin" ]; then
    cp "${SCRIPT_DIR}/build/CodexBarCustom" "${BIN_TARGET}"
else
    echo "Cần quyền quản trị để chép vào /usr/local/bin:"
    sudo cp "${SCRIPT_DIR}/build/CodexBarCustom" "${BIN_TARGET}"
fi
chmod +x "${BIN_TARGET}"

# 4. Cấu hình tự khởi động cùng máy qua LaunchAgent
echo "[3/4] Cấu hình LaunchAgent tự khởi động cùng macOS..."
mkdir -p "${HOME}/Library/LaunchAgents"
cp "${PLIST_SRC}" "${PLIST_TARGET}"
launchctl unload "${PLIST_TARGET}" 2>/dev/null || true
launchctl load "${PLIST_TARGET}"

# 5. Khởi động ứng dụng
echo "[4/4] Khởi động CodexBarCustom..."
sleep 1
if pgrep -f CodexBarCustom >/dev/null; then
    echo "✅ CodexBarCustom đã cài đặt và đang chạy thành công trên Menu Bar!"
else
    nohup "${BIN_TARGET}" >/dev/null 2>&1 &
    sleep 1
    if pgrep -f CodexBarCustom >/dev/null; then
        echo "✅ CodexBarCustom đã cài đặt và đang chạy thành công trên Menu Bar!"
    else
        echo "⚠️ Ứng dụng đã cài đặt nhưng chưa khởi động được. Hãy chạy thử: ${BIN_TARGET}"
    fi
fi
