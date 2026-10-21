# Orbiter Menubar

**Orbiter Menubar** là bộ công cụ giám sát hiệu năng hệ thống server và điều phối hạn ngạch (AI Quota) đa tài khoản chạy trực tiếp trên macOS Menu Bar với trải nghiệm native chuẩn Apple.

---

## 🏛 Kiến trúc hệ thống (System Architecture)

```
┌──────────────────────────────────────────────────────────────┐
│  Linux / Server Host (Ubuntu @ 100.127.1.234)                │
│  - Multi-account AI Token Keeper & Vault (Claude 4h cycle)   │
│  - cliproxy-quota-bridge (Python Daemon:8318)                │
│  - System Monitor Kernel Telemetry (/proc, statvfs 1:1 btop) │
│  - Cloudflared Quick Tunnels & Listening Dev Ports Manager   │
└──────────────────────────────┬───────────────────────────────┘
                               │ HTTP REST API (:8318)
┌──────────────────────────────▼───────────────────────────────┐
│  macOS Client (iMac, MacBook, v.v.)                          │
│  - OrbiterMenuBar (Native Swift AppKit / SwiftUI Menu Bar)   │
│  - LaunchAgent tự khởi động cùng máy                         │
│  - 3 Thẻ Menubar độc lập: Claude, Antigravity, Ubuntu Server │
│  - Đồng bộ hiển thị Quota (% đã dùng hoặc % còn lại)        │
└──────────────────────────────────────────────────────────────┘
```

---

## ✨ Tính năng nổi bật

### 1. Giám sát & Quản trị Server Ubuntu chuẩn chỉ 1:1 `btop`
- **CPU, RAM, Swap & Disk chính xác**:
  - Đo lường dung lượng Disk trực tiếp qua `statvfs` kernel (`f_bfree`), khớp tuyệt đối 100% với `btop` và `df -h`.
  - Hiển thị trên Menubar dưới dạng trực quan: `C 17% · M 35% · D 31%` (trong đó `D 31%` là **% dung lượng ổ đĩa còn trống**).
- **Quản trị Port & Process phát triển (Dev Ports)**:
  - Hiển thị rõ ràng Port nào đang mở, đường dẫn tiến trình (`path`) và tên ứng dụng.
  - Hỗ trợ nút **Kill process** 1-chạm khi port bị kẹt.
- **Cloudflared Quick Tunnel**:
  - Tự động phát hiện tunnel công khai đang ánh xạ tới các port nội bộ.
  - Sao chép URL tunnel trực tiếp vào clipboard.
- **Siêu nhẹ & Tiết kiệm tài nguyên**:
  - Không chạy lệnh subprocess nặng nề, loại bỏ hoàn toàn các hook cồng kềnh.

### 2. Điều phối Hạn ngạch AI (Claude & Antigravity Proactive Keeper)
- **Hỗ trợ Pool đa tài khoản**:
  - Quản lý thứ tự ưu tiên xả quota (`#1`, `#2`, `#3`) bằng nút mũi tên `▲▼` tức thì không độ trễ.
  - Bấm vào tài khoản để chuyển Active Account an toàn với hộp thoại xác nhận.
  - Nút pause/play cạnh mỗi tài khoản (hoặc chuột phải → Tắt/Bật account) để tắt/bật account trong CLIProxy, có xác nhận; account đang tắt hiện mờ và không được chọn làm account đang chạy.
- **Tùy chọn hiển thị Quota linh hoạt**:
  - Lựa chọn giữa **Đã sử dụng (% đã dùng)** (chuẩn Claude) hoặc **Còn lại (% còn trống)**.
  - Tự động đồng bộ nhất quán trên toàn bộ thanh tiến độ, nhãn thông số và biểu tượng trên Menu Bar của tất cả các provider (Claude, Antigravity, Gemini, GPT).
- **Hiển thị mốc Reset thông minh**:
  - Tự động quy đổi thời gian còn lại thành mốc giờ và ngày cụ thể:
    - Trong ngày: `Đặt lại sau 21m · 17:25:30`
    - Qua ngày mai: `Đặt lại sau 18h · Mai 11:01:45`
    - Dài hạn: `Đặt lại sau 6d 15h · 19/10 08:26`
