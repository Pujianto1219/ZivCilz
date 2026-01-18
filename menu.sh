#!/bin/bash
# Script Menu ZivCilz
# Repo: https://github.com/Pujianto1219/ZivCilz

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/akun.db"
BOT_DATA="/etc/zivpn/bot_data"

# Init files
mkdir -p /etc/zivpn
touch "$DB"
if [ ! -f "$CONFIG" ]; then echo '{"auth": []}' > "$CONFIG"; fi

clear_screen() {
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${YELLOW}           ZIVCILZ MANAGER (FIXED)                 ${NC}"
    echo -e "${BLUE}====================================================${NC}"
    echo -e " 1. Buat Akun"
    echo -e " 2. Hapus Akun"
    echo -e " 3. Perpanjang Akun"
    echo -e " 4. Cek User"
    echo -e " 5. Restart Service"
    echo -e " 6. Setup Backup Bot"
    echo -e " 7. Backup Manual"
    echo -e " x. Keluar"
    echo -e "${BLUE}====================================================${NC}"
}

add_user() {
    echo -e "${GREEN}[ BUAT AKUN ]${NC}"
    read -p "Username : " user
    [[ "$user" =~ [[:space:]] ]] && { echo "${RED}No spaces!${NC}"; sleep 1; menu; }
    grep -q "^$user:" "$DB" && { echo "${RED}Exists!${NC}"; sleep 1; menu; }
    
    read -p "Password : " pass
    read -p "Durasi (angka/trial): " masa_in
    
    if [[ "$masa_in" == "trial" ]]; then
        exp=$(date -d "+60 minutes" +%s)
        txt="Trial 60 Min"
    else
        m=$(echo "$masa_in" | tr -dc '0-9')
        [[ -z "$m" ]] && { echo "${RED}Angka woy!${NC}"; sleep 1; menu; }
        exp=$(date -d "+${m} days" +%s)
        txt="$m Hari"
    fi
    
    jq --arg u "$user" --arg p "$pass" '.auth += [{"user": $u, "pass": $p, "mode": "unli"}]' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    echo "${user}:${exp}" >> "$DB"
    systemctl restart udp-zivpn
    echo -e "${GREEN}Sukses! $user ($txt)${NC}"; sleep 2; menu
}

del_user() {
    read -p "User: " u
    jq --arg x "$u" '.auth |= map(select(.user != $x))' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    grep -v "^$u:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
    systemctl restart udp-zivpn
    echo "Deleted."; sleep 1; menu
}

renew_user() {
    read -p "User: " u
    grep -q "^$u:" "$DB" || { echo "Not found"; sleep 1; menu; }
    read -p "Tambah hari (angka): " h
    h=$(echo "$h" | tr -dc '0-9')
    cur=$(grep "^$u:" "$DB" | cut -d: -f2)
    now=$(date +%s)
    [[ ! "$cur" =~ ^[0-9]+$ ]] && cur=$now
    if [ "$cur" -lt "$now" ]; then nex=$(date -d "+$h days" +%s); else nex=$(date -d "@$cur + $h days" +%s); fi
    grep -v "^$u:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
    echo "${u}:${nex}" >> "$DB"
    echo "Renewed."; sleep 1; menu
}

list_user() {
    clear; echo "LIST USER:"; echo "-----------------"
    while read -r l; do
        u=$(echo $l | cut -d: -f1); e=$(echo $l | cut -d: -f2)
        [[ ! "$e" =~ ^[0-9]+$ ]] && continue
        d=$(date -d "@$e" "+%d-%b-%Y")
        [ "$e" -lt "$(date +%s)" ] && s="EXP" || s="ON"
        echo "$u | $d | $s"
    done < "$DB"
    read -p "Enter..." ; menu
}

setup_bot() {
    read -p "Token: " t; read -p "ChatID: " c
    echo "$t:$c" > "$BOT_DATA"; echo "Saved."; sleep 1; menu
}

menu() {
    clear_screen; read -p "Opt: " o
    case $o in
        1) add_user ;; 2) del_user ;; 3) renew_user ;; 4) list_user ;;
        5) systemctl restart udp-zivpn; systemctl restart nginx; menu ;;
        6) setup_bot ;; 7) /usr/bin/backup-zivpn; echo "Done"; sleep 1; menu ;;
        x) exit ;; *) menu ;;
    esac
}
menu
