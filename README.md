# DevOps - Session 03 - Bài 2: Custom Error Page 404 với Nginx

Bài tập cấu hình Nginx phục vụ trang lỗi 404 tự thiết kế thay cho trang mặc định, đồng thời bảo vệ tệp `404.html` bằng chỉ thị `internal` để không thể truy cập trực tiếp qua `http://<IP>/404.html`. Thực hiện trên máy chủ Ubuntu 24.04.3 LTS (hostname `halo`) với Nginx 1.24.0.

## Mục lục

- [Báo cáo chi tiết: homework/session_03/ex2/README.md](homework/session_03/ex2/README.md)
  - Mục tiêu và yêu cầu
  - Môi trường thực hiện
  - Kiến thức nền: `error_page` và `internal`
  - Các bước thực hiện và kết quả kiểm tra
  - Giải thích kết quả kiểm tra
  - Mở rộng và lỗi thường gặp
  - Bảng đối chiếu yêu cầu đề bài, kết luận

## Danh sách tệp

| Tệp | Mô tả |
|---|---|
| `homework/session_03/ex2/404.html` | Trang lỗi 404 tùy biến (HTML5, CSS nội tuyến) |
| `homework/session_03/ex2/my-web.conf` | Server Block Nginx hoàn chỉnh sau khi sửa |
| `homework/session_03/ex2/README.md` | Báo cáo bài làm |
| `homework/session_03/ex2/terminal_log.txt` | Nhật ký lệnh và kết quả trên Terminal |
| `homework/session_03/ex2/deploy_404.sh` | Script triển khai tự động, idempotent |
