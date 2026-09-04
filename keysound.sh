#!/bin/bash
set -euo pipefail

# ==============================================================================
# Wayvibes Installation & Setup Orchestrator (Laptop - Wayland/Hyprland)
# Tự động hóa toàn bộ quy trình thiết lập Wayvibes, Soundpacks và Systemd Service
# ==============================================================================

CONFIG_DIR="$HOME/.config/wayvibes"
CONFIG_FILE="$CONFIG_DIR/config.env"
SOUNDPACKS_DIR="$CONFIG_DIR/soundpacks"
BASE_DIR="$SOUNDPACKS_DIR/wayclick_soundpacks"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/wayvibes.service"

declare -A ALIASES=(
    [unicomp]="unicomp_classic"
    [tealios]="tealios_v2"
    [brown]="cherry_mx_brown_pbt"
    [red]="cherry_mx_red_pbt"
    [black]="cherry_mx_black_pbt"
    [cream]="nk_cream"
    [panda]="glorious_panda"
    [clicky]="kailh_box_white"
)

echo "=========================================================================="
echo "  KHỞI ĐỘNG CÀI ĐẶT WAYVIBES (MECHANICAL KEYBOARD SOUND FOR LAPTOP)"
echo "=========================================================================="

# ------------------------------------------------------------------------------
# Bước 1: Cài đặt Wayvibes từ AUR
# ------------------------------------------------------------------------------
echo ""
echo "[Bước 1/6] Kiểm tra cài đặt package wayvibes-git..."
if command -v wayvibes &>/dev/null; then
    echo "✓ Wayvibes đã được cài đặt trên hệ thống: $(command -v wayvibes)"
else
    echo "→ Không tìm thấy wayvibes binary. Đang cài đặt wayvibes-git từ AUR..."
    if command -v yay &>/dev/null; then
        yay -S --needed wayvibes-git
    elif command -v paru &>/dev/null; then
        paru -S --needed wayvibes-git
    else
        echo "✗ Lỗi: Không tìm thấy AUR helper (yay hoặc paru). Vui lòng cài đặt wayvibes-git thủ công trước khi tiếp tục." >&2
        exit 1
    fi
    echo "✓ Đã cài đặt thành công wayvibes-git."
fi

# ------------------------------------------------------------------------------
# Bước 2: Phân quyền nhóm input
# ------------------------------------------------------------------------------
echo ""
echo "[Bước 2/6] Kiểm tra phân quyền nhóm 'input'..."
if groups | grep -qw input; then
    echo "✓ Tài khoản $USER đã thuộc nhóm 'input' và phiên hiện tại đã có đủ quyền."
else
    if getent group input | grep -qw "$USER"; then
        echo "ℹ Tài khoản $USER đã được gán nhóm 'input' trong hệ thống nhưng phiên làm việc hiện tại CHƯA nhận quyền mới."
    else
        echo "→ Đang thêm tài khoản $USER vào nhóm 'input' (yêu cầu sudo)..."
        sudo usermod -aG input "$USER"
        echo "✓ Đã thêm $USER vào nhóm 'input'."
    fi

    echo ""
    echo "=========================================================================="
    echo "  ⚠ YÊU CẦU BẮT BUỘC: ĐĂNG XUẤT (LOGOUT) HOẶC REBOOT MÁY TÍNH!"
    echo "=========================================================================="
    echo "Wayvibes cần quyền đọc sự kiện trực tiếp từ /dev/input/event*."
    echo "Nhân Linux chỉ kích hoạt quyền nhóm 'input' cho phiên của bạn sau khi bạn"
    echo "Đăng xuất (Log out) và đăng nhập lại, hoặc Khởi động lại (Reboot) máy."
    echo ""
    echo "Các bước tiếp theo:"
    echo "  1. Hãy lưu công việc, Đăng xuất hoặc Reboot máy."
    echo "  2. Sau khi đăng nhập lại, mở terminal và chạy lại script này:"
    echo "     $0"
    echo "=========================================================================="
    exit 0
fi

# ------------------------------------------------------------------------------
# Bước 3: Tải kho soundpack Wayclick_soundpacks
# ------------------------------------------------------------------------------
echo ""
echo "[Bước 3/6] Kiểm tra kho soundpack mặc định (Wayclick_soundpacks)..."
mkdir -p "$SOUNDPACKS_DIR"
if [ -d "$BASE_DIR" ]; then
    echo "✓ Kho soundpack Wayclick_soundpacks đã tồn tại tại $BASE_DIR."
