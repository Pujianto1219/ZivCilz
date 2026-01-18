#!/bin/bash
# Script Menu Management ZiVPN (Fixed & Robust Version)
# Repo: https://github.com/Pujianto1219/ZiVPN

# --- Warna ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Files ---
CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/akun.db"
BOT_DATA="/etc/zivpn/bot_data"
DOMAIN_FILE="/etc/xray/domain"

# --- Validasi File ---
touch "$DB"
if [ ! -f "$CONFIG" ]; then echo '{"auth": []}' > "$CONFIG"; fi

clear_screen() {
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${YELLOW}           ZIVPN MANAGER (AUTO FIX)                ${NC}"
    echo -e "${BLUE}====================================================${NC}"
    echo -e " 1. Buat Akun SSH/UDP"
    echo -e " 2. Hapus Akun"
    echo -e " 3. Perpanjang Akun"
    echo -e " 4. Cek Daftar User"
    echo -e " 5. Restart Service"
    echo -e " 6. Setup Auto Backup (Telegram)"
    echo -e " 7. Backup Sekarang (Manual)"
    echo -e " x. Keluar"
    echo -e "${BLUE}====================================================${NC}"
}

# --- Fungsi User Management ---
add_user() {
    echo -e "${GREEN}[ BUAT AKUN BARU ]${NC}"
    read -p "Username : " user
    # Cek spasi
    if [[ "$user" =~ [[:space:]] ]]; then
        echo -e "${RED}Username tidak boleh ada spasi!${NC}"; sleep 2; menu
    fi
    # Cek duplikat
    if grep -q "^$user:" "$DB"; then 
        echo -e "${RED}User sudah ada!${NC}"; sleep 1; menu
    fi

    read -p "Password : " pass
    read -p "Durasi (angka saja, contoh: 30) atau ketik 'trial': " masa_input

    # LOGIKA PEMBERSIHAN INPUT (PENTING)
    if [[ "$masa_input" == "trial" ]]; then
        exp_seconds=$(date -d "+60 minutes" +%s)
        masa_txt="60 Menit (Trial)"
    else
        # Ambil hanya angkanya saja (menghapus kata 'hari', 'days', dll)
        masa=$(echo "$masa_input" | tr -dc '0-9')
        
        # Cek jika input kosong atau bukan angka
        if [[ -z "$masa" ]]; then
            echo -e "${RED}Durasi harus berupa angka!${NC}"; sleep 2; menu
        fi
        
        exp_seconds=$(date -d "+${masa} days" +%s)
        masa_txt="$masa Hari"
    fi

    # Simpan ke Config JSON
    jq --arg u "$user" --arg p "$pass" '.auth += [{"user": $u, "pass": $p, "mode": "unli"}]' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    
    # Simpan ke Database
    echo "${user}:${exp_seconds}" >> "$DB"
    
    systemctl restart udp-zivpn
    
    clear
    echo -e "${GREEN}Sukses Membuat Akun!${NC}"
    echo -e "Username : $user"
    echo -e "Expired  : $masa_txt"
    echo -e ""
    read -n 1 -s -r -p "Tekan enter untuk kembali..."
    menu
}

del_user() {
    echo -e "${RED}[ HAPUS AKUN ]${NC}"
    read -p "Username : " user
    
    if ! grep -q "^$user:" "$DB"; then 
        echo -e "${RED}User tidak ditemukan!${NC}"; sleep 1; menu
    fi

    # Hapus dari JSON
    jq --arg u "$user" '.auth |= map(select(.user != $u))' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    
    # Hapus dari Database
    grep -v "^$user:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
    
    systemctl restart udp-zivpn
    echo -e "${GREEN}User $user berhasil dihapus.${NC}"
    sleep 2; menu
}

renew_user() {
    echo -e "${YELLOW}[ PERPANJANG AKUN ]${NC}"
    read -p "Username : " user
    if ! grep -q "^$user:" "$DB"; then echo -e "${RED}User tidak ditemukan!${NC}"; sleep 1; menu; fi
    
    read -p "Tambah Masa Aktif (angka saja): " hari_input
    hari=$(echo "$hari_input" | tr -dc '0-9') # Bersihkan input
    
    if [[ -z "$hari" ]]; then echo -e "${RED}Input salah!${NC}"; sleep 1; menu; fi

    curr=$(grep "^$user:" "$DB" | cut -d: -f2)
    now=$(date +%s)
    
    # Validasi database lama
    if [[ ! "$curr" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Data user rusak, mereset expired jadi baru...${NC}"
        new_exp=$(date -d "+${hari} days" +%s)
    else
        if [ "$curr" -lt "$now" ]; then 
            new_exp=$(date -d "+${hari} days" +%s)
        else 
            new_exp=$(date -d "@$curr + $hari days" +%s)
        fi
    fi
    
    grep -v "^$user:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
    echo "${user}:${new_exp}" >> "$DB"
    echo -e "${GREEN}Berhasil diperpanjang!${NC}"
    sleep 2; menu
}

list_user() {
    clear
    echo -e "${BLUE}User List:${NC}"
    echo -e "-----------------------------------------"
    printf "%-15s | %-15s | %-10s\n" "Username" "Expired" "Status"
    echo -e "-----------------------------------------"
    
    while read -r line; do
        u=$(echo $line | cut -d: -f1)
        e=$(echo $line | cut -d: -f2)
        
        # Skip jika data rusak (expired kosong atau bukan angka)
        if [[ -z "$e" || ! "$e" =~ ^[0-9]+$ ]]; then
            continue
        fi

        d=$(date -d "@$e" "+%d-%b-%Y")
        now=$(date +%s)
        
        if [ "$e" -lt "$now" ]; then
            stat="${RED}EXPIRED${NC}"
        else
            stat="${GREEN}ACTIVE${NC}"
        fi
        printf "%-15s | %-15s | %-10s\n" "$u" "$d" "$stat"
    done < "$DB"
    echo -e "-----------------------------------------"
    read -n 1 -s -r -p "Tekan enter untuk kembali..."
    menu
}

# --- Backup Functions ---
setup_backup() {
    echo -e "${GREEN}[ SETUP TELEGRAM BOT ]${NC}"
    read -p "Bot Token : " token
    read -p "Chat ID   : " chatid
    if [[ -z "$token" || -z "$chatid" ]]; then
        echo -e "${RED}Data kosong!${NC}"; sleep 1; menu
    fi
    echo "${token}:${chatid}" > "$BOT_DATA"
    echo -e "${GREEN}Tersimpan!${NC}"; sleep 1; menu
}

run_backup() {
    if [ ! -f /usr/bin/backup-zivpn ]; then
        echo -e "${RED}Script backup belum terinstall di setup.sh${NC}"; sleep 2; menu
    fi
    /usr/bin/backup-zivpn
    echo -e "${GREEN}Backup berjalan...${NC}"; sleep 2; menu
}

# --- Main Logic ---
menu() {
    clear_screen
    read -p "Pilih: " opt
    case $opt in
        1) add_user ;;
        2) del_user ;;
        3) renew_user ;;
        4) list_user ;;
        5) systemctl restart udp-zivpn; systemctl restart nginx; echo "Done"; sleep 1; menu ;;
        6) setup_backup ;;
        7) run_backup ;;
        x) exit 0 ;;
        *) menu ;;
    esac
}

chmod +x menu.sh
menu
