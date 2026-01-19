#!/bin/bash
# Zivpn Management Menu (Ultimate Edition - Fixed Timezone)
# Repo: https://github.com/Pujianto1219/ZivCilz

# SET TIMEZONE ASIA/JAKARTA (WIB)
timedatectl set-timezone Asia/Jakarta

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
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

# Pastikan DB & Domain file ada
touch $DB_FILE
mkdir -p /etc/zivpn

# Fungsi Header Info
header() {
    clear
    # Banner ASCII ZIVCILZ
    echo -e "${CYAN}"
    echo -e "███████╗██╗██╗   ██╗ ██████╗██╗██╗     ███████╗"
    echo -e "╚══███╔╝██║██║   ██║██╔════╝██║██║     ╚══███╔╝"
    echo -e "  ███╔╝ ██║██║   ██║██║     ██║██║       ███╔╝ "
    echo -e " ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║      ███╔╝  "
    echo -e "███████╗██║ ╚████╔╝ ╚██████╗██║███████╗███████╗"
    echo -e "╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}====================================================${NC}"
    
    # System Info Calculation
    RAM_USED=$(free -m | grep Mem | awk '{print $3}')
    RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^[ \t]*//' | head -1 | awk '{print $1,$2,$3}')
    
    # Ambil Data IP & Region
    MYIP=$(curl -sS ipinfo.io/ip)
    ISP=$(curl -sS ipinfo.io/org)
    CITY=$(curl -sS ipinfo.io/city)
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "Belum diset")
    
    # Waktu Server
    TIME=$(date +"%H:%M:%S")
    DATE=$(date +"%d-%b-%Y")

    echo -e " OS      : $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/PRETTY_NAME//g' | sed 's/=//g' | sed 's/"//g')"
    echo -e " CPU     : $CPU_MODEL"
    echo -e " RAM     : ${GREEN}${RAM_USED}MB${NC} / ${GREEN}${RAM_TOTAL}MB${NC}"
    echo -e " ISP     : $ISP"
    echo -e " Location: $CITY (Asia/Jakarta)"
    echo -e " IP VPS  : $MYIP"
    echo -e " Domain  : ${GREEN}$DOMAIN${NC}"
    echo -e " Time    : $TIME WIB | $DATE"
    
    # Cek Status Service
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e " Status  : ${GREEN}● RUNNING${NC}"
    else
        echo -e " Status  : ${RED}● STOPPED${NC}"
    fi
    echo -e "${YELLOW}====================================================${NC}"
}

