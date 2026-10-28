#!/bin/sh
# Convierte .cbr/.cbz a .cbz en grises al tamaño de la Glo HD (1072x1448), JPEG q85, sin recompresión zip.
# Medido en el Kobo: Punpun 02 pasó de ~1130 ms a ~86 ms por página (168 MB -> 77 MB).
# Uso: convertir-manga.sh <archivo.cbr|cbz> <carpeta_salida>
set -e
IN="$1"; OUTDIR="$2"
NAME="$(basename "$IN")"; NAME="${NAME%.*}"
OUT="$OUTDIR/$NAME.cbz"
[ -f "$OUT" ] && { echo "ya existe: $OUT"; exit 0; }
TMP="$(mktemp -d "${TMPDIR_SSD:-${TMPDIR:-/tmp}}/conv.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src" "$TMP/out" "$OUTDIR"
case "$IN" in
	*.cbr|*.rar) unrar x -idq "$IN" "$TMP/src/" ;;
	*) unzip -qq "$IN" -d "$TMP/src" ;;
esac
n=0
find "$TMP/src" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | LC_ALL=C sort | while read -r f; do
	n=$((n + 1))
	magick "$f" -colorspace Gray -resize '1072x1448>' -quality 85 "$TMP/out/$(printf '%04d' $n).jpg"
done
(cd "$TMP/out" && zip -q -0 "$OUT.part" ./*.jpg) && mv "$OUT.part" "$OUT"
echo "ok: $OUT ($(du -h "$OUT" | cut -f1))"
