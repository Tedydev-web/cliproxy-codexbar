# Bộ Widget iOS Độc Lập Cho CodexBar & Orbiter Menubar

Hệ thống được thiết kế **tách biệt làm 2 Widget độc lập** chuẩn kích thước **Medium (2x4)** và **Small (2x2)** của iOS, tương đồng 1:1 với phong cách giao diện CodexBar & Orbiter Menubar trên macOS:

---

## 1. Widget 1: Claude Pool Quota (`CodexBarClaudeWidget.js`)
* **File script**: [`ios-widget/CodexBarClaudeWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/CodexBarClaudeWidget.js)
* **Kích thước**: Hỗ trợ **Large (4x4)**, **Medium (2x4)** hoặc **Small (2x2)**
* **Giao diện**:
  - Tái tạo 1:1 theo card Claude của CodexBar & Orbiter macOS.
  - **Dạng Large (4x4)**: Hiển thị đầy đủ **cả 3 tài khoản trong Pool**:
    - Tài khoản #1 đang ưu tiên: Full quota 5h, hàng tuần, thời gian đặt lại, dự trữ nhịp độ.
    - 2 Tài khoản còn lại (#2 & #3): Hiển thị chi tiết từng card riêng với đầy đủ quota 5h & tuần, thanh tiến trình mini 3 đoạn, gói dịch vụ và huy hiệu trạng thái (● Khả dụng / ⚠️ 429 API / ⛔ Hết hạn) y hệt desktop!
  - **Dạng Medium (2x4)**: Hiển thị tài khoản chính đang ưu tiên #1 với đầy đủ 2 thanh tiến trình 5h và Tuần full-width.
  - **Dạng Small (2x2)**: Thu gọn tối giản hiển thị 2 thanh tiến trình 5h và Tuần.
* **Tính năng Đổi Tài Khoản Ưu Tiên (Interactive Switcher)**:
  - Khi bạn mở script trong app Scriptable (hoặc bấm vào widget), một bảng chọn Native iOS sẽ hiện lên danh sách **cả 3 tài khoản trong Pool**.
  - Bạn chỉ cần bấm chọn 1 tài khoản, widget sẽ tự động gửi lệnh tới `/v1/set-priority` để đưa tài khoản đó lên **ưu tiên số #1 (Drain order)** ngay tức thì!

---

## 2. Widget 2: Antigravity Quota (`OrbiterAGYWidget.js`)
* **File script**: [`ios-widget/OrbiterAGYWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterAGYWidget.js)
* **Kích thước**: Khuyên dùng **Medium (2x4)** hoặc **Small (2x2)**
* **Giao diện**:
  - Tái tạo 1:1 theo card `AntigravityFullCardView` trong Orbiter Menubar.
  - Nhóm 1: **Gemini Models** (Flash Lite & Pro) — Thanh Segmented Bar màu **Teal Green (`#00C389`)**.
  - Nhóm 2: **Claude & GPT Models** (Opus, Sonnet, GPT-OSS) — Thanh Segmented Bar màu **Purple (`#8B5CF6`)**.
  - Hiển thị tài khoản email Antigravity (`hieudat2310.bh@gmail.com`) và gói `Tier Pro`.

---

## 3. Widget 3: Ubuntu Server Monitor (`OrbiterServerMonitorWidget.js`)
* **File script**: [`ios-widget/OrbiterServerMonitorWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterServerMonitorWidget.js)
* **Kích thước**: Khuyên dùng **Medium (2x4)** hoặc **Small (2x2)**
* **Giao diện**:
  - Tái tạo 1:1 theo card **Ubuntu Host** trong Orbiter macOS Menubar (`OrbiterMenuBar.swift`).
  - **Header**: Ubuntu Host (`100.127.1.234`) kèm thời gian Uptime và chấm tròn trạng thái `● Online` (Xanh lá).
  - **CPU**: % Đang dùng, số Cores, chỉ số tải Load Average, thanh Segmented Bar xanh lá (đỏ nếu > 80%).
  - **RAM**: % Đã dùng, dung lượng `GB đã dùng / tổng GB`, thanh Segmented Bar màu Mint/Teal (`#00C389`).
  - **Ổ cứng (/)**: % Đã dùng, dung lượng còn trống và tổng ổ cứng, thanh Segmented Bar màu tím (`#AF52DE`).
* **Tính năng chạm (Interactive)**:
  - Khi mở trong app Scriptable, hiển thị toàn bộ danh sách **Dev Ports đang mở** (Port 8004, 8317, 8318, 3000...), dịch vụ hệ thống (CLIProxy, Herdr, Cloudflared) và Cloudflare Tunnels.

---

## Cách Cài Đặt Trên iPhone:

1. **Widget 1 (Claude Quota)**:
   - Trong app **Scriptable**, tạo script mới tên **`CodexBarClaude`**.
   - Copy mã từ file [`CodexBarClaudeWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/CodexBarClaudeWidget.js) và dán vào.
   - Thêm widget ngoài Home Screen kích thước **Medium (2x4)** hoặc **Small (2x2)**, chọn script `CodexBarClaude`.

2. **Widget 2 (Gemini / Antigravity Quota)**:
   - Trong app **Scriptable**, tạo script mới tên **`OrbiterAGY`**.
   - Copy mã từ file [`OrbiterAGYWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterAGYWidget.js) và dán vào.
   - Thêm widget ngoài Home Screen kích thước **Medium (2x4)** hoặc **Small (2x2)**, chọn script `OrbiterAGY`.

3. **Widget 3 (Ubuntu Server Monitor)**:
   - Trong app **Scriptable**, tạo script mới tên **`OrbiterServerMonitor`**.
   - Copy mã từ file [`OrbiterServerMonitorWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterServerMonitorWidget.js) và dán vào.
   - Thêm widget ngoài Home Screen kích thước **Medium (2x4)** hoặc **Small (2x2)**, chọn script `OrbiterServerMonitor`.
