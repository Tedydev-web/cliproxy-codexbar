#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Tự động chọn thư mục cài đặt phù hợp (ưu tiên /usr/local/bin nếu ghi được, nếu không dùng ~/.local/bin)
if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    BIN_DIR="/usr/local/bin"
elif mkdir -p "/usr/local/bin" 2>/dev/null && [ -w "/usr/local/bin" ]; then
    BIN_DIR="/usr/local/bin"
else
    BIN_DIR="${HOME}/.local/bin"
    mkdir -p "${BIN_DIR}"
fi

BIN_TARGET="${BIN_DIR}/CodexBarCustom"
PLIST_TARGET="${HOME}/Library/LaunchAgents/com.tedydev.codexbarcustom.plist"

echo "=== Cài đặt CodexBarCustom trên macOS ==="

# 1. Biên dịch
"${SCRIPT_DIR}/build.sh"

# 2. Dừng tiến trình cũ nếu đang chạy
echo "[1/4] Dừng tiến trình CodexBarCustom cũ (nếu có)..."
pkill -f CodexBarCustom || true
sleep 1

# 3. Cài đặt file nhị phân
echo "[2/4] Cài đặt file thực thi vào ${BIN_TARGET}..."
cp "${SCRIPT_DIR}/build/CodexBarCustom" "${BIN_TARGET}"
chmod +x "${BIN_TARGET}"

# 4. Cấu hình tự khởi động cùng máy qua LaunchAgent
echo "[3/4] Cấu hình LaunchAgent tự khởi động cùng macOS..."
mkdir -p "${HOME}/Library/LaunchAgents"
cat <<EOF > "${PLIST_TARGET}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tedydev.codexbarcustom</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_TARGET}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/CodexBarCustom.err.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/CodexBarCustom.out.log</string>
</dict>
</plist>
EOF
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
