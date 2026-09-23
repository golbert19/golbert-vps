#!/usr/bin/env python3
# Golbert VPS Manager PRO - ws-proxy.py
# Proxy WS -> SSH Local - Estable para Ubuntu 22.04
import socket
import threading
import select

LISTEN_ADDR = '0.0.0.0'
LISTEN_PORT = 80  # WS NO TLS
SSH_ADDR = '127.0.0.1'
SSH_PORT = 22
BUFLEN = 4096

def handle_client(client):
    try:
        # Leer handshake WS
        data = client.recv(BUFLEN).decode(errors='ignore')
        if not data:
            client.close()
            return
        
        # Respuesta WS simple 101
        if 'Upgrade: websocket' in data or 'upgrade' in data.lower():
            response = (
                'HTTP/1.1 
