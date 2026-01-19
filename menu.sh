#!/bin/bash
# Zivpn Management Menu (Integrated with XP & Backup)
# Repo: https://github.com/Pujianto1219/ZivCilz

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Konfigurasi
CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/akun.db"
SERVICE_NAME="zivpn.service"

# Cek Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Harus dijalankan sebagai root!${NC}" 
   exit 1
fi

# Pastikan DB ada
touch $DB_FILE

# Fungsi Header
header() {
    clear
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${WHITE}       ZIVPN UDP MANAGEMENT MENU       ${NC}"
    echo -e "${CYAN}=======================================${NC}"
    
    # Info Domain & IP
    DOMAIN=$(cat /etc/zivpn/domain 2>/dev/null || echo "Tidak ada domain")
    MYIP=$(wget -qO- ipinfo.io/ip || curl -s ifconfig.me)
    echo -e " Host/IP : ${YELLOW}$MYIP${NC}"
    echo -e " Domain  : ${YELLOW}$DOMAIN${NC}"
    
    # Cek Status Service
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e " Status  : ${GREEN}RUNNING${NC}"
    else
        echo -e " Status  : ${RED}STOPPED${NC}"
    fi
    echo -e "${CYAN}=======================================${NC}"
}

# Main Loop
while true; do
    header
    echo -e "[1] Create User (Buat Akun)"
    echo -e "[2] Delete User (Hapus Akun)"
    echo -e "[3] Renew User (Perpanjang Akun)"
    echo -e "[4] User List (Lihat Daftar User)"
    echo -e "[5] Manual Backup"
    echo -e "[6] Restart Service"
    echo -e "[x] Exit"
    echo -e ""
    read -p "Select Option: " opt

    case $opt in
        1)
            echo -e ""
            echo -e "${CYAN}--- CREATE USER ---${NC}"
            read -p "Username/Password : " new_pass
            if [ -z "$new_pass" ]; then echo -e "${RED}Tidak boleh kosong!${NC}"; sleep 1; continue; fi
            
            # Cek duplikat
            if grep -q "\"$new_pass\"" $CONFIG_FILE; then
                echo -e "${RED}User '$new_pass' sudah ada!${NC}"
                sleep 2
                continue
            fi

            read -p "Masa Aktif (Hari) : " masa_aktif
            if [[ ! $masa_aktif =~ ^[0-9]+$ ]]; then
                masa_aktif=30
                echo -e "${YELLOW}Input salah, default ke 30 hari.${NC}"
            fi

            # Hitung Expired
            exp_date=$(date -d "+${masa_aktif} days" +%s)
            exp_date_display=$(date -d "+${masa_aktif} days" +"%Y-%m-%d")

            # Backup Config
            cp $CONFIG_FILE $CONFIG_FILE.bak
            
            # Add ke JSON
            jq --arg pass "$new_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
            
            # Add ke Database (untuk Auto Delete)
            echo "${new_pass}:${exp_date}" >> $DB_FILE

            systemctl restart $SERVICE_NAME
            
            echo -e ""
            echo -e "${GREEN}Sukses! User berhasil dibuat.${NC}"
            echo -e "User/Pass : ${YELLOW}$new_pass${NC}"
            echo -e "Expired   : ${YELLOW}$exp_date_display${NC}"
            ;;
        
        2)
            echo -e ""
            echo -e "${CYAN}--- DELETE USER ---${NC}"
            # Tampilkan user dulu
            jq -r '.auth.config[]' $CONFIG_FILE
            echo -e ""
            read -p "Masukkan User yang akan DIHAPUS: " del_pass
            
            if jq -e --arg pass "$del_pass" '.auth.config | index($pass)' $CONFIG_FILE > /dev/null; then
                # Hapus dari JSON
                jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                # Hapus dari DB
                grep -v "^${del_pass}:" $DB_FILE > /tmp/db_tmp && mv /tmp/db_tmp $DB_FILE
                
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}User '$del_pass' berhasil dihapus.${NC}"
            else
                echo -e "${RED}User tidak ditemukan!${NC}"
            fi
            ;;

        3)
            echo -e ""
            echo -e "${CYAN}--- RENEW USER ---${NC}"
            read -p "Masukkan User: " renew_pass
            
            # Cek apakah user ada di DB
            if grep -q "^${renew_pass}:" $DB_FILE; then
                read -p "Tambah Masa Aktif (Hari): " add_days
                
                # Ambil expired lama
                current_exp=$(grep "^${renew_pass}:" $DB_FILE | cut -d: -f2)
                # Tambah hari
                new_exp=$(date -d "@$current_exp + $add_days days" +%s)
                new_date_display=$(date -d "@$new_exp" +"%Y-%m-%d")

                # Update DB
                grep -v "^${renew_pass}:" $DB_FILE > /tmp/db_tmp
                echo "${renew_pass}:${new_exp}" >> /tmp/db_tmp
                mv /tmp/db_tmp $DB_FILE
                
                echo -e "${GREEN}Sukses! Expired baru: $new_date_display${NC}"
            else
                echo -e "${RED}User tidak ditemukan di Database Expired!${NC}"
                echo -e "${YELLOW}Tips: Hapus user lalu buat ulang jika user lama tidak ada di DB.${NC}"
            fi
            ;;

        4)
            echo -e ""
            echo -e "${CYAN}--- USER LIST & EXPIRY ---${NC}"
            echo -e "User             | Expired Date"
            echo -e "-----------------------------------"
            
            # Loop config JSON
            for user in $(jq -r '.auth.config[]' $CONFIG_FILE); do
                # Ambil tanggal dari DB
                exp_timestamp=$(grep "^${user}:" $DB_FILE | cut -d: -f2)
                
                if [[ -n "$exp_timestamp" && "$exp_timestamp" =~ ^[0-9]+$ ]]; then
                    exp_date_str=$(date -d "@$exp_timestamp" +"%Y-%m-%d")
                else
                    exp_date_str="Unlimited/No-DB"
                fi
                printf "%-16s | %s\n" "$user" "$exp_date_str"
            done
            echo -e "-----------------------------------"
            ;;

        5)
            echo -e ""
            echo -e "${YELLOW}Running Backup Script...${NC}"
            if [ -f "/usr/bin/backup-zivpn" ]; then
                /usr/bin/backup-zivpn
                echo -e "${GREEN}Backup selesai! Cek folder /root.${NC}"
            else
                echo -e "${RED}Script backup tidak ditemukan!${NC}"
            fi
            ;;

        6)
            echo -e "${YELLOW}Restarting Zivpn Service...${NC}"
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
    read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
done
