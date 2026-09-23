#!/usr/bin/env python3
import socket, threading, select
LISTEN = 8080
SSH_HOST = '127.0.0.1'
SSH_PORT = 22

def handle(client):
    try:
        data = client.recv(8192).decode(errors='ignore')
        if 'Upgrade: websocket' in data or 'upgrade: websocket' in data.lower():
            client.send(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
        else:
            client.send(b'HTTP/1.1 200 Golbert WS OK\r\nContent-Length: 0\r\n\r\n')
        ssh = socket.socket()
        ssh.settimeout(10)
        ssh.connect((SSH_HOST, SSH_PORT))
        while True:
            r, _, _ = select.select([client, ssh], [], [], 60)
            if client in r:
                d = client.recv(8192)
                if not d: break
                ssh.sendall(d)
            if ssh in r:
                d = ssh.recv(8192)
                if not d: break
                client.sendall(d)
    except Exception as e:
        pass
    finally:
        try: client.close()
        except: pass
        try: ssh.close()
        except: pass

s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', LISTEN))
s.listen(128)
print(f"Golbert WS {LISTEN} -> {SSH_HOST}:{SSH_PORT}")
while True:
    c, _ = s.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
bash <(curl -Ls https://raw.githubusercontent.com/golbert19/golbert-vps/main/setup)
