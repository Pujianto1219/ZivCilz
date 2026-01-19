#!/bin/bash
# Zivpn Bot Manager (Placeholder / Under Development)
# Repo: https://github.com/Pujianto1219/ZivCilz

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Tampilan Banner Maintenance
clear
echo -e "${RED}"
echo -e " ██████╗ ███╗   ██╗    ██████╗ ███████╗██╗   ██╗"
echo -e "██╔═══██╗████╗  ██║    ██╔══██╗██╔════╝██║   ██║"
echo -e "██║   ██║██╔██╗ ██║    ██║  ██║█████╗  ██║   ██║"
echo -e "██║   ██║██║╚██╗██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝"
echo -e "╚██████╔╝██║ ╚████║    ██████╔╝███████╗ ╚████╔╝ "
echo -e " ╚═════╝ ╚═╝  ╚═══╝    ╚═════╝ ╚══════╝  ╚═══╝ "
echo -e "${NC}"

echo -e "${YELLOW}======================================================${NC}"
echo -e "        ${WHITE}FITUR BOT SEDANG DALAM PENGEMBANGAN${NC}"
echo -e "${YELLOW}======================================================${NC}"
echo -e ""
echo -e " ${CYAN}[INFO]${NC} Mohon maaf, fitur Notifikasi Telegram saat ini"
echo -e " sedang dinonaktifkan sementara untuk perbaikan sistem."
echo -e ""
echo -e " Fungsi yang terdampak:"
echo -e " 1. Setup Bot Token"
echo -e " 2. Notifikasi Create/Delete User"
echo -e " 3. Pengiriman File Backup ke Telegram"
echo -e ""
echo -e " ${GREEN}Silakan tunggu update versi berikutnya.${NC}"
echo -e ""
echo -e "${YELLOW}======================================================${NC}"

# Logic agar tidak langsung keluar jika dipanggil manual
# Jika dipanggil oleh sistem (create/delete/backup), dia hanya exit (silent)
# Jika dipanggil user (setup), dia minta enter

if [[ "$1" == "setup" || -z "$1" ]]; then
    echo -e ""
    read -n 1 -s -r -p "Tekan Enter untuk kembali ke Menu..."
fi
