# claude-web: nguồn quota qua phiên claude.ai (cookie `sessionKey`)

Bổ sung cho quota OAuth: lấy quota 5 giờ, 7 ngày, quota theo model, cloud credits và extra usage từ API web của claude.ai bằng cookie `sessionKey` của trình duyệt. Cách này **không phụ thuộc refresh token OAuth**. Hành vi được port từ [CodexBar](https://github.com/steipete/CodexBar) (MIT), xem `THIRD_PARTY_NOTICES`.

## Kiến trúc

```
Mac (có trình duyệt đã đăng nhập claude.ai)             Ubuntu (CLIProxy + bridge)
 LaunchAgent com.tedydev.claude-web-push    ssh        claude-web-session ingest
  đọc cookie Chrome qua Keychain  ───────────────────▶   xác minh đúng tài khoản (UUID tổ chức + email)
                                                          lưu ~/.cliproxy/web-sessions/<tên>.json (0600)
 Safari (đọc qua SSH, nhờ quyền của sshd) ◀── claude-web-sync (timer 2 giờ) ┘
                                                                 │
 bridge: providers/claude_web.py (luồng nền 300s, request chỉ đọc bộ nhớ) ◀── claude-web-session check --no-recover
```

- Cloudflare chặn mọi client HTTP thường tới `claude.ai`. `curl_cffi` giả vân tay TLS của Chrome nên qua được (venv riêng, không đụng Python hệ thống).
- Script đọc cookie nằm trên Ubuntu và được truyền qua SSH mỗi lần chạy: Mac không lưu mã hay cookie nào ngoài một file `.plist`.

## Cài đặt

Ubuntu (idempotent, giữ nguyên cookie đã lưu):

```bash
./web-session/install.sh            # NO_TIMER=1 để không bật timer
```

macOS (chạy trên từng Mac có trình duyệt đăng nhập claude.ai; `sync-all.sh` tự làm bước này):

```bash
UBUNTU_HOST=user@100.x.y.z ./web-session/mac/install-mac-push.sh
```

Lần đầu Chrome cần quyền Keychain: chạy trong **phiên đồ họa** của Mac
`security find-generic-password -w -s "Chrome Safe Storage" -a "Chrome" > /dev/null` và bấm **Always Allow**
(qua SSH, macOS không thể hiện hộp thoại và trả `rc=36`).

## Lệnh

| Lệnh | Việc |
|---|---|
| `claude-web-session check [email] [--force] [--no-recover]` | Lấy quota. `--force` bỏ qua cổng 429, `--no-recover` không nhập lại cookie từ trình duyệt |
| `claude-web-session list` | Trạng thái từng phiên (`needs_reauth`, `gated`) |
| `claude-web-session add <email>` | Dán cookie thủ công (giá trị trần, header `Cookie:` hoặc Copy-as-cURL) |
| `claude-web-session ingest` | Nhận NDJSON từ `mac_cookie_reader.py` và tự khớp tài khoản trong pool |
| `claude-web-sync` | Kéo cookie từ Mac ngay (Safari qua SSH, Chrome qua LaunchAgent) |
| `claude-web-upstream-diff` | Commit mới của CodexBar chạm các file đã port, tính từ `upstream/PINNED_SHA` |

## Hành vi (theo CodexBar)

- 401/403: nhập lại cookie từ trình duyệt đúng một lần rồi thử lại (cooldown 15 phút); thất bại thì gắn `needs_reauth`.
- 429: chặn đến `max(Retry-After, now+5 phút)`, xóa khi thành công.
- Cloudflare, lỗi mạng, 5xx: giữ cookie, trả số liệu cũ kèm `stale`, `stale_since`.
- `Set-Cookie` đổi `sessionKey`: lưu giá trị mới.
- Bridge chọn nguồn: passive (nếu mới hơn web) → OAuth → web-session → header probe; trường bổ sung (`scoped_weekly`, `cloud_credits`, `extra_usage`) được gộp vào mọi nguồn.

## Lưu ý bảo mật

- Cookie `sessionKey` mở toàn bộ tài khoản claude.ai: file lưu `0600`, thư mục `0700`, **không bao giờ commit**.
- Đừng bấm Log out trong trình duyệt của tài khoản đã đẩy cookie (cookie sẽ chết). Mỗi tài khoản nên một profile trình duyệt riêng.
- API `claude.ai/api/...` là API nội bộ, không có cam kết ổn định.
