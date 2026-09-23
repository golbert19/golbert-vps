#!/bin/bash
# GOLBERT V4.3 LTS FINAL DEFINITIVO - 1 COMANDO
set -e
mkdir -p /etc/xray /etc/golbert /etc/xray/certs
IP=$(curl -s ifconfig.me)
RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n1)
DOMAIN="l1nve-${RAND}.golbertvps.org.pe"
echo $DOMAIN > /etc/xray/domain
echo "9773873C2BC34C6D-da22c5b8" > /etc/golbert/license.key
echo "Dominio: $DOMAIN - IP: $IP"

apt update -y && apt install -y curl wget jq haproxy stunnel4 python3 screen -y
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/xray/certs/xray.key -out /etc/xray/certs/xray.crt -subj "/CN=$DOMAIN" 2>/dev/null
cat /etc/xray/certs/xray.crt /etc/xray/certs/xray.key > /etc/xray/certs/xray.pem

REPO="https://raw.githubusercontent.com/golbert19/golbert-vps/main"
wget -O /etc/xray/config.json $REPO/xray-config-base.json -q
wget -O /etc/haproxy/haproxy.cfg $REPO/haproxy.cfg -q
wget -O /etc/stunnel/stunnel.conf $REPO/stunnel.conf -q
wget -O /usr/bin/golbert $REPO/golbert_panel_v4.3.sh -q
wget -O /etc/systemd/system/badvpn.service $REPO/badvpn.service -q
wget -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw -q
wget -O /usr/bin/golbert-cron $REPO/cron-golbert.sh -q
wget -O /etc/systemd/system/golbert-cron.service $REPO/golbert-cron.service -q
wget -O /etc/systemd/system/golbert-cron.timer $REPO/golbert-cron.timer -q

chmod +x /usr/bin/golbert /usr/bin/badvpn-udpgw /usr/bin/golbert-cron
cp /usr/bin/golbert /bin/golbert

/usr/local/bin/xray x25519 > /etc/xray/reality.txt 2>&1 || true
PRIV=$(cat /etc/xray/reality.txt | grep Private | awk '{print $3}')
sed -i "s/PRIVATE_KEY_AUTO/$PRIV/" /etc/xray/config.json || true
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || true

systemctl daemon-reload
systemctl enable xray haproxy stunnel4 badvpn golbert-cron.timer --now
systemctl restart xray haproxy stunnel4 badvpn
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/golbert-cron > /dev/null 2>&1") | crontab -
golbert
