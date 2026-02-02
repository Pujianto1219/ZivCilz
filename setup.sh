#!/bin/bash
# Zivpn UDP Installer - Final (Anti-Cache & Auto-Check IP)
# Repo: https://github.com/Pujianto1219/ZivCilz

# 1. SET TIMEZONE
timedatectl set-timezone Asia/Jakarta

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# URL Database IP (Link Base)
# Kita tidak pasang ?v= di sini agar bisa dimodifikasi dinamis di bawah
REPO_IP="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"

# 2. Cek Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}" 
   exit 1
fi

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "    ZIVPN UDP INSTALLER (ANTI-CACHE MODE)    "
echo -e "${CYAN}=========================================${NC}"

# 3. IP Validation (Updated with Anti-Cache Headers)
echo -e "${YELLOW}[1/12] Validating IP Address...${NC}"
MYIP=$(curl -s ifconfig.me || wget -qO- ipinfo.io/ip)
echo -e "Your IP: ${GREEN}$MYIP${NC}"

# LOGIC BARU: Menggunakan Curl dengan Header No-Cache
# Teknik: Menambahkan ?v=waktu&r=acak agar GitHub dipaksa ambil file baru
CHECK_IP=$(curl -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" "${REPO_IP}?v=$(date +%s)&r=$RANDOM" | grep -w "$MYIP")

if [[ -n "$CHECK_IP" ]]; then
    echo -e "${GREEN}[SUCCESS] IP Verified!${NC}"
    sleep 1
else
    echo -e "${RED}[ERROR] IP $MYIP is not registered!${NC}"
    # rm -f "$0"
    exit 1
fi

# 4. Low-Spec Optimization
echo -e "${YELLOW}[2/12] Optimizing for Low-Spec VPS...${NC}"
RAM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
if [ "$RAM_TOTAL" -lt 2000 ]; then
    if [ $(swapon -s | wc -l) -lt 2 ]; then
        fallocate -l 1G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null 2>&1
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
fi

# 5. Install Dependencies
echo -e "${YELLOW}[3/12] Installing Dependencies...${NC}"
apt-get update -y
apt-get install wget openssl dnsutils iptables jq zip cron curl net-tools -y >/dev/null 2>&1

# 6. Domain Configuration
echo -e "${YELLOW}[4/12] Domain Configuration${NC}"
mkdir -p /etc/zivpn

# Cek apakah domain sudah ada (Mode Update)
if [ -f "/etc/zivpn/domain" ]; then
    OLD_DOMAIN=$(cat /etc/zivpn/domain)
    echo -e "Domain terdeteksi: ${GREEN}$OLD_DOMAIN${NC}"
    echo -e "Gunakan domain lama? (y/n)"
    read -p "Pilih: " keep_domain
    if [[ "$keep_domain" == "y" || "$keep_domain" == "Y" ]]; then
        domain_input=$OLD_DOMAIN
    else
        echo -e -n "Masukkan Domain Baru: "
        read domain_input
        echo "$domain_input" > /etc/zivpn/domain
    fi
else
    while true; do
        echo -e -n "Masukkan Domain: "
        read domain_input
        if [ -z "$domain_input" ]; then continue; fi
        echo "$domain_input" > /etc/zivpn/domain
        break
    done
fi

# 7. Setup Binary
echo -e "${YELLOW}[5/12] Updating Core Binary...${NC}"
systemctl stop zivpn.service >/dev/null 2>&1 || true

wget -q https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

# Generate SSL
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=ID/CN=$domain_input" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# 8. Kernel Tuning
echo -e "${YELLOW}[6/12] Tuning Network Kernel...${NC}"
if ! grep -q "net.core.rmem_max" /etc/sysctl.conf; then
cat <<EOF >> /etc/sysctl.conf
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=65535
EOF
sysctl -p >/dev/null 2>&1
fi

# 9. Config JSON (IPv4 FIXED)
echo -e "${YELLOW}[7/12] Checking Config...${NC}"
if [ ! -f "/etc/zivpn/config.json" ]; then
    RANDOM_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
cat <<EOF > /etc/zivpn/config.json
{
  "listen": "0.0.0.0:5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["$RANDOM_PASS"]
  }
}
EOF
fi
touch /etc/zivpn/akun.db

# 10. Service & Firewall
echo -e "${YELLOW}[8/12] Finalizing Service...${NC}"
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network-online.target

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

DEFAULT_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if [ -n "$DEFAULT_IFACE" ]; then
    iptables -t nat -D PREROUTING -i $DEFAULT_IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null
    iptables -t nat -A PREROUTING -i $DEFAULT_IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
fi

# 11. AUTOMATION SCRIPTS
echo -e "${YELLOW}[9/12] Installing Auto-Manage Scripts...${NC}"

