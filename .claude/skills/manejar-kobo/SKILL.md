---
name: manejar-kobo
description: Operar una Kobo Glo HD con este proyecto por SSH sobre el cable USB: ver la pantalla (captura del framebuffer), tocar y deslizar con toques simulados, leer registros, copiar archivos y reiniciar KOReader. Úsala cuando haya que probar la interfaz, revisar qué muestra la Kobo, depurar el plugin glohd o moverse dentro del e-reader sin que la persona lo toque.
---

# Manejar la Kobo por SSH

Todo pasa por `ssh kobo`. Si no conecta, la red USB está apagada: pide a la persona que la encienda (Atajos › Red USB, o Ajustes › Sistema › Avanzado › Red USB) con el cable conectado. Configuración en `docs/03-red-usb-y-ssh.md`.

```sh
ssh -o ConnectTimeout=5 kobo 'echo ok; cat /sys/class/power_supply/mc13892_bat/capacity 2>/dev/null'
```

## Ver la pantalla

```sh
herramientas/kobo-captura.sh /tmp/kobo-cap/pantalla.png
```

Luego abre el PNG (con la herramienta de lectura de imágenes) y míralo **antes** de decidir dónde tocar. La pantalla es 1072×1448 en vertical. Si KOReader está girado, la captura sale de lado: ten en cuenta la rotación al calcular coordenadas.

Para ver una transición (por ejemplo, si algo parpadea), graba cuadros en bucle dentro de la Kobo y conviértelos después con la misma lógica de `kobo-captura.sh`:

```sh
ssh kobo 'mkdir -p /tmp/cap; i=0; while [ $i -lt 20 ]; do dd if=/dev/fb0 of=/tmp/cap/$i.raw bs=1088 count=1448 2>/dev/null; i=$((i+1)); usleep 150000; done'
```

## Tocar y deslizar

`tocar.lua` debe estar en `/mnt/onboard/.adds/usbnet/` y se corre con el `luajit` de KOReader. Define un atajo:

```sh
T='cd /mnt/onboard/.adds/koreader && ./luajit /mnt/onboard/.adds/usbnet/tocar.lua'
ssh kobo "$T 536 724"                 # toque
ssh kobo "$T 536 724 800"             # toque largo (> 500 ms)
ssh kobo "$T 536 10 536 900 desliz"   # deslizar hacia abajo desde arriba = Atajos
ssh kobo "$T 900 724 150 724 desliz"  # deslizar a la izquierda = página siguiente / siguiente hoja
ssh kobo "$T 105 485 1000 485 desliz 60"   # arrastre lento (deslizadores)
```

Coordenadas de pantalla en vertical, (0,0) arriba a la izquierda. Después de cada gesto espera ~1 s (la tinta electrónica tarda) y toma otra captura para confirmar.

Gestos de la interfaz:

| Gesto | Dónde | Resultado |
|---|---|---|
| Toque arriba o abajo | dentro de un libro | Barra de lectura |
| Deslizar hacia abajo desde el borde superior | libro o Biblioteca | Atajos |
| Deslizar a los lados | Biblioteca, Archivos | Cambiar de hoja |
| Deslizar vertical en el cuarto izquierdo | libro o Biblioteca | Brillo |
| Toque largo | portada, saga, archivo | Hoja de acciones |
| Botón ⏻ de los Atajos (arriba a la derecha) | Atajos | Apagar / reiniciar |

## Reiniciar KOReader

No lo mates por SSH (no maneja `SIGTERM` y puede perder ajustes). Por toques: abre los Atajos, toca ⏻ y desliza el control de "Reiniciar KOReader". La última posición medida fue ⏻ en (983,78) y el deslizador en y=485, pero **confírmalo con una captura** antes de deslizar: los otros controles apagan o reinician la Kobo.

## Registros y estado

| Qué | Dónde (en la Kobo) |
|---|---|
| Registro de KOReader (errores de Lua del plugin) | `/mnt/onboard/.adds/koreader/crash.log` |
| Red USB | `/mnt/onboard/.adds/usbnet/usbnet.log` |
| Batería | `/mnt/onboard/.adds/usbnet/bateria.csv` |
| Arranque | `/mnt/onboard/.kobo/koreader-boot.log`, `.kobo/arranque-avisos.log` |
| Botón / kobowake | `dmesg \| grep -i kobowake`, `lsmod` |
| Ajustes del plugin | claves `glohd_*` en `/mnt/onboard/.adds/koreader/settings.reader.lua` |

```sh
ssh kobo 'tail -50 /mnt/onboard/.adds/koreader/crash.log'
```

## Copiar archivos

```sh
scp -r koreader/plugins/glohd.koplugin kobo:/mnt/onboard/.adds/koreader/plugins/
```

Antes de sobrescribir, guarda una copia en la Kobo (`cp -r glohd.koplugin glohd.koplugin.antes`) o en la computadora. Los cambios en Lua se ven después de reiniciar KOReader.

## Cuidado

- Con el cable conectado la Kobo no se suspende. Las pruebas de sueño y batería se hacen desconectada.
- No toques `/etc`, el firmware ni las particiones sin que la persona lo pida.
- Para mangas de prueba usa un archivo pequeño: abrir mangas grandes a color tarda segundos.
