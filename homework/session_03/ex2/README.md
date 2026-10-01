# Bài 2 - Session 03: Cấu hình trang lỗi tùy chỉnh (Custom Error Page 404)

## Mục lục

1. [Mục tiêu và yêu cầu](#1-mục-tiêu-và-yêu-cầu)
2. [Môi trường thực hiện](#2-môi-trường-thực-hiện)
3. [Kiến thức nền: error_page và internal](#3-kiến-thức-nền-error_page-và-internal)
4. [Các bước thực hiện](#4-các-bước-thực-hiện)
5. [Giải thích kết quả kiểm tra](#5-giải-thích-kết-quả-kiểm-tra)
6. [Mở rộng: gộp nhiều mã lỗi](#6-mở-rộng-gộp-nhiều-mã-lỗi)
7. [Lỗi thường gặp và cách xử lý](#7-lỗi-thường-gặp-và-cách-xử-lý)
8. [Bảng đối chiếu yêu cầu đề bài](#8-bảng-đối-chiếu-yêu-cầu-đề-bài)
9. [Danh sách tệp nộp](#9-danh-sách-tệp-nộp)
10. [Kết luận](#10-kết-luận)

---

## 1. Mục tiêu và yêu cầu

Trang web chính thức của học viên cần hiển thị giao diện lỗi thân thiện khi người dùng gõ sai đường dẫn, thay cho trang 404 mặc định của Nginx (đơn điệu và lộ phiên bản máy chủ). Đồng thời tệp HTML báo lỗi phải được bảo vệ bằng chỉ thị `internal` để không ai truy cập trực tiếp được.

Các ràng buộc của đề bài:

- Tạo tệp `404.html` chứa HTML tùy biến, lưu trong web root `/var/www/my-web/html/`.
- Server Block dùng chỉ thị `error_page 404 /404.html;`.
- Thiết lập block `location = /404.html { internal; }` trỏ `root` chính xác và ngăn truy cập trực tiếp `http://<IP>/404.html`.
- Kiểm tra: `curl -I http://<IP>/invalid-path-demo` trả `404 Not Found` kèm nội dung trang tùy biến; `curl -I http://<IP>/404.html` cũng trả `404 Not Found` (do `internal` chặn).

## 2. Môi trường thực hiện

| Thành phần | Giá trị |
|---|---|
| Máy chủ | Ubuntu 24.04.3 LTS, hostname `halo`, IP `103.116.104.228` |
| Người dùng | `devops` (nhóm `sudo`), SSH cổng 2222 |
| Web server | `nginx/1.24.0 (Ubuntu)` |
| Site | `my-web`, web root `/var/www/my-web/html/`, file cấu hình `/etc/nginx/sites-available/my-web.conf` |
| Máy cá nhân | Windows, Git Bash, IP công cộng `113.161.72.19`, curl 8.15.0 |
| Thời gian | Thứ Sáu 2026-10-02, 10:01 đến 10:21 (+0700) |

Kết nối: `ssh -p 2222 -i ~/.ssh/id_ed25519_ptit_s02 devops@103.116.104.228`. Toàn bộ lệnh và kết quả được ghi đầy đủ trong tệp `terminal_log.txt`; báo cáo này trích những đoạn quan trọng nhất.

## 3. Kiến thức nền: error_page và internal

### 3.1. Chỉ thị error_page

Cú pháp: `error_page code ... [=[response]] uri;`

Khi Nginx sinh ra một mã trạng thái lỗi nằm trong danh sách (ở đây là 404), thay vì gửi trang lỗi dựng sẵn, Nginx thực hiện một chuyển hướng nội bộ (internal redirect) sang `uri` đã khai báo. Request mới được xử lý lại từ đầu qua cơ chế chọn `location`, nhưng mã trạng thái lỗi ban đầu vẫn được giữ lại để gửi cho client, trừ khi dùng dạng `=code`.

Chuyển hướng nội bộ khác với redirect 301/302: client không nhận thêm phản hồi nào, không đổi URL trên thanh địa chỉ và không phát sinh thêm request.

### 3.2. Chỉ thị internal

`internal;` đặt trong `location` nghĩa là location đó chỉ phục vụ request nội bộ, gồm:

- chuyển hướng do `error_page`;
- chuyển hướng do `try_files` hoặc `index`;
- chuyển hướng do `rewrite ... last`;
- header `X-Accel-Redirect` từ backend;
- subrequest (ví dụ SSI, `add_before_body`).

Request từ bên ngoài (trình duyệt, curl) tới location này bị Nginx trả `404 Not Found`.

### 3.3. Dấu "=" trong location

`location = /404.html` là khớp chính xác: chỉ URI đúng bằng `/404.html` mới vào block này, và đây là kiểu khớp có độ ưu tiên cao nhất (dừng tìm kiếm ngay khi khớp). Nhờ vậy `location /` hay bất kỳ regex nào không chen vào được.

### 3.4. Luồng xử lý

Trường hợp 1 - truy cập đường dẫn không tồn tại:

```
Client                        Nginx (server block my-web)
  |  GET /invalid-path-demo        |
  |------------------------------->|  location /  -> try_files $uri $uri/ =404
  |                                |  khong thay tep  -> sinh ma 404
  |                                |  error_page 404 /404.html
  |                                |  chuyen huong NOI BO (client khong thay)
  |                                |  location = /404.html  (internal: cho phep)
  |                                |  doc /var/www/my-web/html/404.html
  |  404 Not Found + trang tuy bien|
  |<-------------------------------|
```

Trường hợp 2 - truy cập trực tiếp `/404.html`:

```
Client                        Nginx (server block my-web)
  |  GET /404.html                 |
  |------------------------------->|  location = /404.html  co "internal"
  |                                |  request tu ben ngoai -> bi tu choi: 404
  |                                |  error_page 404 /404.html
  |                                |  chuyen huong NOI BO -> lan nay duoc phep
  |                                |  doc /var/www/my-web/html/404.html
  |  404 Not Found + trang tuy bien|
  |<-------------------------------|
```

Kết quả: dù đi đường nào, client luôn nhận mã 404 kèm trang tùy biến; không có đường nào trả 200 cho `/404.html`.

## 4. Các bước thực hiện

### 4.1. Kiểm tra trước khi cấu hình

Từ máy cá nhân, gửi request tới một đường dẫn không tồn tại:

```
$ curl -i http://103.116.104.228/invalid-path-demo
HTTP/1.1 404 Not Found
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 02 Oct 2026 03:01:52 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.24.0 (Ubuntu)</center>
</body>
</html>
```

Đây là trang mặc định: 162 byte, giao diện thô và hiện nguyên phiên bản Nginx.

Hiện trạng trên máy chủ (SSH vào bằng user `devops`):

```
devops@halo:~$ ls -la /var/www/my-web/html
total 12
drwxr-x--- 2 devops www-data 4096 Oct  1 15:03 .
drwxr-x--- 3 devops www-data 4096 Oct  1 14:58 ..
-rw-r----- 1 devops www-data  623 Oct  1 15:03 index.html
```

### 4.2. Tạo trang 404.html

Thư mục web root thuộc `devops:www-data` nên `devops` tạo tệp trực tiếp, không cần `sudo`. Nội dung đầy đủ nằm ở tệp `404.html` trong thư mục này. Các điểm chính:

- Khai báo `<!DOCTYPE html>`, `<html lang="vi">`, `<meta charset="utf-8">` để hiển thị đúng tiếng Việt có dấu.
- `<meta name="viewport" ...>` để hiển thị tốt trên điện thoại.
- CSS nội tuyến trong thẻ `<style>`: không dùng ảnh ngoài, font ngoài hay thư viện, nên trang tự đủ và không phát sinh thêm request (kể cả khi các đường dẫn tĩnh khác đang lỗi).
- Mã `404` cỡ lớn (96px), thông điệp thân thiện và nút "Quay về trang chủ" dẫn tới `/`.
- Hỗ trợ giao diện tối qua `prefers-color-scheme: dark`.

Các lệnh đã chạy:

```
devops@halo:~$ cat > /var/www/my-web/html/404.html <<'EOF'
(nội dung 404.html)
EOF
devops@halo:~$ chmod 640 /var/www/my-web/html/404.html
devops@halo:~$ sudo chgrp www-data /var/www/my-web/html/404.html
devops@halo:~$ ls -la /var/www/my-web/html
total 16
drwxr-x--- 2 devops www-data 4096 Oct  2 10:07 .
drwxr-x--- 3 devops www-data 4096 Oct  1 14:58 ..
-rw-r----- 1 devops www-data 2036 Oct  2 10:07 404.html
-rw-r----- 1 devops www-data  623 Oct  1 15:03 index.html
devops@halo:~$ wc -c /var/www/my-web/html/404.html
2036 /var/www/my-web/html/404.html
```

Giải thích:

- `chmod 640`: chủ sở hữu đọc/ghi, nhóm chỉ đọc, người khác không có quyền.
- Tệp mới tạo có nhóm `devops` (nhóm chính của user), trong khi worker Nginx chạy bằng `www-data`. Với quyền 640 và thư mục 750, `www-data` chỉ đọc được nếu thuộc nhóm của tệp, vì vậy phải đổi nhóm sang `www-data` bằng `sudo chgrp`.
- Kích thước 2036 byte, lớn hơn 512 byte (xem mục 7).

### 4.3. Sửa Server Block

Sao lưu bản gốc rồi ghi cấu hình mới:

```
devops@halo:~$ sudo cp -p /etc/nginx/sites-available/my-web.conf /etc/nginx/sites-available/my-web.conf.bak-20261002
devops@halo:~$ sudo tee /etc/nginx/sites-available/my-web.conf > /dev/null <<'EOF'
(nội dung my-web.conf)
EOF
```

Tệp sao lưu `.bak-20261002` nằm trong `sites-available` và không có symlink trong `sites-enabled`, nên Nginx không nạp nó (Nginx chỉ nạp `sites-enabled/*`).

Cấu hình sau khi sửa (tệp `my-web.conf`):

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /var/www/my-web/html;
    index index.html;

    access_log /var/log/nginx/my-web.access.log;
    error_log  /var/log/nginx/my-web.error.log;

    # Chuyển hướng NỘI BỘ sang /404.html khi gặp 404; không có "=" nên mã vẫn là 404
    error_page 404 /404.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # "=" : khớp chính xác URI /404.html
    location = /404.html {
        root /var/www/my-web/html;
        internal;
    }
}
```

(Bản đầy đủ có chú thích tiếng Việt cho từng chỉ thị nằm trong tệp `my-web.conf`.)

Phần thay đổi so với bản gốc chỉ gồm hai khối: dòng `error_page 404 /404.html;` và `location = /404.html { ... }`. Các chỉ thị còn lại được giữ nguyên, chỉ bổ sung chú thích.

Kiểm tra nhanh các dòng then chốt:

```
devops@halo:~$ grep -nE '^[[:space:]]*(error_page|location|internal|root)' /etc/nginx/sites-available/my-web.conf
14:    root /var/www/my-web/html;
25:    error_page 404 /404.html;
27:    location / {
35:    location = /404.html {
38:        root /var/www/my-web/html;
43:        internal;
```

### 4.4. Kiểm tra cú pháp và reload

```
devops@halo:~$ sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
devops@halo:~$ sudo systemctl reload nginx
```

Luôn chạy `nginx -t` trước `reload`: nếu cấu hình sai, Nginx đang chạy không bị ảnh hưởng vì chưa nạp cấu hình lỗi. Dùng `reload` (không phải `restart`) để các worker cũ xử lý nốt kết nối đang mở rồi mới thoát, không gián đoạn dịch vụ.

Kiểm tra bằng `systemctl status nginx` (xem `terminal_log.txt`, bước 5): trạng thái `active (running)`, dòng `Reloaded nginx.service` lúc 10:13:02.

Tiến trình master giữ nguyên PID 1321, hai worker mới (4379, 4380) thay cho worker cũ: đúng hành vi của reload.

### 4.5. Kiểm tra kết quả

Thực hiện từ máy cá nhân.

Đường dẫn không tồn tại (đúng lệnh của đề):

```
$ curl -I http://103.116.104.228/invalid-path-demo
HTTP/1.1 404 Not Found
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 02 Oct 2026 03:14:09 GMT
Content-Type: text/html
Content-Length: 2036
Last-Modified: Fri, 02 Oct 2026 03:07:34 GMT
Connection: keep-alive
ETag: "6abf1ff6-7f4"
```

Nội dung trả về:

```
$ curl -s http://103.116.104.228/invalid-path-demo | head
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>404 - Không tìm thấy trang</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
```

Truy cập trực tiếp tệp lỗi:

```
$ curl -I http://103.116.104.228/404.html
HTTP/1.1 404 Not Found
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 02 Oct 2026 03:14:58 GMT
Content-Type: text/html
Content-Length: 2036
Last-Modified: Fri, 02 Oct 2026 03:07:34 GMT
Connection: keep-alive
ETag: "6abf1ff6-7f4"
```

Trang chủ vẫn bình thường:

```
$ curl -I http://103.116.104.228/
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 02 Oct 2026 03:15:20 GMT
Content-Type: text/html
Content-Length: 623
Last-Modified: Thu, 01 Oct 2026 08:03:19 GMT
Connection: keep-alive
ETag: "6abe13c7-26f"
Accept-Ranges: bytes
```

Đối chiếu mã trạng thái và số byte tải về của hai đường dẫn:

```
$ curl -s -o /dev/null -w '%{http_code} %{size_download}\n' http://103.116.104.228/invalid-path-demo http://103.116.104.228/404.html
404 2036
404 2036
```

### 4.6. Đối chiếu nhật ký Nginx

```
devops@halo:~$ sudo tail -n 7 /var/log/nginx/my-web.access.log
113.161.72.19 - - [02/Oct/2026:10:01:52 +0700] "GET /invalid-path-demo HTTP/1.1" 404 162 "-" "curl/8.15.0"
113.161.72.19 - - [02/Oct/2026:10:14:09 +0700] "HEAD /invalid-path-demo HTTP/1.1" 404 0 "-" "curl/8.15.0"
113.161.72.19 - - [02/Oct/2026:10:14:31 +0700] "GET /invalid-path-demo HTTP/1.1" 404 2036 "-" "curl/8.15.0"
113.161.72.19 - - [02/Oct/2026:10:14:58 +0700] "HEAD /404.html HTTP/1.1" 404 0 "-" "curl/8.15.0"
113.161.72.19 - - [02/Oct/2026:10:15:20 +0700] "HEAD / HTTP/1.1" 200 0 "-" "curl/8.15.0"
113.161.72.19 - - [02/Oct/2026:10:15:50 +0700] "GET /invalid-path-demo HTTP/1.1" 404 2036 "-" "curl/8.15.0"
113.161.72.19 - - [02/Oct/2026:10:15:50 +0700] "GET /404.html HTTP/1.1" 404 2036 "-" "curl/8.15.0"
devops@halo:~$ sudo wc -l /var/log/nginx/my-web.error.log
0 /var/log/nginx/my-web.error.log
```

Nhận xét:

- Ở lần kiểm tra đầu (10:01:52, chưa cấu hình) số byte gửi là 162; sau khi cấu hình, các request lỗi gửi 2036 byte, đúng bằng kích thước `404.html`.
- Request HEAD có `body_bytes_sent` bằng 0 vì không có thân phản hồi, nhưng header `Content-Length` vẫn báo 2036.
- Error log của site vẫn trống (0 dòng): với `try_files $uri $uri/ =404;`, Nginx tự kiểm tra sự tồn tại của tệp và trả 404 theo chỉ định, nên không ghi dòng lỗi `open() ... failed`. Dấu vết của các request sai đường dẫn nằm ở access log.
- Request trực tiếp tới `/404.html` cũng không sinh dòng lỗi, vì nó bị chặn ngay ở bước chọn location (`internal`), trước khi Nginx mở tệp.

## 5. Giải thích kết quả kiểm tra

### 5.1. Vì sao `curl -I /404.html` trả 404

Request `/404.html` từ curl là request bên ngoài. Nó khớp `location = /404.html`, nhưng block này có `internal` nên Nginx từ chối bằng mã 404 (lưu ý là 404 chứ không phải 403).

### 5.2. Vì sao vẫn hiện trang 404 tùy biến

Mã 404 vừa sinh ra lại khớp `error_page 404 /404.html;`, nên Nginx chuyển hướng nội bộ về `/404.html`. Lần này request mang cờ "nội bộ", `internal` cho phép, và tệp được phục vụ. Nói cách khác, chính cơ chế chặn đã tự kích hoạt trang lỗi: người dùng thấy trang đẹp nhưng không thể coi `/404.html` như một trang bình thường.

### 5.3. Vì sao mã trạng thái là 404 chứ không phải 200

Trong `error_page 404 /404.html;` không có dạng `=code`, nên Nginx giữ nguyên mã lỗi gốc khi trả trang tùy biến. Nếu viết `error_page 404 =200 /404.html;` thì mã sẽ bị đổi thành 200, dẫn tới "soft 404": công cụ tìm kiếm tưởng đó là trang thật và đánh chỉ mục, giám sát không phát hiện được lỗi. Vì vậy bài này cố ý giữ mã 404.

### 5.4. Vai trò của root trong location = /404.html

`location = /404.html` có `root /var/www/my-web/html;` riêng, nên đường dẫn tệp được xác định là `root + URI` = `/var/www/my-web/html/404.html`, không phụ thuộc root cấp server. Khi sau này đổi root của server (hoặc chuyển trang lỗi dùng chung nhiều site), block này vẫn trỏ đúng vị trí tệp lỗi.

### 5.5. Vì sao Content-Length là 2036 và ETag có dạng "6abf1ff6-7f4"

- `Content-Length: 2036` bằng đúng kích thước tệp `404.html` (`wc -c` ra 2036), chứng tỏ trang trả về là tệp tùy biến chứ không phải trang mặc định 162 byte.
- Nginx tạo ETag theo định dạng `"<mtime hex>-<size hex>"`. Thời điểm sửa đổi tệp 2026-10-02 10:07:34 (+0700), tức 03:07:34 GMT, là `0x6abf1ff6` giây kể từ epoch; kích thước 2036 là `0x7f4`. Ghép lại thành `"6abf1ff6-7f4"`, khớp với `Last-Modified: Fri, 02 Oct 2026 03:07:34 GMT`.
- Không có `Accept-Ranges: bytes` ở phản hồi 404 vì Nginx chỉ hỗ trợ range với phản hồi 200.

## 6. Mở rộng: gộp nhiều mã lỗi

Có thể khai báo nhiều mã lỗi dùng chung một trang:

```nginx
# Lỗi phía máy chủ dùng chung trang 50x.html
error_page 500 502 503 504 /50x.html;

location = /50x.html {
    root /var/www/my-web/html;
    internal;
}
```

Lưu ý:

- Cần tạo thêm tệp `50x.html` (cũng nên lớn hơn 512 byte) và đặt quyền giống `404.html`.
- Mỗi trang lỗi nên có `location = ...` riêng với `internal`, theo cùng mẫu.
- Khi Nginx làm reverse proxy, lỗi do backend trả về mặc định không bị `error_page` bắt; cần bật `proxy_intercept_errors on;` nếu muốn thay bằng trang riêng.

## 7. Lỗi thường gặp và cách xử lý

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Vẫn ra trang 404 mặc định của Nginx | Chưa `reload`, hoặc thiếu tệp `404.html`, hoặc sai tên tệp | `sudo nginx -t && sudo systemctl reload nginx`; kiểm tra `ls -la /var/www/my-web/html/404.html` |
| Vẫn ra trang mặc định, error log có `open() "/var/www/html/404.html" failed (2: ...)` | Quên khai báo `root` trong `location = /404.html` và root cấp server khác, hoặc `root` trỏ sai thư mục | Khai báo `root /var/www/my-web/html;` trong location, bảo đảm đường dẫn `root + /404.html` có tệp thật |
| Phản hồi 403 Forbidden, error log có `open() ".../404.html" failed (13: Permission denied)` | Tệp 404.html thuộc nhóm `devops` hoặc quyền 600, worker `www-data` không đọc được | `sudo chgrp www-data` và `chmod 640` cho tệp; thư mục phải có quyền `x` cho nhóm (750) |
| Truy cập `/404.html` trả 200 và hiện trang | Quên `internal;` trong location | Thêm `internal;` rồi `nginx -t`, `reload` |
| Mã trạng thái là 200 thay vì 404 | Viết `error_page 404 =200 /404.html;` | Bỏ `=200` |
| `nginx -t` báo `unexpected "}"` hoặc `directive is not terminated by ";"` | Thiếu dấu chấm phẩy, sai dấu ngoặc | Sửa theo số dòng báo lỗi; không `reload` khi `nginx -t` chưa thành công |
| Trình duyệt vẫn hiện trang cũ | Cache của trình duyệt | Nhấn Ctrl+F5, hoặc kiểm tra bằng `curl` |
| Trang lỗi bị trình duyệt đời cũ thay bằng trang riêng của nó | Trang lỗi nhỏ hơn 512 byte; một số trình duyệt cũ (như Internet Explorer) bỏ qua trang lỗi ngắn hơn ngưỡng này | Giữ trang lỗi lớn hơn 512 byte (`404.html` ở đây là 2036 byte) |

Quay lui nếu cần:

```
sudo cp -p /etc/nginx/sites-available/my-web.conf.bak-20261002 /etc/nginx/sites-available/my-web.conf
sudo nginx -t && sudo systemctl reload nginx
```

## 8. Bảng đối chiếu yêu cầu đề bài

| Yêu cầu | Cách thực hiện | Kết quả |
|---|---|---|
| Tạo `404.html` HTML tùy biến trong `/var/www/my-web/html/` | Tạo bằng user `devops`, 2036 byte, `chmod 640`, nhóm `www-data` | Đạt |
| Server Block dùng `error_page 404 /404.html;` | Dòng 25 của `my-web.conf`, cấp server | Đạt |
| `location = /404.html { internal; }` trỏ root chính xác | Dòng 35 đến 44: `root /var/www/my-web/html;` và `internal;` | Đạt |
| Ngăn truy cập trực tiếp `http://<IP>/404.html` | `curl -I /404.html` trả `HTTP/1.1 404 Not Found` | Đạt |
| `curl -I /invalid-path-demo` trả 404 kèm trang tùy biến | `HTTP/1.1 404 Not Found`, `Content-Length: 2036`, nội dung có `<title>404 - Không tìm thấy trang</title>` | Đạt |
| `sudo nginx -t` trước khi `reload` | Hai dòng `syntax is ok` và `test is successful`, sau đó `reload` | Đạt |
| Site vẫn hoạt động bình thường | `curl -I /` trả `200 OK` | Đạt |
| Nộp `404.html` và file cấu hình Server Block | Hai tệp `404.html`, `my-web.conf` trong `homework/session_03/ex2/` | Đạt |

## 9. Danh sách tệp nộp

Đường dẫn nộp: `homework/session_03/ex2/`

| Tệp | Nội dung |
|---|---|
| `404.html` | Trang lỗi 404 tùy biến (HTML5, CSS nội tuyến, 2036 byte) |
| `my-web.conf` | Server Block hoàn chỉnh sau khi sửa, có chú thích tiếng Việt |
| `README.md` | Báo cáo này |
| `terminal_log.txt` | Nhật ký đầy đủ các lệnh và kết quả trên Terminal |
| `deploy_404.sh` | Script bash idempotent tự động hóa toàn bộ các bước |

Script `deploy_404.sh` thực hiện: chép `404.html` (quyền 640, `devops:www-data`) -> chép `my-web.conf` (sao lưu bản cũ nếu khác) -> `nginx -t` (lỗi thì khôi phục bản sao lưu và dừng) -> `reload` -> kiểm tra nhanh bằng curl tới `127.0.0.1`. Chạy lại nhiều lần không gây lỗi, và không reload nếu không có thay đổi.

```
chmod +x deploy_404.sh
./deploy_404.sh
```

## 10. Kết luận

Trang 404 mặc định của Nginx đã được thay bằng trang tự thiết kế, thân thiện, hiển thị đúng tiếng Việt và có nút quay về trang chủ. Cấu hình dựa trên ba chỉ thị phối hợp với nhau:

1. `error_page 404 /404.html;` chuyển hướng nội bộ mọi lỗi 404 sang trang tùy biến và vẫn giữ mã trạng thái 404.
2. `location = /404.html` khớp chính xác URI của trang lỗi, với `root` khai báo tường minh nên không phụ thuộc cấu hình cấp server.
3. `internal;` khiến request bên ngoài tới `/404.html` bị từ chối bằng 404 (và chính 404 đó lại được `error_page` thay bằng trang tùy biến), nên trang lỗi chỉ được dùng như một phản hồi lỗi, không thể truy cập như một trang nội dung.

Hai phép kiểm tra của đề đều cho `HTTP/1.1 404 Not Found` với `Content-Length: 2036`, trùng kích thước tệp `404.html`, trong khi trang chủ vẫn trả 200. Quy trình luôn kiểm tra cú pháp bằng `nginx -t` trước khi `reload`, và có sẵn bản sao lưu cấu hình để quay lui khi cần.
