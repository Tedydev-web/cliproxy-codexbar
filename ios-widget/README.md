# Hướng Dẫn Cài Đặt Widget CodexBar / CLIProxy Quota Lên iPhone

File script: [`ios-widget/CodexBarWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/CodexBarWidget.js)

## Cách Hoạt Động
- Ứng dụng **Scriptable** (miễn phí trên App Store) hỗ trợ viết JavaScript vẽ Widget native chuẩn iOS.
- Khi iPhone bật app **Tailscale**, iPhone nằm chung mạng riêng ảo với Ubuntu Host (`100.127.1.234`).
- Widget sẽ query trực tiếp API:
  - `http://100.127.1.234:8318/v1/pool-status` (Quota Claude 5h & Weekly của các tài khoản theo thứ tự ưu tiên #1, #2)
  - `http://100.127.1.234:8318/v1/system-telemetry` (CPU %, RAM %)
- Tự động hiển thị và refresh mỗi 10-15 phút ngay trên Màn hình chính (Home Screen) hoặc Màn hình khóa (Lock Screen).

---

## Các Bước Cài Đặt (Chỉ 2 Phút)

### Bước 1: Chuẩn bị trên iPhone
1. Cài đặt app **Tailscale** từ App Store, đăng nhập cùng tài khoản và bật **Connect**.
2. Cài đặt app **Scriptable** từ App Store (Miễn phí, chuẩn cộng đồng iOS dev).

### Bước 2: Thêm Script vào Scriptable
1. Mở app **Scriptable** trên iPhone.
2. Nhấn nút dấu **`+`** ở góc trên cùng bên phải để tạo script mới.
3. Đổi tên script thành **`CodexBar`**.
4. Copy toàn bộ nội dung trong file [`ios-widget/CodexBarWidget.js`](file:///home/tedydev/Documents/workspace/cliproxy-codexbar/ios-widget/CodexBarWidget.js) và dán vào.
5. Nhấn nút **Play** ▶ ở góc dưới để chạy thử. Bạn sẽ thấy giao diện preview hiển thị Quota & Telemetry.
6. Nhấn **Done**.

### Bước 3: Đưa Widget ra Màn hình chính iPhone
1. Nhấn giữ vào một vùng trống trên Màn hình chính iPhone cho đến khi các icon rung rinh.
2. Nhấn dấu **`+`** ở góc trên cùng bên trái màn hình.
3. Tìm và chọn **Scriptable**.
4. Chọn kích thước widget: **Medium** (khuyên dùng) hoặc Small, rồi nhấn **Thêm tiện ích (Add Widget)**.
5. Nhấn vào widget vừa thêm trên màn hình:
   - **Script**: Chọn `CodexBar`
   - **When Interacting**: Chọn `Open App` hoặc `Run Script`
6. Nhấn ra ngoài màn hình chính để hoàn tất!
