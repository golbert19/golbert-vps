#!/bin/bash

# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar OpenVPN
sudo apt install openvpn easy-rsa -y

# Instalar y configurar V2Ray
bash <(curl -s -L https://git.io/v2ray.sh)

# Instalar Dropbear
sudo apt install dropbear -y

# Instalar BadVPN
sudo apt install build-essential cmake git -y
git clone https://github.com/ambrop72/badvpn.git
cd badvpn && mkdir build && cd build
cmake .. && make && sudo make install
cd ../.. && rm -rf badvpn

# Instalar Stunnel
sudo apt install stunnel4 -y

# Configuración de BadVPN
echo "alias badvpn-udpgw='badvpn-udpgw --listen-address 0.0.0.0:7300'" >> ~/.bashrc
source ~/.bashrc

# Permitir puertos en el firewall
sudo ufw allow 22/tcp    # SSH Directo
sudo ufw allow 8080/tcp  # TCP BHTTP
sudo ufw allow 8180/udp  # UDP HCR
sudo ufw allow 109/tcp   # Dropbear
sudo ufw allow 443/tcp   # SSL / TLS (Stunnel)
sudo ufw allow 7300/udp  # BadVPN
sudo ufw allow 80/tcp    # SSH Proxy HTTP y WS
sudo ufw allow 1194/udp  # OpenVPN

# Iniciar servicios
sudo systemctl start openvpn@server
sudo systemctl start dropbear
badvpn-udpgw --listen-address 0.0.0.0:7300 &

# Proporcionar estado de servicios
echo "Servicios iniciados correctamente."
