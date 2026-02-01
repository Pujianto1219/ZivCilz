#!/bin/bash
# Script Auto Update ZivPN
# Repo: https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main

# Warna
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
CYAN='\033[1;96m'
NC='\033[0m'

# URL Repo Utama
REPO="https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "      ${YELLOW}UPDATE SCRIPT ZIVPN LATEST${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e ""

# 1. Update Menu
echo -e " [1/3] Updating Menu..."
wget -q "${REPO}/menu.sh" -O /usr/bin/menu
chmod +x /usr/bin/menu
echo -e " ${GREEN}✔ Menu Updated${NC}"

# 2. Update Bot
echo -e " [2/3] Updating Bot Manager..."
wget -q "${REPO}/bot.sh" -O /usr/bin/zivbot
chmod +x /usr/bin/zivbot
echo -e " ${GREEN}✔ Bot Updated${NC}"

# 3. Update Script Update (Self Update)
echo -e " [3/3] Updating Updater..."
wget -q "${REPO}/update.sh" -O /usr/bin/zivpn-update
chmod +x /usr/bin/zivpn-update
echo -e " ${GREEN}✔ Updater Updated${NC}"

# Tambahan: Jika Anda memisahkan file XP dan Backup ke GitHub,
# Hilangkan tanda pagar (#) di bawah ini:
# wget -q "${REPO}/xp.sh" -O /usr/bin/xp-zivpn && chmod +x /usr/bin/xp-zivpn
# wget -q "${REPO}/backup.sh" -O /usr/bin/backup-zivpn && chmod +x /usr/bin/backup-zivpn

echo -e ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "    ${GREEN}UPDATE SELESAI / DONE SUCCESSFULLY${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
sleep 2
clear
menu
