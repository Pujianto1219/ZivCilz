#!/bin/bash
# Zivpn Management Menu (Premium 2-Column Layout)
# Repo: https://github.com/Pujianto1219/ZivCilz

# 1. SET TIMEZONE
timedatectl set-timezone Asia/Jakarta

# Warna & Format
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfigurasi
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

# Fungsi Banner
header() {
    clear
    echo -e "${CYAN}"
    echo -e "███████╗██╗██╗   ██╗ ██████╗██╗██╗     ███████╗"
    echo -e "╚══███╔╝██║██║   ██║██╔════╝██║██║     ╚══███╔╝"
    echo -e "  ███╔╝ ██║██║   ██║██║     ██║██║       ███╔╝ "
    echo -e " ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║      ███╔╝  "
    echo -e "███████╗██║ ╚████╔╝ ╚██████╗██║███████╗███████╗"
    echo -e "╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝╚══════╝"
    echo -e "${NC}"
    
    # System Info
    RAM_USED=$(free -m | grep Mem | awk '{print $3}')
    RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    MYIP=$(wget -qO- ipinfo.io/ip)
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "Belum diset")
    DATE=$(date +"%d-%b-%Y | %H:%M WIB")

    echo -e "${YELLOW}======================================================${NC}"
    echo -e " ${WHITE}OS${NC}   : Ubuntu 20.04/22.04 LTS   ${WHITE}IP${NC}     : $MYIP"
    echo -e " ${WHITE}RAM${NC}  : $RAM_USED / $RAM_TOTAL MB           ${WHITE}Domain${NC} : $DOMAIN"
    echo -e " ${WHITE}Time${NC} : $DATE       ${WHITE}Status${NC} : $(systemctl is-active --quiet zivpn && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
    echo -e "${YELLOW}======================================================${NC}"
}

# Main Loop
while true; do
    header
    # Menu 2 Kolom
    echo -e "${CYAN}[ USER MANAGEMENT ]${NC}                  ${CYAN}[ SYSTEM MENU ]${NC}"
    echo -e "${GREEN}[01]${NC} Create User                     ${GREEN}[06]${NC} Change Domain"
    echo -e "${GREEN}[02]${NC} Create Trial                    ${GREEN}[07]${NC} Setup Bot Notif"
    echo -e "${GREEN}[03]${NC} Delete User                     ${GREEN}[08]${NC} Force Delete Exp"
    echo -e "${GREEN}[04]${NC} Renew User                      ${GREEN}[09]${NC} Backup Data"
    echo -e "${GREEN}[05]${NC} User List                       ${GREEN}[10]${NC} Restore Backup"
    echo -e "                                      ${GREEN}[11]${NC} Restart Service"
    echo -e ""
    echo -e "                    ${RED}[x] Exit Menu${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    echo -e ""
    read -p " Select Option : " opt

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
            echo -e "${GREEN}Success! User: $new_pass | Exp: $exp_display${NC}"
            ;;

        2|02)
            echo -e "${CYAN}--- CREATE TRIAL USER ---${NC}"
            read -p "Username : " trial_user
            if [ -z "$trial_user" ]; then echo -e "${RED}Empty!${NC}"; sleep 1; continue; fi
            read -p "Minutes : " trial_min
            if [[ ! $trial_min =~ ^[0-9]+$ ]]; then trial_min=30; fi
            
            exp_date=$(date -d "+${trial_min} minutes" +%s)
            exp_display=$(date -d "+${trial_min} minutes" +"%H:%M:%S")
            
            jq --arg pass "$trial_user" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
            echo "${trial_user}:${exp_date}" >> $DB_FILE
            systemctl restart $SERVICE_NAME
            
            if [ -f "/usr/bin/zivbot" ]; then zivbot create "$trial_user" "$exp_display (Trial)" & fi
            echo -e "${GREEN}Trial Created! Valid: $trial_min Min${NC}"
            ;;

        3|03)
            echo -e "${CYAN}--- DELETE USER ---${NC}"
            read -p "Username : " del_pass
            if jq -e --arg pass "$del_pass" '.auth.config | index($pass)' $CONFIG_FILE > /dev/null; then
                jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                grep -v "^${del_pass}:" $DB_FILE > /tmp/db_tmp && mv /tmp/db_tmp $DB_FILE
                systemctl restart $SERVICE_NAME
                
                if [ -f "/usr/bin/zivbot" ]; then zivbot delete "$del_pass" & fi
                echo -e "${GREEN}User deleted.${NC}"
            else
                echo -e "${RED}Not found!${NC}"
            fi
            ;;

        4|04)
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
                echo -e "${GREEN}Renew Success! New Exp: $new_date${NC}"
            else
                echo -e "${RED}User not in DB!${NC}"
            fi
            ;;

        5|05)
            echo -e "${CYAN}--- USER LIST ---${NC}"
            echo -e "User             | Expired"
            echo -e "---------------------------------"
            for user in $(jq -r '.auth.config[]' $CONFIG_FILE); do
                exp_ts=$(grep "^${user}:" $DB_FILE | cut -d: -f2)
                if [[ -n "$exp_ts" && "$exp_ts" =~ ^[0-9]+$ ]]; then
                    if [ "$exp_ts" -gt "$(date +%s)" ]; then
                         diff=$(($exp_ts - $(date +%s)))
                         if [ $diff -lt 86400 ]; then exp_str=$(date -d "@$exp_ts" +"%H:%M"); else exp_str=$(date -d "@$exp_ts" +"%Y-%m-%d"); fi
                    else exp_str="${RED}EXPIRED${NC}"; fi
                else exp_str="Unlimited"; fi
                printf "%-16s | %s\n" "$user" "$exp_str"
            done
            echo -e "---------------------------------"
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
            if [ -f "/usr/bin/zivbot" ]; then zivbot setup; else echo -e "${RED}Bot Script Missing!${NC}"; fi
            ;;

        8|08)
            echo -e "${YELLOW}Checking Expired Users...${NC}"
            if [ -f "/usr/bin/xp-zivpn" ]; then /usr/bin/xp-zivpn; echo -e "${GREEN}Done.${NC}"; fi
            ;;

        9|09)
            echo -e "${CYAN}--- BACKUP DATA ---${NC}"
            echo -e "${YELLOW}Processing...${NC}"
            if [ -f "/usr/bin/backup-zivpn" ]; then 
                /usr/bin/backup-zivpn
                echo -e "${GREEN}Backup sent to Telegram!${NC}"
                echo -e "Silakan cek bot Anda, lalu Salin Link Download/File untuk Restore."
            fi
            ;;

        10)
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

        11)
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}Service Restarted.${NC}"
            ;;

        x|X) clear; exit 0 ;;
        *) echo -e "${RED}Invalid!${NC}" ;;
    esac
    echo -e ""
    read -n 1 -s -r -p "Press Enter to return..."
done
