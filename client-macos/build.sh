#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/Sources/OrbiterMenuBar.swift"
OUTPUT="${SCRIPT_DIR}/build/OrbiterMenuBar"

echo "=== Biên dịch OrbiterMenuBar cho macOS ==="

mkdir -p "${SCRIPT_DIR}/build"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "❌ Lỗi: swiftc chưa được cài đặt. Hãy cài đặt Xcode Command Line Tools qua lệnh: xcode-select --install"
    exit 1
fi

echo "[1/2] Đang biên dịch với tối ưu hóa (-O)..."
swiftc -O -framework Cocoa -framework SwiftUI "${SRC}" -o "${OUTPUT}"

echo "[2/2] Hoàn tất! File thực thi đã được tạo tại: ${OUTPUT}"
ls -lh "${OUTPUT}"