- **Hai loại credential Claude trong pool**:
  - **OAuth (`/login`)**: CLIProxy tự refresh mỗi 4h, nhưng refresh token chỉ sống khoảng 30 ngày kể từ lần đăng nhập gốc. Token Keeper cảnh báo khi còn ≤ 3 ngày; hết hạn thì tự cách ly vào `~/.cliproxy/auth-paused`.
  - **Setup-token (`claude setup-token`)**: access token sống 1 năm, không có refresh token. Đặt token vào `access_token` của auth file, để trống `refresh_token`/`id_token`, đặt `expired` = ngày tạo + 365 ngày. Token Keeper cảnh báo khi còn ≤ 30 ngày.
  - Setup-token không có quyền đọc usage API, nên bridge lấy % quota cho các tài khoản này theo thứ tự: (1) tín hiệu passive từ request đi qua proxy nếu còn mới (< 30 phút); (2) một OAuth "usage reader" cùng email nằm trong `~/.cliproxy/auth` (có `refresh_token`, không nằm trong `accounts.json`, priority 1), được CLIProxy/Keeper refresh như OAuth thường; (3) khi reader chết, bridge gửi request Haiku 1 token bằng chính setup-token và đọc header `anthropic-ratelimit-unified-*`, tối đa 5 phút/lần.

### 3. Trải nghiệm Native macOS Menu Bar
- **Giao diện chuẩn Apple**:
  - Thiết kế mỏng, thanh thoát, bo góc và hiệu ứng kính mờ (translucent glass) với viền hairline siêu nét.
  - Menu mở neo thẳng dưới icon, không bị trôi hay che khuất.
  - Cửa sổ Cài đặt (Settings) co giãn linh hoạt (`resizable`), tự động cuộn nội dung mượt mà.
- **Tùy chỉnh tần suất cập nhật**:
  - Cho phép cấu hình chu kỳ làm mới từ 100ms tới 24h (mặc định 2000ms), kèm tùy chọn tự động làm mới ngay khi click mở menubar.

---

## 📦 Cách cài đặt nhanh

### Cách 1: Cài đặt tự động bằng 1 dòng lệnh (Khuyên dùng)
Tự động nhận diện macOS (cài Orbiter Menubar + LaunchAgent) hoặc Linux (cài Backend Bridge + Token Keeper):

```bash
curl -fsSL https://raw.githubusercontent.com/Tedydev-web/cliproxy-codexbar/main/install.sh | bash
```

### Cách 2: Tải file `.dmg` cài đặt trực tiếp trên macOS
```bash
cd client-macos
./package-dmg.sh
# File cài đặt sẽ được tạo tại: build/OrbiterMenuBar-macOS.dmg
```

### Cách 3: Đồng bộ toàn bộ các máy trong mạng nội bộ (Sync-All)
Đứng tại máy chủ trung tâm và chạy:
```bash
./sync-all.sh
```

---

## ⚙️ Cài đặt & Cấu hình thủ công

### 1. Trên máy chủ Linux (Ubuntu Server)
```bash
# Cài đặt Python Bridge Service
mkdir -p ~/.local/lib/cliproxy-bridge ~/.local/bin
cp -r backend/bridge/* ~/.local/lib/cliproxy-bridge/
cp backend/cliproxy-quota-bridge.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cliproxy-quota-bridge.service
```

Kiểm tra API hoạt động:
```bash
curl http://localhost:8318/v1/telemetry
```

### 2. Trên máy macOS Client
```bash
cd client-macos
./install-client.sh
```
Script sẽ biên dịch mã nguồn `OrbiterMenuBar.swift` thành file nhị phân tối ưu `-O`, đưa vào `/usr/local/bin/OrbiterMenuBar` và kích hoạt dịch vụ tự khởi động `com.tedydev.orbitermenubar`.

### 3. iOS Widget (Scriptable, qua Tailscale)
Dán nguyên văn `ios-widget/OrbiterWidgetLoader.js` vào Scriptable **một lần** (file không chứa secret). Lần đầu mở script trong app, loader hỏi `CLIPROXY_MANAGEMENT_SECRET` (trong `~/.cliproxy/bridge.env`) và URL bridge rồi lưu vào iOS Keychain, dùng chung cho mọi script. Khi bridge trả 401 (secret đã rotate), mở script trong app để nhập lại. Đặt tên script chứa `AGY` (hoặc Parameter của widget là `agy`) để chạy widget Antigravity; mọi tên khác chạy widget Claude.

