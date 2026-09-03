#!/usr/bin/env bash
#
# setup-nvidia-modeset.sh
#
# Cấu hình NVIDIA modeset + early KMS đúng chuẩn cho Hyprland (Wayland) trên
# Arch Linux dùng UKI/systemd-boot. Đây là bước NÊN LÀM ngay sau khi cài Arch
# mới trên máy có NVIDIA — không phải bước sửa lỗi đen TTY1 (lỗi đó do SDDM,
# xem disable-sddm.sh).
#
# Khác với bản cũ: script này THÊM module nvidia vào initramfs (early KMS)
# thay vì gỡ đi — đây là khuyến nghị chính thức cho Hyprland + NVIDIA để
# tránh giật/lag lúc khởi động.
#
# Script kiểm tra kỹ thông tin máy trước khi sửa gì — nếu phần cứng/cấu hình
# không khớp giả định (không có NVIDIA, không dùng UKI...), script sẽ DỪNG
# và báo rõ lý do thay vì đoán mò.
#
# Cách dùng: sudo bash setup-nvidia-modeset.sh

set -euo pipefail

CMDLINE_FILE="/etc/kernel/cmdline"
MKINITCPIO_FILE="/etc/mkinitcpio.conf"
UKI_FILE="/boot/EFI/Linux/arch-linux.efi"

# ------------------------------------------------------------------
# 0. Quyền root
# ------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Lỗi: cần chạy bằng sudo." >&2
    echo "Ví dụ: sudo bash $0" >&2
    exit 1
fi

echo "======================================================"
echo " KIỂM TRA THÔNG TIN MÁY TRƯỚC KHI SỬA"
echo "======================================================"

# ------------------------------------------------------------------
# 1. Có GPU NVIDIA thật không
# ------------------------------------------------------------------
echo
echo "--> Kiểm tra GPU NVIDIA (lspci)..."
if ! command -v lspci >/dev/null 2>&1; then
    echo "    Cảnh báo: không có lệnh lspci, cài gói 'pciutils' để kiểm tra đầy đủ." >&2
fi

NVIDIA_PCI="$(lspci -nn 2>/dev/null | grep -iE 'vga|3d' | grep -i nvidia || true)"
if [[ -z "$NVIDIA_PCI" ]]; then
    echo "    Không tìm thấy GPU NVIDIA nào trên máy này." >&2
    echo "    Script này chỉ dành cho máy có NVIDIA — dừng lại để tránh sửa nhầm." >&2
    exit 1
fi
echo "    Tìm thấy: $NVIDIA_PCI"

# ------------------------------------------------------------------
# 2. Driver nvidia có đang được dùng không (đã cài đúng gói chưa)
# ------------------------------------------------------------------
echo
echo "--> Kiểm tra driver đang gắn với GPU NVIDIA..."
NVIDIA_DRIVER_LINE="$(lspci -k 2>/dev/null | grep -A3 -i 'nvidia' | grep -i 'Kernel driver in use' || true)"
if [[ -z "$NVIDIA_DRIVER_LINE" ]]; then
    echo "    Cảnh báo: không xác định được driver đang dùng cho NVIDIA." >&2
elif echo "$NVIDIA_DRIVER_LINE" | grep -qi nouveau; then
    echo "    Cảnh báo: đang dùng driver nouveau (mã nguồn mở), không phải driver" >&2
    echo "    nvidia proprietary. Script này giả định bạn dùng driver 'nvidia'." >&2
    echo "    Kiểm tra: pacman -Qs nvidia   để xem gói đã cài." >&2
    read -r -p "    Vẫn tiếp tục? (y/N): " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Dừng lại theo yêu cầu."; exit 1; }
elif echo "$NVIDIA_DRIVER_LINE" | grep -qi nvidia; then
    echo "    OK: driver 'nvidia' đang được dùng ($NVIDIA_DRIVER_LINE)"
else
    echo "    Cảnh báo: driver lạ ($NVIDIA_DRIVER_LINE), kiểm tra lại thủ công." >&2
fi

# Kiểm tra gói nvidia-utils / nvidia đã cài chưa
echo
echo "--> Kiểm tra gói nvidia đã cài (pacman -Qs nvidia)..."
if command -v pacman >/dev/null 2>&1; then
    NVIDIA_PKGS="$(pacman -Qs '^nvidia' 2>/dev/null || true)"
    if [[ -z "$NVIDIA_PKGS" ]]; then
        echo "    Cảnh báo: không thấy gói nvidia nào đã cài qua pacman." >&2
        echo "    Cài trước bằng: sudo pacman -S nvidia-open nvidia-utils   (hoặc nvidia/nvidia-dkms tùy kernel)" >&2
        read -r -p "    Vẫn tiếp tục sửa cấu hình? (y/N): " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "Dừng lại theo yêu cầu."; exit 1; }
    else
        echo "    Đã cài:"
        echo "$NVIDIA_PKGS" | sed 's/^/      /'
    fi
fi

# ------------------------------------------------------------------
# 3. Xác nhận đang dùng UKI qua systemd-boot (không phải GRUB)
# ------------------------------------------------------------------
echo
echo "--> Kiểm tra bootloader..."
if command -v bootctl >/dev/null 2>&1 && bootctl status >/dev/null 2>&1; then
    echo "    OK: systemd-boot đang được dùng."
else
    echo "    Cảnh báo: không xác nhận được systemd-boot qua 'bootctl status'." >&2
    echo "    Nếu bạn dùng GRUB, script này KHÔNG áp dụng được — cần sửa" >&2
    echo "    /etc/default/grub thay vì /etc/kernel/cmdline." >&2
    read -r -p "    Vẫn tiếp tục (chỉ nên nếu bạn chắc chắn dùng UKI)? (y/N): " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Dừng lại theo yêu cầu."; exit 1; }
