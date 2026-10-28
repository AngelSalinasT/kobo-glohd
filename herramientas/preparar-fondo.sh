#!/bin/sh
# Prepara una imagen como fondo de bloqueo para la Glo HD: llena 1072x1448 recortando al centro,
# grises, 16 niveles (lo que muestra la pantalla) con dithering Floyd-Steinberg.
# Uso: [RECORTAR=1] preparar-fondo.sh <imagen> <carpeta_salida> [nombre]
#   RECORTAR=1 quita bordes lisos (p. ej. bandas blancas) antes de llenar la pantalla.
set -e
IN="$1"; OUTDIR="$2"; mkdir -p "$OUTDIR"
NAME="${3:-$(basename "${IN%.*}")}"
TRIM=""; [ "${RECORTAR:-0}" = 1 ] && TRIM="-fuzz 8% -trim +repage"
OUT="$OUTDIR/$NAME.png"
# Paleta de 16 grises exactos (0x00, 0x11, ..., 0xFF) para que el dithering use los niveles del panel.
PAL="$(mktemp -t pal16).png"
magick -size 1x16 gradient:black-white -depth 8 -colorspace Gray "$PAL"
magick "$IN" -auto-orient $TRIM -colorspace Gray -resize '1072x1448^' -gravity center -extent 1072x1448 \
	-dither FloydSteinberg -remap "$PAL" -strip "$OUT"
rm -f "$PAL"
echo "ok: $OUT ($(magick identify -format '%wx%h %[colorspace] %k grises' "$OUT"))"
