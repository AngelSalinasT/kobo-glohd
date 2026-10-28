# 03 · Red USB y SSH

Entrar a la Kobo por el cable USB, sin Wi-Fi. Es lo que permite que un agente de IA (Claude Code, por ejemplo) instale archivos, lea registros, tome capturas de la pantalla y simule toques.

## Cómo funciona

`Herramientas/red-usb-encender.sh`:

1. Carga `g_ether.ko`, el módulo que ya trae el firmware de Kobo: el puerto USB se vuelve una tarjeta de red.
2. Pone `usb0` en `169.254.73.1` (link-local, sin DHCP).
3. Copia `.adds/usbnet/authorized_keys` a la configuración de SSH de KOReader y levanta el `dropbear` que trae KOReader en el puerto **2222**, **solo con llave** (sin contraseña).
4. Registra todo en `.adds/usbnet/usbnet.log`.

`red-usb-apagar.sh` hace lo contrario. Mientras la red está encendida no existe el modo almacenamiento USB (es el mismo puerto).

## Encenderla

Desde la Kobo, cualquiera de estas:

- Atajos (deslizar hacia abajo) › círculo "Red USB".
- Ajustes › Sistema › Avanzado › Red USB.
- Menú "Glo HD" › Red USB.
- Opción "red al conectar el cable": en lugar de preguntar por almacenamiento USB, enciende la red. Si eliges almacenamiento, la red se apaga sola antes.

Al desconectar el cable la red se apaga sola. Mientras está encendida se bloquea la espera ligera entre páginas, porque esa espera duerme el controlador USB y la computadora lo ve como una desconexión.

## Conectarse desde la computadora

En macOS la Kobo aparece como interfaz "RNDIS/Ethernet Gadget" y se asigna una IP link-local sola, sin `sudo`. En Linux suele aparecer como `usb0`/`enx…`; si no toma IP, asígnale una a mano (`169.254.73.2/16`).

Agrega esto a `~/.ssh/config`:

```
Host kobo
    HostName 169.254.73.1
    Port 2222
    User root
    UserKnownHostsFile ~/.ssh/known_hosts_kobo
```

Y prueba:

```sh
ssh kobo 'uname -a; cat /proc/loadavg'
```

## Conectar Claude Code (u otro agente)

Una vez que `ssh kobo` funciona, un agente puede hacer todo por SSH. Este repo trae dos skills para Claude Code en `.claude/skills/`:

- `instalar-glohd`: instala o actualiza el proyecto en la Kobo y lo verifica.
- `manejar-kobo`: ver la pantalla (captura del framebuffer), tocar y deslizar, leer registros y reiniciar KOReader sin tocar la Kobo.

Abre Claude Code en la carpeta del repo y pídele, por ejemplo: "instala esto en mi Kobo" o "abre la Biblioteca y toma una captura". Otros agentes pueden leer [AGENTS.md](../AGENTS.md).

## Herramientas que usan la red

| Herramienta | Dónde corre | Qué hace |
|---|---|---|
| `herramientas/kobo-captura.sh [salida.png]` | computadora | Copia `/dev/fb0` por SSH y lo convierte a PNG de 1072×1448. Usa `sips` (macOS); en Linux cambia la última línea por `convert` de ImageMagick. |
| `.adds/usbnet/tocar.lua X Y [ms]` | Kobo | Toque simulado. `ms` > 500 = toque largo. |
| `.adds/usbnet/tocar.lua X1 Y1 X2 Y2 desliz [ms_por_paso]` | Kobo | Deslizamiento. |

`tocar.lua` se corre con el `luajit` de KOReader:

```sh
ssh kobo 'cd /mnt/onboard/.adds/koreader && ./luajit /mnt/onboard/.adds/usbnet/tocar.lua 536 724'
```

Las coordenadas son de pantalla en vertical (0,0 arriba a la izquierda, 1072×1448). El táctil zForce tiene los ejes cruzados y X en espejo; `tocar.lua` ya hace la conversión.

## Notas

- Con el cable conectado el kernel no deja suspender (`Device or resource busy`). Para probar el sueño, desconecta y luego lee `dmesg`.
- Reiniciar KOReader matándolo por SSH no es limpio (no maneja `SIGTERM`). Mejor hazlo desde la interfaz, en persona o con toques simulados (ver la skill `manejar-kobo`).
