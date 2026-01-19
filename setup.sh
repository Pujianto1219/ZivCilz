#!/bin/bash
# Script Auto Installer ZivCilz (Permanent Menu Edition)
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
echo -e "${blue}[INFO] Checking IP Validation...${nc}"
MYIP=$(curl -sS ipv4.icanhazip.com)
[ -z "$MYIP" ] && MYIP=$(curl -sS ifconfig.me)

# URL IP Database Pujianto1219
IP_DB="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"

if wget -qO- "$IP_DB" | tr -d '\r' | grep -w "$MYIP" > /dev/null; then
    echo -e "${green}✅ IP Terdaftar! Akses Diizinkan.${nc}"
else
    echo -e "${red}❌ IP $MYIP TIDAK TERDAFTAR DI DATABASE!${nc}"
    rm "$0" 2>/dev/null
    exit 1
fi

echo -e "${blue}[INFO] Installing Dependencies...${nc}"
apt-get update
apt-get install -y --no-install-recommends wget curl git zip unzip tar net-tools systemd dnsutils vnstat nginx socat cron gnupg2 ca-certificates lsb-release jq iptables-persistent

# 2. OPTIMASI VPS
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 3. DOMAIN SETUP
echo -e "${yellow}===================================================${nc}"
echo -e "Masukkan Domain (Pastikan A Record mengarah ke $MYIP)"
while true; do
    read -p "Domain: " domain
    [ -z "$domain" ] && continue
    
    DOMAIN_IP=$(dig +short "$domain" | head -n 1)
    
    if [[ "$DOMAIN_IP" == "$MYIP" ]]; then
        echo "$domain" > /root/domain
        mkdir -p /etc/zivpn
        echo "$domain" > /etc/zivpn/domain
        echo -e "${green}Domain Valid!${nc}"
        break
    else
        echo -e "${red}IP Domain ($DOMAIN_IP) tidak sama dengan IP VPS ($MYIP)!${nc}"
        echo -e "${yellow}Matikan Proxy Cloudflare (DNS Only) jika error berlanjut.${nc}"
    fi
done

# 4. SSL SETUP
echo -e "${blue}[INFO] Setup SSL / Acme.sh...${nc}"
systemctl stop nginx
mkdir -p /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force
/root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/zivpn/zivpn.crt --keypath /etc/zivpn/zivpn.key --ecc

# 5. CONFIG JSON
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

# 6. UDP CORE INSTALLATION
echo -e "${blue}[INFO] Downloading Core Binary...${nc}"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-arm64"
else
    echo -e "${red}Arsitektur CPU tidak didukung!${nc}"; exit 1
fi

wget -q -O /usr/bin/udp-zivpn "$URL_CORE"
chmod +x /usr/bin/udp-zivpn

cat > /etc/systemd/system/udp-zivpn.service <<EOF
[Unit]
Description=UDP ZivCilz Core
After=network.target

[Service]
User=root
Type=simple
WorkingDirectory=/etc/zivpn
ExecStart=/usr/bin/udp-zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=ZIVPN_LOG_LEVEL=info

[Install]
WantedBy=multi-user.target
EOF

iptables -I INPUT -p udp --dport 5667 -j ACCEPT
iptables -I INPUT -p udp --dport 1:65535 -j ACCEPT
netfilter-persistent save > /dev/null

systemctl daemon-reload
systemctl enable udp-zivpn
systemctl restart udp-zivpn

# Nginx Configuration
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
    location / {
        try_files \$uri \$uri/ =404;
        add_header Content-Type text/plain;
        return 200 "ZivCilz UDP Server Running";
    }
}
EOF
rm /etc/nginx/sites-enabled/default 2>/dev/null
systemctl restart nginx

# 7. AUTO DELETE & BACKUP
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
        jq --arg u "$U" '.auth.config -= [$u]' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        grep -v "^$U:" "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
        RESTART=1
    fi
done < "$DB"
[ "$RESTART" -eq 1 ] && systemctl restart udp-zivpn
EOF
chmod +x /usr/bin/xp-zivpn

# 8. MENU INSTALLATION (PERMANENT)
echo -e "${blue}[INFO] Installing Permanent Menu...${nc}"
cd /root
rm -rf /root/ZivCilz
git clone https://github.com/Pujianto1219/ZivCilz.git
cd /root/ZivCilz

if [ -f "menu.sh" ]; then
    # Menyalin file menu ke /usr/bin/menu agar jadi command global
    cp menu.sh /usr/bin/menu
    chmod +x /usr/bin/menu
    echo -e "${green}Menu Installed Permanently!${nc}"
else
    echo -e "${red}File menu.sh tidak ditemukan di Repo!${nc}"
fi

# Cleanup
cd /root
rm -rf /root/ZivCilz

# Cronjob
sed -i "/xp-zivpn/d" /etc/crontab
echo "* * * * * root /usr/bin/xp-zivpn" >> /etc/crontab
service cron restart

# 9. FINISH & AUTO-START MENU
echo -e "${green}Instalasi Selesai! Mengarahkan ke Menu...${nc}"
sleep 2
clear
menu # Menjalankan perintah menu secara langsung
