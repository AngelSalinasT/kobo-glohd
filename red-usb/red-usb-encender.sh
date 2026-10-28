#!/bin/sh
# Red por cable USB + SSH (mod propio, no toca el firmware).
# Carga g_ether (USB como tarjeta de red), pone IP link-local y levanta el dropbear de KOReader solo con llave.
# Para apagar: red-usb-apagar.sh (o reiniciar el Kobo).
U=/mnt/onboard/.adds/usbnet
KO=/mnt/onboard/.adds/koreader
IP=169.254.73.1
PIDF=/tmp/dropbear_usbnet.pid
LOG=$U/usbnet.log
log() { echo "$*"; echo "$(date '+%F %T') $*" >> "$LOG"; }

if [ -z "$PLATFORM" ]; then
	PLATFORM="$(ntx_hwconfig -s -p /dev/mmcblk0 CPU 2>/dev/null)-ntx"
fi
MOD=/drivers/$PLATFORM/usb/gadget/g_ether.ko
log "== encender (PLATFORM=$PLATFORM)"

if lsmod | grep -qE '^g_(file|mass)_storage'; then
	log "ERROR: el modo almacenamiento USB está activo. Desconecta y vuelve a intentar."
	exit 1
fi
if ! lsmod | grep -q '^g_ether'; then
	insmod "$MOD" >> "$LOG" 2>&1 || { log "ERROR: no cargó $MOD"; exit 1; }
	sleep 2
fi
ifconfig usb0 $IP netmask 255.255.0.0 up >> "$LOG" 2>&1 || { log "ERROR: no subió usb0"; exit 1; }

mkdir -p "$KO/settings/SSH"
cp "$U/authorized_keys" "$KO/settings/SSH/authorized_keys"
[ -d /dev/pts ] || { mkdir -p /dev/pts; mount -t devpts devpts /dev/pts; }

if [ -f "$PIDF" ] && [ -d "/proc/$(cat $PIDF)" ]; then
	log "dropbear ya estaba corriendo"
else
	cd "$KO" && ./dropbear -E -R -s -p 2222 -P "$PIDF" >> "$LOG" 2>&1 || { log "ERROR: dropbear no arrancó"; exit 1; }
fi
log "OK: ssh -p 2222 root@$IP"
