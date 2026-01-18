#!/bin/bash
# Script Auto Installer ZivCilz (Updated Repo)
# Repo: https://github.com/Pujianto1219/ZivCilz

# --- Warna ---
green='\e[32m'
red='\e[31m'
yellow='\e[33m'
blue='\e[34m'
nc='\e[0m'

if [ "${EUID}" -ne 0 ]; then
    echo -e "${red}Jalankan script sebagai root!${nc}"
    exit 1
fi

clear
echo -e "${yellow}===================================================${nc}"
echo -e "${green}      AUTOSCRIPT ZIVCILZ (NEW REPO)              ${nc}"
echo -e "${yellow}===================================================${nc}"

# 1. CEK IP & DEPENDENCIES
# ... (bagian atas script) ...

echo -e "${blue}[CHECK] Verifikasi IP Address...${nc}"
MYIP=$(curl -sS ipv4.icanhazip.com)
[ -z "$MYIP" ] && MYIP=$(curl -sS ifconfig.me)

echo -e "IP VPS Anda: $MYIP"

IP_DB="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"

# MENGGUNAKAN tr -d '\r' UNTUK MEMBERSIHKAN FORMAT WINDOWS
if wget -qO- "$IP_DB" | tr -d '\r' | grep -w "$MYIP" > /dev/null; then
    echo -e "${green}✅ IP Terdaftar!${nc}"
else
    echo -e "${red}❌ IP TIDAK TERDAFTAR!${nc}"
    echo -e "Cek kembali file 'ip' di GitHub Anda."
    echo -e "Pastikan IP $MYIP ada di sana tanpa spasi tambahan."
    exit 1
fi

# Install Dependencies
apt-get update
apt-get install -y --no-install-recommends wget curl git zip unzip tar net-tools systemd dnsutils vnstat nginx socat cron gnupg2 ca-certificates lsb-release jq

# 2. OPTIMASI VPS
echo -e "${blue}[INFO] Optimasi VPS...${nc}"
# Swap
GET_RAM=$(free -m | grep Mem | awk '{print $2}')
if [ "$GET_RAM" -le 2000 ] && [ ! -f /swapfile ]; then
    dd if=/dev/zero of=/swapfile bs=1024 count=1048576
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi
# BBR
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 3. INPUT DOMAIN
echo -e "${yellow}===================================================${nc}"
echo -e "Masukkan Domain (Pastikan A Record ke: ${green}$MYIP${nc})"
echo ""
while true; do
    read -p "Domain: " domain
    [ -z "$domain" ] && continue
    DOMAIN_IP=$(dig +short "$domain" | head -n 1)
    if [[ "$DOMAIN_IP" == "$MYIP" ]]; then
        echo -e "${green}✅ Domain Valid!${nc}"
        echo "$domain" > /root/domain
        mkdir -p /etc/xray
        echo "$domain" > /etc/xray/domain
        break
    else
        echo -e "${red}❌ IP Domain ($DOMAIN_IP) != IP VPS ($MYIP)${nc}"
        read -p "Tekan Enter untuk ulang atau CTRL+C batal..."
    fi
done

# 4. SSL SETUP
echo -e "${blue}[INFO] Setup SSL...${nc}"
systemctl stop nginx
mkdir -p /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force
/root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# 5. NGINX CONFIG
cat > /etc/nginx/conf.d/zivpn.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domain};
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:ZiVPN:10m;
    ssl_session_tickets off;
    root /var/www/html;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
systemctl restart nginx

# 6. UDP CORE INSTALL (FROM REPO ZIVCILZ)
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    # URL UPDATE KE ZIVCILZ
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/1.0/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    # URL UPDATE KE ZIVCILZ
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/1.0/udp-zivpn-linux-arm64"
else
    echo -e "${red}CPU Not Supported${nc}"; exit 1
fi

wget -O /usr/bin/udp-zivpn "$URL_CORE"
chmod +x /usr/bin/udp-zivpn

# FIX SERVICE: Menambahkan WorkingDirectory agar config terbaca
cat > /etc/systemd/system/udp-zivpn.service <<EOF
[Unit]
Description=UDP ZivCilz Core
After=network.target

[Service]
User=root
Type=simple
WorkingDirectory=/etc/zivpn
ExecStart=/usr/bin/udp-zivpn
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-zivpn
systemctl start udp-zivpn

# 7. FITUR TAMBAHAN (AUTO DELETE & CONFIG)
echo -e "${blue}[INFO] Installing Config & Auto-XP...${nc}"
mkdir -p /etc/zivpn
touch /etc/zivpn/akun.db

# DOWNLOAD CONFIG DARI REPO ZIVCILZ
if [ ! -f "/etc/zivpn/config.json" ]; then
    echo '{"auth": []}' > /etc/zivpn/config.json
    # Jika di repo ada config default, uncomment baris bawah:
    # wget -q -O /etc/zivpn/config.json https://raw.githubusercontent.com/Pujianto1219/ZivCilz/refs/heads/main/config.json
fi

# Script Auto Delete (XP)
cat > /usr/bin/xp-zivpn <<'EOF'
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
        jq --arg u "$U" '.auth |= map(select(.user != $u))' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        grep -v "^$U:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
        RESTART=1
    fi
done < "$DB"
[ "$RESTART" -eq 1 ] && systemctl restart udp-zivpn
EOF
chmod +x /usr/bin/xp-zivpn

# Script Backup
cat > /usr/bin/backup-zivpn <<'EOF'
#!/bin/bash
DATA_FILE="/etc/zivpn/bot_data"
[ ! -f "$DATA_FILE" ] && exit 0
TOKEN=$(cat $DATA_FILE | cut -d: -f1)
CHATID=$(cat $DATA_FILE | cut -d: -f2)
DATE=$(date +"%Y-%m-%d")
NAME=$(cat /root/domain 2>/dev/null || echo "VPS")
mkdir -p /root/backup
cp /etc/zivpn/config.json /root/backup/
cp /etc/zivpn/akun.db /root/backup/
cd /root/
zip -r backup-$DATE.zip backup > /dev/null 2>&1
curl -F chat_id="$CHATID" -F document=@"backup-$DATE.zip" -F caption="Backup $NAME - $DATE" https://api.telegram.org/bot$TOKEN/sendDocument > /dev/null 2>&1
rm -rf /root/backup /root/backup-$DATE.zip
EOF
chmod +x /usr/bin/backup-zivpn

# Cronjob
sed -i "/xp-zivpn/d" /etc/crontab
sed -i "/backup-zivpn/d" /etc/crontab
echo "* * * * * root /usr/bin/xp-zivpn" >> /etc/crontab
echo "0 0 * * * root /usr/bin/backup-zivpn" >> /etc/crontab
service cron restart

# 8. DOWNLOAD MENU DARI REPO ZIVCILZ
echo -e "${blue}[INFO] Cloning Menu ZivCilz...${nc}"
cd /root
rm -rf /root/ZivCilz
git clone https://github.com/Pujianto1219/ZivCilz.git
cd /root/ZivCilz
chmod +x *.sh

# Cleanup
apt-get autoremove -y
apt-get clean

# Jalankan Menu
if [ -f "menu.sh" ]; then
    ./menu.sh
fi
