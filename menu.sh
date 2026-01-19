#!/bin/bash
# Zivpn Management Menu (Neon Premium Theme & Fixed Logic)
# Repo: https://github.com/Pujianto1219/ZivCilz

# 1. SET TIMEZONE
timedatectl set-timezone Asia/Jakarta

# --- WARNA NEON PREMIUM ---
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
PURPLE='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
NC='\e[0m'

# Konfigurasi
CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/akun.db"
DOMAIN_FILE="/etc/zivpn/domain"
SERVICE_NAME="zivpn.service"

# Cek Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Harus dijalankan sebagai root!${NC}" 
   exit 1
fi

touch $DB_FILE
mkdir -p /etc/zivpn

# --- FUNGSI STATUS (FIXED ERROR DISPLAY) ---
get_status() {
    # Memisahkan Warna dan Teks agar printf tidak error menghitung lebar
    if systemctl is-active --quiet zivpn; then 
        S_UDP="ON "
        C_UDP=$GREEN
    else 
        S_UDP="OFF"
        C_UDP=$RED
    fi

    if systemctl is-active --quiet cron; then 
        S_CRON="ON "
        C_CRON=$GREEN
    else 
        S_CRON="OFF"
        C_CRON=$RED
    fi
}

# --- FUNGSI OUTPUT STRUK ---
show_receipt() {
    local user=$1
    local pass=$2
    local exp=$3
    
    # Ambil Info Detail (Silent)
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

# --- HEADER BANNER ---
header() {
    clear
    get_status
    
    # System Info
    RAM_USED=$(free -m | grep Mem | awk '{print $3}')
    RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    MYIP=$(wget -qO- ipinfo.io/ip)
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "Belum diset")
    DATE=$(date +"%d %b %Y")
    
    # ISP Shortener
    ISP=$(wget -qO- ipinfo.io/org | cut -d " " -f 2-10 | cut -c 1-20) 
    
    # Layout Garis Neon
    B_TOP="${PURPLE}┌────────────────────────────────────────────────────┐${NC}"
    B_MID="${PURPLE}├────────────────────────────────────────────────────┤${NC}"
    B_BOT="${PURPLE}└────────────────────────────────────────────────────┘${NC}"
    V="${PURPLE}│${NC}"

    # 1. BIG BANNER ZIVCILZ (Blue Style)
    echo -e "${BLUE}"
    echo -e "███████╗██╗██╗   ██╗ ██████╗██╗██╗     ███████╗"
    echo -e "╚══███╔╝██║██║   ██║██╔════╝██║██║     ╚══███╔╝"
    echo -e "  ███╔╝ ██║██║   ██║██║     ██║██║       ███╔╝ "
    echo -e " ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║      ███╔╝  "
    echo -e "███████╗██║ ╚████╔╝ ╚██████╗██║███████╗███████╗"
    echo -e "╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝╚══════╝"
    echo -e "${NC}"

    # 2. INFO BOX
    echo -e "$B_TOP"
    printf "$V ${WHITE}%-6s${NC} : %-16s ${PURPLE}│${NC} ${WHITE}%-6s${NC} : %-15s$V\n" "OS" "Ubuntu 20.04" "IP" "$MYIP"
    printf "$V ${WHITE}%-6s${NC} : %-16s ${PURPLE}│${NC} ${WHITE}%-6s${NC} : %-15s$V\n" "RAM" "$RAM_USED/$RAM_TOTAL MB" "ISP" "$ISP"
    printf "$V ${WHITE}%-6s${NC} : %-16s ${PURPLE}│${NC} ${WHITE}%-6s${NC} : %-15s$V\n" "DATE" "$DATE" "DOMAIN" "$DOMAIN"
    echo -e "$B_MID"
    # Status bar fix (Warna variable terpisah)
    printf "$V      ${CYAN}%-10s${NC} ${C_UDP}%-9s${NC} ${PURPLE}│${NC}      ${CYAN}%-10s${NC} ${C_CRON}%-9s${NC}     $V\n" "ZIVPN UDP:" "$S_UDP" "AUTO XP:" "$S_CRON"
    echo -e "$B_BOT"
}

