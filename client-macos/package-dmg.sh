#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="OrbiterMenuBar"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-macOS.dmg"
DMG_OUTPUT="${BUILD_DIR}/${DMG_NAME}"

echo "=== Đóng gói ${APP_NAME} thành macOS App Bundle & .dmg ==="

# 1. Biên dịch binary
"${SCRIPT_DIR}/build.sh"

# 2. Tạo App Bundle Structure
echo "[1/3] Tạo App Bundle tại: ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy icon resources
if [ -d "${SCRIPT_DIR}/Resources" ]; then
    cp -r "${SCRIPT_DIR}/Resources/"* "${APP_BUNDLE}/Contents/Resources/"
fi

# Info.plist
cat <<PLIST > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.tedydev.orbitermenubar</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# 3. Tạo DMG nếu chạy trên macOS
if command -v hdiutil >/dev/null 2>&1; then
    echo "[2/3] Đang đóng gói file DMG bằng hdiutil..."
    DMG_TMP="${BUILD_DIR}/dmg-temp"
    rm -rf "${DMG_TMP}" "${DMG_OUTPUT}"
    mkdir -p "${DMG_TMP}"
    cp -r "${APP_BUNDLE}" "${DMG_TMP}/"
    ln -s /Applications "${DMG_TMP}/Applications"

    hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"
    rm -rf "${DMG_TMP}"
    echo "[3/3] ✅ Hoàn tất! File DMG đã tạo tại: ${DMG_OUTPUT}"
    ls -lh "${DMG_OUTPUT}"
else
    echo "[2/3] ℹ️ hdiutil chỉ có trên macOS. Đã tạo hoàn tất App Bundle ${APP_BUNDLE}."
fi
