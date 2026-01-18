#!/bin/bash
# Script Auto Installer ZiVPN (All-in-One + Auto Delete)
# Features: IP Auth, Domain Check, UDP Core, Nginx, SSL, Vnstat, BBR, Swap, Auto-Exp
# Repo: https://github.com/Pujianto1219/ZiVPN

# --- Warna ---
green='\e[32m'
red='\e[31m'
yellow='\e[33m'
blue='\e[34m'
nc='\e[0m'

# --- Cek Root ---
if [ "${EUID}" -ne 0 ]; then
    echo -e "${red}Jalankan script sebagai root!${nc}"
    exit 1
fi

clear
echo -e "${yellow}===================================================${nc}"
echo -e "${green}    AUTOSCRIPT ZIVPN (FULL & OPTIMIZED)          ${nc}"
echo -e "${yellow}===================================================${nc}"

# ==========================================================
# 1. PENGECEKAN IP & LISENSI
# ==========================================================
echo -e "${blue}[CHECK] Verifikasi IP Address...${nc}"
MYIP=$(curl -sS ipv4.icanhazip.com)
[ -z "$MYIP" ] && MYIP=$(curl -sS ifconfig.me)

IP_DB="https://raw.githubusercontent.com/Pujianto1219/ip/refs/heads/main/ip"

if wget -qO- "$IP_DB" | grep -w "$MYIP" > /dev/null; then
    echo -e "${green}✅ IP $MYIP Terdaftar!${nc}"
else
    echo -e "${red}❌ IP $MYIP TIDAK TERDAFTAR! Hubungi Admin.${nc}"
    rm -f setup.sh
    exit 1
fi
sleep 1

# ==========================================================
# 2. OPTIMASI SISTEM (KHUSUS LOW SPEC VPS)
# ==========================================================
echo -e "${blue}[OPTIMIZE] Mengoptimalkan performa VPS...${nc}"

# a. Menambahkan Swap (RAM Virtual) jika RAM < 2GB
GET_RAM=$(free -m | grep Mem | awk '{print $2}')
if [ "$GET_RAM" -le 2000 ]; then
    echo -e "${yellow}- Terdeteksi RAM rendah, membuat Swap 1GB...${nc}"
    if [ ! -f /swapfile ]; then
        dd if=/dev/zero of=/swapfile bs=1024 count=1048576
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
        echo -e "${green}- Swap File berhasil dibuat.${nc}"
    else
        echo -e "${yellow}- Swap File sudah ada, skip.${nc}"
    fi
fi

# b. Mengaktifkan TCP BBR
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${green}- TCP BBR Diaktifkan.${nc}"
fi

# c. Tuning Kernel Ringan
echo "fs.file-max = 65535" >> /etc/sysctl.conf
sysctl -p

# ==========================================================
# 3. UPDATE & INSTALL DEPENDENCIES
# ==========================================================
echo -e "${blue}[INFO] Install Dependencies...${nc}"
apt-get update
# Menambahkan jq untuk manipulasi JSON (Wajib untuk auto-delete)
apt-get install -y --no-install-recommends wget curl git zip unzip tar net-tools systemd dnsutils vnstat nginx socat cron gnupg2 ca-certificates lsb-release jq

# Aktifkan vnstat
systemctl enable vnstat
systemctl start vnstat

# ==========================================================
# 4. INPUT DOMAIN
# ==========================================================
echo -e "${yellow}===================================================${nc}"
echo -e "Masukkan Domain (Pastikan A Record ke: ${green}$MYIP${nc})"
echo -e "Matikan Proxy Cloudflare (Awan Oranye)!" 
echo ""

while true; do
    read -p "Domain: " domain
    [ -z "$domain" ] && continue

    echo -e "${blue}Cek DNS $domain...${nc}"
    DOMAIN_IP=$(dig +short "$domain" | head -n 1)

    if [[ "$DOMAIN_IP" == "$MYIP" ]]; then
        echo -e "${green}✅ Domain Valid!${nc}"
        echo "$domain" > /root/domain
        mkdir -p /etc/xray
        echo "$domain" > /etc/xray/domain
        break
    else
        echo -e "${red}❌ IP Domain ($DOMAIN_IP) != IP VPS ($MYIP).${nc}"
        echo -e "Cek DNS Anda atau tunggu propagasi."
        echo -e "Tekan CTRL+C untuk batal, atau enter untuk ulang."
        read -p ""
    fi
