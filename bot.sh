#!/bin/bash
# Zivpn Telegram Bot Setup
# Repo: https://github.com/Pujianto1219/ZivCilz

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

BOT_FILE="/etc/zivpn/bot_data"

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "       TELEGRAM BOT CONFIGURATION        "
echo -e "${CYAN}=========================================${NC}"

# Cek apakah sudah ada data
if [ -f "$BOT_FILE" ]; then
    CURRENT_DATA=$(cat $BOT_FILE)
    OLD_TOKEN=$(echo $CURRENT_DATA | cut -d: -f1)
    OLD_ID=$(echo $CURRENT_DATA | cut -d: -f2)
    
    echo -e "Data Saat Ini:"
    echo -e "Token   : ${GREEN}${OLD_TOKEN:0:10}.........${NC}"
    echo -e "Chat ID : ${GREEN}$OLD_ID${NC}"
    echo -e ""
    echo -e "[1] Ubah Data Bot"
    echo -e "[2] Test Kirim Pesan"
    echo -e "[x] Kembali"
    read -p "Pilih: " opt
else
    echo -e "${YELLOW}Belum ada data bot tersimpan.${NC}"
    opt="1"
fi

case $opt in
1)
    echo -e ""
    echo -e "${YELLOW}Panduan Singkat:${NC}"
    echo -e "1. Buat bot di @BotFather -> dapatkan Token"
    echo -e "2. Chat ke bot Anda, klik START"
    echo -e "3. Cek ID Anda di @userinfobot -> dapatkan Chat ID"
    echo -e ""
    
    read -p "Masukkan Bot Token : " token
    read -p "Masukkan Chat ID   : " chatid
    
    if [[ -z "$token" || -z "$chatid" ]]; then
        echo -e "${RED}Data tidak boleh kosong!${NC}"
        exit 1
    fi
    
    # Simpan Data
    echo "${token}:${chatid}" > $BOT_FILE
    echo -e "${GREEN}Data berhasil disimpan!${NC}"
    
    # Tawaran Test
    read -p "Ingin test kirim pesan sekarang? (y/n): " test_now
    if [[ "$test_now" == "y" ]]; then
        bash "$0" # Restart script untuk masuk menu test
    fi
    ;;

2)
    if [ ! -f "$BOT_FILE" ]; then
        echo -e "${RED}Data bot belum diset!${NC}"
        exit 1
    fi
    
    DATA=$(cat $BOT_FILE)
    TOKEN=$(echo $DATA | cut -d: -f1)
    ID=$(echo $DATA | cut -d: -f2)
    DOMAIN=$(cat /etc/zivpn/domain 2>/dev/null)
    
    echo -e "${YELLOW}Mengirim pesan test...${NC}"
    MSG="✅ *ZIVPN BOT TEST*%0A%0AHalo, notifikasi bot berhasil terhubung!%0A🖥️ Domain: \`$DOMAIN\`"
    
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$ID" \
        -d text="$MSG" \
        -d parse_mode="Markdown" > /dev/null
        
    echo -e "${GREEN}Pesan terkirim! Silakan cek Telegram Anda.${NC}"
    read -n 1 -s -r -p "Tekan Enter untuk kembali..."
    ;;

x|X)
    exit 0
    ;;
esac
