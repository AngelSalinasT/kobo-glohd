#!/bin/sh
# Compila los módulos para el kernel 3.0.35+ de la Kobo Glo HD.
# El kernel se extrae en una imagen case-sensitive (macOS no distingue mayúsculas por defecto).
# WORK = carpeta de trabajo con espacio (~6 GB); por defecto ./.build dentro del repo.
# Uso: ./build.sh            (la primera vez descarga y compila el kernel, ~10 min)
set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$REPO/.build}"
IMG="$WORK/kobokernel.sparseimage"
VOL=/Volumes/kobokernel
URL=https://raw.githubusercontent.com/kobolabs/Kobo-Reader/master/hw/imx6sl-glohd/kernel.tar.bz2

mkdir -p "$WORK/src"
[ -f "$IMG" ] || hdiutil create -size 6g -type SPARSE -fs "Case-sensitive APFS" -volname kobokernel "$IMG"
[ -d "$VOL" ] || hdiutil attach "$IMG" -nobrowse
if [ ! -f "$VOL/linux/Makefile" ]; then
	[ -f "$WORK/src/kernel.tar.bz2" ] || curl -sSL -o "$WORK/src/kernel.tar.bz2" "$URL"
	mkdir -p "$VOL/linux" && tar xjf "$WORK/src/kernel.tar.bz2" -C "$VOL/linux"
	cp "$REPO/kernel/config-3.0.35+" "$VOL/linux/.config"
fi

docker ps -a --format '{{.Names}}' | grep -qx kobo-build || {
	docker run -d --name kobo-build --platform linux/amd64 -v "$VOL:/work" -v "$REPO:/repo" ubuntu:14.04 sleep infinity
	docker exec kobo-build sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gcc-arm-linux-gnueabihf make bc'
}
docker start kobo-build >/dev/null

docker exec kobo-build sh -c '
set -e
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
cd /work/linux
if [ ! -f Module.symvers ]; then
	yes "" | make oldconfig >/dev/null
	make -j8 zImage modules >/work/build.log 2>&1
fi
make LOCALVERSION=+ prepare >/dev/null 2>&1   # vermagic "3.0.35+" como el del Kobo
for d in modulos/kobowake experimentos/kobowake_diag; do
	m=$(basename $d)
	make -C /work/linux M=/repo/$d modules
	cp /repo/$d/$m.ko /repo/dist/
done'
echo "Listo: $REPO/dist"
