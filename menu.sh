#!/bin/bash
# Zivpn Management Menu (Fixed Alignment & White Text)
# Repo: https://github.com/Pujianto1219/ZivCilz

# 1. SET TIMEZONE
timedatectl set-timezone Asia/Jakarta

# --- DEFINISI WARNA ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- KONFIGURASI ---
CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/akun.db"
DOMAIN_FILE="/etc/zivpn/domain"
BOT_FILE="/etc/zivpn/bot_data"
SERVICE_NAME="zivpn.service"

# Cek Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Harus dijalankan sebagai root!${NC}" 
   exit 1
fi

touch $DB_FILE
mkdir -p /etc/zivpn

# --- FUNGSI STATUS ---
get_status() {
    # Kita buat status sederhana ON/OFF tanpa warna di variabel ini
    # Warna akan ditambahkan saat printf agar tidak merusak kolom
    if systemctl is-active --quiet zivpn; then S_UDP="ON "; else S_UDP="OFF"; fi
    if systemctl is-active --quiet cron; then S_CRON="ON "; else S_CRON="OFF"; fi
}

# --- FUNGSI STRUK (RECEIPT) ---
show_receipt() {
    local user=$1
    local pass=$2
    local exp=$3
    
    MYIP=$(wget -qO- ipinfo.io/ip)
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
    
    # Ambil Data & Potong jika kepanjangan (Supaya kotak tidak jebol)
    RAM_USED=$(free -m | grep Mem | awk '{print $3}')
    RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    MYIP=$(wget -qO- ipinfo.io/ip)
    
    # Domain max 18 karakter
    RAW_DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "Belum diset")
    DOMAIN="${RAW_DOMAIN:0:18}" 
    
    DATE=$(date +"%d %b %Y")
    
    # ISP max 18 karakter
    RAW_ISP=$(wget -qO- ipinfo.io/org | cut -d " " -f 2-10)
    ISP="${RAW_ISP:0:18}"
    
    # Border Characters
    C_BORDER=$PURPLE
    C_LABEL=$CYAN
    C_TEXT=$WHITE
    
    TOP="${C_BORDER}┌────────────────────────────────────────────────────┐${NC}"
    MID="${C_BORDER}├────────────────────────────────────────────────────┤${NC}"
    BOT="${C_BORDER}└────────────────────────────────────────────────────┘${NC}"
    V="${C_BORDER}│${NC}"

    # 1. BANNER ASCII
    echo -e "${BLUE}"
    echo -e "███████╗██╗██╗   ██╗ ██████╗██╗██╗     ███████╗"
    echo -e "╚══███╔╝██║██║   ██║██╔════╝██║██║     ╚══███╔╝"
    echo -e "  ███╔╝ ██║██║   ██║██║     ██║██║       ███╔╝ "
    echo -e " ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║      ███╔╝  "
    echo -e "███████╗██║ ╚████╔╝ ╚██████╗██║███████╗███████╗"
    echo -e "╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝╚══════╝"
    echo -e "${NC}"

    # 2. INFO BOX (Presisi Tinggi dengan printf)
    echo -e "$TOP"
    printf "$V ${C_LABEL}%-6s${NC} : ${C_TEXT}%-16s${NC} ${C_BORDER}│${NC} ${C_LABEL}%-6s${NC} : ${C_TEXT}%-15s${NC} $V\n" "OS" "Ubuntu LTS" "IP" "$MYIP"
    printf "$V ${C_LABEL}%-6s${NC} : ${C_TEXT}%-16s${NC} ${C_BORDER}│${NC} ${C_LABEL}%-6s${NC} : ${C_TEXT}%-15s${NC} $V\n" "RAM" "$RAM_USED/$RAM_TOTAL MB" "ISP" "$ISP"
    printf "$V ${C_LABEL}%-6s${NC} : ${C_TEXT}%-16s${NC} ${C_BORDER}│${NC} ${C_LABEL}%-6s${NC} : ${C_TEXT}%-15s${NC} $V\n" "DATE" "$DATE" "DOMAIN" "$DOMAIN"
    echo -e "$MID"
    
    # Status Bar (Warna Logika Manual agar rapi)
    if [[ "$S_UDP" == "ON " ]]; then COL_UDP=$GREEN; else COL_UDP=$RED; fi
    if [[ "$S_CRON" == "ON " ]]; then COL_CRON=$GREEN; else COL_CRON=$RED; fi
    
    printf "$V      ${C_LABEL}%-10s${NC} ${COL_UDP}%-9s${NC} ${C_BORDER}│${NC}      ${C_LABEL}%-10s${NC} ${COL_CRON}%-9s${NC}     $V\n" "ZIVPN UDP:" "$S_UDP" "AUTO XP:" "$S_CRON"
    echo -e "$BOT"
}

