# CLIProxy CodexBar (Custom Suite)

Hệ thống giám sát và quản lý Quota CLIProxy (Claude & Antigravity) trên macOS Menu Bar theo chuẩn thiết kế native của **CodexBar**.

---

## 🏛 Kiến trúc hệ thống

```
┌──────────────────────────────────────────────┐
│  Linux / Server Host (100.127.1.234)         │
│  - CLIProxy + CCS Node.js Runtime            │
│  - cliproxy-quota-bridge (Python Daemon:8318)│
│  - systemd user service quản lý vòng đời     │
└──────────────────────┬───────────────────────┘
                       │ HTTP REST API (:8318)
┌──────────────────────▼───────────────────────┐
│  macOS Client (iMac, MacBook, v.v.)          │
│  - CodexBarCustom (Swift native AppKit Menu) │
│  - LaunchAgent tự khởi động cùng máy         │
│  - Nhúng sẵn biểu tượng Base64 (Zero-asset)  │
└──────────────────────────────────────────────┘
```

---

## ✨ Tính năng nổi bật

1. **Giao diện Menu Bar Native Chuẩn Apple**:
   - Menu gắn thẳng dưới biểu tượng, không bao giờ trồi lên mép màn hình.
   - Thẻ mỏng, sang trọng, bo góc với kính mờ mờ nhạt (translucent glass) và viền hairline siêu mảnh.
2. **Hiển thị mốc thời gian Reset chính xác**:
   - Không chỉ hiển thị thời gian ước tính (e.g. `21m`, `18h`, `6d 15h`), hệ thống tự động tính ra **mốc giờ cụ thể**:
     - Trong ngày: `Đặt lại sau 21m · 17:25:30`
     - Qua ngày mai: `Đặt lại sau 18h · Mai 11:01:45`
     - Dài hạn: `Đặt lại sau 6d 15h · 19/10 08:26`
3. **Quản lý thứ tự ưu tiên Pool (Drain Order)**:
   - Cụm điều khiển `#1`, `#2`, `#3` kèm nút mũi tên `▲▼` siêu mỏng (18px) cho phép đổi thứ tự 1-click tức thì không độ trễ.
   - Tự động gọi API `/v1/set-order` đồng bộ vào CLIProxy selector.
4. **Chuyển đổi Active Account an toàn**:
   - Chạm vào thẻ để đổi tài khoản active tức thì.
   - Tự động bật hộp thoại xác nhận (`NSAlert`) để tránh bấm nhầm gây đứt quãng phiên code.
5. **Token Keeper Proactive Monitor**:
   - Theo dõi chu kỳ giữ token 4h, thanh tiến độ và mốc quét tiếp theo trên cùng một dòng gọn gàng.
   - Bấm vào mở cửa sổ xem toàn bộ log thực thi của keeper.

---

## 📦 Cách cài đặt nhanh (1-Line Install & Packaging)

### Cách 1: Cài đặt tự động bằng 1 dòng lệnh (Khuyên dùng)
Tự động nhận diện macOS (cài Menu Bar App + LaunchAgent) hoặc Linux (cài Backend Service + systemd):

```bash
curl -fsSL https://raw.githubusercontent.com/Tedydev-web/cliproxy-codexbar/main/install.sh | bash
```

### Cách 2: Tải file `.dmg` cài đặt trực tiếp trên macOS
File `.dmg` tự động đóng gói ứng dụng `CodexBarCustom.app` kèm đường dẫn kéo thả vào thư mục `/Applications`:

```bash
cd client-macos
./package-dmg.sh
# File cài đặt sẽ được tạo tại: build/CodexBarCustom-macOS.dmg
```

### Cách 3: Đồng bộ toàn bộ các máy trong mạng nội bộ (Sync-All)
```bash
./sync-all.sh
```

---

## 🚀 Hướng dẫn cài đặt thủ công
```bash
curl http://localhost:8318/v1/pool-status
```

