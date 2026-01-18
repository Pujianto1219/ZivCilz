![ZIVPN](zivpn.png)

UDP server installation for ZIVPN Tunnel (SSH/DNS/UDP) VPN app.
<br>

>Server binary for Linux amd64 and arm.

### INSTALL
```
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y wget && wget -q https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/setup.sh && chmod +x setup.sh && ./setup.sh
```
#### Installation AMD
```
wget -O zi.sh https://raw.githubusercontent.com/Pujianto1219/ZivCilz/main/zi.sh; sudo chmod +x zi.sh; sudo ./zi.sh
```

#### Installation ARM
```
bash <(curl -fsSL https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/zi2.sh)
```


### Uninstall

```
sudo wget -O ziun.sh https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/uninstall.sh; sudo chmod +x ziun.sh; sudo ./ziun.sh
```

Client App available:

<a href="https://play.google.com/store/apps/details?id=com.zi.zivpn" target="_blank" rel="noreferrer">Download APP on Playstore</a>
> ZIVPN
                
----
Bash script by PowerMX
