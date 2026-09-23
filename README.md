# 🚀 GOLBERT VPS MEIN v4.3.2 - 101 OK
> Instalador automático para Ubuntu 22.04 limpio. FIX definitivo para `Premature`, `password incorrect`, `xray.service does not exist` y `400 Bad Request`. Optimizado para HTTP Custom / Injector / NapsternetV.

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?style=for-the-badge&logo=ubuntu)
![Bash](https://img.shields.io/badge/Installer-Bash-4EAA25?style=for-the-badge&logo=gnu-bash)
![Status](https://img.shields.io/badge/Status-101%20OK-brightgreen?style=for-the-badge)

## 📋 Descripción
Este no es el instalador genérico. Golbert MEIN instala una infraestructura de venta SSH/WS completa:
- **HAProxy + WS-Proxy Python** - Puente 80 -> 8080 -> 22 para `101 Switching Protocols`
- **Xray-Core** - Instalado correctamente para evitar `Unit file xray.service does not exist`
- **Dropbear 109/110, Stunnel 443, BadVPN UDPGW 7300**
- **SSH FIX** - Corrige `MaxStartups`, `usermod -s /bin/bash` y `chage -E -1` para evitar Premature.

## 🚀 Requisitos Previos
- Ubuntu 20.04+ / 22.04 limpio (recomendado 22.04)
- Acceso root
- 1GB RAM / 10GB Disco mínimo
- IP limpia

## 📥 Instalación - Todo en un Bloque

```bash
# OPCION 1 - OFICIAL RECOMENDADA
wget -4 -O setup https://raw.githubusercontent.com/golbert19/golbert-vps-mein/mein/setup && chmod +x setup && sudo ./setup

# OPCION 2 - UNA LINEA CURL
bash <(curl -sL https://raw.githubusercontent.com/golbert19/golbert-vps-mein/mein/setup)

# OPCION 3 - GIT CLONE
git clone https://github.com/golbert19/golbert-vps-mein.git && cd golbert-vps-mein && chmod +x setup && sudo ./setup

# ABRIR MENU DESPUES DE INSTALAR
golbert
