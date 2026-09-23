# --- AUTO-UPDATE GOLBERT V4.3 ---
if [[ "$1" == "--update" || "$1" == "-u" ]]; then
  echo -e "\033[0;36m[UPDATE] Descargando última versión desde GitHub...\033[0m"
  RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n1)
  NEW_DOMAIN="l1nve-${RAND}.golbertvps.org.pe"
  echo $NEW_DOMAIN > /etc/xray/domain
  echo -e "Nuevo dominio aleatorio: $NEW_DOMAIN"
  
  # Descarga panel nuevo
  wget -O /usr/bin/golbert https://raw.githubusercontent.com/golbert19/golbert-vps/main/golbert_panel_v4.3.sh -q
  chmod +x /usr/bin/golbert; cp /usr/bin/golbert /bin/golbert
  
  # Descarga configs base nuevos
  wget -O /etc/xray/config.json https://raw.githubusercontent.com/golbert19/golbert-vps/main/xray-config-base.json -q
  wget -O /etc/haproxy/haproxy.cfg https://raw.githubusercontent.com/golbert19/golbert-vps/main/haproxy.cfg -q
  wget -O /etc/stunnel/stunnel.conf https://raw.githubusercontent.com/golbert19/golbert-vps/main/stunnel.conf -q
  wget -O /etc/systemd/system/badvpn.service https://raw.githubusercontent.com/golbert19/golbert-vps/main/badvpn.service -q
  
  # Regenera cert con nuevo dominio
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/xray/certs/xray.key \
    -out /etc/xray/certs/xray.crt \
    -subj "/CN=$NEW_DOMAIN" 2>/dev/null
  cat /etc/xray/certs/xray.crt /etc/xray/certs/xray.key > /etc/xray/certs/xray.pem
  
  # Regenera REALITY keys
  /usr/local/bin/xray x25519 > /etc/xray/reality.txt 2>&1
  PRIV=$(cat /etc/xray/reality.txt | grep Private | awk '{print $3}')
  PUB=$(cat /etc/xray/reality.txt | grep Public | awk '{print $3}')
  sed -i "s/PRIVATE_KEY_AUTO/$PRIV/" /etc/xray/config.json
  
  systemctl daemon-reload
  systemctl restart xray haproxy stunnel4 badvpn
  
  echo -e "\033[0;32m=== UPDATE COMPLETO V4.3 ===\033[0m"
  echo "Dominio: $NEW_DOMAIN"
  echo "IP: $(curl -s ifconfig.me)"
  echo "SSLIP: $(curl -s ifconfig.me | tr '.' '-').sslip.io"
  echo "Reality PUB: $PUB"
  exit 0
fi

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  echo "GOLBERT V4.3 LTS - KEY: 9773873C2BC34C6D-da22c5b8"
  echo "Dominio: $(cat /etc/xray/domain 2>/dev/null)"
  echo "IP: $(curl -s ifconfig.me 2>/dev/null)"
  exit 0
fi
