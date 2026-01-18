#!/bin/bash
# Script Auto Uninstall ZivCilz
# Membersihkan semua sisa instalasi ZivCilz/ZiVPN

# --- Warna ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Cek Root ---
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Jalankan script sebagai root!${NC}"
    exit 1
fi

clear
echo -e "${YELLOW}===================================================${NC}"
echo -e "${RED}          ZIVCILZ AUTO UNINSTALLER                ${NC}"
echo -e "${YELLOW}===================================================${NC}"
echo -e ""
echo -e "Script ini akan menghapus:"
echo -e " - Service UDP ZiVPN & Config"
echo -e " - Akun Database & Config JSON"
echo -e " - Sertifikat SSL & Config Nginx"
echo -e " - Script Menu & Auto Backup"
echo -e ""
read -p "Apakah Anda yakin ingin melanjutkan? (y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${YELLOW}Dibatalkan.${NC}"
    exit 0
fi

echo -e ""
echo -e "${BLUE}[1/5] Menghentikan Service...${NC}"
systemctl stop udp-zivpn
systemctl disable udp-zivpn
systemctl stop vnstat

# Hapus Service File
rm -f /etc/systemd/system/udp-zivpn.service
systemctl daemon-reload
systemctl reset-failed

echo -e "${BLUE}[2/5] Menghapus File Binary & Script...${NC}"
rm -f /usr/bin/udp-zivpn
rm -f /usr/bin/xp-zivpn
rm -f /usr/bin/backup-zivpn
rm -f /usr/bin/menu
rm -rf /root/ZivCilz
rm -rf /root/ZiVPN 
rm -f /root/setup.sh
rm -f /root/menu.sh

echo -e "${BLUE}[3/5] Membersihkan Konfigurasi & Database...${NC}"
rm -rf /etc/zivpn
rm -rf /etc/xray
rm -f /root/domain

# Hapus Config Nginx yang dibuat script
rm -f /etc/nginx/conf.d/zivpn.conf

# Hapus SSL acme.sh
rm -rf /root/.acme.sh

echo -e "${BLUE}[4/5] Membersihkan Cronjob...${NC}"
# Hapus baris cron yang mengandung kata kunci script kita
sed -i "/xp-zivpn/d" /etc/crontab
sed -i "/backup-zivpn/d" /etc/crontab
service cron restart

echo -e "${BLUE}[5/5] Finishing...${NC}"
# Restart Nginx agar bersih dari config lama
systemctl restart nginx
# Restart Vnstat (opsional, biarkan jalan default)
systemctl start vnstat

echo -e "${YELLOW}===================================================${NC}"
echo -e "${GREEN}      UNINSTALL SELESAI. VPS BERSIH.             ${NC}"
echo -e "${YELLOW}===================================================${NC}"
echo -e "Catatan: Dependencies (curl, git, zip, dll) tidak dihapus"
echo -e "agar tidak merusak fungsi dasar VPS Anda."