done

# ==========================================================
# 5. SSL SETUP (ACME STANDALONE)
# ==========================================================
echo -e "${blue}[INFO] Request SSL...${nc}"
systemctl stop nginx

mkdir -p /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt

if /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force; then
    echo -e "${green}SSL Sukses!${nc}"
else
    echo -e "${red}Gagal SSL! Pastikan Port 80 kosong.${nc}"
fi

/root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
chmod 644 /etc/xray/xray.crt
chmod 644 /etc/xray/xray.key

# ==========================================================
# 6. NGINX OPTIMIZED CONFIG
# ==========================================================
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

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
    
    # SSL Optimization
    ssl_session_timeout 1d;
    ssl_session_cache shared:ZiVPN:10m;
    ssl_session_tickets off;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

systemctl restart nginx

# ==========================================================
# 7. UDP CORE INSTALL
# ==========================================================
echo -e "${blue}[INFO] Install UDP Core...${nc}"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL_CORE="https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-arm64"
else
    echo -e "${red}CPU tidak support!${nc}"
    exit 1
fi

wget -O /usr/bin/udp-zivpn "$URL_CORE"
chmod +x /usr/bin/udp-zivpn

cat > /etc/systemd/system/udp-zivpn.service <<EOF
[Unit]
Description=UDP ZiVPN Core
After=network.target

[Service]
User=root
Type=simple
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

# ==========================================================
# 8. AUTO DELETE EXPIRED SETUP
# ==========================================================
echo -e "${blue}[INFO] Menginstall fitur Auto-Delete Expired...${nc}"

# Buat folder config database
mkdir -p /etc/zivpn
touch /etc/zivpn/akun.db

# Ambil Config Default agar file json tersedia
if [ ! -f "/etc/zivpn/config.json" ]; then
    wget -q -O /etc/zivpn/config.json https://raw.githubusercontent.com/Pujianto1219/ZivCilz/refs/heads/main/config.json
fi

# Membuat Script XP Otomatis di VPS
cat > /usr/bin/xp-zivpn <<'EOF'
#!/bin/bash
# Script Auto Delete Expired User ZiVPN
CONFIG_FILE="/etc/zivpn/config.json"
DB_FILE="/etc/zivpn/akun.db"

if [ ! -f "$DB_FILE" ]; then
    exit 0
fi

CURRENT_TIME=$(date +%s)
RESTART_NEEDED=0

while read -r line; do
    USER=$(echo $line | cut -d: -f1)
    EXP=$(echo $line | cut -d: -f2)

    if [[ ! "$EXP" =~ ^[0-9]+$ ]]; then
        continue
    fi

    if [ "$CURRENT_TIME" -ge "$EXP" ]; then
        echo "User $USER expired. Menghapus..."
        jq --arg u "$USER" '.auth |= map(select(.user != $u))' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        grep -v "^$USER:" "$DB_FILE" > "${DB_FILE}.tmp" && mv "${DB_FILE}.tmp" "$DB_FILE"
        RESTART_NEEDED=1
    fi
done < "$DB_FILE"

if [ "$RESTART_NEEDED" -eq 1 ]; then
    systemctl restart udp-zivpn
fi
EOF

chmod +x /usr/bin/xp-zivpn

# Pasang Cronjob (Jalan tiap 1 menit)
sed -i "/xp-zivpn/d" /etc/crontab
echo "* * * * * root /usr/bin/xp-zivpn" >> /etc/crontab
service cron restart
echo -e "${green}- Auto Delete berhasil dipasang.${nc}"

# ==========================================================
# 9. FINISHING & CLEANUP
# ==========================================================
echo -e "${blue}[INFO] Menjalankan Script Repo...${nc}"
cd /root
rm -rf /root/ZiVPN
git clone https://github.com/Pujianto1219/ZivCilz.git
cd /root/ZiVPN
chmod +x *.sh

# Cleanup File Sampah
apt-get autoremove -y
apt-get clean

# Jalankan Menu
if [ -f "setup.sh" ]; then
    ./setup.sh
elif [ -f "menu.sh" ]; then
    ./menu.sh
fi

echo -e "${yellow}===================================================${nc}"
echo -e "${green}   INSTALLASI SELESAI & AUTO-XP AKTIF            ${nc}"
echo -e "${yellow}===================================================${nc}"
