#!/bin/bash
# GOLBERT VPS MEIN v4.3.2 - FIX RAW 101
apt-get update -y && apt-get install -y python3 python3-pip git curl wget screen
mkdir -p /etc/golbert && cd /etc/golbert

cat > ws-proxy.py <<'PYEOF'
import socket, threading, select, re
PORT=80
def handle(c):
    try:
        req=c.recv(4096).decode(errors='ignore')
        if not req: c.close(); return
        host=''; port=22
        m=re.search(r'X-Real-Host:\s*([^\r\n:]+):?(\d+)?', req, re.I)
        if m:
            host=m.group(1).strip();
            if m.group(2): port=int(m.group(2))
        else:
            m2=re.search(r'CONNECT\s+([^\s:]+):?(\d+)?', req, re.I)
            if m2:
                host=m2.group(1).strip()
                if m2.group(2): port=int(m2.group(2))
        if not host: host='127.0.0.1'
        # FIX 101: respuesta RAW 101 sin headers extra
        c.sendall(b'HTTP/1.1 101 Switching Protocols\r\n\r\n')
        r=socket.create_connection((host, port), timeout=5)
        while True:
            rr,_,_=select.select([c,r],[],[],60)
            if not rr: break
            for sock in rr:
                other=r if sock is c else c
                data=sock.recv(8192)
                if not data: c.close(); r.close(); return
                other.sendall(data)
    except:
        try: c.close()
        except: pass

s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', PORT)); s.listen(100)
print(f"GOLBERT RAW 101 ON {PORT}")
while True:
    conn,_=s.accept()
    threading.Thread(target=handle, args=(conn,), daemon=True).start()
PYEOF

cat > /etc/systemd/system/golbert.service <<'SVCEOF'
[Unit]
Description=Golbert WS Proxy
After=network.target
[Service]
ExecStart=/usr/bin/python3 /etc/golbert/ws-proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable golbert
systemctl restart golbert
echo "--- GOLBERT INSTALADO FIX 101 ---"
