#!/bin/bash
# GOLBERT V4.3.2 LTS - 101 -> SSH OK - DEFINITIVO GITHUB
set -e
clear
echo "=========================================="
echo " GOLBERT V4.3.2 LTS - 101 WS -> SSH OK"
echo "=========================================="

mkdir -p /etc/xray /etc/golbert /etc/xray/certs /var/log/golbert
IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')
RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n1)
DOMAIN="l1nve-${RAND}.golbertvps.org.pe"
SSLIP="${IP//./-}.sslip.io"

echo "$DOMAIN" > /etc/xray/domain
echo "9773873C2BC34C6D-da22c5b8" > /etc/golbert/license.key
echo "IP: $IP | Dominio: $DOMAIN | SSLIP: $SSLIP"

# 1. Limpia 80/443
echo "[1/8] Liberando 80/443..."
systemctl stop apache2 nginx 2>/dev/null || true
systemctl disable apache2 nginx 2>/dev/null || true
fuser -k 80/tcp 443/tcp 8080/tcp 2>/dev/null || true
apt remove -y apache2 nginx -y 2>/dev/null || true

# 2. Dependencias
echo "[2/8] Dependencias..."
apt update -y
apt install -y curl wget jq haproxy stunnel4 python3 python3-pip screen openssl socat cron net-tools lsof psmisc -y

# 3. XRAY
echo "[3/8] XRAY..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install --beta 2>/dev/null || bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install

# 4. CERT SAN
echo "[4/8] CERT SAN..."
openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -keyout /etc/xray/certs/xray.key -out /etc/xray/certs/xray.crt -subj "/C=PE/ST=Lima/L=Ica/O=Golbert/CN=$DOMAIN" -addext "subjectAltName=DNS:$DOMAIN,DNS:$SSLIP,DNS:*.${SSLIP},IP:$IP" 2>/dev/null
cat /etc/xray/certs/xray.crt /etc/xray/certs/xray.key > /etc/xray/certs/xray.pem
chmod 600 /etc/xray/certs/xray.pem

# 5. FIX SSHD - ESTO ARREGLA EL PREMATURE DESPUES DEL 101
echo "[5/8] Fix SSHD para 101 -> SSH..."
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*Port.*/Port 22/' /etc/ssh/sshd_config
grep -q "^Port 109" /etc/ssh/sshd_config || echo "Port 109" >> /etc/ssh/sshd_config
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || true
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

# 6. Descarga configs de Github
echo "[6/8] Descargando configs..."
REPO="https://raw.githubusercontent.com/golbert19/golbert-vps/main"
wget -O /etc/xray/config.json $REPO/xray-config-base.json -q
wget -O /etc/haproxy/haproxy.cfg $REPO/haproxy.cfg -q
wget -O /etc/stunnel/stunnel.conf $REPO/stunnel.conf -q
wget -O /usr/bin/golbert $REPO/golbert_panel_v4.3.sh -q
wget -O /etc/systemd/system/badvpn.service $REPO/badvpn.service -q
wget -O /etc/systemd/system/ws-proxy.service $REPO/ws-proxy.service -q
wget -O /etc/systemd/system/golbert-cron.service $REPO/golbert-cron.service -q
wget -O /etc/systemd/system/golbert-cron.timer $REPO/golbert-cron.timer -q
wget -O /usr/bin/golbert-cron $REPO/cron-golbert.sh -q
wget -O /usr/local/bin/ws-proxy.py $REPO/ws-proxy.py -q
wget -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw -q || curl -L -o /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw
chmod +x /usr/bin/golbert /usr/bin/badvpn-udpgw /usr/bin/golbert-cron /usr/local/bin/ws-proxy.py
cp /usr/bin/golbert /bin/golbert 2>/dev/null || true

# 7. REALITY
echo "[7/8] Reality..."
/usr/local/bin/xray x25519 > /etc/xray/reality.txt 2>&1 || true
PRIV=$(grep Private /etc/xray/reality.txt | awk '{print $3}')
PUB=$(grep Public /etc/xray/reality.txt | awk '{print $3}' | head -n1)
[[ "$PRIV" != "" ]] && sed -i "s/PRIVATE_KEY_AUTO/$PRIV/" /etc/xray/config.json
echo "$PUB" > /etc/xray/reality-pub.txt

# 8. Firewall + Servicios
echo "[8/8] Firewall + Servicios..."
ufw --force reset 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22,80,443,444,445,442,109,143,8443,7300,8080/tcp 2>/dev/null || true
ufw allow 7300/udp 2>/dev/null || true
ufw --force enable 2>/dev/null || true
iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true

systemctl daemon-reload
systemctl enable xray haproxy stunnel4 badvpn ws-proxy golbert-cron.timer --now 2>/dev/null || true
systemctl restart xray haproxy stunnel4 badvpn ws-proxy 2>/dev/null || true
(crontab -l 2>/dev/null | grep -v golbert-cron; echo "0 0 * * * /usr/bin/golbert-cron > /dev/null 2>&1") | crontab -

echo ""
echo "=========================================="
echo " GOLBERT V4.3.2 INSTALADO - 101 OK"
echo " Dominio: $DOMAIN"
echo " SSLIP: $SSLIP"
echo " IP: $IP"
echo " PUB Reality: $PUB"
echo "=========================================="
ss -tlnp | grep -E "haproxy|8080"
echo "--- TEST 80 ---"
curl -i http://127.0.0.1:80/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | head -5
echo "--- TEST 443 ---"
curl -ik https://127.0.0.1:443/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | head -5
echo "--- TEST SSH 22 ---"
timeout 1 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/22 && echo "SSH 22 OK"' || echo "SSH FAIL"

sleep 2
golbert
