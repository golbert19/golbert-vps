#!/bin/bash
# GOLBERT V4.3.2 LTS - MEIN - SETUP TODO EN UNO - 101 WS -> SSH OK
set -e
if [[ $EUID -ne 0 ]]; then echo "Corre como root: sudo./setup"; exit 1; fi
clear
echo "=========================================="
echo " GOLBERT V4.3.2 MEIN - 101 WS -> SSH OK"
echo "=========================================="

mkdir -p /etc/xray/certs /etc/golbert /var/log/golbert
IP=$(curl -4 -s ifconfig.me || curl -4 -s ipinfo.io/ip || hostname -I | awk '{print $1}')
RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n1)
DOMAIN="l1nve-${RAND}.golbertvps.org.pe"
SSLIP="${IP//./-}.sslip.io"
echo "$DOMAIN" > /etc/xray/domain
echo "9773873C2BC34C6D-da22c5b8" > /etc/golbert/license.key
echo "[INFO] IP: $IP | Dominio: $DOMAIN | SSLIP: $SSLIP"

# [1] LIMPIA 80/443
echo "[1/9] Limpiando 80/443..."
systemctl stop apache2 nginx 2>/dev/null || true
systemctl disable apache2 nginx 2>/dev/null || true
fuser -k 80/tcp 443/tcp 8080/tcp 2>/dev/null || true

# [2] DEPENDENCIAS
echo "[2/9] Dependencias..."
apt update -y
apt install -y curl wget jq haproxy stunnel4 python3 screen openssl socat cron net-tools lsof psmisc uuid-runtime -y

# [3] XRAY
echo "[3/9] Instalando XRAY..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install --beta 2>/dev/null || bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install.sh)" @ install || true

# [4] CERT SAN
echo "[4/9] Cert SAN..."
openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -keyout /etc/xray/certs/xray.key -out /etc/xray/certs/xray.crt -subj "/C=PE/ST=Lima/L=Ica/O=Golbert/CN=$DOMAIN" -addext "subjectAltName=DNS:$DOMAIN,DNS:$SSLIP,DNS:*.${SSLIP},IP:$IP" 2>/dev/null
cat /etc/xray/certs/xray.crt /etc/xray/certs/xray.key > /etc/xray/certs/xray.pem
chmod 600 /etc/xray/certs/xray.pem

# [5] FIX SSHD - FIX PREMATURE CLOSE
echo "[5/9] Fix SSHD..."
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
grep -q "^Port 22" /etc/ssh/sshd_config || echo "Port 22" >> /etc/ssh/sshd_config
grep -q "^Port 109" /etc/ssh/sshd_config || echo "Port 109" >> /etc/ssh/sshd_config
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || echo "ENABLED=1" > /etc/default/stunnel4
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true

