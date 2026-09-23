#!/bin/bash
# Golbert VPS Manager PRO - Ubuntu 22.04
if [ "$(id -u)" != "0" ]; then echo "Ejecuta como root"; exit 1; fi

apt update -y
apt install -y curl wget python3 python3-pip dropbear stunnel4 openvpn easy-rsa

# --- Crear comando golbert ---
curl -Ls https://raw.githubusercontent.com/golbert19/golbert-vps/main/menu.sh -o /usr/bin/golbert
curl -Ls https://raw.githubusercontent.com/golbert19/golbert-vps/main/ws-proxy.py -o /usr/local/bin/ws-proxy.py
chmod +x /usr/bin/golbert /usr/local/bin/ws-proxy.py

echo ""
echo "Golbert VPS instalado correctamente"
echo "Escribe: golbert para abrir el menu"
echo "Puertos: 109, 443, 80, 8180, 8080, 7300, 1194/udp, 5300, 8443, 8880"
