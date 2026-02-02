#!/bin/bash
# Zivpn Management Menu (Secure IP Gatekeeper + Glowing Theme)
# Repo: https://github.com/Pujianto1219/ZivCilz

# 1. SET TIMEZONE
timedatectl set-timezone Asia/Jakarta

# --- WARNA ULTRA BRIGHT (GLOWING) ---
# Menggunakan kode '1;9x' untuk efek tebal dan terang
RED='\033[1;91m'      # Merah Menyala
GREEN='\033[1;92m'    # Hijau Menyala
YELLOW='\033[1;93m'   # Kuning Emas
BLUE='\033[1;94m'     # Biru Elektrik
PURPLE='\033[1;95m'   # Ungu Neon
CYAN='\033[1;96m'     # Cyan Terang
WHITE='\033[1;97m'    # Putih Bersih
NC='\033[0m'          # Reset

# --- KONFIGURASI ---
CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/akun.db"
DOMAIN_FILE="/etc/zivpn/domain"
PERMISSION_URL="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip?v=$(date +%s)"
SERVICE_NAME="zivpn.service"

# --- CEK ROOT ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Harus dijalankan sebagai root!${NC}" 
   exit 1
fi

touch $DB_FILE
mkdir -p /etc/zivpn

# =================================================================
# 🛡️ GATEKEEPER SYSTEM (CEK IP SEBELUM MASUK MENU)
# =================================================================
MYIP=$(wget -qO- ipinfo.io/ip)
# Mengambil data dari github
RAW_DATA=$(curl -s "$PERMISSION_URL" | grep "$MYIP")

# Logika Validasi
VALID_IP=false
if [[ -n "$RAW_DATA" ]]; then
    CLIENT_NAME=$(echo "$RAW_DATA" | awk '{print $2}')
    LICENSE_EXP=$(echo "$RAW_DATA" | awk '{print $3}')
    
    # Cek Tanggal Expired (Simple String Comparison YYYY-MM-DD)
    TODAY=$(date +%Y-%m-%d)
    if [[ "$LICENSE_EXP" > "$TODAY" || "$LICENSE_EXP" == "$TODAY" ]]; then
        VALID_IP=true
    else
        STATUS_MSG="LICENSE EXPIRED"
    fi
else
    STATUS_MSG="IP NOT REGISTERED"
fi

# JIKA IP TIDAK VALID / EXPIRED -> TAMPILKAN PERINGATAN & EXIT
if [ "$VALID_IP" = false ]; then
    clear
    echo -e "${RED}██████╗ ███████╗███╗   ██╗██╗███████╗██████╗ ${NC}"
    echo -e "${RED}██╔══██╗██╔════╝████╗  ██║██║██╔════╝██╔══██╗${NC}"
    echo -e "${RED}██║  ██║█████╗  ██╔██╗ ██║██║█████╗  ██║  ██║${NC}"
    echo -e "${RED}██║  ██║██╔══╝  ██║╚██╗██║██║██╔══╝  ██║  ██║${NC}"
    echo -e "${RED}██████╔╝███████╗██║ ╚████║██║███████╗██████╔╝${NC}"
    echo -e "${RED}╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚══════╝╚═════╝ ${NC}"
    echo -e ""
    echo -e "${WHITE}══════════════════════════════════════════════════${NC}"
    echo -e " ${RED}⚠️  ACCESS DENIED: ${STATUS_MSG} ⚠️${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e " Your IP  : ${YELLOW}$MYIP${NC}"
    echo -e " Status   : ${RED}Inactive / Not Found${NC}"
    echo -e ""
    echo -e " ${CYAN}Silakan Hubungi Admin untuk Mendaftarkan IP Anda:${NC}"
    echo -e " ${GREEN}WhatsApp : 087733994799${NC}"
    echo -e " ${GREEN}Telegram : @AcilOffcial${NC}"
    echo -e ""
    echo -e "${WHITE}══════════════════════════════════════════════════${NC}"
    exit 0
fi

# =================================================================
# ✅ MASUK MENU UTAMA (HANYA JIKA IP VALID)
# =================================================================

# --- FUNGSI STATUS ---
get_status() {
    if systemctl is-active --quiet zivpn; then S_UDP="ON "; else S_UDP="OFF"; fi
    if systemctl is-active --quiet cron; then S_CRON="ON "; else S_CRON="OFF"; fi
}