# [6] XRAY CONFIG
echo "[6/9] Config XRAY..."
UUID=$(cat /proc/sys/kernel/random/uuid)
PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n1)
cat > /etc/xray/config.json << XRAY
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "port": 10001, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [{ "id": "$UUID", "alterId": 0 }] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "port": 10002, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [{ "id": "$UUID" }], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "port": 10003, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [{ "password": "$PASS" }] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    { "port": 10004, "listen": "127.0.0.1", "protocol": "shadowsocks", "settings": { "method": "chacha20-poly1305", "password": "$PASS", "network": "tcp,udp" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/ssws" } } }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
XRAY

# [7] HAPROXY FIX 101
echo "[7/9] Haproxy FIX 101..."
cat > /etc/haproxy/haproxy.cfg << 'CFG'
global
    log /dev/log local0
    maxconn 4096
    daemon
    crt-base /etc/xray/certs
defaults
    log global
    mode http
    timeout connect 5s
    timeout client 120s
    timeout server 120s
    timeout tunnel 2h
frontend http-in
    bind *:80
    bind *:443 ssl crt /etc/xray/certs/xray.pem alpn h2,http/1.1
    acl is_vmess path_beg /vmess
    acl is_vless path_beg /vless
    acl is_trojan path_beg /trojan
    acl is_ss path_beg /ssws
    use_backend vmess-ws if is_vmess
    use_backend vless-ws if is_vless
    use_backend trojan-ws if is_trojan
    use_backend ss-ws if is_ss
    default_backend ssh-ws
backend ssh-ws
    server ssh 127.0.0.1:8080
backend vmess-ws
    server x 127.0.0.1:10001
backend vless-ws
    server x 127.0.0.1:10002
backend trojan-ws
    server x 127.0.0.1:10003
backend ss-ws
    server x 127.0.0.1:10004
CFG

# [8] WS-PROXY.PY + SERVICE + STUNNEL + BADVPN + PANEL
echo "[8/9] WS-Proxy + Servicios..."
cat > /usr/local/bin/ws-proxy.py << 'PY'
#!/usr/bin/env python3
import socket, threading, select
LISTEN=8080
SSH=('127.0.0.1',22)
def handle(c):
    try:
        d=c.recv(8192).decode(errors='ignore')
        if 'websocket' in d.lower(): c.send(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
        else: c.send(b'HTTP/1.1 200 Golbert OK\r\nContent-Length:0\r\n\r\n')
        s=socket.socket(); s.connect(SSH)
        while True:
            r,_,_=select.select([c,s],[],[],60)
            if c in r:
                x=c.recv(8192)
                if not x: break
                s.sendall(x)
            if s in r:
                x=s.recv(8192)
                if not x: break
                c.sendall(x)
    except: pass
    finally:
        try: c.close()
        except: pass
srv=socket.socket(); srv.setsockopt(1,1,1); srv.bind(('0.0.0.0',LISTEN)); srv.listen(128)
print(f"Golbert WS {LISTEN} -> {SSH}")
while True:
    cl,_=srv.accept(); threading.Thread(target=handle,args=(cl,),daemon=True).start()
PY
chmod +x /usr/local/bin/ws-proxy.py

cat > /etc/systemd/system/ws-proxy.service << 'SVC'
[Unit]
Description=Golbert WS Proxy V4.3.2
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
SVC

cat > /etc/stunnel/stunnel.conf << 'ST'
pid = /var/run/stunnel4/stunnel.pid
cert = /etc/xray/certs/xray.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[ssh-tls]
accept = 444
connect = 127.0.0.1:22
[openvpn-tls]
accept = 442
connect = 127.0.0.1:1194
ST

wget -q -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw || curl -L -o /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw
cat > /etc/systemd/system/badvpn.service << 'BAD'
[Unit]
Description=BadVPN UDPGW
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=always
[Install]
WantedBy=multi-user.target
BAD

REPO="https://raw.githubusercontent.com/golbert19/golbert-vps/mein"
wget -q -O /usr/bin/golbert $REPO/golbert_panel_v4.3.sh || wget -q -O /usr/bin/golbert https://raw.githubusercontent.com/golbert19/golbert-vps/main/golbert_panel_v4.3.sh || true
chmod +x /usr/bin/golbert; cp /usr/bin/golbert /bin/golbert 2>/dev/null || true

# [9] FIREWALL + START
echo "[9/9] Iniciando..."
ufw --force reset 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22,80,443,444,442,109,7300/tcp 2>/dev/null || true
ufw allow 7300/udp 2>/dev/null || true
ufw --force enable 2>/dev/null || true
iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true

systemctl daemon-reload
systemctl enable xray haproxy stunnel4 badvpn ws-proxy --now
systemctl restart xray haproxy stunnel4 badvpn ws-proxy
echo ""
echo "=========================================="
echo " GOLBERT MEIN INSTALADO - 101 OK"
echo " IP: $IP"
echo " Dominio: $DOMAIN"
echo " SSLIP: $SSLIP"
echo " UUID: $UUID"
echo "=========================================="
ss -tlnp | grep -E "haproxy|8080|1000"
curl -i http://127.0.0.1:80/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | head -n 3
curl -ik https://127.0.0.1:443/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | head -n 3
sleep 2
/usr/bin/golbert 2>/dev/null || /bin/golbert 2>/dev/null || echo "Panel: escribe golbert"
