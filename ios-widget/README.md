# Bộ Widget iOS Độc Lập Cho CodexBar & Orbiter Menubar

Hệ thống được thiết kế **tách biệt làm 2 Widget độc lập** chuẩn kích thước **Medium (2x4)** và **Small (2x2)** của iOS, tương đồng 1:1 với phong cách giao diện CodexBar & Orbiter Menubar trên macOS:

---

## 1. Widget 1: Claude Pool Quota (`CodexBarClaudeWidget.js`)
* **File script**: [`ios-widget/CodexBarClaudeWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/CodexBarClaudeWidget.js)
* **Kích thước**: Khuyên dùng **Medium (2x4)** hoặc **Small (2x2)**
* **Giao diện**:
  - Tái tạo 1:1 theo card Claude của CodexBar macOS.
  - Hiển thị đầy đủ **Phiên 5h** (% đã dùng, thời gian đặt lại, dự trữ nhịp độ).
  - Hiển thị đầy đủ **Hàng tuần** (% đã dùng, thời gian đặt lại).
  - Thanh tiến trình **Segmented Bar (3 đoạn)** màu cam rực rỡ (`#F97316`) kèm vạch xanh lá (`#22C55E`).
* **Tính năng Đổi Tài Khoản Ưu Tiên (Interactive Switcher)**:
  - Khi bạn mở script trong app Scriptable (hoặc cấu hình widget "Run Script"), một bảng chọn Native iOS sẽ hiện lên danh sách **cả 3 tài khoản trong Pool**.
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

## Cách Cài Đặt Trên iPhone (Chỉ 2 Bước):

1. **Thêm Widget Claude**:
   - Trong app **Scriptable**, tạo script mới tên **`CodexBarClaude`**.
   - Copy mã từ file [`CodexBarClaudeWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/CodexBarClaudeWidget.js) và dán vào.
   - Ra màn hình chính thêm Widget Scriptable kích thước **Medium**, chọn script `CodexBarClaude`.

2. **Thêm Widget Antigravity**:
   - Trong app **Scriptable**, tạo script mới tên **`OrbiterAGY`**.
   - Copy mã từ file [`OrbiterAGYWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterAGYWidget.js) và dán vào.
   - Ra màn hình chính thêm Widget Scriptable kích thước **Medium**, chọn script `OrbiterAGY`.