# A. Script XP
cat <<'EOF' > /usr/bin/xp-zivpn
#!/bin/bash
CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/akun.db"
[ ! -f "$DB" ] && exit 0
NOW=$(date +%s)
RESTART=0
while read -r line; do
    U=$(echo $line | cut -d: -f1)
    E=$(echo $line | cut -d: -f2)
    [[ ! "$E" =~ ^[0-9]+$ ]] && continue
    if [ "$NOW" -ge "$E" ]; then
        jq --arg u "$U" '.auth.config -= [$u]' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        grep -v "^$U:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
        if [ -f "/usr/bin/zivbot" ]; then /usr/bin/zivbot expired "$U" & fi
        RESTART=1
    fi
done < "$DB"
[ "$RESTART" -eq 1 ] && systemctl restart zivpn.service
EOF
chmod +x /usr/bin/xp-zivpn

# B. Script Backup
cat <<'EOF' > /usr/bin/backup-zivpn
#!/bin/bash
DATE=$(date +"%Y-%m-%d-%H-%M")
DOMAIN=$(cat /etc/zivpn/domain 2>/dev/null || echo "vps")
BACKUP_DIR="/root/backup"
mkdir -p $BACKUP_DIR
cp /etc/zivpn/config.json $BACKUP_DIR/
cp /etc/zivpn/akun.db $BACKUP_DIR/
ZIP_FILE="${BACKUP_DIR}/backup-${DOMAIN}-${DATE}.zip"
cd $BACKUP_DIR
zip -r $ZIP_FILE . > /dev/null 2>&1
mv $ZIP_FILE /root/
if [ -f "/usr/bin/zivbot" ]; then /usr/bin/zivbot backup "/root/backup-${DOMAIN}-${DATE}.zip"; fi
rm -rf $BACKUP_DIR
rm -f "/root/backup-${DOMAIN}-${DATE}.zip"
EOF
chmod +x /usr/bin/backup-zivpn

# C. SCRIPT BARU: AUTO IP CHECKER (ANTI-DELAY VERSION)
# ==========================================
cat <<'EOF' > /usr/bin/zivpn-ipcheck
#!/bin/bash
# Auto IP Checker for Zivpn (Anti-Cache)
REPO_IP="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"
MYIP=$(curl -s ifconfig.me)
LOG_FILE="/var/log/zivpn-ipcheck.log"

# FETCH DATA DENGAN NO-CACHE HEADERS + RANDOM PARAMETER
# Ini memaksa GitHub memberikan file terbaru, melewati cache CDN
RAW_DATA=$(curl -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" "${REPO_IP}?v=$(date +%s)&r=$RANDOM" | grep "$MYIP")
TODAY=$(date +%Y-%m-%d)

if [[ -n "$RAW_DATA" ]]; then
    EXP_DATE=$(echo "$RAW_DATA" | awk '{print $3}')
    if [[ "$EXP_DATE" > "$TODAY" || "$EXP_DATE" == "$TODAY" ]]; then
        # IP VALID
        if ! systemctl is-active --quiet zivpn.service; then
            systemctl start zivpn.service
            echo "$(date): Service Restarted (IP Valid)" >> $LOG_FILE
        fi
    else
        # IP EXPIRED
        echo "$(date): IP Expired on $EXP_DATE. Stopping Service." >> $LOG_FILE
        systemctl stop zivpn.service
    fi
else
    # IP TIDAK TERDAFTAR
    echo "$(date): IP Not Registered ($MYIP). Stopping Service." >> $LOG_FILE
    systemctl stop zivpn.service
fi
EOF
chmod +x /usr/bin/zivpn-ipcheck
# ==========================================

# 12. SETUP CRONJOBS
echo -e "${YELLOW}[10/12] Registering Cronjobs...${NC}"
sed -i "/xp-zivpn/d" /etc/crontab
sed -i "/backup-zivpn/d" /etc/crontab
sed -i "/zivpn-ipcheck/d" /etc/crontab

# 1. Cek User Expired (Per Menit)
echo "* * * * * root /usr/bin/xp-zivpn" >> /etc/crontab
# 2. Cek Validitas IP VPS (Setiap 5 Menit agar lebih responsif)
echo "*/5 * * * * root /usr/bin/zivpn-ipcheck" >> /etc/crontab
# 3. Auto Backup (Jam 5 Pagi)
echo "0 5 * * * root /usr/bin/backup-zivpn" >> /etc/crontab

service cron restart

# 13. Download Scripts
echo -e "${YELLOW}[11/12] Downloading Menu & Bot...${NC}"
wget -q "https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/menu.sh" -O /usr/bin/menu
chmod +x /usr/bin/menu

wget -q "https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/bot.sh" -O /usr/bin/zivbot
chmod +x /usr/bin/zivbot

touch /root/.hushlogin
if ! grep -q "menu" /root/.bashrc; then
    echo "if [ -t 0 ]; then menu; fi" >> /root/.bashrc
fi

# Cleanup
rm -f zi.* 2>/dev/null
rm -f "$0" 

echo -e "${CYAN}=========================================${NC}"
echo -e "    UPDATE/INSTALL SELESAI (NO DELAY MODE) "
echo -e "${CYAN}=========================================${NC}"
echo -e " Domain      : $domain_input"
echo -e " IP Check    : Active (Real-time No Cache)"
echo -e "${CYAN}=========================================${NC}"
sleep 2
clear
menu
