#!/bin/bash
# ZivPN Telegram Bot Manager
# Repo: https://github.com/Pujianto1219/ZivCilz

# Konfigurasi Disimpan di sini
BOT_DATA="/etc/zivpn/bot.json"

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Pastikan JQ terinstall (Seharusnya sudah ada dari setup.sh)
if ! command -v jq &> /dev/null; then
    apt-get install jq -y > /dev/null 2>&1
fi

# ==========================================
# 1. SETUP BOT (Dipanggil Manual)
# ==========================================
setup_bot() {
    clear
    echo -e "${GREEN}==============================${NC}"
    echo -e "    SETUP NOTIFIKASI TELEGRAM     "
    echo -e "${GREEN}==============================${NC}"
    echo ""
    echo "1. Buka @BotFather di Telegram -> Buat Bot -> Ambil Token"
    echo "2. Chat Pancingan ke Bot anda (ketik /start)"
    echo "3. Cek Chat ID anda di @userinfobot"
    echo ""
    
    read -p "Masukkan Bot Token : " TOKEN
    read -p "Masukkan Chat ID   : " CHATID

    # Validasi Input
    if [[ -z "$TOKEN" || -z "$CHATID" ]]; then
        echo -e "${RED}Data tidak boleh kosong!${NC}"
        exit 1
    fi

    # Simpan ke JSON
    cat <<EOF > "$BOT_DATA"
{
  "token": "$TOKEN",
  "chatid": "$CHATID"
}
EOF
    
    echo -e "${GREEN}Data tersimpan di $BOT_DATA${NC}"
    echo -e "Sedang mencoba mengirim pesan test..."
    
    send_msg "✅ *ZivPN Notification Connected*
    
VPS Domain: $(cat /etc/zivpn/domain 2>/dev/null)
Status: Bot berhasil diaktifkan."
}

# ==========================================
# 2. FUNGSI KIRIM PESAN (TEXT)
# ==========================================
send_msg() {
    if [ ! -f "$BOT_DATA" ]; then exit 0; fi
    
    TOKEN=$(jq -r .token "$BOT_DATA")
    CHATID=$(jq -r .chatid "$BOT_DATA")
    MSG="$1"
    
    # Kirim via Curl
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHATID" \
        -d text="$MSG" \
        -d parse_mode="Markdown" > /dev/null 2>&1
}

# ==========================================
# 3. FUNGSI KIRIM DOKUMEN (BACKUP)
# ==========================================
send_file() {
    if [ ! -f "$BOT_DATA" ]; then exit 0; fi
    
    TOKEN=$(jq -r .token "$BOT_DATA")
    CHATID=$(jq -r .chatid "$BOT_DATA")
    FILE="$1"
    CAPTION="$2"
    
    # Kirim Document
    curl -s -F document=@"$FILE" -F caption="$CAPTION" \
    "https://api.telegram.org/bot$TOKEN/sendDocument?chat_id=$CHATID" > /dev/null 2>&1
}

# ==========================================
# 4. LOGIKA HANDLING ARGUMEN
# ==========================================
case "$1" in
    setup)
        setup_bot
        ;;
    expired)
        # Dipanggil oleh cron: xp-zivpn
        USER="$2"
        MSG="⚠️ *USER EXPIRED*
        
User: \`$USER\`
Status: Akun telah dihapus otomatis."
        send_msg "$MSG"
        ;;
    backup)
        # Dipanggil oleh cron: backup-zivpn
        FILE="$2"
        DOMAIN=$(cat /etc/zivpn/domain 2>/dev/null)
        DATE=$(date "+%Y-%m-%d")
        CAPTION="💾 *AUTO BACKUP VPS*
        
Domain: \`$DOMAIN\`
Tanggal: $DATE"
        send_file "$FILE" "$CAPTION"
        ;;
    *)
        # Jika dijalankan tanpa argumen, anggap user mau setup
        setup_bot
        ;;
esac
