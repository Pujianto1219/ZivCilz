#!/bin/bash
# Zivpn UDP Module Installer
# Optimized & Fixed by Gemini
# Original Creator: Zahid Islam

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cek apakah user adalah root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}" 
   exit 1
fi

clear
echo -e "${YELLOW}=========================================${NC}"
echo -e "      Zivpn UDP Auto Installer           "
echo -e "${YELLOW}=========================================${NC}"

echo -e "${GREEN}[+] Updating server repositories...${NC}"
apt-get update && apt-get upgrade -y
apt-get install wget openssl -y 1> /dev/null 2> /dev/null

echo -e "${GREEN}[+] Stopping existing services...${NC}"
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "${GREEN}[+] Downloading UDP Binary...${NC}"
# Download Binary
wget https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn

# Buat direktori config
mkdir -p /etc/zivpn

echo -e "${GREEN}[+] Generating SSL Certificate...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Zivpn/OU=IT/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2> /dev/null

# Tuning Network Kernel
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# Konfigurasi Password
echo -e "${YELLOW}=========================================${NC}"
echo -e "ZIVPN UDP Password Configuration"
echo -e "${YELLOW}=========================================${NC}"
read -p "Masukkan password (pisahkan dengan koma, cth: pass1,pass2). Tekan Enter untuk default 'zi': " input_config

# Set default jika kosong
if [ -z "$input_config" ]; then
    input_config="zi"
fi

# Format password untuk JSON (mengubah koma menjadi kutip-koma-kutip)
# Contoh input: pass1,pass2 -> Output: "pass1","pass2"
formatted_passwords=$(echo "$input_config" | sed 's/,/","/g')

echo -e "${GREEN}[+] Creating Configuration File...${NC}"
# Membuat file config.json secara langsung
cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["$formatted_passwords"]
  }
}
EOF

echo -e "${GREEN}[+] Creating Systemd Service...${NC}"
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}[+] Enabling and Starting Service...${NC}"
systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

echo -e "${GREEN}[+] Applying Firewall Rules...${NC}"
# Mendapatkan interface default secara otomatis
DEFAULT_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

if [ -z "$DEFAULT_IFACE" ]; then
    echo -e "${RED}[!] Warning: Could not detect default interface for iptables.${NC}"
else
    iptables -t nat -A PREROUTING -i $DEFAULT_IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
fi

# UFW rules
if command -v ufw > /dev/null; then
    ufw allow 6000:19999/udp > /dev/null
    ufw allow 5667/udp > /dev/null
fi

# Bersih-bersih file temporary
rm zi.* 1> /dev/null 2> /dev/null

echo -e "${YELLOW}=========================================${NC}"
echo -e "   ZIVPN UDP Installed Successfully!   "
echo -e "${YELLOW}=========================================${NC}"
echo -e " Config File : /etc/zivpn/config.json"
echo -e " Passwords   : [ \"$formatted_passwords\" ]"
echo -e " Port        : 5667 (Redirected from 6000-19999)"
echo -e "${YELLOW}=========================================${NC}"