# --- MAIN LOOP ---
while true; do
    header
    
    # 3. MENU BOX (Teks Putih, Nomor Kuning)
    echo -e "${PURPLE}┌─────────────────────${WHITE}[ MENU ]${PURPLE}───────────────────────┐${NC}"
    printf "${PURPLE}│${NC} ${YELLOW}[01]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC} ${YELLOW}[06]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC}\n" "Create User" "Change Domain"
    printf "${PURPLE}│${NC} ${YELLOW}[02]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC} ${YELLOW}[07]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC}\n" "Create Trial" "Force Delete Exp"
    printf "${PURPLE}│${NC} ${YELLOW}[03]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC} ${YELLOW}[08]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC}\n" "Renew User" "Backup Data"
    printf "${PURPLE}│${NC} ${YELLOW}[04]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC} ${YELLOW}[09]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC}\n" "Delete User" "Restore Backup"
    printf "${PURPLE}│${NC} ${YELLOW}[05]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC} ${YELLOW}[10]${NC} ${WHITE}%-18s${NC} ${PURPLE}│${NC}\n" "User List" "Restart Service"
    echo -e "${PURPLE}└────────────────────────────────────────────────────┘${NC}"
    
    # 4. EXIT BOX
    echo -e "${PURPLE}┌────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}               ${RED}[x] Exit / Keluar${NC}                    ${PURPLE}│${NC}"
    echo -e "${PURPLE}└────────────────────────────────────────────────────┘${NC}"
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
            if grep -q "^${renew_pass}:" $DB_FILE; then
                read -p " Add Days : " add_days
                current_exp=$(grep "^${renew_pass}:" $DB_FILE | cut -d: -f2)
                new_exp=$(date -d "@$current_exp + $add_days days" +%s)
                new_date=$(date -d "@$new_exp" +"%Y-%m-%d")
                
                grep -v "^${renew_pass}:" $DB_FILE > /tmp/db_tmp
                echo "${renew_pass}:${new_exp}" >> /tmp/db_tmp; mv /tmp/db_tmp $DB_FILE
                
                if [ -f "/usr/bin/zivbot" ]; then zivbot renew "$renew_pass" "$new_date" & fi
                show_receipt "$renew_pass" "$renew_pass" "$new_date (Renewed)"
            else
                echo -e "${RED}User not in DB!${NC}"
            fi
            ;;

        4|04)
            echo -e ""
            echo -e " ${YELLOW}➤ DELETE USER${NC}"
            
            # Interactive Selection Logic
            i=1
            usernames=()
            
            # Header Tabel Delete
            echo -e "${PURPLE}┌─────┬──────────────────────┐${NC}"
            echo -e "${PURPLE}│${NC} NO  ${PURPLE}│${NC} ${WHITE}USERNAME${NC}             ${PURPLE}│${NC}"
            echo -e "${PURPLE}├─────┼──────────────────────┤${NC}"
            
            while read -r user; do
                usernames+=("$user")
                printf "${PURPLE}│${NC} %-3s ${PURPLE}│${NC} ${WHITE}%-20s${NC} ${PURPLE}│${NC}\n" "$i" "$user"
                ((i++))
            done < <(jq -r '.auth.config[]' $CONFIG_FILE)
            
            echo -e "${PURPLE}└─────┴──────────────────────┘${NC}"
            
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
            echo -e "${PURPLE}┌─────────────────────┬──────────────────────────┐${NC}"
            echo -e "${PURPLE}│${NC} ${WHITE}USER${NC}                ${PURPLE}│${NC} ${WHITE}EXPIRED${NC}                  ${PURPLE}│${NC}"
            echo -e "${PURPLE}├─────────────────────┼──────────────────────────┤${NC}"
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
                # Warna teks isi tabel putih
                printf "${PURPLE}│${NC} ${WHITE}%-19s${NC} ${PURPLE}│${NC} ${WHITE}%-24s${NC} ${PURPLE}│${NC}\n" "$user" "$exp_str"
            done
            echo -e "${PURPLE}└─────────────────────┴──────────────────────────┘${NC}"
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
            echo -e "${YELLOW}Creating Backup...${NC}"
            if [ -f "/usr/bin/backup-zivpn" ]; then 
                /usr/bin/backup-zivpn
                echo -e "${GREEN}Backup sent to Telegram!${NC}"
            fi
            ;;

        9|09)
            echo -e ""
            echo -e " ${YELLOW}➤ RESTORE BACKUP${NC}"
            echo -e " ${WHITE}Paste Direct Link (ZIP format)${NC}"
            read -p " Link : " link_zip
            if [ -z "$link_zip" ]; then echo -e "${RED}Aborted.${NC}"; continue; fi
            mkdir -p /root/restore && cd /root/restore
            wget -q "$link_zip" -O backup.zip
            if [ -f "backup.zip" ]; then
                unzip -o backup.zip > /dev/null 2>&1
                if [ -d "backup" ]; then
                    cp backup/config.json /etc/zivpn/
                    cp backup/akun.db /etc/zivpn/
                    systemctl restart $SERVICE_NAME
                    echo -e "${GREEN}Restore Success!${NC}"
                else
                    echo -e "${RED}Invalid Backup ZIP.${NC}"
                fi
            else
                echo -e "${RED}Download Failed.${NC}"
            fi
            rm -rf /root/restore
            ;;

        10)
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}Service Restarted.${NC}"
            ;;

        x|X) clear; exit 0 ;;
        *) echo -e "${RED}Invalid Option!${NC}" ;;
    esac
    echo -e ""
    read -n 1 -s -r -p "Press Enter to return..."
done
