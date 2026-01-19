#!/bin/bash
# Zivpn UDP Installer - Auto Cron & Menu
# Repo: https://github.com/Pujianto1219/ZivCilz

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
echo -e "   ZIVPN UDP INSTALLER (FULL FEATURES)   "
echo -e "${CYAN}=========================================${NC}"

# 2. IP Validation
echo -e "${YELLOW}[1/10] Validating IP Address...${NC}"
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
echo -e "${YELLOW}[2/10] Optimizing for Low-Spec VPS...${NC}"
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

# 4. Install Dependencies
echo -e "${YELLOW}[3/10] Installing Dependencies...${NC}"
apt-get update -y
# Install Cron, Zip, JQ, dll
apt-get install wget openssl dnsutils iptables jq zip cron -y >/dev/null 2>&1

# 5. Domain Validation
echo -e "${YELLOW}[4/10] Domain Configuration${NC}"
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
        # Simpan domain untuk keperluan menu/backup nanti
        echo "$domain_input" > /etc/xray/domain 2>/dev/null # Opsional jika ada script lain butuh
        break
    else
        echo -e "${RED}[!] Domain mengarah ke $DOMAIN_IP (Bukan $MYIP)${NC}"
        echo -e "${YELLOW}[Tip] Matikan Cloudflare Proxy (Orange Cloud).${NC}"
    fi
done

# 6. Setup Binary
echo -e "${YELLOW}[5/10] Downloading Resources...${NC}"
systemctl stop zivpn.service >/dev/null 2>&1
mkdir -p /etc/zivpn

wget -q https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

# Generate SSL
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=ID/CN=$domain_input" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# 7. Kernel Tuning
echo -e "${YELLOW}[6/10] Tuning Network Kernel...${NC}"
cat <<EOF >> /etc/sysctl.conf
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=65535
EOF
sysctl -p >/dev/null 2>&1

# 8. AUTO PASSWORD
echo -e "${YELLOW}[7/10] Generating Config...${NC}"
RANDOM_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)

cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["$RANDOM_PASS"]
  }
}
EOF
# Buat file database kosong untuk menampung data user & expiry
touch /etc/zivpn/akun.db

# 9. Create Service & Firewall
echo -e "${YELLOW}[8/10] Finalizing Service...${NC}"
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

# 10. SETUP CRON, XP, BACKUP & MENU
echo -e "${YELLOW}[9/10] Setting up Auto-Manage Scripts...${NC}"

# A. Script XP (Auto Delete)
cat <<'EOF' > /usr/bin/xp-zivpn
#!/bin/bash
# Script Auto Delete User Expired
CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/akun.db"
[ ! -f "$DB" ] && exit 0
NOW=$(date +%s)
RESTART=0
while read -r line; do
    # Format DB: user:timestamp
    U=$(echo $line | cut -d: -f1)
    E=$(echo $line | cut -d: -f2)
    [[ ! "$E" =~ ^[0-9]+$ ]] && continue
    if [ "$NOW" -ge "$E" ]; then
        echo "User $U expired. Deleting..."
        # Hapus dari Config JSON
        jq --arg u "$U" '.auth.config -= [$u]' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        # Hapus dari Database
        grep -v "^$U:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
        RESTART=1
    fi
done < "$DB"
[ "$RESTART" -eq 1 ] && systemctl restart zivpn.service
EOF
chmod +x /usr/bin/xp-zivpn

# B. Script Backup
cat <<'EOF' > /usr/bin/backup-zivpn
#!/bin/bash
# Script Auto Backup Data
DATE=$(date +"%Y-%m-%d")
mkdir -p /root/backup
# Copy Config & DB
cp /etc/zivpn/config.json /root/backup/
cp /etc/zivpn/akun.db /root/backup/
cd /root/
# Zip File
zip -r backup-zivpn-$DATE.zip backup > /dev/null 2>&1
rm -rf /root/backup
echo "Backup Selesai: /root/backup-zivpn-$DATE.zip"
EOF
chmod +x /usr/bin/backup-zivpn

# C. Pasang Cronjob
# Hapus cron lama (jika ada) untuk menghindari duplikat
sed -i "/xp-zivpn/d" /etc/crontab
sed -i "/backup-zivpn/d" /etc/crontab
# Tambah Cron baru
# xp-zivpn jalan setiap jam 12 malam (00:00)
echo "0 0 * * * root /usr/bin/xp-zivpn" >> /etc/crontab
# backup-zivpn jalan setiap jam 5 pagi (05:00)
echo "0 5 * * * root /usr/bin/backup-zivpn" >> /etc/crontab
service cron restart

# D. Download Menu Permanen
echo -e "${YELLOW}[+] Installing Menu...${NC}"
wget -q "https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/menu.sh" -O /usr/bin/menu
chmod +x /usr/bin/menu

# Clean up
rm zi.* 2>/dev/null
rm -- "$0" 2>/dev/null

echo -e "${CYAN}=========================================${NC}"
echo -e "      INSTALASI SELESAI (OPTIMIZED)      "
echo -e "${CYAN}=========================================${NC}"
echo -e " Domain     : $domain_input"
echo -e " Auto Pass  : $RANDOM_PASS"
echo -e " Port       : 5667 (UDP)"
echo -e " Cron XP    : 00:00 (Auto Delete)"
echo -e " Cron Backup: 05:00 (Auto Backup)"
echo -e "${CYAN}=========================================${NC}"
echo -e " Membuka Menu dalam 3 detik..."
sleep 3
clear
menu
