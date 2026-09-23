#!/bin/bash
# GOLBERT PANEL V4.3.2 LTS - MEIN - FIX 101 -> SSH OK
# Compatible con Ubuntu 20/22/24

G="\e[32m"; Y="\e[33m"; R="\e[31m"; C="\e[36m"; W="\e[0m"; B="\e[1m"
LICENSE="9773873C2BC34C6D-da22c5b8"
DB="/etc/golbert/users.db"
mkdir -p /etc/golbert /var/log/golbert

# FIX SSHD SIEMPRE AL ABRIR PANEL
fix_sshd(){
  sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
  sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null
  sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
  sed -i 's/#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config 2>/dev/null
  sed -i 's/#*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config 2>/dev/null
  grep -q "^Port 22" /etc/ssh/sshd_config || echo "Port 22" >> /etc/ssh/sshd_config
  systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
}

check_license(){
  [[ -f /etc/golbert/license.key ]] && LIC=$(cat /etc/golbert/license.key) || LIC=""
  if [[ "$LIC"!= "$LICENSE" ]]; then
    echo -e "${R}Licencia invalida${W}"; echo "$LICENSE" > /etc/golbert/license.key
  fi
}

banner(){
  clear
  IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
  DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "No domain")
  echo -e "${C}╔════════════════════════════════════════╗${W}"
  echo -e "${C}║${W} ${B}GOLBERT V4.3.2 LTS - MEIN - 101 OK${W} ${C}║${W}"
  echo -e "${C}║${W} IP: $IP ${C}║${W}"
  echo -e "${C}║${W} Dominio: $DOMAIN ${C}║${W}"
  echo -e "${C}╚════════════════════════════════════════╝${W}"
  echo ""
  echo -e "${Y}Servicios:${W}"
  systemctl is-active xray >/dev/null 2>&1 && echo -e " XRAY: ${G}ON${W}" || echo -e " XRAY: ${R}OFF${W}"
  systemctl is-active haproxy >/dev/null 2>&1 && echo -e " HAPROXY 80/443: ${G}ON${W}" || echo -e " HAPROXY: ${R}OFF${W}"
  systemctl is-active ws-proxy >/dev/null 2>&1 && echo -e " WS-PROXY 8080: ${G}ON${W}" || echo -e " WS-PROXY: ${R}OFF${W}"
  echo ""
  curl -s -i http://127.0.0.1:80/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | grep -E "101|200|400|302" | head -1 | sed "s/^/ WS 80: /"
  curl -sk -i https://127.0.0.1:443/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | grep -E "101|200|400|302" | head -1 | sed "s/^/ WS 443: /"
  echo ""
}

create_user(){
  fix_sshd
  echo -e "${B}=== CREAR USUARIO SSH ===${W}"
  read -p "Usuario: " USR
  read -p "Contraseña: " PASS
  read -p "Dias de validez [30]: " DIAS
  DIAS=${DIAS:-30}
  read -p "Limite de conexiones [1]: " LIM
  LIM=${LIM:-1}

  if id "$USR" &>/dev/null; then
    echo -e "${R}Usuario ya existe, eliminando...${W}"
    userdel -f "$USR" 2>/dev/null; pkill -u "$USR" 2>/dev/null || true
  fi

  # CREACION CORRECTA - SHELL VALIDO + NO EXPIRADO
  useradd -M -s /bin/bash "$USR" 2>/dev/null || adduser --disabled-password --gecos "" "$USR"
  echo "$USR:$PASS" | chpasswd
  chage -E -1 "$USR" 2>/dev/null
  chage -M 99999 "$USR" 2>/dev/null
  usermod -e "" "$USR" 2>/dev/null
  usermod -s /bin/bash "$USR"
  passwd -u "$USR" 2>/dev/null || true

  EXP=$(date -d "+$DIAS days" +"%Y-%m-%d")
  echo "$USR|$PASS|$EXP|$LIM|$(date +%Y-%m-%d)" >> "$DB"
  chage -E "$EXP" "$USR" 2>/dev/null || true

  echo ""
  echo -e "${G}Usuario creado OK - Prueba 101 -> SSH${W}"
  echo -e "Usuario: ${B}$USR${W}"
  echo -e "Pass: ${B}$PASS${W}"
  echo -e "Expira: $EXP"
  echo -e "Limite: $LIM"
  echo ""
  echo -e "${Y}Payload HTTP Injector:${W}"
  echo -e "80: GET / HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]"
  echo -e "443: GET / HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf] + SNI $DOMAIN"
  echo ""
  read -p "Enter para continuar..."
}

remove_user(){
  echo -e "${B}=== ELIMINAR USUARIO ===${W}"
  cat /etc/passwd | grep "/bin/bash" | grep -v root | cut -d: -f1 | nl
  read -p "Usuario a borrar: " USR
  userdel -f "$USR" 2>/dev/null
  pkill -u "$USR" 2>/dev/null || true
  sed -i "/^$USR|/d" "$DB" 2>/dev/null
  echo -e "${G}Borrado${W}"; sleep 1
}

list_users(){
  echo -e "${B}=== USUARIOS SSH ===${W}"
  printf "%-15s %-12s %-6s\n" "USUARIO" "EXPIRA" "CREADO" "LIM"
  echo "------------------------------------------------"
  if [[ -f $DB ]]; then
    while IFS='|' read -r u p exp lim cre; do
      if id "$u" &>/dev/null; then
        printf "%-15s %-12s %-12s %-6s\n" "$u" "$exp" "$cre" "$lim"
      fi
    done < "$DB"
  else
    cat /etc/passwd | grep "/bin/bash" | grep -v root | cut -d: -f1 | while read u; do echo "$u"; done
  fi
  echo ""; read -p "Enter..."
}

monitor(){
  echo -e "${B}=== CONEXIONES ACTIVAS ===${W}"
  echo -e "${Y}SSH:${W}"; ss -tnp | grep sshd | grep ESTAB || echo "Ninguna"
  echo ""; echo -e "${Y}HAPROXY 80/443:${W}"; ss -tnp | grep haproxy | head -20
  echo ""; echo -e "${Y}WS-PROXY 8080:${W}"; ss -tnp | grep 8080
  echo ""; read -p "Enter..."
}

restart_all(){
  echo -e "${Y}Reiniciando...${W}"
  fix_sshd
  systemctl restart ws-proxy haproxy xray stunnel4 badvpn 2>/dev/null
  echo -e "${G}Reiniciado - Test 101:${W}"
  curl -i http://127.0.0.1:80/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | grep 101
  curl -ik https://127.0.0.1:443/ -H "Upgrade: websocket" -H "Connection: Upgrade" 2>&1 | grep 101
  sleep 2
}

# MAIN
check_license
fix_sshd
while true; do
  banner
  echo -e "${B}1.${W} Crear Usuario SSH (FIX 101->SSH)"
  echo -e "${B}2.${W} Eliminar Usuario"
  echo -e "${B}3.${W} Listar Usuarios"
  echo -e "${B}4.${W} Monitor Conexiones"
  echo -e "${B}5.${W} Reiniciar Servicios + Test 101"
  echo -e "${B}6.${W} Ver Log WS-Proxy"
  echo -e "${B}0.${W} Salir"
  echo ""
  read -p "Opcion: " OP
  case $OP in
    1) create_user ;;
    2) remove_user ;;
    3) list_users ;;
    4) monitor ;;
    5) restart_all ;;
    6) journalctl -u ws-proxy -n 50 --no-pager; read -p "Enter..." ;;
    0) exit 0 ;;
  esac
done
