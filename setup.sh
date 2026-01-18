#!/bin/bash
# Script Auto Installer ZivCilz (Custom Config Structure)
# Repo: https://github.com/Pujianto1219/ZivCilz

green='\e[32m'
red='\e[31m'
yellow='\e[33m'
blue='\e[34m'
nc='\e[0m'

if [ "${EUID}" -ne 0 ]; then
    echo -e "${red}Run as root!${nc}"
    exit 1
fi

clear
echo -e "${yellow}===================================================${nc}"
echo -e "${green}   AUTOSCRIPT ZIVCILZ (MODE: PASSWORDS)          ${nc}"
echo -e "${yellow}===================================================${nc}"

# 1. CEK IP & DEPENDENCIES
MYIP=$(curl -sS ipv4.icanhazip.com)
[ -z "$MYIP" ] && MYIP=$(curl -sS ifconfig.me)

IP_DB="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"
if wget -qO- "$IP_DB" | tr -d '\r' | grep -w "$MYIP" > /dev/null; then
    echo -e "${green}✅ IP Terdaftar!${nc}"
else
    echo -e "${red}❌ IP TIDAK TERDAFTAR!${nc}"
    exit 1
fi

apt-get update
apt-get install -y --no-install-recommends wget curl git zip unzip tar net-tools systemd dnsutils vnstat nginx socat cron gnupg2 ca-certificates lsb-release jq iptables-persistent

# 2. OPTIMASI VPS
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 3. DOMAIN
echo -e "${yellow}===================================================${nc}"
echo -e "Masukkan Domain (A Record -> $MYIP)"
while true; do
    read -p "Domain: " domain
    [ -z "$domain" ] && continue
    DOMAIN_IP=$(dig +short "$domain" | head -n 1)
    if [[ "$DOMAIN_IP" == "$MYIP" ]]; then
        echo "$domain" > /root/domain
        mkdir -p /etc/zivpn
        echo "$domain" > /etc/zivpn/domain
        break
    else
        echo -e "${red}IP Domain Salah!${nc}"
    fi
done

# 4. SSL SETUP (Sesuai Path Config Anda)
echo -e "${blue}[INFO] Setup SSL ke /etc/zivpn/...${nc}"
systemctl stop nginx
mkdir -p /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force
# Install ke folder /etc/zivpn sesuai config json
/root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/zivpn/zivpn.crt --keypath /etc/zivpn/zivpn.key --ecc

# 5. CONFIG JSON (CUSTOM USER)
echo -e "${blue}[INFO] Writing Config JSON...${nc}"
cat > /etc/zivpn/config.json <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": ["zi"]
  }
}
EOF
chmod 644 /etc/zivpn/config.json
touch /etc/zivpn/akun.db

# 6. UDP CORE
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/1.0/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/1.0/udp-zivpn-linux-arm64"
else
    echo -e "${red}CPU Not Supported${nc}"; exit 1
fi

wget -O /usr/bin/udp-zivpn "$URL_CORE"
chmod +x /usr/bin/udp-zivpn

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

# Buka Port 5667 (Sesuai Config)
iptables -I INPUT -p udp --dport 5667 -j ACCEPT
iptables -I INPUT -p udp --dport 1:65535 -j ACCEPT
netfilter-persistent save

systemctl daemon-reload
systemctl enable udp-zivpn
systemctl restart udp-zivpn

# Nginx (Hanya untuk Web Page / Validation)
cat > /etc/nginx/conf.d/zivpn.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name ${domain};
    ssl_certificate /etc/zivpn/zivpn.crt;
    ssl_certificate_key /etc/zivpn/zivpn.key;
    root /var/www/html;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
systemctl restart nginx

# 7. AUTO DELETE (DIADAPTASI KE STRUKTUR JSON BARU)
cat > /usr/bin/xp-zivpn <<'EOF'
#!/bin/bash
CONFIG="/etc/zivpn/config.json"
DB="/etc/zivpn/akun.db"
[ ! -f "$DB" ] && exit 0
NOW=$(date +%s)
RESTART=0
while read -r line; do
    U=$(echo $line | cut -d: -f1) # User dianggap sebagai Password/Token
    E=$(echo $line | cut -d: -f2)
    [[ ! "$E" =~ ^[0-9]+$ ]] && continue
    if [ "$NOW" -ge "$E" ]; then
        # Hapus String dari Array auth.config
        jq --arg u "$U" '.auth.config -= [$u]' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
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

# 8. MENU
echo -e "${blue}[INFO] Cloning Menu...${nc}"
cd /root
rm -rf /root/ZivCilz
git clone https://github.com/Pujianto1219/ZivCilz.git
cd /root/ZivCilz
chmod +x *.sh

if [ -f "menu.sh" ]; then ./menu.sh; fi
