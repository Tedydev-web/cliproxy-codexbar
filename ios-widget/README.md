# Bộ Widget iOS Độc Lập Cho Orbiter (Scriptable)

Hệ thống được rút gọn và tối ưu hóa chuyên biệt thành **đúng 2 Widget độc lập**, đồng bộ 1:1 với phong cách giao diện của **Orbiter Menubar trên macOS**:

---

## 1. Widget 1: Antigravity Quota (Kích thước Medium 2x4)
* **File script**: [`ios-widget/OrbiterAGYWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterAGYWidget.js)
* **Kích thước**: **Medium (2x4)** (khuyên dùng) hoặc Small (2x2)
* **Giao diện & Tính năng**:
  - Đồng bộ 1:1 theo card `AntigravityFullCardView` trong Orbiter Menubar macOS.
  - **Header**: Icon Antigravity Shuttle (`#00C389`), tài khoản `dat.donghieu@gmail.com`, gói `Gói Pro`, mốc cập nhật thời gian thực.
  - **Giới hạn 5h (Gemini Flash & Pro)**: Thanh Segmented Progress Bar màu **Teal Green (`#00C389`)**, hiển thị **% đã dùng** (chế độ Used mặc định như Orbiter macOS), dòng phụ hiển thị % còn lại và thời gian đặt lại.
  - **Giới hạn Tuần**: Thanh Segmented Progress Bar màu **Amber Yellow (`#F5C542`)**, hiển thị **% đã dùng**, dòng phụ hiển thị % còn lại và thời gian đặt lại.
  - **Chỉ số Claude & GPT**: Huy hiệu trạng thái mức đã dùng cho Opus, Sonnet, GPT-OSS.
  - **Cơ chế chống rớt mạng**: Timeout 12s, bộ nhớ đệm Cache thông minh và huy hiệu cảnh báo `(Ngoại tuyến)` khi mất sóng Tailscale.

---

## 2. Widget 2: Claude Pool Quota (Kích thước Large 4x4)
* **File script**: [`ios-widget/OrbiterClaudeWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterClaudeWidget.js)
* **Kích thước**: **Large (4x4)**
* **Giao diện & Tính năng**:
  - Tái tạo 1:1 theo card Claude của Orbiter Desktop macOS (chế độ **Quota Used**).
  - **Header**: Icon Claude Sparkle (`#F97316`), tài khoản chính đang ưu tiên, thời gian cập nhật.
  - **Hiển thị đầy đủ cả 3 tài khoản trong Pool**:
    1. `#1 trthuhuyen2712@gmail.com` (Đang dùng, Gói Max 5x) — Full bar 5h & tuần hiển thị **% đã dùng**, vạch nhịp độ an toàn (`greenPace`), dự trữ nhịp độ.
    2. `#2 projecttoncorporation@gmail.com` (Sẵn sàng, Gói Max 20x) — Full bar 5h & tuần hiển thị **% đã dùng**.
    3. `#3 projectplayground2025@gmail.com` (Tạm dừng - Quá hạn 30 ngày) — Thẻ thông báo cách ly.
  - **Theo dõi vòng đời OAuth 30 ngày**: Tự động hiển thị huy hiệu cảnh báo nguy cơ (ví dụ: `⚠️ Hết hạn sau 2d 7h` hoặc `ℹ️ Hết hạn sau 5d`) trực tiếp trên widget!
  - **Chốt chặn dự phòng Console API (capi)**: Hiển thị trạng thái kết nối trực tuyến của Anthropic Console API Key ở chân widget.

---

## Cách Cài Đặt Lên iPhone / iPad (Scriptable):

1. **Cài đặt Widget Antigravity (Medium 2x4)**:
   - Trong app **Scriptable**, tạo script mới tên **`OrbiterAGY`**.
   - Copy toàn bộ nội dung file [`OrbiterAGYWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterAGYWidget.js) và dán vào.
   - Ra màn hình chính (Home Screen), thêm widget Scriptable kích thước **Medium (2x4)**, chọn script `OrbiterAGY`.

2. **Cài đặt Widget Claude (Large 4x4)**:
   - Trong app **Scriptable**, tạo script mới tên **`OrbiterClaude`**.
   - Copy toàn bộ nội dung file [`OrbiterClaudeWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/OrbiterClaudeWidget.js) và dán vào.
   - Ra màn hình chính (Home Screen), thêm widget Scriptable kích thước **Large (4x4)**, chọn script `OrbiterClaude`.