fi

if [[ ! -f "$CMDLINE_FILE" ]]; then
    echo "    Lỗi: không tìm thấy $CMDLINE_FILE — hệ thống có thể không dùng UKI" >&2
    echo "    theo kiểu chuẩn (Boot Loader Specification Type #2). Dừng lại." >&2
    exit 1
fi
echo "    OK: tìm thấy $CMDLINE_FILE"

if [[ ! -f "$MKINITCPIO_FILE" ]]; then
    echo "    Lỗi: không tìm thấy $MKINITCPIO_FILE" >&2
    exit 1
fi
echo "    OK: tìm thấy $MKINITCPIO_FILE"

# ------------------------------------------------------------------
# 4. Cảnh báo nếu có SDDM/display manager khác đang enable
#    (để tránh lặp lại nhầm lẫn lần trước — script này KHÔNG đụng vào DM)
# ------------------------------------------------------------------
echo
echo "--> Kiểm tra display manager (script này không đụng vào, chỉ cảnh báo)..."
for dm in sddm gdm gdm3 lightdm lxdm greetd; do
    if systemctl is-enabled "$dm" >/dev/null 2>&1; then
        echo "    Lưu ý: $dm đang enabled. Nếu TTY1 đen, đó thường là do $dm," >&2
        echo "    không phải do thiếu modeset — xem lại disable-sddm.sh nếu cần." >&2
    fi
done

echo
echo "======================================================"
echo " TẤT CẢ KIỂM TRA XONG — BẮT ĐẦU SỬA CẤU HÌNH"
echo "======================================================"
read -r -p "Tiếp tục sửa file cấu hình? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Đã hủy, không sửa gì cả."; exit 0; }

# ------------------------------------------------------------------
# 5. Sao lưu
# ------------------------------------------------------------------
TS="$(date +%Y%m%d%H%M%S)"
cp -a "$CMDLINE_FILE" "${CMDLINE_FILE}.bak.${TS}"
cp -a "$MKINITCPIO_FILE" "${MKINITCPIO_FILE}.bak.${TS}"
echo
echo "==> Đã sao lưu ${CMDLINE_FILE}.bak.${TS} và ${MKINITCPIO_FILE}.bak.${TS}"

# ------------------------------------------------------------------
# 6. Thêm nvidia-drm.modeset=1 vào cmdline (nếu chưa có)
# ------------------------------------------------------------------
echo
echo "==> Bước 1/3: nvidia-drm.modeset=1 trong $CMDLINE_FILE"
if grep -qw "nvidia-drm.modeset=1" "$CMDLINE_FILE"; then
    echo "    Đã có sẵn, bỏ qua."
else
    content="$(tr -d '\n' < "$CMDLINE_FILE")"
    printf '%s nvidia-drm.modeset=1\n' "$content" > "$CMDLINE_FILE"
    echo "    Đã thêm. Nội dung mới:"
    echo "    $(cat "$CMDLINE_FILE")"
fi

# ------------------------------------------------------------------
# 7. Đảm bảo module nvidia CÓ trong initramfs (early KMS - khuyến nghị
#    chính thức cho Hyprland+NVIDIA, KHÁC với bản cũ đã gỡ nhầm)
# ------------------------------------------------------------------
echo
echo "==> Bước 2/3: đảm bảo module NVIDIA có trong MODULES= (early KMS)"
current_line="$(grep '^MODULES=' "$MKINITCPIO_FILE" || true)"
if [[ -z "$current_line" ]]; then
    echo "    Lỗi: không tìm thấy dòng MODULES= trong $MKINITCPIO_FILE" >&2
    exit 1
fi

# Xóa nouveau nếu có (xung đột với driver nvidia proprietary)
if echo "$current_line" | grep -qw nouveau; then
    sed -i -E '/^MODULES=/ s/\bnouveau\b//g' "$MKINITCPIO_FILE"
    echo "    Đã gỡ nouveau (xung đột với driver nvidia)."
fi

# Thêm 4 module nvidia nếu chưa có
current_line="$(grep '^MODULES=' "$MKINITCPIO_FILE")"
if echo "$current_line" | grep -qw nvidia_drm; then
    echo "    Module NVIDIA đã có sẵn, bỏ qua."
else
    sed -i -E 's/^MODULES=\(([^)]*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_FILE"
    echo "    Đã thêm nvidia nvidia_modeset nvidia_uvm nvidia_drm."
fi

# Dọn khoảng trắng thừa
sed -i -E '/^MODULES=/ s/\( +/(/; /^MODULES=/ s/ +/ /g; /^MODULES=/ s/ \)/)/' "$MKINITCPIO_FILE"
echo "    Dòng MODULES hiện tại:"
grep '^MODULES=' "$MKINITCPIO_FILE" | sed 's/^/    /'

# ------------------------------------------------------------------
# 8. Rebuild UKI
# ------------------------------------------------------------------
echo
echo "==> Bước 3/3: rebuild UKI (mkinitcpio -P)"
mkinitcpio -P

echo
if [[ -f "$UKI_FILE" ]]; then
    echo "==> Xác nhận UKI đã cập nhật:"
    ls -la "$UKI_FILE" | sed 's/^/    /'
else
    echo "    Cảnh báo: không tìm thấy $UKI_FILE để xác nhận." >&2
fi

echo
echo "======================================================"
echo " HOÀN TẤT. Khởi động lại để áp dụng: sudo reboot"
echo "======================================================"