# Main Loop
while true; do
    header
    echo -e " [1]  Create User (Buat Akun Reguler)"
    echo -e " [2]  ${CYAN}Create Trial (Akun Menit/Jam)${NC}"
    echo -e " [3]  Delete User (Hapus Akun)"
    echo -e " [4]  Renew User (Perpanjang Akun)"
    echo -e " [5]  User List (Lihat Daftar User)"
    echo -e " [6]  ${CYAN}Change Domain (Ganti Domain)${NC}"
    echo -e " [7]  ${CYAN}Setup Bot Telegram (Backup Notif)${NC}"
    echo -e " [8]  Force Delete Expired (Manual XP)"
    echo -e " [9]  Manual Backup Data"
    echo -e " [10] Restart Service"
    echo -e " [x]  Exit"
    echo -e ""
    read -p " Select Option: " opt

    case $opt in
        1) # Create User
            echo -e ""
            echo -e "${CYAN}--- CREATE REGULAR USER ---${NC}"
            read -p "Username : " new_pass
            if [ -z "$new_pass" ]; then echo -e "${RED}Tidak boleh kosong!${NC}"; sleep 1; continue; fi
            
            if grep -q "\"$new_pass\"" $CONFIG_FILE; then
                echo -e "${RED}User '$new_pass' sudah ada!${NC}"; sleep 2; continue
            fi

            read -p "Masa Aktif (Hari) : " masa_aktif
            if [[ ! $masa_aktif =~ ^[0-9]+$ ]]; then masa_aktif=30; fi

            exp_date=$(date -d "+${masa_aktif} days" +%s)
            exp_date_display=$(date -d "+${masa_aktif} days" +"%Y-%m-%d")

            cp $CONFIG_FILE $CONFIG_FILE.bak
            jq --arg pass "$new_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
            echo "${new_pass}:${exp_date}" >> $DB_FILE
            systemctl restart $SERVICE_NAME
            
            echo -e "${GREEN}Sukses! User dibuat.${NC}"
            echo -e "User: $new_pass | Exp: $exp_date_display"
            ;;

        2) # Create Trial
            echo -e ""
            echo -e "${CYAN}--- CREATE TRIAL USER ---${NC}"
            read -p "Username Trial : " trial_user
            if [ -z "$trial_user" ]; then echo -e "${RED}Tidak boleh kosong!${NC}"; sleep 1; continue; fi
            
            if grep -q "\"$trial_user\"" $CONFIG_FILE; then
                echo -e "${RED}User '$trial_user' sudah ada!${NC}"; sleep 2; continue
            fi

            read -p "Durasi (Menit) : " trial_min
            if [[ ! $trial_min =~ ^[0-9]+$ ]]; then trial_min=30; echo "Default 30 menit."; fi

            # Hitung Detik
            exp_date=$(date -d "+${trial_min} minutes" +%s)
            exp_date_display=$(date -d "+${trial_min} minutes" +"%H:%M:%S")

            jq --arg pass "$trial_user" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
            echo "${trial_user}:${exp_date}" >> $DB_FILE
            systemctl restart $SERVICE_NAME
            
            echo -e "${GREEN}Trial Sukses!${NC}"
            echo -e "User: $trial_user | Valid: $trial_min Menit ($exp_date_display)"
            ;;
        
        3) # Delete User
            echo -e ""
            echo -e "${CYAN}--- DELETE USER ---${NC}"
            jq -r '.auth.config[]' $CONFIG_FILE
            echo -e ""
            read -p "User to Delete: " del_pass
            
            if jq -e --arg pass "$del_pass" '.auth.config | index($pass)' $CONFIG_FILE > /dev/null; then
                jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                grep -v "^${del_pass}:" $DB_FILE > /tmp/db_tmp && mv /tmp/db_tmp $DB_FILE
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}User '$del_pass' dihapus.${NC}"
            else
                echo -e "${RED}User tidak ditemukan!${NC}"
            fi
            ;;

        4) # Renew User
            echo -e ""
            echo -e "${CYAN}--- RENEW USER ---${NC}"
            read -p "User: " renew_pass
            if grep -q "^${renew_pass}:" $DB_FILE; then
                read -p "Tambah Hari: " add_days
                current_exp=$(grep "^${renew_pass}:" $DB_FILE | cut -d: -f2)
                new_exp=$(date -d "@$current_exp + $add_days days" +%s)
                new_date_display=$(date -d "@$new_exp" +"%Y-%m-%d")
                
                grep -v "^${renew_pass}:" $DB_FILE > /tmp/db_tmp
                echo "${renew_pass}:${new_exp}" >> /tmp/db_tmp
                mv /tmp/db_tmp $DB_FILE
                echo -e "${GREEN}Perpanjang Sukses! Exp baru: $new_date_display${NC}"
            else
                echo -e "${RED}User tidak ditemukan di Database!${NC}"
            fi
            ;;

        5) # User List
            echo -e ""
            echo -e "${CYAN}--- USER LIST ---${NC}"
            echo -e "User             | Status/Expired"
            echo -e "-----------------------------------"
            for user in $(jq -r '.auth.config[]' $CONFIG_FILE); do
                exp_timestamp=$(grep "^${user}:" $DB_FILE | cut -d: -f2)
                if [[ -n "$exp_timestamp" && "$exp_timestamp" =~ ^[0-9]+$ ]]; then
                    if [ "$exp_timestamp" -gt "$(date +%s)" ]; then
                         # Hitung sisa waktu
                         diff=$(($exp_timestamp - $(date +%s)))
                         if [ $diff -lt 86400 ]; then
                             # Kurang dari 24 jam (Tampil Jam)
                             exp_date_str=$(date -d "@$exp_timestamp" +"%H:%M (%d-%b)")
                         else
                             # Lebih dari 24 jam (Tampil Tanggal)
                             exp_date_str=$(date -d "@$exp_timestamp" +"%Y-%m-%d")
                         fi
                    else
                         exp_date_str="EXPIRED"
                    fi
                else
                    exp_date_str="Unlimited"
                fi
                printf "%-16s | %s\n" "$user" "$exp_date_str"
            done
            echo -e "-----------------------------------"
            ;;

        6) # Ganti Domain
            echo -e ""
            echo -e "${CYAN}--- CHANGE DOMAIN ---${NC}"
            echo -e "Domain Saat Ini: $(cat $DOMAIN_FILE 2>/dev/null)"
            read -p "Masukkan Domain Baru: " new_domain
            if [ -z "$new_domain" ]; then echo -e "${RED}Batal.${NC}"; continue; fi
            
            echo "$new_domain" > $DOMAIN_FILE
            
            # Regenerate SSL Self-Signed agar cocok dengan domain baru
            echo -e "${YELLOW}Updating SSL Certificate...${NC}"
            openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=ID/CN=$new_domain" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null
            
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}Domain berhasil diubah ke: $new_domain${NC}"
            ;;

        7) # Setup Bot Telegram
            echo -e ""
            echo -e "${CYAN}--- SETUP BOT TELEGRAM (Backup) ---${NC}"
            read -p "Bot Token : " bot_token
            read -p "Chat ID   : " chat_id
            
            if [[ -z "$bot_token" || -z "$chat_id" ]]; then
                echo -e "${RED}Data tidak lengkap.${NC}"
            else
                # Simpan Format token:chatid
                echo "${bot_token}:${chat_id}" > $BOT_FILE
                echo -e "${GREEN}Data Bot tersimpan!${NC}"
                echo -e "Coba jalankan Manual Backup untuk test."
            fi
            ;;

        8) # Manual XP
            echo -e ""
            echo -e "${YELLOW}Menjalankan Script Auto-Delete Expired...${NC}"
            if [ -f "/usr/bin/xp-zivpn" ]; then
                /usr/bin/xp-zivpn
                echo -e "${GREEN}Selesai check & delete expired user.${NC}"
            else
                echo -e "${RED}Script XP tidak ditemukan.${NC}"
            fi
            ;;

        9) # Backup
            echo -e ""
            echo -e "${YELLOW}Running Backup...${NC}"
            if [ -f "/usr/bin/backup-zivpn" ]; then
                /usr/bin/backup-zivpn
                echo -e "${GREEN}Backup Done.${NC}"
                # Cek jika bot diset, beri info
                if [ -f "$BOT_FILE" ]; then echo -e "Cek Telegram Anda jika konfigurasi bot benar."; fi
            else
                echo -e "${RED}Script backup tidak ditemukan.${NC}"
            fi
            ;;

        10) # Restart
            systemctl restart $SERVICE_NAME
            echo -e "${GREEN}Service Restarted.${NC}"
            ;;
            
        x|X)
            clear
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid!${NC}"
            ;;
    esac
    
    echo -e ""
    read -n 1 -s -r -p "Tekan Enter untuk kembali..."
done
