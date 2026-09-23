#!/bin/bash
# GOLBERT VPS MAIN v4.3.2 - 101 OK - FIX DEFINITIVO
# FIX: 400 missing Sec-WebSocket-Key + websockets lib eliminada (RAW Proxy)

if [ "$(id -u)" != "0" ]; then echo "Ejecuta como root"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

echo "=== GOLBERT MAIN v4.3.2 101 OK - Instalando ==="

apt-get update -y
apt-get install -y python3 python3-pip haproxy openssh-server dropbear stunnel4 screen curl wget socat

# SSH FIX - Evita Premature
sed -i 's/^#*MaxStartups.*/MaxStartups 1000:1000:1000/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "MaxStartups 1000:1000:1000" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
mkdir -p /var/run/sshd

# HAPROXY 80 -> 8080
cat > /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    daemon
    maxconn 5000
    user haproxy
    group haproxy
defaults
    mode tcp
    log global
    timeout connect 5s
    timeout client 60s
    timeout server 60s
    retries 3
frontend http-in
    bind *:80
    default_backend ws-backend
backend ws-backend
    server ws1 127.0.0.1:8080 maxconn 1000 check
EOF

# WS-PROXY RAW 101 - NO USA websockets
mkdir -p /usr/local/bin
cat > /usr/local/bin/ws-proxy.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading, select
LISTEN = ('0.0.0.0', 8080)
SSH = ('127.0.0.1', 22)
RESP = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
def pipe(a,b):
    try:
        while True:
            r,_,_ = select.select([a,b],[],[],60)
            if a in r:
                d=a.recv(8192)
                if not d: break
                b.sendall(d)
            if b in r:
                d=b.recv(8192)
                if not d: break
                a.sendall(d)
    except: pass
    finally:
        try: a.close()
        except: pass
        try: b.close()
        except: pass
def handle(cli):
    try:
        cli.settimeout(5)
        data=b""
        while b"\r\n\r\n" not in data:
            chunk=cli.recv(4096)
            if not chunk: return
            data+=chunk
            if len(data)>8192: break
        cli.sendall(RESP)
        srv=socket.create_connection(SSH, timeout=5)
        cli.settimeout(None)
        pipe(cli,srv)
    except:
        try: cli.close()
        except: pass
def main():
    s=socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(LISTEN)
    s.listen(500)
    print(f"GOLBERT RAW 101 Proxy {LISTEN} -> {SSH} OK")
    while True:
        c,a=s.accept()
        threading.Thread(target=handle, args=(c,), daemon=True).start()
if __name__=="__main__":
    main()
PYEOF

chmod +x /usr/local/bin/ws-proxy.py

# SERVICE
cat > /etc/systemd/system/ws-proxy.service <<'EOF'
[Unit]
Description=Golbert WS Proxy 101 OK RAW
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

# MENU
cat > /usr/local/bin/golbert <<'MEOF'
#!/bin/bash
while true; do
clear
echo "=== GOLBERT MEIN v4.3.2 101 OK ==="
echo "[1] Crear usuario"
echo "[2] Test 101"
echo "[3] Listar usuarios"
echo "[4] Eliminar usuario"
echo "[5] Reiniciar servicios"
echo "[0] Salir"
echo -n "Opcion: "; read op
case $op in
1) echo -n "Usuario: "; read u; echo -n "Clave: "; read -s p; echo
   useradd -m -s /bin/bash $u 2>/dev/null; echo "$u:$p" | chpasswd; usermod -s /bin/bash $u; chage -E -1 $u
   echo "Usuario $u creado OK";;
2) echo "Testing 101..."; curl -i -H "Upgrade: websocket" -H "Connection: Upgrade" http://127.0.0.1:80 2>&1 | head -n 20;;
3) cat /etc/passwd | grep "/bin/bash" | cut -d: -f1;;
4) echo -n "Usuario a eliminar: "; read u; userdel -r $u; echo "Eliminado";;
5) systemctl restart ws-proxy haproxy ssh; echo "Servicios reiniciados";;
0) exit 0;;
esac
read -p "Enter para continuar..."
done
MEOF

chmod +x /usr/local/bin/golbert
mkdir -p /usr/local/bin
systemctl daemon-reload
systemctl enable ws-proxy haproxy ssh
systemctl restart ws-proxy
systemctl restart haproxy
systemctl restart ssh
systemctl restart dropbear 2>/dev/null || true
sleep 1
echo ""
echo "=== INSTALADO - Escribe: golbert ==="
curl -i -H "Upgrade: websocket" -H "Connection: Upgrade" http://127.0.0.1:80 2>&1 | head -n 10
echo ""
echo "Si ves '101 Switching Protocols' esta 100% OK"