# --- FUNGSI STRUK ---
show_receipt() {
    local user=$1
    local pass=$2
    local exp=$3
    
    CITY=$(wget -qO- ipinfo.io/city)
    ISP=$(wget -qO- ipinfo.io/org | cut -d " " -f 2-10)
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "$MYIP")
    
    echo -e ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "           ${CYAN}ACCOUNT ZIVPN UDP${NC}              "
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Password   : ${GREEN}$pass${NC}"
    echo -e ""
    echo -e "CITY       : $CITY"
    echo -e "ISP        : $ISP"
    echo -e "Domain     : $DOMAIN"
    echo -e ""
    echo -e "Expired On : ${YELLOW}$exp${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
}

# --- HEADER UTAMA ---
header() {
    clear
    get_status
    
    # Data System
    RAM_USED=$(free -m | grep Mem | awk '{print $3}')
    RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    RAW_DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "Belum diset")
    DOMAIN="${RAW_DOMAIN:0:18}"
    DATE=$(date +"%d %b %Y")
    TOTAL_USERS=$(jq '.auth.config | length' $CONFIG_FILE 2>/dev/null || echo "0")
    
    # Layout Variables (Gunakan Warna Biru Kuat)
    C_BORDER=$BLUE
    
    TOP="${C_BORDER}┌────────────────────────────────────────────────────┐${NC}"
    MID="${C_BORDER}├────────────────────────────────────────────────────┤${NC}"
    BOT="${C_BORDER}└────────────────────────────────────────────────────┘${NC}"
    V="${C_BORDER}│${NC}"

    # 1. BANNER ASCII (STRONG COLOR)
    echo -e "${CYAN}"
    echo -e "███████╗██╗██╗   ██╗ ██████╗██╗██╗     ███████╗"
    echo -e "╚══███╔╝██║██║   ██║██╔════╝██║██║     ╚══███╔╝"
    echo -e "  ███╔╝ ██║██║   ██║██║     ██║██║       ███╔╝ "
    echo -e " ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║      ███╔╝  "
    echo -e "███████╗██║ ╚████╔╝ ╚██████╗██║███████╗███████╗"
    echo -e "╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝╚══════╝"
    echo -e "${NC}"

    # 2. CLIENT INFO (LICENSE)
    echo -e "$TOP"
    printf "$V ${WHITE}%-10s${NC} : ${GREEN}%-35s${NC} $V\n" "CLIENT" "$CLIENT_NAME"
    printf "$V ${WHITE}%-10s${NC} : ${YELLOW}%-35s${NC} $V\n" "EXP IP" "$LICENSE_EXP"
    echo -e "$BOT"
    
    # 3. SYSTEM INFO
    echo -e "$TOP"
    printf "$V ${WHITE}%-6s${NC} : ${CYAN}%-16s${NC} ${C_BORDER}│${NC} ${WHITE}%-6s${NC} : ${CYAN}%-15s${NC} $V\n" "OS" "Ubuntu LTS" "IP" "$MYIP"
    printf "$V ${WHITE}%-6s${NC} : ${CYAN}%-16s${NC} ${C_BORDER}│${NC} ${WHITE}%-6s${NC} : ${CYAN}%-15s${NC} $V\n" "RAM" "$RAM_USED/$RAM_TOTAL MB" "USER" "$TOTAL_USERS Account"
    printf "$V ${WHITE}%-6s${NC} : ${CYAN}%-16s${NC} ${C_BORDER}│${NC} ${WHITE}%-6s${NC} : ${CYAN}%-15s${NC} $V\n" "DATE" "$DATE" "DOMAIN" "$DOMAIN"
    echo -e "$MID"
    
    # Status Logic Color
    if [[ "$S_UDP" == "ON " ]]; then COL_UDP=$GREEN; else COL_UDP=$RED; fi
    if [[ "$S_CRON" == "ON " ]]; then COL_CRON=$GREEN; else COL_CRON=$RED; fi
    
    printf "$V      ${WHITE}%-10s${NC} ${COL_UDP}%-9s${NC} ${C_BORDER}│${NC}      ${WHITE}%-10s${NC} ${COL_CRON}%-9s${NC}     $V\n" "ZIVPN UDP:" "$S_UDP" "AUTO XP:" "$S_CRON"
    echo -e "$BOT"
}

