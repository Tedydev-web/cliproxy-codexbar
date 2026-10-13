#!/usr/bin/env bash
#
# One-line installer for CLIProxy CodexBar System
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Tedydev-web/cliproxy-codexbar/main/install.sh | bash
#
set -euo pipefail

OS="$(uname -s)"
echo "=== CLIProxy CodexBar Installer (Detected OS: ${OS}) ==="

if [ "${OS}" = "Darwin" ]; then
    echo ">> Cài đặt Client cho macOS..."
    TMP_DIR="/tmp/cliproxy-codexbar-install"
    rm -rf "${TMP_DIR}"
    git clone --depth 1 https://github.com/Tedydev-web/cliproxy-codexbar.git "${TMP_DIR}"
    cd "${TMP_DIR}/client-macos"
    ./install-client.sh
    echo "🎉 Cài đặt CodexBar Custom trên macOS thành công!"
elif [ "${OS}" = "Linux" ]; then
    echo ">> Cài đặt Backend Quota Bridge trên Linux..."
    TMP_DIR="/tmp/cliproxy-codexbar-install"
    rm -rf "${TMP_DIR}"
    git clone --depth 1 https://github.com/Tedydev-web/cliproxy-codexbar.git "${TMP_DIR}"
    cd "${TMP_DIR}"
    mkdir -p "${HOME}/.local/lib/cliproxy-bridge" "${HOME}/.local/bin"
    cp -r backend/bridge/* "${HOME}/.local/lib/cliproxy-bridge/"
    cat << 'WRAPPER' > "${HOME}/.local/bin/cliproxy-quota-bridge"
#!/usr/bin/env bash
exec python3 ~/.local/lib/cliproxy-bridge/main.py "$@"
WRAPPER
    chmod +x "${HOME}/.local/bin/cliproxy-quota-bridge"
    
    mkdir -p "${HOME}/.config/systemd/user"
    cp backend/cliproxy-quota-bridge.service "${HOME}/.config/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable --now cliproxy-quota-bridge.service
    echo "🎉 Cài đặt Backend Quota Bridge trên Linux thành công!"
else
    echo "❌ Hệ điều hành ${OS} chưa được hỗ trợ."
    exit 1
fi
