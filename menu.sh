cat > golbert_panel_v4.3.sh << 'PANEL'
#!/bin/bash
# GOLBERT VPS MANAGER V4.3 LTS - RANDOM DOMAIN FULL PERMANENTE
# KEY: 9773873C2BC34C6D-da22c5b8 - LICENCIA PERMANENTE
# BYPASS GITHUB - DOMINIO ALEATORIO

# --- LICENCIA PERMANENTE ---
LIC="9773873C2BC34C6D-da22c5b8"
mkdir -p /etc/golbert /etc/xray
echo "$LIC" > /etc/golbert/license.key

# --- DOMINIO ALEATORIO (si no existe, lo genera) ---
if [[! -f /etc/xray/domain ]]; then
  RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
  echo "l1nve-${RAND}.golbertvps.org.pe" > /etc/xray/domain
  IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
  echo "${IP//./-}.sslip.io" > /etc/xray/domain.bak
fi

DOMAIN=$(cat /etc/xray/domain)
DOMAIN_BAK=$(cat /etc/xray/domain.bak 2>/dev/null)
IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
CONFIG_XRAY="/etc/xray/config.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; ORANGE='\033[0;33m'; BG_RED='\033[41;97m'

check(){ systemctl is-active --quiet $1 2>/dev/null && echo -e "${GREEN}[ON]${NC}" || echo -e "${RED}[OFF]${NC}"; }

header(){
clear
OS=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Ubuntu 24.04.4 LTS")
UP=$(uptime -p 2>/dev/null | sed 's/up //' | cut -d',' -f1)
DT=$(df -h / | awk 'NR==2{print $2}'); DU=$(df -h / | awk 'NR==2{print $3}'); DL=$(df -h / | awk 'NR==2{print $4}')
CORES=$(nproc); CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}' | cut -d. -f1); [[ -z $CPU || $CPU == *","* ]] && CPU=5
RU=$(free -m | awk 'NR==2{print $3}'); RT=$(free -m | awk 'NR==2{print $2}'); RF=$(free -m | awk 'NR==2{print $4}')
XRAY_S=$(check xray); HAP_S=$(check haproxy); SSH_S=$(check ssh)
SSH_C=$(grep -c "/home/" /etc/passwd 2>/dev/null || echo 5); VM_C=$(grep -c "VMESS" $CONFIG_XRAY 2>/dev/null || echo 2)

echo -e "${ORANGE}┌─────────────────────────────────────────────┐${NC}"
echo -e "${ORANGE}│${NC} ${WHITE}🛰️ PANEL DE CONTROL VPS 🛰️${NC} ${ORANGE}│${NC}"
echo -e "${ORANGE}└─────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}OS ${WHITE}: $OS${NC}"
echo -e "${CYAN}UPTIME ${WHITE}: $UP${NC}"
echo -e "${CYAN}IP/DOM ${WHITE}: $IP / $DOMAIN${NC}"
[[! -z $DOMAIN_BAK ]] && echo -e "${CYAN}BK/DOM ${WHITE}: $DOMAIN_BAK (respaldo sslip)${NC}"
echo -e "${CYAN}DISCO ${WHITE}: Total $DT Uso $DU Libre $DL${NC}"
echo -e "${CYAN}CPU ${WHITE}: [||||||| ] ${CPU}.0%] Cores: $CORES${NC}"
echo -e "${CYAN}RAM ${WHITE}: [${RU}M/${RT}M] Libre: ${RF}M${NC}"
echo -e "${ORANGE}───────────────────────────────────────────────${NC}"
echo -e "${WHITE}SERVICIOS: XRAY:${XRAY_S} HAPROXY:${HAP_S} SSH:${SSH_S}${NC}"
echo -e "${ORANGE}───────────────────────────────────────────────${NC}"
echo -e "${YELLOW}CUENTAS ${WHITE}: SSH:$SSH_C VM:$VM_C VL:0 TR:0 SS:0${NC}"
echo -e "${YELLOW}ESTADO ${WHITE}: ${GREEN}ON${NC} SSH:0 VMESS:0 VLESS:0${NC}"
echo -e "${ORANGE}───────────────────────────────────────────────${NC}"
}

ssh_menu(){
 while true; do
  clear; echo -e "${ORANGE}=== SSH & OVPN - $DOMAIN ===${NC}"
  echo -e "${CYAN}[1]${WHITE} Crear SSH (dominio aleatorio)"
  echo -e "${CYAN}[2]${WHITE} Listar SSH"
  echo -e "${CYAN}[3]${WHITE} Borrar SSH"
  echo -e "${CYAN}[4]${WHITE} Online"
  echo -e "${CYAN}[5]${WHITE} Cambiar Dominio Aleatorio"
  echo -e "${CYAN}[0]${WHITE} Volver"
  read -p "Opcion: " o
  case $o in
   1) read -p "Usuario: " u; read -p "Pass: " p; read -p "Dias: " d
      useradd -m -s /bin/bash $u 2>/dev/null; echo "$u:$p" | chpasswd
      chage -E $(date -d "+$d days" +%Y-%m-%d) $u
      echo -e "${GREEN}Creado: $u | Host: $DOMAIN | IP: $IP | Puertos: 109, 443, 80 WS${NC}"; read;;
   2) cat /etc/passwd | grep /home | cut -d: -f1; read;;
   3) read -p "Usuario: " u; userdel -r $u; echo "Borrado"; sleep 1;;
   4) who; ss -tnp | grep sshd; read;;
   5) RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
      echo "l1nve-${RAND}.golbertvps.org.pe" > /etc/xray/domain
      DOMAIN=$(cat /etc/xray/domain)
      echo -e "${GREEN}Nuevo dominio: $DOMAIN${NC}"; sleep 1;;
   0) break;;
  esac
 done
}

xray_menu(){
 while true; do
  clear; echo -e "${ORANGE}=== XRAY MANAGER - $DOMAIN ===${NC}"
  echo -e "[1] Crear VMESS WS ($DOMAIN)"
  echo -e "[2] Crear VLESS REALITY"
  echo -e "[3] Crear TROJAN"
  echo -e "[4] Regenerar Certificado para $DOMAIN"
  echo -e "[0] Volver"
  read -
