#!/bin/bash
# Zivpn UDP Installer - Low Spec Optimized
# Features: IP Permission, Domain Validation, Auto Swap, Kernel Tuning

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# URL Database IP
PERMISSION_URL="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"

# 1. Cek Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}" 
   exit 1
fi

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "   ZIVPN UDP INSTALLER (LITE EDITION)    "
echo -e "${CYAN}=========================================${NC}"

# 2. IP Validation
echo -e "${YELLOW}[1/8] Validating IP Address...${NC}"
MYIP=$(wget -qO- ipinfo.io/ip || curl -s ifconfig.me)
echo -e "Your IP: ${GREEN}$MYIP${NC}"

if wget -qO- "$PERMISSION_URL" | grep -qw "$MYIP"; then
    echo -e "${GREEN}[SUCCESS] IP Verified!${NC}"
    sleep 1
else
    echo -e "${RED}[ERROR] IP $MYIP is not registered!${NC}"
    rm -- "$0" 2>/dev/null
    exit 1
fi

# 3. Low-Spec Optimization (Auto Swap)
echo -e "${YELLOW}[2/8] Optimizing for Low-Spec VPS...${NC}"
RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
if [ "$RAM_TOTAL" -lt 2000 ]; then
    echo -e "${CYAN}[info] RAM detected: ${RAM_TOTAL}MB. Checking Swap...${NC}"
    if [ $(swapon -s | wc -l) -lt 2 ]; then
        echo -e "${GREEN}[+] Creating 1GB Swap File...${NC}"
        fallocate -l 1G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null 2>&1
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}[+] Swap Created!${NC}"
    else
        echo -e "${CYAN}[info] Swap already exists.${NC}"
    fi
else
    echo -e "${CYAN}[info] RAM is sufficient (>2GB). Skipping Swap.${NC}"
fi

# 4. Install Dependencies (Ditambah JQ untuk Menu)
echo -e "${YELLOW}[3/8] Installing Dependencies...${NC}"
apt-get update -y
# Tambahan: paket 'jq' wajib diinstall untuk menu json
apt-get install wget openssl dnsutils iptables jq -y >/dev/null 2>&1

# 5. Domain Validation
echo -e "${YELLOW}[4/8] Domain Configuration${NC}"
echo -e "Pastikan domain diarahkan ke IP: ${GREEN}$MYIP${NC}"

while true; do
    echo -e -n "Masukkan Domain: "
    read domain_input
    
    if [ -z "$domain_input" ]; then
        echo -e "${RED}[!] Domain tidak boleh kosong.${NC}"
        continue
    fi

    DOMAIN_IP=$(dig +short "$domain_input" | grep -v '[a-z]' | head -1)

    if [ -z "$DOMAIN_IP" ]; then
        echo -e "${RED}[!] Domain tidak valid/belum propagasi.${NC}"
    elif [ "$DOMAIN_IP" == "$MYIP" ]; then
        echo -e "${GREEN}[OK] Domain Verified.${NC}"
        break
    else
        echo -e "${RED}[!] Domain mengarah ke $DOMAIN_IP (Bukan $MYIP)${NC}"
        echo -e "${YELLOW}[Tip] Matikan Cloudflare Proxy (Orange Cloud).${NC}"
    fi
done

# 6. Stop Old Service & Download Binary
echo -e "${YELLOW}[5/8] Downloading Resources...${NC}"
systemctl stop zivpn.service >/dev/null 2>&1
mkdir -p /etc/zivpn

wget -q https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

# Generate SSL
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=ID/CN=$domain_input" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# 7. Kernel Tuning
echo -e "${YELLOW}[6/8] Tuning Network Kernel...${NC}"
cat <<EOF >> /etc/sysctl.conf
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=65535
EOF
sysctl -p >/dev/null 2>&1

# 8. Input Password
echo -e "${YELLOW}[7/8] Password Setup${NC}"
while true; do
    echo -e -n "Masukkan password (cth: pass1,pass2): "
    read input_config
    if [ -n "$input_config" ]; then break; fi
done
formatted_passwords=$(echo "$input_config" | sed 's/,/","/g')

# Create Config
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

# 9. Create Service & Firewall
echo -e "${YELLOW}[8/8] Finalizing...${NC}"
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
LimitNOFILE=65535
Environment=ZIVPN_LOG_LEVEL=info

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

# Firewall
DEFAULT_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if [ -n "$DEFAULT_IFACE" ]; then
    iptables -t nat -A PREROUTING -i $DEFAULT_IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
fi

# --------------------------------------------------------
# DOWNLOAD MENU (Bagian Baru)
# Pastikan ganti URL di bawah ini dengan link raw 'menu.sh' Anda!
# --------------------------------------------------------
echo -e "${YELLOW}[+] Installing Menu...${NC}"
wget -q "https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/menu.sh" -O /usr/bin/menu
chmod +x /usr/bin/menu

# Clean up
rm zi.* 2>/dev/null
rm -- "$0" 2>/dev/null

echo -e "${CYAN}=========================================${NC}"
echo -e "      INSTALASI SELESAI (OPTIMIZED)      "
echo -e "${CYAN}=========================================${NC}"
echo -e " Domain    : $domain_input"
echo -e " Password  : $input_config"
echo -e " Port      : 5667 (UDP)"
echo -e " Command   : Ketik 'menu' untuk akses panel"
echo -e "${CYAN}=========================================${NC}"