else
    echo "→ Đang clone kho soundpack Wayclick từ GitHub..."
    git clone https://github.com/dusklinux/wayclick_soundpacks.git "$BASE_DIR" || \
    git clone https://github.com/cacoco/wayclick.git "$BASE_DIR"
    echo "✓ Đã clone thành công kho soundpack Wayclick."
fi

# Chuẩn hóa cấu trúc config.json từ Wayclick ("mappings") sang Wayvibes ("defines")
echo "→ Đồng bộ hóa định dạng soundpack cho Wayvibes..."
find "$SOUNDPACKS_DIR" -name "config.json" -exec sed -i 's/"mappings":/"defines":/g' {} + 2>/dev/null || true
echo "✓ Định dạng soundpack đã sẵn sàng cho Wayvibes."

# ------------------------------------------------------------------------------
# Bước 4: Thiết lập các file cấu hình và script vận hành
# ------------------------------------------------------------------------------
echo ""
echo "[Bước 4/6] Khởi tạo các file cấu hình và script vận hành..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$SYSTEMD_USER_DIR"

# 4.1 config.env
if [ -f "$CONFIG_FILE" ]; then
    echo "✓ File cấu hình config.env đã tồn tại ($CONFIG_FILE)."
else
    echo "→ Tạo file config.env mặc định..."
    cat << 'EOF' > "$CONFIG_FILE"
# Cấu hình âm thanh bàn phím Wayvibes
SOUNDPACK=unicomp_classic
VOLUME=1.0
EOF
    echo "✓ Đã tạo $CONFIG_FILE."
fi

# 4.2 run.sh (sao chép chính xác từ docs/installation.md)
if [ -f "$CONFIG_DIR/run.sh" ]; then
    echo "✓ Script run.sh đã tồn tại."
    chmod +x "$CONFIG_DIR/run.sh"
else
    echo "→ Tạo script run.sh..."
    cat << 'EOF' > "$CONFIG_DIR/run.sh"
#!/bin/bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/wayvibes"
CONFIG_FILE="$CONFIG_DIR/config.env"
BASE_DIR="$CONFIG_DIR/soundpacks/wayclick_soundpacks"
DEVICE_NAME="AT Translated Set 2 keyboard"

# Đọc cấu hình nếu tồn tại
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

PACK="${SOUNDPACK:-unicomp_classic}"
VOL="${VOLUME:-1.0}"

# Bảng alias hỗ trợ tên ngắn
declare -A ALIASES=(
    [unicomp]="unicomp_classic"
    [tealios]="tealios_v2"
    [brown]="cherry_mx_brown_pbt"
    [red]="cherry_mx_red_pbt"
    [black]="cherry_mx_black_pbt"
    [cream]="nk_cream"
    [panda]="glorious_panda"
    [clicky]="kailh_box_white"
)

PACK="${ALIASES[$PACK]:-$PACK}"

# Ưu tiên tìm trong BASE_DIR trước, tránh nhầm thư mục trùng tên ở $HOME
if [ -d "$BASE_DIR/$PACK" ]; then
    SOUNDPACK_DIR="$BASE_DIR/$PACK"
elif [[ "$PACK" == *"/"* ]] && [ -d "$PACK" ]; then
    SOUNDPACK_DIR="$(realpath "$PACK")"
else
    echo "⚠ Không tìm thấy soundpack '$PACK', dùng mặc định unicomp_classic"
    SOUNDPACK_DIR="$BASE_DIR/unicomp_classic"
fi

echo "Khởi chạy Wayvibes cho [$DEVICE_NAME] — Soundpack: $(basename "$SOUNDPACK_DIR") (Volume: $VOL)"

# Chuyển giao PID trực tiếp cho Wayvibes để Systemd quản lý chính xác
exec wayvibes --device-name "$DEVICE_NAME" "$SOUNDPACK_DIR" -v "$VOL"
EOF
    chmod +x "$CONFIG_DIR/run.sh"
    echo "✓ Đã tạo và cấp quyền thực thi cho $CONFIG_DIR/run.sh."
fi

