#!/bin/bash
# Zivpn UDP Module Auto Installer
# Modified for Automation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Password Logic (Auto argument)
# Usage: ./script.sh "pass1,pass2"
# If empty, defaults to "zi"
INPUT_PASS="${1:-zi}"

echo -e "${GREEN}[+] Updating server repositories...${NC}"
apt-get update -qq && apt-get upgrade -y -qq

echo -e "${GREEN}[+] Stopping existing Zivpn service...${NC}"
systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "${GREEN}[+] Downloading UDP Service Binary...${NC}"
wget https://github.com/Pujianto1219/ZivCilz/releases/download/Ziv-Panel2.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn

echo -e "${GREEN}[+] Configuring Directories and Files...${NC}"
mkdir -p /etc/zivpn
wget https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo -e "${GREEN}[+] Generating SSL Certificates...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Zivpn Auto/OU=IT/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2> /dev/null

# Kernel Tuning
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

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

echo -e "${GREEN}[+] Setting up Password Configuration: ${YELLOW}${INPUT_PASS}${NC}"

# Logic convert input string to array config
IFS=',' read -r -a config <<< "$INPUT_PASS"
if [ ${#config[@]} -eq 1 ]; then
    config+=(${config[0]})
fi

# Create JSON array string
new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"

# Replace in config.json
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

echo -e "${GREEN}[+] Enabling and Starting Service...${NC}"
systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

echo -e "${GREEN}[+] Configuring Firewall (IPTables & UFW)...${NC}"
# Detect Default Interface
DEFAULT_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -A PREROUTING -i $DEFAULT_IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667

# UFW rules
if command -v ufw > /dev/null; then
    ufw allow 6000:19999/udp > /dev/null
    ufw allow 5667/udp > /dev/null
fi

# Cleanup
rm -f zi.* 1> /dev/null 2> /dev/null

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   ZIVPN UDP INSTALLED SUCCESSFULLY      ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e " Password : ${YELLOW}${INPUT_PASS}${NC}"
echo -e " Port     : ${YELLOW}5667 (Internal), 6000-19999 (Public)${NC}"
echo -e " Status   : $(systemctl is-active zivpn.service)"
echo -e "${GREEN}=========================================${NC}"
