#!/bin/bash
# Zivpn Management Menu
# Created by Gemini for Pujianto1219

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Konfigurasi
CONFIG_FILE="/etc/zivpn/config.json"
SERVICE_NAME="zivpn.service"

# Cek Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Harus dijalankan sebagai root!${NC}" 
   exit 1
fi

# Fungsi Header
header() {
    clear
    echo -e "${CYAN}=======================================${NC}"
    echo -e "       ZIVPN UDP MANAGEMENT MENU       "
    echo -e "${CYAN}=======================================${NC}"
    # Cek Status Service
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "Status Service: ${GREEN}RUNNING${NC}"
    else
        echo -e "Status Service: ${RED}STOPPED${NC}"
    fi
    echo -e "${CYAN}=======================================${NC}"
}

# Main Loop
while true; do
    header
    echo -e "[1] Add User (Tambah Password)"
    echo -e "[2] Delete User (Hapus Password)"
    echo -e "[3] Show User List (Lihat User)"
    echo -e "[4] Restart Service"
    echo -e "[x] Exit"
    echo -e ""
    read -p "Select Option: " opt

    case $opt in
        1)
            echo -e ""
            read -p "Masukkan Password Baru: " new_pass
            if [ -z "$new_pass" ]; then echo -e "${RED}Password tidak boleh kosong!${NC}"; sleep 1; continue; fi
            
            # Cek apakah password sudah ada
            if grep -q "\"$new_pass\"" $CONFIG_FILE; then
                echo -e "${RED}User '$new_pass' sudah ada!${NC}"
            else
                # Backup dulu
                cp $CONFIG_FILE $CONFIG_FILE.bak
                # Tambah user via JQ
                jq --arg pass "$new_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}Sukses! User '$new_pass' berhasil ditambahkan.${NC}"
            fi
            ;;
        2)
            echo -e ""
            echo -e "${YELLOW}Daftar User Saat Ini:${NC}"
            jq -r '.auth.config[]' $CONFIG_FILE
            echo -e ""
            read -p "Ketik Password yang akan DIHAPUS: " del_pass
            
            # Cek keberadaan user
            if jq -e --arg pass "$del_pass" '.auth.config | index($pass)' $CONFIG_FILE > /dev/null; then
                jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/zivpn_tmp.json && mv /tmp/zivpn_tmp.json $CONFIG_FILE
                systemctl restart $SERVICE_NAME
                echo -e "${GREEN}Sukses! User '$del_pass' telah dihapus.${NC}"
            else
                echo -e "${RED}User tidak ditemukan!${NC}"
            fi
            ;;
        3)
            echo -e ""
            echo -e "${CYAN}--- Registered Users ---${NC}"
            jq -r '.auth.config[]' $CONFIG_FILE
            echo -e "${CYAN}------------------------${NC}"
            ;;
        4)
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