# 4.3 switch.sh (sao chép chính xác từ docs/installation.md)
if [ -f "$CONFIG_DIR/switch.sh" ]; then
    echo "✓ Script switch.sh đã tồn tại."
    chmod +x "$CONFIG_DIR/switch.sh"
else
    echo "→ Tạo script switch.sh..."
    cat << 'EOF' > "$CONFIG_DIR/switch.sh"
#!/bin/bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/wayvibes"
CONFIG_FILE="$CONFIG_DIR/config.env"
BASE_DIR="$CONFIG_DIR/soundpacks/wayclick_soundpacks"

declare -A ALIASES=(
    [unicomp]="unicomp_classic"
    [tealios]="tealios_v2"
    [brown]="cherry_mx_brown_pbt"
    [red]="cherry_mx_red_pbt"
    [black]="cherry_mx_black_pbt"
    [cream]="nk_cream"
    [panda]="glorious_panda"
    [clicky]="kailh_box_white"
)

if [ $# -lt 1 ]; then
    echo "Sử dụng: $(basename "$0") <tên_soundpack|alias> [volume (0.0-10.0)]"
    echo "Ví dụ:   $(basename "$0") cream 1.2"
    exit 1
fi

INPUT_PACK="$1"
RESOLVED_PACK="${ALIASES[$INPUT_PACK]:-$INPUT_PACK}"

# 1. Validate soundpack: Kiểm tra trước khi lưu
if [ -d "$BASE_DIR/$RESOLVED_PACK" ]; then
    TARGET_PACK="$RESOLVED_PACK"
elif [[ "$INPUT_PACK" == *"/"* ]] && [ -d "$INPUT_PACK" ]; then
    TARGET_PACK="$(realpath "$INPUT_PACK")"
else
    echo "✗ Lỗi: Không tìm thấy soundpack '$INPUT_PACK' trong $BASE_DIR!"
    echo "  Danh sách có sẵn: ${!ALIASES[*]}"
    exit 1
fi

# 2. Validate volume: Kiểm tra dải 0.0 - 10.0
NEW_VOL="${2:-}"
if [ -z "$NEW_VOL" ] && [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    NEW_VOL="${VOLUME:-1.0}"
elif [ -z "$NEW_VOL" ]; then
    NEW_VOL="1.0"
fi

if ! [[ "$NEW_VOL" =~ ^([0-9](\.[0-9]+)?|10(\.0+)?)$ ]]; then
    echo "✗ Lỗi: Volume '$NEW_VOL' không hợp lệ. Phải nằm trong khoảng 0.0 đến 10.0 (ví dụ: 1.0, 2.5)"
    exit 1
fi

# Tự động đồng bộ hóa chuẩn defines cho soundpack
if [ -f "$BASE_DIR/$TARGET_PACK/config.json" ]; then
    sed -i 's/"mappings":/"defines":/g' "$BASE_DIR/$TARGET_PACK/config.json" 2>/dev/null || true
fi

# Lưu cấu hình bền vững
cat << INNER_EOF > "$CONFIG_FILE"
SOUNDPACK=$TARGET_PACK
VOLUME=$NEW_VOL
INNER_EOF

echo "✓ Đã lưu cấu hình: Soundpack=$(basename "$TARGET_PACK"), Volume=$NEW_VOL"

# Áp dụng ngay vào service
if systemctl --user is-active --quiet wayvibes.service; then
    systemctl --user restart wayvibes.service
    echo "✓ Đã áp dụng cấu hình mới vào service đang chạy."
else
    echo "ℹ Service chưa được bật. Bạn có thể bật bằng: systemctl --user start wayvibes.service"
fi
EOF
    chmod +x "$CONFIG_DIR/switch.sh"
    echo "✓ Đã tạo và cấp quyền thực thi cho $CONFIG_DIR/switch.sh."
fi

# 4.4 wayvibes.service (sao chép chính xác từ docs/installation.md)
if [ -f "$SERVICE_FILE" ]; then
    echo "✓ File service đã tồn tại ($SERVICE_FILE)."
else
    echo "→ Tạo file service $SERVICE_FILE..."
    cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=Wayvibes Mechanical Keyboard Sound Service (Laptop)
Documentation=https://github.com/sahaj-b/wayvibes
After=pipewire.service pipewire.socket wireplumber.service
Wants=pipewire.service pipewire.socket wireplumber.service

[Service]
Type=simple
WorkingDirectory=%h/.config/wayvibes
ExecStart=%h/.config/wayvibes/run.sh
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=default.target
EOF
    echo "✓ Đã tạo file service $SERVICE_FILE."
fi

# ------------------------------------------------------------------------------
# Bước 5: Kích hoạt Systemd User Service
# ------------------------------------------------------------------------------
echo ""
echo "[Bước 5/6] Nạp và kích hoạt Systemd User Service..."
systemctl --user daemon-reload
systemctl --user enable --now wayvibes.service
echo "✓ Đã kích hoạt wayvibes.service."

# ------------------------------------------------------------------------------
# Bước 6: Cấu hình tương tác Soundtrack & Volume
# ------------------------------------------------------------------------------
echo ""
echo "[Bước 6/6] Thiết lập Soundtrack và Âm lượng ban đầu"
echo "--------------------------------------------------------------------------"

CHOSEN_PACK=""
CHOSEN_VOL=""

while true; do
    read -rp "Bạn đã có soundtrack riêng chưa? (y/n): " has_custom
    case "$has_custom" in
        [yY]|[yY][eE][sS])
            while true; do
                read -rp "Nhập đường dẫn soundpack riêng (hoặc 'b' để quay lại): " input_pack
                if [[ "$input_pack" == "b" || "$input_pack" == "B" ]]; then
                    break
                fi
                if [ -z "$input_pack" ]; then
                    echo "✗ Vui lòng không để trống đường dẫn."
                    continue
                fi

                # Chuẩn hóa tilde nếu có
                expanded_pack="${input_pack/#\~/$HOME}"
                resolved_pack="${ALIASES[$expanded_pack]:-$expanded_pack}"

                target_dir=""
                # Validate theo đúng logic resolve path của switch.sh
                if [ -d "$BASE_DIR/$resolved_pack" ]; then
                    target_dir="$BASE_DIR/$resolved_pack"
                    CHOSEN_PACK="$resolved_pack"
                elif [[ "$expanded_pack" == *"/"* ]] && [ -d "$expanded_pack" ]; then
                    target_dir="$(realpath "$expanded_pack")"
                    CHOSEN_PACK="$target_dir"
                else
                    echo "✗ Lỗi: Không tìm thấy soundpack '$input_pack' trong $BASE_DIR!"
                    echo "  Gợi ý: Nhập đường dẫn thư mục tuyệt đối chứa soundpack (ví dụ: /path/to/soundpack) hoặc 'b' để quay lại."
                    continue
                fi

                # Kiểm tra cấu trúc hợp lệ (config.json và file âm thanh)
                if [ ! -f "$target_dir/config.json" ]; then
                    echo "✗ Lỗi: Không tìm thấy soundpack hợp lệ: thiếu file config.json trong '$target_dir'!"
                    continue
                fi

                if ! compgen -G "$target_dir/*.wav" > /dev/null && \
                   ! compgen -G "$target_dir/*.mp3" > /dev/null && \
                   ! compgen -G "$target_dir/*.flac" > /dev/null; then
                    echo "✗ Lỗi: Không tìm thấy file âm thanh (*.wav, *.mp3, *.flac) trong soundpack '$target_dir'!"
                    continue
                fi

                break 2
            done
            ;;
        [nN]|[nN][oO])
            echo ""
            echo "Danh mục Soundpack có sẵn trong Wayclick_soundpacks:"
            echo "----------------------------------------------------------------------------------------"
            printf "%-10s | %-24s | %-18s | %s\n" "Alias" "Tên thư mục đầy đủ" "Loại switch" "Đặc trưng âm thanh"
            echo "----------------------------------------------------------------------------------------"
            printf "%-10s | %-24s | %-18s | %s\n" "unicomp" "unicomp_classic" "Buckling Spring" "Tiếng đanh, giòn IBM Model M (Mặc định)"
            printf "%-10s | %-24s | %-18s | %s\n" "cream" "nk_cream" "Linear (POM)" "Âm 'clack' đanh, ấm và mượt mà"
            printf "%-10s | %-24s | %-18s | %s\n" "panda" "glorious_panda" "Tactile" "Âm 'thock' đầm, trầm, tactile bump"
            printf "%-10s | %-24s | %-18s | %s\n" "brown" "cherry_mx_brown_pbt" "Light Tactile" "Tiếng gõ nhẹ nhàng, phổ thông"
            printf "%-10s | %-24s | %-18s | %s\n" "red" "cherry_mx_red_pbt" "Linear" "Êm, trơn, thích hợp không gian yên tĩnh"
            printf "%-10s | %-24s | %-18s | %s\n" "black" "cherry_mx_black_pbt" "Heavy Linear" "Âm trầm, nặng, chắc tay"
            printf "%-10s | %-24s | %-18s | %s\n" "tealios" "tealios_v2" "Smooth Linear" "Trơn láng cao cấp, âm êm"
            printf "%-10s | %-24s | %-18s | %s\n" "clicky" "kailh_box_white" "Clicky (Clickbar)" "Âm click kép sắc nét, đanh gọn"
            echo "----------------------------------------------------------------------------------------"
            echo ""

            while true; do
                read -rp "Chọn tên soundpack/alias muốn dùng [Mặc định: unicomp]: " selected_pack
                selected_pack="${selected_pack:-unicomp}"
                resolved="${ALIASES[$selected_pack]:-$selected_pack}"

                if [ -d "$BASE_DIR/$resolved" ]; then
                    CHOSEN_PACK="$selected_pack"
                    break 2
                else
                    echo "✗ Lỗi: Không tìm thấy soundpack '$selected_pack' trong $BASE_DIR!"
                    echo "  Danh sách có sẵn: ${!ALIASES[*]}"
                fi
            done
            ;;
        *)
            echo "Vui lòng chỉ nhập 'y' hoặc 'n'."
            ;;
    esac
