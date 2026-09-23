#!/bin/bash
# GOLBERT VPS MANAGER PRO v2.0 - Ubuntu 22.04 - FULL
# Puertos: 109 DROPBEAR | 443 TLS | 80,8080,8180 WS | 7300 BADVPN | 1194 OPENVPN | 8443 XRAY | 5300 DNS

if [ "$(id -u)"!= "0" ]; then echo "Ejecuta como root"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive
IP=$(curl -s ipv4.icanhazip.com)

apt update -y
apt install -y dropbear stunnel4 curl wget python3 python3-pip screen qrencode unzip openvpn easy-rsa nginx certbot ufw

# --- 1. DROPBEAR 109 ---
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-p 109"' >> /etc/default/dropbear
systemctl enable dropbear --now

# --- 2. STUNNEL 443 -> 109 ---
mkdir -p /etc/stunnel
openssl req -new -x509 -days 3650 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem -subj "/CN=$IP" >/dev/null 2>&1
cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
[dropbear]
accept = 443
connect = 127.0.0.1:109
EOF
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable stunnel4 --now

# --- 3. WS-PROXY 80,8080,8180 ---