# --- MAIN LOOP ---
while true; do
    header
    
    # MENU BOX (Glowing White Text, Red Brackets, Yellow Numbers)
    echo -e "${BLUE}┌─────────────────────${WHITE}[ MENU ]${BLUE}───────────────────────┐${NC}"
    printf "${BLUE}│${NC} ${RED}[${YELLOW}01${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC} ${RED}[${YELLOW}06${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC}\n" "Create User" "Change Domain"
    printf "${BLUE}│${NC} ${RED}[${YELLOW}02${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC} ${RED}[${YELLOW}07${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC}\n" "Create Trial" "Force Delete Exp"
    printf "${BLUE}│${NC} ${RED}[${YELLOW}03${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC} ${RED}[${YELLOW}08${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC}\n" "Renew User" "Backup Data"
    printf "${BLUE}│${NC} ${RED}[${YELLOW}04${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC} ${RED}[${YELLOW}09${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC}\n" "Delete User" "Restore Backup"
    printf "${BLUE}│${NC} ${RED}[${YELLOW}05${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC} ${RED}[${YELLOW}10${RED}]${NC} ${WHITE}%-18s${NC} ${BLUE}│${NC}\n" "User List" "Restart Service"
    echo -e "${BLUE}└────────────────────────────────────────────────────┘${NC}"
    
    # EXIT BOX
    echo -e "${BLUE}┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}               ${RED}[x] Exit / Keluar${NC}                    ${BLUE}│${NC}"
    echo -e "${BLUE}└────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    echo -e -n " Select Option : "
    read opt

    case $opt in
        1|01) 
            echo -e ""
            echo -e " ${YELLOW}➤ CREATE REGULAR USER${NC}"
            read -p " Username : " new_pass
            if [ -z "$new_pass" ]; then echo -e "${RED}Empty!${NC}"; sleep 1; continue; fi
            if grep -q "\"$new_pass\"" $CONFIG_FILE; then echo -e "${RED}Exists!${NC}"; sleep 1; continue; fi
            read -p " Active Days : " masa_aktif
            if [[ ! $masa_aktif =~ ^[0-9]+$ ]]; then masa_aktif=30; fi
            
            exp_date=$(date -d "+${masa_aktif} days" +%s)
            exp_display=$(date -d "+${masa_aktif} days" +"%Y-%m-%d")
            
            cp $CONFIG_FILE $CONFIG_FILE.bak
            jq --arg pass "$new_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
            echo "${new_pass}:${exp_date}" >> $DB_FILE
            systemctl restart $SERVICE_NAME
            
            if [ -f "/usr/bin/zivbot" ]; then zivbot create "$new_pass" "$exp_display" & fi
            show_receipt "$new_pass" "$new_pass" "$exp_display"
            ;;

        2|02)
            echo -e ""
            echo -e " ${YELLOW}➤ CREATE TRIAL USER${NC}"
            read -p " Username : " trial_user
            if [ -z "$trial_user" ]; then echo -e "${RED}Empty!${NC}"; sleep 1; continue; fi
            read -p " Minutes : " trial_min
            if [[ ! $trial_min =~ ^[0-9]+$ ]]; then trial_min=30; fi
            
            exp_date=$(date -d "+${trial_min} minutes" +%s)
            exp_display=$(date -d "+${trial_min} minutes" +"%Y-%m-%d %H:%M:%S")
            
            jq --arg pass "$trial_user" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
            echo "${trial_user}:${exp_date}" >> $DB_FILE
            systemctl restart $SERVICE_NAME
            
            if [ -f "/usr/bin/zivbot" ]; then zivbot create "$trial_user" "$exp_display (Trial)" & fi
            show_receipt "$trial_user" "$trial_user" "$exp_display (Trial)"
            ;;

        3|03)
            echo -e ""
            echo -e " ${YELLOW}➤ RENEW USER${NC}"
            read -p " Username : " renew_pass
            
            # Cek User di Database
            if grep -q "^${renew_pass}:" $DB_FILE; then
                read -p " Add Days : " add_days
                
                # Hitung Tanggal Baru
                current_exp=$(grep "^${renew_pass}:" $DB_FILE | cut -d: -f2)
                now=$(date +%s)
                
                # Jika sudah expired, hitung mulai dari sekarang
                if [ "$current_exp" -lt "$now" ]; then
                    current_exp=$now
                fi
                
                new_exp=$(date -d "@$current_exp + $add_days days" +%s)
                new_date=$(date -d "@$new_exp" +"%Y-%m-%d")
                
                # Update Database
                grep -v "^${renew_pass}:" $DB_FILE > /tmp/db_tmp
                echo "${renew_pass}:${new_exp}" >> /tmp/db_tmp; mv /tmp/db_tmp $DB_FILE
                
                # Update Config JSON (Jika user sempat terhapus otomatis)
                if ! grep -q "\"$renew_pass\"" $CONFIG_FILE; then
                     echo -e "${YELLOW}User expired & removed. Reactivating...${NC}"
                     jq --arg pass "$renew_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                fi
                
                systemctl restart $SERVICE_NAME
                
                # Kirim Notif
                if [ -f "/usr/bin/zivbot" ]; then zivbot renew "$renew_pass" "$new_date" & fi
                show_receipt "$renew_pass" "$renew_pass" "$new_date (Renewed)"
            else
                echo -e "${RED}User not found in Database!${NC}"
            fi
            ;;

        4|04)
            echo -e ""
            echo -e " ${YELLOW}➤ DELETE USER${NC}"
            i=1
            usernames=()
            
            # Header Tabel Delete (Blue Border)
            echo -e "${BLUE}┌─────┬──────────────────────┐${NC}"
            echo -e "${BLUE}│${NC} NO  ${BLUE}│${NC} ${WHITE}USERNAME${NC}             ${BLUE}│${NC}"
            echo -e "${BLUE}├─────┼──────────────────────┤${NC}"
            
            while read -r user; do
                usernames+=("$user")
                printf "${BLUE}│${NC} %-3s ${BLUE}│${NC} ${WHITE}%-20s${NC} ${BLUE}│${NC}\n" "$i" "$user"
                ((i++))
            done < <(jq -r '.auth.config[]' $CONFIG_FILE)
            
            echo -e "${BLUE}└─────┴──────────────────────┘${NC}"
            
            if [ ${#usernames[@]} -eq 0 ]; then
                echo -e "${RED}No users found.${NC}"
            else
                echo -e ""
                read -p " Select Number (1-${#usernames[@]}): " selection
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#usernames[@]}" ]; then
                    del_pass="${usernames[$((selection-1))]}"
                    echo -e " Deleting: ${YELLOW}$del_pass${NC} ..."
                    
                    jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                    grep -v "^${del_pass}:" $DB_FILE > /tmp/db_tmp && mv /tmp/db_tmp $DB_FILE
                    systemctl restart $SERVICE_NAME
                    
                    if [ -f "/usr/bin/zivbot" ]; then zivbot delete "$del_pass" & fi
                    echo -e "${GREEN}Success! User '$del_pass' deleted.${NC}"
                else
                    echo -e "${RED}Invalid Selection!${NC}"
                fi
            fi
            ;;

        5|05)
            echo -e ""
            echo -e " ${YELLOW}➤ USER LIST${NC}"
            echo -e "${BLUE}┌─────────────────────┬──────────────────────────┐${NC}"
            echo -e "${BLUE}│${NC} ${WHITE}USER${NC}                ${BLUE}│${NC} ${WHITE}EXPIRED${NC}                  ${BLUE}│${NC}"
            echo -e "${BLUE}├─────────────────────┼──────────────────────────┤${NC}"
            for user in $(jq -r '.auth.config[]' $CONFIG_FILE); do
                exp_ts=$(grep "^${user}:" $DB_FILE | cut -d: -f2)
                if [[ -n "$exp_ts" && "$exp_ts" =~ ^[0-9]+$ ]]; then
                    if [ "$exp_ts" -gt "$(date +%s)" ]; then
                         diff=$(($exp_ts - $(date +%s)))
                         if [ $diff -lt 86400 ]; then 
                            exp_str=$(date -d "@$exp_ts" +"%H:%M (%d-%b)")
                         else 
                            exp_str=$(date -d "@$exp_ts" +"%Y-%m-%d")
                         fi
                    else 
                        exp_str="${RED}EXPIRED${NC}"
                    fi
                else 
                    exp_str="Unlimited"
                fi
                printf "${BLUE}│${NC} ${WHITE}%-19s${NC} ${BLUE}│${NC} ${WHITE}%-24s${NC} ${BLUE}│${NC}\n" "$user" "$exp_str"
            done
            echo -e "${BLUE}└─────────────────────┴──────────────────────────┘${NC}"
            ;;

        6|06)
            echo -e ""
            echo -e " ${YELLOW}➤ CHANGE DOMAIN${NC}"
            read -p " New Domain : " new_domain
            if [ -n "$new_domain" ]; then
                echo "$new_domain" > $DOMAIN_FILE
                openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=ID/CN=$new_domain" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}Domain Updated!${NC}"
            fi
            ;;

        7|07)
            echo -e ""
            echo -e "${YELLOW}Checking Expired Users...${NC}"
            if [ -f "/usr/bin/xp-zivpn" ]; then /usr/bin/xp-zivpn; echo -e "${GREEN}Done.${NC}"; fi
            ;;

        8|08)
            echo -e ""
            echo -e "${YELLOW}➤ BACKUP DATA${NC}"
            echo -e " Memproses backup database & config..."
            if [ -f "/usr/bin/backup-zivpn" ]; then 
                /usr/bin/backup-zivpn
            else
                echo -e "${RED}Script backup tidak ditemukan!${NC}"
            fi
            ;;

        9|09)
            echo -e ""
            echo -e " ${YELLOW}➤ RESTORE BACKUP${NC}"
            echo -e " ${WHITE}Paste Link Transfer.sh (Direct Link)${NC}"
            read -p " Link : " link_zip

            # Validasi Input Kosong
            if [ -z "$link_zip" ]; then 
                echo -e "${RED}Link tidak boleh kosong!${NC}"
                sleep 1
                continue
            fi

            # Buat folder sementara
            echo -e " ${YELLOW}Downloading Backup...${NC}"
            rm -rf /root/restore # Bersihkan sisa restore lama jika ada
            mkdir -p /root/restore
            cd /root/restore

            # Download File
            wget -q "$link_zip" -O backup.zip
            
            # Cek apakah file terdownload dengan benar (Size > 0)
            if [ ! -s "backup.zip" ]; then
                echo -e "${RED}Download Gagal! Cek Link atau Koneksi.${NC}"
                cd /root
                rm -rf /root/restore
                continue
            fi

            # Extract File
            echo -e " ${YELLOW}Extracting Data...${NC}"
            unzip -o backup.zip > /dev/null 2>&1

            # LOGIKA RESTORE (Cek Struktur Zip)
            # Kondisi 1: Jika hasil zip ada di dalam folder "backup" (Sesuai script backup kita)
            if [ -f "backup/config.json" ] && [ -f "backup/akun.db" ]; then
                cp backup/config.json /etc/zivpn/
                cp backup/akun.db /etc/zivpn/
                STATUS="OK"
            
            # Kondisi 2: Jika user buat zip manual (file langsung di luar tanpa folder)
            elif [ -f "config.json" ] && [ -f "akun.db" ]; then
                cp config.json /etc/zivpn/
                cp akun.db /etc/zivpn/
                STATUS="OK"
            
            else
                STATUS="FAIL"
            fi

            # Finalisasi
            cd /root
            rm -rf /root/restore

            if [ "$STATUS" == "OK" ]; then
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}Restore Success! Database telah dipulihkan.${NC}"
            else
                echo -e "${RED}Gagal! File Backup Corrupt atau Tidak Lengkap.${NC}"
                echo -e "Pastikan file zip berisi config.json & akun.db"
            fi
            ;;

        10)
            # MENU BARU: BOT MANAGER
            echo -e ""
            echo -e " ${YELLOW}➤ BOT MANAGER${NC}"
            if [ -f "/usr/bin/zivbot" ]; then
                /usr/bin/zivbot setup
            else
                echo -e "${RED}Script bot not found!${NC}"
            fi
            ;;

        x|X) clear; exit 0 ;;
        *) echo -e "${RED}Invalid Option!${NC}" ;;
    esac
    echo -e ""
    read -n 1 -s -r -p "Press Enter to return..."
done