# --- MAIN LOOP ---
while true; do
    header
    
    # 3. MENU BOX (Layout Rapi 2 Kolom)
    echo -e "${PURPLE}┌─────────────────────${WHITE}[ MENU ]${PURPLE}───────────────────────┐${NC}"
    printf "${PURPLE}│${NC} ${YELLOW}[01]${NC} %-18s ${PURPLE}│${NC} ${YELLOW}[06]${NC} %-18s ${PURPLE}│${NC}\n" "Create User" "Change Domain"
    printf "${PURPLE}│${NC} ${YELLOW}[02]${NC} %-18s ${PURPLE}│${NC} ${YELLOW}[07]${NC} %-18s ${PURPLE}│${NC}\n" "Create Trial" "Force Delete Exp"
    printf "${PURPLE}│${NC} ${YELLOW}[03]${NC} %-18s ${PURPLE}│${NC} ${YELLOW}[08]${NC} %-18s ${PURPLE}│${NC}\n" "Renew User" "Backup Data"
    printf "${PURPLE}│${NC} ${YELLOW}[04]${NC} %-18s ${PURPLE}│${NC} ${YELLOW}[09]${NC} %-18s ${PURPLE}│${NC}\n" "Delete User" "Restore Backup"
    printf "${PURPLE}│${NC} ${YELLOW}[05]${NC} %-18s ${PURPLE}│${NC} ${YELLOW}[10]${NC} %-18s ${PURPLE}│${NC}\n" "User List" "Restart Service"
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
            echo -e "${CYAN}--- CREATE REGULAR USER ---${NC}"
            read -p "Username : " new_pass
            if [ -z "$new_pass" ]; then echo -e "${RED}Empty!${NC}"; sleep 1; continue; fi
            if grep -q "\"$new_pass\"" $CONFIG_FILE; then echo -e "${RED}Exists!${NC}"; sleep 1; continue; fi
            read -p "Active Days : " masa_aktif
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
            echo -e "${CYAN}--- CREATE TRIAL USER ---${NC}"
            read -p "Username : " trial_user
            if [ -z "$trial_user" ]; then echo -e "${RED}Empty!${NC}"; sleep 1; continue; fi
            read -p "Minutes : " trial_min
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
            echo -e "${CYAN}--- RENEW USER ---${NC}"
            read -p "Username : " renew_pass
            if grep -q "^${renew_pass}:" $DB_FILE; then
                read -p "Add Days : " add_days
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
            echo -e "${CYAN}--- DELETE USER ---${NC}"
            # LIST USER INTERAKTIF
            i=1
            usernames=()
            echo -e "${PURPLE}┌─────┬──────────────────────┐${NC}"
            echo -e "${PURPLE}│${NC} NO  ${PURPLE}│${NC} USERNAME             ${PURPLE}│${NC}"
            echo -e "${PURPLE}├─────┼──────────────────────┤${NC}"
            while read -r user; do
                usernames+=("$user")
                printf "${PURPLE}│${NC} %-3s ${PURPLE}│${NC} %-20s ${PURPLE}│${NC}\n" "$i" "$user"
                ((i++))
            done < <(jq -r '.auth.config[]' $CONFIG_FILE)
            echo -e "${PURPLE}└─────┴──────────────────────┘${NC}"
            
            if [ ${#usernames[@]} -eq 0 ]; then
                echo -e "${RED}No users found.${NC}"
            else
                echo -e ""
                read -p " Select Number (1-${#usernames[@]}): " sel
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#usernames[@]}" ]; then
                    del_pass="${usernames[$((sel-1))]}"
                    
                    jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                    grep -v "^${del_pass}:" $DB_FILE > /tmp/db_tmp && mv /tmp/db_tmp $DB_FILE
                    systemctl restart $SERVICE_NAME
                    
                    if [ -f "/usr/bin/zivbot" ]; then zivbot delete "$del_pass" & fi
                    echo -e "${GREEN}User '$del_pass' Deleted.${NC}"
                else
                    echo -e "${RED}Invalid Selection!${NC}"
                fi
            fi
            ;;

        5|05)
            echo -e "${CYAN}--- USER LIST ---${NC}"
            echo -e "${PURPLE}┌─────────────────────┬──────────────────────────┐${NC}"
            echo -e "${PURPLE}│${NC} USER                ${PURPLE}│${NC} EXPIRED                  ${PURPLE}│${NC}"
            echo -e "${PURPLE}├─────────────────────┼──────────────────────────┤${NC}"
            for user in $(jq -r '.auth.config[]' $CONFIG_FILE); do
                exp_ts=$(grep "^${user}:" $DB_FILE | cut -d: -f2)
                if [[ -n "$exp_ts" && "$exp_ts" =~ ^[0-9]+$ ]]; then
                    if [ "$exp_ts" -gt "$(date +%s)" ]; then
                         diff=$(($exp_ts - $(date +%s)))
                         if [ $diff -lt 86400 ]; then exp_str=$(date -d "@$exp_ts" +"%H:%M (%d-%b)"); else exp_str=$(date -d "@$exp_ts" +"%Y-%m-%d"); fi
                    else exp_str="${RED}EXPIRED${NC}"; fi
                else exp_str="Unlimited"; fi
                printf "${PURPLE}│${NC} %-19s ${PURPLE}│${NC} %-24s ${PURPLE}│${NC}\n" "$user" "$exp_str"
            done
            echo -e "${PURPLE}└─────────────────────┴──────────────────────────┘${NC}"
            ;;

        6|06)
            echo -e "${CYAN}--- CHANGE DOMAIN ---${NC}"
            read -p "New Domain : " new_domain
            if [ -n "$new_domain" ]; then
                echo "$new_domain" > $DOMAIN_FILE
                openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=ID/CN=$new_domain" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}Domain Updated!${NC}"
            fi
            ;;

        7|07)
            echo -e "${YELLOW}Checking Expired Users...${NC}"
            if [ -f "/usr/bin/xp-zivpn" ]; then /usr/bin/xp-zivpn; echo -e "${GREEN}Done.${NC}"; fi
            ;;

        8|08)
            echo -e "${CYAN}--- BACKUP DATA ---${NC}"
            echo -e "${YELLOW}Processing...${NC}"
            if [ -f "/usr/bin/backup-zivpn" ]; then 
                /usr/bin/backup-zivpn
                echo -e "${GREEN}Backup sent to Telegram!${NC}"
                echo -e "Silakan cek bot Anda, lalu Salin Link Download/File untuk Restore."
            fi
            ;;

        9|09)
            echo -e "${CYAN}--- RESTORE BACKUP ---${NC}"
            echo -e "${YELLOW}Pastikan link berbentuk DIRECT LINK (Raw/Zip) dari Telegram/Cloud.${NC}"
            read -p "Link ZIP : " link_zip
            if [ -z "$link_zip" ]; then echo -e "${RED}Aborted.${NC}"; continue; fi
            
            mkdir -p /root/restore
            cd /root/restore
            echo -e "Downloading..."
            wget -q "$link_zip" -O backup.zip
            if [ -f "backup.zip" ]; then
                unzip -o backup.zip > /dev/null 2>&1
                if [ -d "backup" ]; then
                    cp backup/config.json /etc/zivpn/
                    cp backup/akun.db /etc/zivpn/
                    systemctl restart $SERVICE_NAME
                    echo -e "${GREEN}Restore Berhasil!${NC}"
                else
                    echo -e "${RED}Isi ZIP tidak valid (Folder 'backup' tidak ditemukan).${NC}"
                fi
            else
                echo -e "${RED}Download Gagal! Cek Link Anda.${NC}"
            fi
            rm -rf /root/restore
            ;;

        10)
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}Service Restarted.${NC}"
            ;;

        x|X) clear; exit 0 ;;
        *) echo -e "${RED}Invalid!${NC}" ;;
    esac
    echo -e ""
    read -n 1 -s -r -p "Press Enter to return..."
done
