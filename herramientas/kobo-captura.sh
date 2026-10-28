#!/bin/sh
# Captura la pantalla del Kobo Glo HD (fb 8 bpp, stride 1088, visible 1072x1448) a PNG, desde la Mac.
# Requiere la red USB encendida y el alias "kobo" en ~/.ssh/config (ver docs/03-red-usb-y-ssh.md).
# Uso: herramientas/kobo-captura.sh [salida.png]
salida=${1:-/tmp/kobo-cap/pantalla.png}
mkdir -p "$(dirname "$salida")" /tmp/kobo-cap
off=$(ssh kobo 'cut -d, -f2 /sys/class/graphics/fb0/pan')
ssh kobo "dd if=/dev/fb0 bs=1088 skip=$off count=1448 2>/dev/null" > /tmp/kobo-cap/raw || exit 1
python3 - "$salida" <<'PY'
import sys
raw = open("/tmp/kobo-cap/raw", "rb").read()
w, s, h = 1072, 1088, 1448
filas = b"".join(raw[y*s:y*s+w] for y in range(h))
pgm = sys.argv[1].rsplit(".", 1)[0] + ".pgm"
open(pgm, "wb").write(b"P5 %d %d 255\n" % (w, h) + filas)
PY
sips -s format png "${salida%.*}.pgm" --out "$salida" >/dev/null && echo "$salida"
