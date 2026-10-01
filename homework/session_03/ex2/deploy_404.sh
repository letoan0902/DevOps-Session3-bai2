#!/usr/bin/env bash
# deploy_404.sh - Triển khai trang lỗi 404 tùy chỉnh cho site my-web (Bài 2, Session 03).
#
# Các bước:
#   1. Chép 404.html vào web root với quyền 640, chủ sở hữu devops:www-data.
#   2. Chép my-web.conf vào /etc/nginx/sites-available (sao lưu bản cũ nếu có thay đổi).
#   3. Kiểm tra cú pháp bằng "nginx -t"; nếu lỗi thì khôi phục bản sao lưu và dừng.
#   4. Reload Nginx (không làm gián đoạn kết nối đang phục vụ).
#   5. Kiểm tra nhanh kết quả bằng curl tới 127.0.0.1.
#
# Script idempotent: chạy lại nhiều lần cho cùng một kết quả, chỉ sao lưu/reload khi
# nội dung thực sự thay đổi.
#
# Cách dùng (đặt 404.html, my-web.conf cùng thư mục với script):
#   chmod +x deploy_404.sh
#   ./deploy_404.sh

set -euo pipefail

# ---------- Cấu hình ----------
WEB_ROOT="/var/www/my-web/html"
CONF_NAME="my-web.conf"
CONF_DST="/etc/nginx/sites-available/${CONF_NAME}"
ENABLED_LINK="/etc/nginx/sites-enabled/${CONF_NAME}"
OWNER="devops"
GROUP="www-data"
SERVER_URL="http://127.0.0.1"

# Thư mục chứa script, dùng để tìm 404.html và my-web.conf đi kèm.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_HTML="${SCRIPT_DIR}/404.html"
SRC_CONF="${SCRIPT_DIR}/${CONF_NAME}"

BACKUP=""
CHANGED=0

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { log "LỖI: $*" >&2; exit 1; }

# ---------- Kiểm tra điều kiện ----------
[ -f "${SRC_HTML}" ] || die "Không thấy ${SRC_HTML}"
[ -f "${SRC_CONF}" ] || die "Không thấy ${SRC_CONF}"
[ -d "${WEB_ROOT}" ] || die "Web root ${WEB_ROOT} chưa tồn tại"
command -v nginx >/dev/null 2>&1 || die "Chưa cài đặt Nginx"

# Chạy bằng user thường thì dùng sudo, chạy bằng root thì không cần.
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ---------- Bước 1: triển khai 404.html ----------
if [ -f "${WEB_ROOT}/404.html" ] && cmp -s "${SRC_HTML}" "${WEB_ROOT}/404.html"; then
    log "404.html không thay đổi, giữ nguyên."
else
    log "Chép 404.html vào ${WEB_ROOT}"
    ${SUDO} install -m 640 -o "${OWNER}" -g "${GROUP}" "${SRC_HTML}" "${WEB_ROOT}/404.html"
    CHANGED=1
fi
# Đảm bảo quyền đúng kể cả khi nội dung không đổi (www-data phải đọc được tệp).
${SUDO} chown "${OWNER}:${GROUP}" "${WEB_ROOT}/404.html"
${SUDO} chmod 640 "${WEB_ROOT}/404.html"

# ---------- Bước 2: triển khai Server Block ----------
if [ -f "${CONF_DST}" ] && cmp -s "${SRC_CONF}" "${CONF_DST}"; then
    log "Server Block không thay đổi, giữ nguyên."
else
    if [ -f "${CONF_DST}" ]; then
        BACKUP="${CONF_DST}.bak-$(date '+%Y%m%d-%H%M%S')"
        log "Sao lưu cấu hình cũ -> ${BACKUP}"
        ${SUDO} cp -p "${CONF_DST}" "${BACKUP}"
    fi
    log "Chép ${CONF_NAME} vào ${CONF_DST}"
    ${SUDO} install -m 644 -o root -g root "${SRC_CONF}" "${CONF_DST}"
    CHANGED=1
fi

# Bảo đảm site đã được bật (symlink sang sites-enabled).
if [ ! -e "${ENABLED_LINK}" ]; then
    log "Tạo symlink ${ENABLED_LINK}"
    ${SUDO} ln -s "${CONF_DST}" "${ENABLED_LINK}"
    CHANGED=1
fi

# ---------- Bước 3: kiểm tra cú pháp trước khi reload ----------
log "Kiểm tra cú pháp: nginx -t"
if ! ${SUDO} nginx -t; then
    if [ -n "${BACKUP}" ]; then
        log "Cú pháp lỗi, khôi phục cấu hình cũ từ ${BACKUP}"
        ${SUDO} cp -p "${BACKUP}" "${CONF_DST}"
    fi
    die "nginx -t thất bại, KHÔNG reload."
fi

# ---------- Bước 4: reload ----------
if [ "${CHANGED}" -eq 1 ]; then
    log "Reload Nginx"
    ${SUDO} systemctl reload nginx
else
    log "Không có thay đổi, bỏ qua reload."
fi

# ---------- Bước 5: kiểm tra nhanh ----------
status_of() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

CODE_MISSING="$(status_of "${SERVER_URL}/invalid-path-demo")"
CODE_DIRECT="$(status_of "${SERVER_URL}/404.html")"
CODE_HOME="$(status_of "${SERVER_URL}/")"
BODY_MISSING="$(curl -s "${SERVER_URL}/invalid-path-demo")"

log "GET /invalid-path-demo -> ${CODE_MISSING} (mong đợi 404)"
log "GET /404.html          -> ${CODE_DIRECT} (mong đợi 404, bị internal chặn)"
log "GET /                  -> ${CODE_HOME} (mong đợi 200)"

[ "${CODE_MISSING}" = "404" ] || die "Đường dẫn sai không trả 404."
[ "${CODE_DIRECT}" = "404" ]  || die "Truy cập trực tiếp /404.html không trả 404."
[ "${CODE_HOME}" = "200" ]    || die "Trang chủ không trả 200."
printf '%s' "${BODY_MISSING}" | grep -q '<title>404 - ' \
    || die "Nội dung trả về không phải trang 404 tùy biến."

log "Hoàn tất: trang 404 tùy biến hoạt động đúng."
