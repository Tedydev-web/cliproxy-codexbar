#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="${SCRIPT_DIR}/client-macos"

# Danh sách các thiết bị macOS cần đồng bộ
MACOS_HOSTS=(
    "tedydev@100.127.1.236"  # MBP
    "tedydev@100.127.1.235"  # iMac
)

echo "=== Orbiter Menubar Multi-Machine Sync Tool ==="

# 1. Đồng bộ Backend trên máy hiện tại (Ubuntu Host)
echo "--------------------------------------------------"
echo "[1/2] Đồng bộ Backend trên máy chủ cục bộ..."
mkdir -p ~/.local/lib/cliproxy-bridge ~/.local/bin
cp -r "${SCRIPT_DIR}/backend/bridge/"* ~/.local/lib/cliproxy-bridge/
mkdir -p ~/.local/lib/cliproxy-bridge/widgets
cp "${SCRIPT_DIR}/ios-widget/OrbiterClaudeWidget.js" "${SCRIPT_DIR}/ios-widget/OrbiterAGYWidget.js" ~/.local/lib/cliproxy-bridge/widgets/
cat << 'EOF' > ~/.local/bin/cliproxy-quota-bridge
#!/usr/bin/env bash
exec python3 ~/.local/lib/cliproxy-bridge/main.py "$@"
EOF
chmod +x ~/.local/bin/cliproxy-quota-bridge
systemctl --user restart cliproxy-quota-bridge
echo "✅ Backend đã được cập nhật và khởi động lại thành công!"

# 2. Đồng bộ các máy macOS
echo "--------------------------------------------------"
echo "[2/2] Đồng bộ các thiết bị macOS..."

BRIDGE_SECRET=$(grep CLIPROXY_MANAGEMENT_SECRET "${HOME}/.cliproxy/bridge.env" | cut -d= -f2-)

for host in "${MACOS_HOSTS[@]}"; do
    echo ">> Đang kiểm tra kết nối tới: ${host}..."
    if ssh -o ConnectTimeout=4 -o BatchMode=yes "${host}" "echo 2>&1" >/dev/null 2>&1; then
        echo "   [+] Kết nối thành công! Đang truyền file và cập nhật..."
        rsync -az --delete "${CLIENT_DIR}/" "${host}:/tmp/client-macos/"
        ssh "${host}" "cd /tmp/client-macos && CLIPROXY_BRIDGE_SECRET='${BRIDGE_SECRET}' ./install-client.sh"
        echo "   ✅ Đã đồng bộ và khởi chạy phiên bản mới nhất trên ${host}!"
    else
        echo "   ⚠️ ${host} hiện đang OFFLINE hoặc ngủ (sleep) - Đã bỏ qua."
        echo "      (Khi máy online trở lại, chỉ cần chạy lại: ./sync-all.sh)"
    fi
done

echo "--------------------------------------------------"
echo "🎉 Hoàn tất quá trình đồng bộ toàn hệ thống!"
