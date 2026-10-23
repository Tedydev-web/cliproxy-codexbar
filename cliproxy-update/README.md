# cliproxy-update: cập nhật CLIProxyAPI có rào chắn và báo trước tính năng mới

Mỗi ngày kiểm tra bản phát hành mới của [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), viết báo cáo những gì thay đổi và **những tùy chọn cấu hình mới chưa được bạn đặt**, rồi tự cập nhật nếu an toàn.

## Quy trình mỗi lần chạy (`cliproxy-update run`)

1. Lấy danh sách bản phát hành chính thức (bỏ prerelease). Không có bản mới thì dừng.
2. So `config.example.yaml` của bản mới với bản đang chạy (lưu ở `~/.local/share/cliproxy-update/cache/`) để liệt kê **tùy chọn mới** và đánh dấu cái nào `NOT SET` trong `~/.cliproxy/config.yaml`. Ghi báo cáo `~/.cliproxy/update-reports/<phiên bản>.md` và gửi thông báo (herdr) một lần cho mỗi phiên bản.
3. Chọn bản cập nhật: bản **mới nhất đã phát hành ít nhất 24 giờ** (soak, tránh bản vừa ra bị lỗi). Bỏ qua nếu đang `hold` hoặc chế độ chỉ thông báo.
4. Tải bản `linux_amd64`, **kiểm tra SHA-256** theo `checksums.txt` của chính bản phát hành.
5. **Smoke test**: chạy binary mới trên cổng ngẫu nhiên với bản sao cấu hình thật và thư mục auth rỗng, yêu cầu nó khởi động và liệt kê được model. Lỗi thì dừng, không đụng gì.
6. **Chỉ chạy khi rảnh**: nếu có request trong 120 giây gần nhất thì hoãn (mã thoát 75, lần hẹn sau thử lại).
7. Sao lưu binary (`cli-proxy-api.bak_v<phiên bản>`, giữ 3 bản) và cấu hình (`~/.cliproxy/backups/`), thay binary nguyên tử, khởi động lại dịch vụ.
8. **Kiểm tra sau cập nhật**: API quản lý phải trả 200 và một request suy luận thật không được lỗi 5xx. Hỏng thì **tự khôi phục** bản cũ và thông báo.
9. **Kiểm tra hợp đồng dữ liệu của bridge** (không khôi phục, chỉ thông báo): `auth-files` còn đủ `name/type/disabled/quota` và `quota.signals` còn đủ 4 tín hiệu Anthropic mà bridge đọc.

## Lệnh

| Lệnh | Việc |
|---|---|
| `cliproxy-update status` | Phiên bản đang chạy, hold, chế độ, trạng thái lần cuối |
| `cliproxy-update check` | Chỉ in báo cáo, không đổi gì |
| `cliproxy-update run` | Quy trình đầy đủ (timer gọi lệnh này lúc 04:30 hằng ngày) |
| `cliproxy-update apply [phiên bản] [--force]` | Cập nhật ngay (`--force` bỏ qua kiểm tra rảnh) |
| `cliproxy-update rollback` | Khôi phục bản sao lưu mới nhất và khởi động lại |

## Cấu hình (biến môi trường trong unit systemd)

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `CLIPROXY_UPDATE_MODE` | `auto` | `notify` chỉ báo cáo, không tự cập nhật |
| `CLIPROXY_UPDATE_MIN_AGE_HOURS` | `24` | Tuổi tối thiểu của bản phát hành trước khi cài |
| `CLIPROXY_UPDATE_IDLE_SEC` | `120` | Hoãn nếu có request trong khoảng này |
| `CLIPROXY_UPDATE_FLAVOR` | `default` | `no-plugin` cho bản không hỗ trợ plugin |

Tạm dừng tự cập nhật: `touch ~/.cliproxy/update.hold` (vẫn nhận báo cáo). Bỏ dừng: xóa file đó.

## Cài đặt

```bash
./cliproxy-update/install.sh        # NO_TIMER=1 để không bật timer
```

## Giới hạn