done

# Hỏi volume
while true; do
    read -rp "Nhập âm lượng volume (0.0 - 10.0) [Mặc định: 1.0]: " input_vol
    input_vol="${input_vol:-1.0}"
    if [[ "$input_vol" =~ ^([0-9](\.[0-9]+)?|10(\.0+)?)$ ]]; then
        CHOSEN_VOL="$input_vol"
        break
    else
        echo "✗ Lỗi: Volume '$input_vol' không hợp lệ. Phải nằm trong khoảng 0.0 đến 10.0 (ví dụ: 1.0, 2.5)"
    fi
done

# Áp dụng cấu hình thông qua switch.sh
echo ""
echo "→ Đang áp dụng cấu hình đã chọn thông qua switch.sh..."
"$CONFIG_DIR/switch.sh" "$CHOSEN_PACK" "$CHOSEN_VOL"

# ------------------------------------------------------------------------------
# Kết thúc: Tóm tắt cấu hình & Cheat sheet
# ------------------------------------------------------------------------------
echo ""
echo "=========================================================================="
echo "  🎉 CÀI ĐẶT VÀ KHỞI TẠO HOÀN TẤT THÀNH CÔNG!"
echo "=========================================================================="
echo "Thông tin thiết lập hiện hành:"
echo "  • Soundpack        : $CHOSEN_PACK"
echo "  • Âm lượng (Volume): $CHOSEN_VOL"
echo "  • Thiết bị ghim    : AT Translated Set 2 keyboard"
echo "  • Systemd Service  : wayvibes.service ($(systemctl --user is-active wayvibes.service 2>/dev/null))"
echo ""
echo "Gợi ý: Thêm các alias sau vào ~/.bashrc (nếu dùng Bash/Zsh) hoặc ~/.config/fish/config.fish (nếu dùng Fish):"
echo "  alias way-switch=\"\$HOME/.config/wayvibes/switch.sh\""
echo "  alias way-status=\"systemctl --user status wayvibes.service\""
echo "  alias way-stop=\"systemctl --user stop wayvibes.service\""
echo "  alias way-start=\"systemctl --user start wayvibes.service\""
echo "  alias way-log=\"journalctl --user -u wayvibes.service -f\""
echo ""
echo "Các lệnh thường dùng hàng ngày:"
echo "  way-switch cream        # Đổi nhanh sang switch NK Cream"
echo "  way-switch clicky 1.5   # Đổi sang Kailh Box White với volume 1.5"
echo "  way-stop                # Tạm tắt âm thanh (khi họp, học bài)"
echo "  way-start               # Bật lại âm thanh"
echo "  way-status              # Kiểm tra trạng thái service và PID"
echo "=========================================================================="