---

### 2. Cài đặt trên máy macOS (iMac / MacBook bất kỳ)
Chép thư mục `client-macos` sang máy Mac mới và chạy:

```bash
cd client-macos
./install-client.sh
```

Script sẽ:
1. Tự động biên dịch file mã nguồn `CodexBarCustom.swift` thành file nhị phân tối ưu hóa `-O`.
2. Cài đặt file thực thi vào `/usr/local/bin/CodexBarCustom`.
3. Tạo và kích hoạt file LaunchAgent (`~/Library/LaunchAgents/com.tedydev.codexbarcustom.plist`) để ứng dụng **tự động chạy ngầm mỗi khi đăng nhập máy tính**.
4. Khởi động ứng dụng ngay lập tức trên Menu Bar.

---

## ⚙️ Tùy chỉnh cấu hình

1. **Đổi IP Bridge Server**:
   - Mở menu `CodexBarCustom` trên Menu Bar -> Chọn **Cài đặt**.
   - Có thể chỉnh sửa trực tiếp địa chỉ Bridge Host URL (mặc định: `http://100.127.1.234:8318`).
   - Cấu hình được lưu tự động trong `UserDefaults` của macOS, không cần biên dịch lại mã nguồn khi đổi IP.
2. **Tần suất làm mới (Auto Refresh)**:
   - Có sẵn các mức: 1s (theo dõi realtime), 15s, 30s, 60s, 300s.
   - Tùy chọn *Tự động làm mới khi mở menu*.

---

## 📂 Cấu trúc thư mục

```
cliproxy-codexbar/
├── backend/
│   ├── cliproxy-quota-bridge        # Python daemon đọc dữ liệu CCS CLIProxy
│   ├── cliproxy-quota-bridge.service# File cấu hình systemd user unit
│   └── setup-backend.sh             # Script cài đặt backend 1-click
├── token-keeper/
│   ├── claude-token-keeper          # Script bảo vệ phiên & proactive refresh
│   ├── claude-token-keeper.service  # Systemd user service unit
│   ├── claude-token-keeper.timer    # Systemd user timer unit (chu kỳ 4h)
│   └── setup-keeper.sh              # Script cài đặt Token Keeper 1-click
├── client-macos/
│   ├── Sources/
│   │   └── CodexBarCustom.swift     # Mã nguồn Swift thuần (Single-file AppKit/SwiftUI)
│   ├── Resources/                   # Biểu tượng PNG template
│   ├── package-dmg.sh               # Đóng gói thành macOS .app và file .dmg
│   ├── build.sh                     # Script biên dịch Swift
│   └── install-client.sh            # Script cài đặt client 1-click
├── install.sh                       # 1-Line global curl installer (Linux + macOS)
├── package.json                     # Cấu hình phân phối qua npm / npx
├── sync-all.sh                      # Kịch bản đồng bộ tức thì toàn bộ cụm máy
└── README.md
```

---

## 🔄 Đồng bộ đa máy (Multi-Machine Sync)

Kho mã nguồn `/home/tedydev/Documents/workspace/cliproxy-codexbar` là **nguồn chân lý duy nhất (Single Source of Truth)**.

Mỗi khi có cập nhật sửa lỗi hoặc cải tiến tính năng, bạn chỉ cần đứng tại thư mục gốc và chạy:

```bash
./sync-all.sh
```

Script sẽ tự động:
1. Đồng bộ file thực thi backend & nạp lại systemd service trên máy chủ Ubuntu.
2. Quét toàn bộ danh sách máy macOS (MBP, iMac qua Tailscale).
3. Nếu máy online: Tự động truyền file mã nguồn mới nhất, biên dịch native `-O`, cài đặt và reload ứng dụng trên Menu Bar.
4. Nếu máy đang ngủ hoặc offline: Bỏ qua an toàn và không gây treo tiến trình.