- Kiểm tra sau cập nhật chỉ bắt được lỗi **hỏng hẳn** (không khởi động, 5xx). Thay đổi hành vi tinh vi vẫn cần đọc báo cáo.
- Khi tài khoản và Console đều hết hạn mức, request suy luận kiểm tra trả 429 (không phải 5xx) và được coi là bình thường.
- Chỉ hỗ trợ Linux `amd64` mặc định (đổi `arch` trong mã nếu cần).

## Cấu hình khuyến nghị đã áp dụng (`~/.cliproxy/config.yaml`, không nằm trong repo vì chứa khóa)

Sau khi nâng lên 8.0.40, đối chiếu cấu hình với toàn bộ `config.example.yaml` và bật:

```yaml
routing:
    cooldown:
        save-cooldown-status: true      # cooldown lưu ra file .cds, còn nguyên sau khi khởi động lại
requests:
    tls-handshake-timeout-seconds: 15   # TLS treo thì retry mới có cơ hội chạy
    streaming:
        keepalive-seconds: 15           # chống đứt kết nối khi model suy nghĩ lâu
        bootstrap-retries: 1            # thử lại trước byte đầu tiên khi lỗi thoáng qua
upstream:
    claude:
        model-level-cooling: true       # 429 của một model không làm nghỉ cả credential
```

Đã kiểm chứng trong sandbox trên 8.0.40: cooldown được ghi ra `.cds` và giữ nguyên qua restart, cooldown có phạm vi theo model, streaming chạy bình thường.
Các tùy chọn còn lại của bản mới (`session-date-pin-days`, `anthropic-beta-*`, `inject-diagnostics`, `client-request-id`, `web-search-result-cache`) giữ mặc định vì mặc định đã là lựa chọn tốt nhất hoặc chỉ áp dụng cho Codex.

Các file `.cds` nằm cạnh file token: các công cụ đọc thư mục auth chỉ nhận `*.json` (`claude-reauth` được vá để không nhận nhầm `.cds` là token mới).

## Việc chưa tự động hóa (cần quyết định)

- Cổng 8317 đang nghe trên mọi giao diện và `management.allow-remote: true`. Nếu không máy nào khác dùng cổng này, nên đặt `server.host: "127.0.0.1"` và `allow-remote: false`.
- `management.disable-auto-update-panel`: bảng điều khiển tự tải bản mới từ GitHub.

## Xung đột và lưu ý đã kiểm chứng bằng thực nghiệm (CLIProxyAPI 8.0.40, sandbox)

| Chủ đề | Kết quả | Khuyến nghị |
|---|---|---|
| `session-affinity: true` cùng Console làm phương án cuối | Phiên đã chuyển sang Console **vẫn ở Console** sau khi pool hồi lại (kiểm tra 65 giây sau), trong khi phiên mới và request không phiên quay về pool ngay sau cooldown (khoảng 30 giây). Giảm `session-affinity-ttl` **không giúp** (phiên đang hoạt động liên tục gia hạn TTL). Tắt affinity thì phiên quay về pool ngay | Tắt `session-affinity` nếu Console trả tiền theo mức dùng nằm trong pool. **Quyết định hiện tại: giữ bật**, vì lợi ích prompt cache lớn hơn và các tác vụ thường ngắn (phiên nghỉ 1 giờ sẽ tự rời Console) |
| `save-cooldown-status` | Thay file token bằng token chạy được thì cooldown cũ **được xóa ngay** | Không xung đột khi đổi token |
| `model-level-cooling` | Không tạo khác biệt trong mọi lỗi giả lập được (không giả lập được lỗi quota 429 thật trên credential dạng file) | **Quyết định hiện tại: giữ bật**, vì có hạn mức riêng theo model (Fable) |
| `~/.ccs/cliproxy` là liên kết tới `~/.cliproxy`, CCS có `session_affinity: true` và `preferences.auto_update: true` | Nếu CCS được cài và chạy, nó có thể ghi đè `config.yaml` và thay binary, giẫm lên `cliproxy-update` | Giữ một bộ cập nhật duy nhất; đặt `preferences.auto_update: false` và đồng bộ `session_affinity` trong `~/.ccs/config.yaml` |

