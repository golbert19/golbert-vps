#!/bin/bash
# MENU GOLBERT PRO v2 - Ubuntu 22.04
# Funciones: Crear user con expiracion, QR V2Ray, Monitor

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

crear_usuario(){
  clear
  echo -e "${CYAN}=== CREAR USUARIO SSH ===${NC}"
  read -p "Nombre de usuario: " username
  if id "$username" &>/dev/null; then echo -e "${RED}El usuario ya existe${NC}"; sleep 2; return; fi
  read -p "Contraseña: " password
  read -p "Dias de validez [30]: " dias
  dias=${dias:-30}
  
  useradd -M -s /bin/false $username
  echo "$username:$password" | chpasswd
  chage -E $(date -d "+$dias days" +%Y-%m-%d) $username
  
  echo -e "${GREEN}Usuario creado!${NC}"
  echo "User: $username | Pass: $password | Expira: $dias dias"
  echo "$username | $password | $dias dias | $(date)" >> /root/usuarios.txt
  read -p "Enter para volver..."
}

ver_usuarios(){
  clear
  echo -e "${CYAN}=== USUARIOS ACTIVOS ===${NC}"
  cat /root/usuarios.txt 2>/dev/null || echo "No hay registro"
  echo ""
  echo "--- Usuarios del sistema con expiracion ---"
  for u in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do
    exp=$(chage -l $u 2>/dev/null | grep Account | cut -d: -f2)
    echo "$u $exp"
  done
  read -p "Enter..."
}

borrar_usuario(){
  read -p "Usuario a borrar: " username
  userdel -r $username 2>/dev/null
  pkill -u $username
  sed -i "/^$username/d" /root/usuarios.txt
  echo "Borrado"
  sleep 1
}

monitor(){
  clear
  echo -e "${CYAN}=== CONEXIONES ACTIVAS ===${NC}"
  echo "Dropbear / SSH:"
  ps aux | grep dropbear | grep -v grep
  echo ""
  echo "Puertos escuchando:"
  ss -tulpn | grep -E '109|443|80|8080|8180|7300|1194|8444'
  read -p "Enter..."
}

v2ray_qr(){
  clear
  echo -e "${CYAN}=== V2RAY / XRAY REALITY ===${NC}"
  cat /usr/local/etc/xray/config.json
  echo ""
  UUID=$(grep -o '"id": "[^"]*"' /usr/local/etc/xray/config.json | head -1 | cut -d'"' -f4)
  echo -e "${YELLOW}Tu UUID:${NC} $UUID"
  echo -e "${YELLOW}IP:${NC} $IP | Puerto: 8444"
  echo ""
  # Link VLESS
  LINK="vless://$UUID@$IP:8444?security=reality&sni=www.google.com&fp=chrome&type=tcp#Golbert-PRO-$IP"
  echo $LINK
  echo ""
  echo $LINK | qrencode -t ANSIUTF8
  read -p "Enter..."
}

reiniciar(){
  systemctl restart dropbear stunnel4 ws-proxy 2>/dev/null; systemctl restart xray 2>/dev/null; pkill badvpn; screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
  echo -e "${GREEN}Servicios reiniciados${NC}"
  sleep 2
}

while true; do
clear
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${GREEN}GOLBERT VPS MANAGER PRO - UBUNTU 22${NC} ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} IP: $IP"
echo -e "${CYAN}║${NC} DROPBEAR 109 | TLS 443 | WS 80/8080/8180"
echo -e "${CYAN}║${NC} BADVPN 7300 | OPENVPN 1194 | XRAY 8444"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo "1) Crear usuario con expiracion"
echo "2) Ver usuarios"
echo "3) Borrar usuario"
echo "4) Monitor de conexiones y puertos"
echo "5) Ver QR y Link V2Ray REALITY"
echo "6) Reiniciar todos los servicios"
echo "0) Salir"
echo ""
read -p "Elige: " opt
case $opt in
 1) crear_usuario ;;
 2) ver_usuarios ;;
 3) borrar_usuario ;;
 4) monitor ;;
 5) v2ray_qr ;;
 6) reiniciar ;;
 0) exit 0 ;;
esac
done
