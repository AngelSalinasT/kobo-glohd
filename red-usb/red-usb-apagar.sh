#!/bin/sh
# Apaga la red por USB: detiene dropbear, baja usb0 y descarga g_ether.
U=/mnt/onboard/.adds/usbnet
PIDF=/tmp/dropbear_usbnet.pid
LOG=$U/usbnet.log
log() { echo "$*"; echo "$(date '+%F %T') $*" >> "$LOG"; }
log "== apagar"
[ -f "$PIDF" ] && kill "$(cat $PIDF)" 2>/dev/null; rm -f "$PIDF"
ifconfig usb0 down 2>/dev/null
lsmod | grep -q '^g_ether' && rmmod g_ether >> "$LOG" 2>&1
log "OK: red USB apagada"
