#!/bin/bash
# GOLBERT V4.3.1 LTS FIX WS 80/443 - DEFINITIVO
set -e
clear
echo "=========================================="
echo " GOLBERT V4.3.1 LTS - FIX WS 80/443"
echo "=========================================="

mkdir -p /etc/xray /etc/golbert /etc/xray/certs /var/log/golbert
IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n1)
DOMAIN="l1nve-${RAND}.golbertvps.org.pe"
SSLIP="${IP//./-}.sslip.io"

echo "$DOMAIN" > /etc/xray/domain
echo "9773873C2BC34C6D-da22c5b8" > /etc/golbert/license.key
echo "IP: $IP"
echo "Dominio: $DOMAIN"
echo "SSLIP: $SSLIP"

# 1. Limpia puertos 80/443
echo "[1/7] Liberando 80/443..."
systemctl stop apache2 nginx 2>/dev/null || true
systemctl disable apache2 nginx 2>/dev/null || true
fuser -k 80/tcp 443/tcp 8080/tcp 2>/dev/null || true
apt remove -y apache2 nginx 2>/dev/null || true

# 2. Dependencias
echo "[2/7] Instalando dependencias..."
apt update -y
apt install -y curl wget jq haproxy stunnel4 python3 python3-pip screen openssl socat cron net-tools lsof -y

# 3. XRAY
echo "[3/7] Instalando XRAY..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install --beta 2>/dev/null || bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install

# 4. CERT CON SAN (FIX WS 443)
echo "[4/7] Generando CERT SAN..."
openssl req -x509 -nodes -days 1095 -newkey rsa:2048 \
-keyout /etc/xray/certs/xray.key \
-out /etc/xray/certs/xray.crt \
-subj "/C=PE/ST=Lima/L=Ica/O=Golbert/CN=$DOMAIN" \
-addext "subjectAltName=DNS:$DOMAIN,DNS:$SSLIP,DNS:*.${SSLIP},IP:$IP" 2>/dev/null

cat /etc/xray/certs/xray.crt /etc/xray/certs/xray.key > /etc/xray/certs/xray.pem
chmod 600 /etc/xray/certs/xray.pem
echo "CERT OK: $(ls -lh /etc/xray/certs/xray.pem)"

# 5. Descarga configs de tu repo
echo "[5/7] Descargando configs..."
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

chmod +x /usr/bin/golbert /usr/bin/badvpn-udpgw /usr/bin/golbert-cron /usr/local/bin/ws-proxy.py 2>/dev/null || true
cp /usr/bin/golbert /bin/golbert 2>/dev/null || true

# 6. REALITY KEY FIX
echo "[6/7] Generando REALITY..."
/usr/local/bin/xray x25519 > /etc/xray/reality.txt 2>&1 || true
PRIV=$(cat /etc/xray/reality.txt | grep "Private" | awk '{print $3}')
PUB=$(cat /etc/xray/reality.txt | grep "Public" | awk '{print $3}' | head -n1)
if [[ "$PRIV" != "" ]]; then
  sed -i "s/PRIVATE_KEY_AUTO/$PRIV/" /etc/xray/config.json
fi
echo "$PUB" > /etc/xray/reality-pub.txt

# 7. Firewall + Enable
echo "[7/7] Firewall + Servicios..."
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || true

ufw --force reset 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22,80,443,444,445,442,109,143,8443,7300,8080/tcp 2>/dev/null || true
ufw allow 7300/udp 2>/dev/null || true
ufw --force enable 2>/dev/null || true

iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null || true

systemctl daemon-reload
systemctl enable xray haproxy stunnel4 badvpn ws-proxy golbert-cron.timer --now 2>/dev/null || true
# FIX SSHD PARA 101 -> SSH OK V4.3.2
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*Port.*/Port 22/' /etc/ssh/sshd_config
grep -q "^Port 109" /etc/ssh/sshd_config || echo "Port 109" >> /etc/ssh/sshd_config
systemctl restart sshd 2>/dev/null; systemctl restart ssh 2>/dev/null || true
systemctl restart xray haproxy stunnel4 badvpn ws-proxy 2>/dev/null || true

(crontab -l 2>/dev/null | grep -v golbert-cron; echo "0 0 * * * /usr/bin/golbert-cron > /dev/null 2>&1") | crontab -

echo ""
echo "=========================================="
echo " GOLBERT V4.3.1 INSTALADO - FIX WS OK"
echo " Dominio: $DOMAIN"
echo " SSLIP: $SSLIP"
echo " IP: $IP"
echo " Reality PUB: $PUB"
echo " Puertos: 80(WS) 443(WS TLS) 8443(REALITY) 444/445(SSL)"
echo " Comando: golbert"
echo "=========================================="
echo ""
echo "TEST WS:"
ss -tulnp | grep -E "haproxy|xray" || netstat -tulnp | grep -E "haproxy|xray"
curl -I http://127.0.0.1:80 2>&1 | head -n 3
curl -Ik https://127.0.0.1:443 2>&1 | head -n 3

sleep 2
golbert
