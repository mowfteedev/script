# 🌙 Caeslestia — Arch + Hyprland Setup Scripts

Bộ script cấu hình và sửa lỗi cho Arch Linux + Hyprland trên laptop Optimus (Intel + NVIDIA).

---

## 📦 Script có sẵn

| Script | Mục đích |
|---|---|
| [`keysound.sh`](keysound.sh) | Cài đặt & cấu hình âm thanh bàn phím cơ (Wayvibes) cho bàn phím laptop |
| [`setup-nvidia-modeset.sh`](setup-nvidia-modeset.sh) | Bật NVIDIA modeset + early KMS đúng chuẩn cho Hyprland (UKI/systemd-boot) |

---

## 🚀 Cách sử dụng

### 1. Tải repo về máy
```bash
git clone https://github.com/mowfteedev/script.git
cd script
```

### 2. Cấp quyền thực thi
```bash
chmod +x *.sh
```

### 3. Chạy script cần dùng

**Âm thanh bàn phím cơ (Wayvibes):**
```bash
./keysound.sh
```
Script sẽ tự cài đặt, xin quyền, tải soundpack và hỏi bạn chọn âm thanh + âm lượng. Nếu chưa có quyền nhóm `input`, script sẽ yêu cầu bạn đăng xuất/khởi động lại rồi chạy lại lệnh trên.

**Cấu hình NVIDIA modeset:**
```bash
sudo bash setup-nvidia-modeset.sh
```
Cần chạy bằng `sudo`. Script chỉ áp dụng cho máy có GPU NVIDIA dùng UKI + systemd-boot — sẽ tự dừng và báo rõ nếu không khớp cấu hình máy bạn.
