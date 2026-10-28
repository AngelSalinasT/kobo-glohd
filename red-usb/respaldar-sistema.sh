#!/bin/sh
# Respaldo de SOLO LECTURA del sistema interno (rootfs) + diagnóstico de energía.
# No modifica nada fuera de /mnt/onboard/respaldo-sistema.
# Ejecutar desde KOReader: mantener presionado el archivo -> "Ejecutar script".

OUT=/mnt/onboard/respaldo-sistema/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT" || exit 1
cd / || exit 1

# --- Sistema interno completo (sin directorios virtuales ni la memoria de usuario)
DIRS=""
for d in *; do
	case "$d" in
		proc|sys|dev|tmp|mnt|var|run|media) ;;
		*) [ -e "$d" ] && DIRS="$DIRS $d" ;;
	esac
done
tar czf "$OUT/rootfs.tgz" $DIRS 2> "$OUT/tar-errores.txt"
sha1sum /etc/init.d/rcS > "$OUT/rcS.sha1"
cp /etc/init.d/rcS "$OUT/rcS"

# --- Diagnóstico de energía / despertar
{
	echo "== fecha"; date
	echo "== uname"; uname -a
	echo "== /sys/power"; for f in /sys/power/*; do [ -f "$f" ] && echo "$f: $(cat "$f" 2>&1)"; done
	echo "== fuentes de wakeup"; find /sys/devices -path '*power/wakeup' 2>/dev/null | while read f; do echo "$f: $(cat "$f" 2>&1)"; done
	echo "== interrupciones"; cat /proc/interrupts
	echo "== input"; cat /proc/bus/input/devices
	echo "== memoria"; free; cat /proc/meminfo
	echo "== cpu"; cat /proc/cpuinfo
	for f in /sys/devices/system/cpu/cpu0/cpufreq/*; do [ -f "$f" ] && echo "$f: $(cat "$f" 2>&1)"; done
	echo "== montajes"; mount
	echo "== procesos"; ps
	echo "== modulos"; lsmod 2>/dev/null; cat /proc/modules
	echo "== bateria"; for f in /sys/class/power_supply/*/*; do [ -f "$f" ] && echo "$f: $(cat "$f" 2>&1)"; done
} > "$OUT/diagnostico.txt" 2>&1
dmesg > "$OUT/dmesg.txt" 2>&1

sync
echo "Listo. Respaldo en $OUT ($(du -sh "$OUT" | cut -f1))"