Mỗi lần chạy, loader gửi `HEAD /v1/widget/<file>` để so `ETag`; chỉ khi code đổi mới tải bằng `GET`. Code được cache trong Scriptable và dùng khi mất kết nối. Cập nhật widget = sửa `ios-widget/*.js` rồi chạy `./sync-all.sh`; không bao giờ phải dán lại loader.

Tính năng widget Claude:

| Ở đâu | Làm gì |
|---|---|
| Chạm widget / mở script trong app | Bảng điều khiển: quota 5h/tuần, hạn token, trạng thái từng account; chạm account để **Đặt làm #1**, **Tắt/Bật** (có xác nhận), Copy email; kèm Làm mới, Xem trước widget, Gửi thông báo thử, Cấu hình bridge, Xoá cache code. Tự làm mới mỗi 10 giây khi đang mở |
| Widget màn hình chính | Xin iOS làm mới sau 1 phút; tần suất thật do iOS quyết định theo ngân sách làm mới widget, nên muốn xem số liệu liên tục thì chạm widget để mở bảng điều khiển |
| Widget màn hình khoá | `accessoryRectangular` (account đang chạy + 5h/tuần + reset), `accessoryCircular` (vòng 5h), `accessoryInline` |
| Thông báo | Account đang chạy ≥ 90% (5h hoặc tuần), account bị cách ly, token sắp hết hạn; mỗi điều kiện báo một lần mỗi chu kỳ. Lần đầu bấm "Gửi thông báo thử" để iOS hỏi quyền |
| Shortcuts / Siri (action "Run Script", input) | `status` (text), `json`, `switch <account>`, `enable <account>`, `disable <account>`; input dạng dictionary `{action, account}` cũng được. `<account>` là một đoạn của email, phải khớp đúng một account |

Bridge từ chối tắt account cuối cùng còn bật (HTTP 409). Đặt #1 chỉ đổi thứ tự cho request mới; phiên đang chạy giữ credential cũ tới khi hết session affinity (1 giờ) hoặc failover.

Code do bridge phục vụ chạy như thân một `async function` với một tham số `orbiter`:

| Thuộc tính | Ý nghĩa |
|---|---|
| `orbiter.api(path, {method, body})` | Gọi bridge (bearer tự gắn), trả JSON; lỗi ném `OrbiterError` có `status` |
| `orbiter.load(file)` | Tải + chạy một file khác trong allowlist, trả giá trị `return` của nó (module dùng chung) |
| `orbiter.mode` | `widget` / `app` / `shortcut` / `siri` |
| `orbiter.family` | `config.widgetFamily` (`small`…`accessoryRectangular`…) |
| `orbiter.params` / `orbiter.input` | `args.queryParameters` (deep-link) / `args.shortcutParameter` |
| `orbiter.runURL` | URL chạy lại chính script (dùng cho `widget.url`, notification) |
| `orbiter.stale` / `orbiter.errors` | Đang chạy bằng code cache và lý do |
| `orbiter.settings()` / `orbiter.clearCache()` | Mở hộp thoại cấu hình bridge / xoá cache code |

---

## 📂 Cấu trúc dự án

```
cliproxy-codexbar/
├── backend/
│   ├── bridge/                      # Python Daemon: Telemetry kernel + Quota API
│   │   ├── main.py
│   │   └── providers/               # Claude, Antigravity, System telemetry
│   └── cliproxy-quota-bridge.service# File cấu hình systemd user unit
├── token-keeper/                    # Multi-account proactive token keeper (4h cycle)
├── client-macos/
│   ├── Sources/
│   │   └── OrbiterMenuBar.swift     # Mã nguồn Swift thuần (Single-file AppKit & SwiftUI)
│   ├── Resources/                   # Biểu tượng PNG template
│   ├── package-dmg.sh               # Đóng gói thành macOS App Bundle & .dmg
│   ├── build.sh                     # Script biên dịch Swift
│   └── install-client.sh            # Script cài đặt client & LaunchAgent
├── install.sh                       # Bộ cài 1-click tự nhận diện OS
├── sync-all.sh                      # Kịch bản đồng bộ tức thì toàn bộ cụm máy
└── README.md
```

---

## 🔄 Đồng bộ đa máy (Multi-Machine Sync)

Thư mục này là **nguồn chân lý duy nhất (Single Source of Truth)**. Mỗi khi nâng cấp tính năng, chỉ cần chạy:

```bash
./sync-all.sh
```

Hệ thống sẽ tự động cập nhật backend trên Ubuntu và deploy bản build mới nhất tới các máy Mac online trong mạng Tailscale.
