#!/bin/bash
#!/bin/bash
# GOLBERT VPS - Sistema de Licencias de 1 solo uso
MI_IP=$(curl -s https://api.ipify.org || wget -qO- https://api.ipify.org)
SERVIDOR="http://23.134.76.218:5000"

# Si el cliente ya viene con KEY=XXXX en el comando, la usa. Si no, la pide.
if [[ -z "$KEY" ]]; then
  echo -e "\e[1;31m\e[1m GOLBERT VPS PERU - LICENCIA REQUERIDA\e[0m"
  echo -n "Ingrese su KEY: "
  read KEY
fi

echo "Validando KEY $KEY para IP $MI_IP..."
VALID=$(curl -s --connect-timeout 10 "$SERVIDOR/validate?key=$KEY&ip=$MI_IP")

if [ "$VALID" != "OK" ]; then
  if [[ $VALID == USADA:* ]]; then
    echo -e "\e[91m❌ Esta KEY ya fue usada en IP ${VALID#USADA:}\e[0m"
    echo "Contacta a @golbertperuvps para nueva licencia"
  else
    echo -e "\e[91m❌ KEY INVALIDA. Compra en @golbertperuvps\e[0m"
  fi
  exit 1
fi

echo -e "\e[92m✅ KEY Valida (1 solo uso) - Instalando Golbert VPS...\e[0m"
sleep 2

# --- A PARTIR DE AQUI TU INSTALACION NORMAL ---
# GOLBERT VPS PRO v2 - LICENCIA TELEGRAM - FULL
if [ "$(id -u)"!= "0" ]; then echo "Ejecuta como root"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

# --- CONFIG TELEGRAM ---
BOT_TOKEN="8755182170:AAFsK1-SieQjCKYlNNwY9B_uCS9ArNemC0w"
CHAT_ID="8823167645"

IP=$(curl -s ipv4.icanhazip.com)
KEY=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | cut -c1-16 | tr 'a-z' 'A-Z')
MACHINE=$(cat /etc/machine-id | cut -c1-8)
LICENSE="$KEY-$MACHINE"

mkdir -p /etc/golbert
echo "$LICENSE" > /etc/golbert/license.key
echo "$IP | $LICENSE | $(date)" > /etc/golbert/info.txt

# --- AVISO A TU TELEGRAM ---
MSG="🔑 NUEVA INSTALACION GOLBERT%0A%0A🌐 IP: $IP%0A🔑 KEY: $LICENSE%0A📅 Fecha: $(date)%0A%0AAgrega este KEY a keys.txt para autorizar"
curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$MSG" > /dev/null 2>&1

# --- INSTALACION PUERTOS ---
apt update -y
apt install -y dropbear stunnel4 curl wget python3 python3-pip screen qrencode unzip

# Dropbear 109
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
systemctl enable dropbear --now

# Stunnel 443
mkdir -p /etc/stunnel
openssl req -new -x509 -days 3650 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem -subj "/CN=$IP" >/dev/null 2>&1
cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
[dropbear]
accept = 443
connect = 127.0.0.1:109
EOF
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable stunnel4 --now
systemctl restart stunnel4

# WS Proxy 80,8080,8180,8880
curl -Ls https://raw.githubusercontent.com/golbert19/golbert-vps/main/ws-proxy.py -o /usr/local/bin/ws-proxy.py
chmod +x /usr/local/bin/ws-proxy.py
for P in 80 8080 8180 8880; do
cat > /etc/systemd/system/ws-proxy-$P.service <<EOL
[Unit]
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py $P
Restart=always
[Install]
WantedBy=multi-user.target
EOL
systemctl daemon-reload
systemctl enable ws-proxy-$P --now
done

# Comando golbert
curl -Ls https://raw.githubusercontent.com/golbert19/golbert-vps/main/menu.sh -o /usr/bin/golbert
chmod +x /usr/bin/golbert

echo "========================================="
echo " GOLBERT INSTALADO"
echo " IP: $IP"
echo " KEY: $LICENSE"
echo " Comando: golbert"
echo "========================================="
