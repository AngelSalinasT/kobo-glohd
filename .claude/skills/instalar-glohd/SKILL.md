---
name: instalar-glohd
description: Instalar o actualizar kobo-glohd (plugin glohd.koplugin, parche de sistema, kobowake, red USB) en una Kobo Glo HD conectada a la computadora, y verificar que funciona. Úsala cuando pidan "instala esto en mi Kobo", "actualiza el plugin", "pásale los cambios a la Kobo" o al empezar con una Kobo nueva.
---

# Instalar kobo-glohd

Referencia completa: `docs/02-instalar.md`. Si la Kobo todavía no tiene KOReader, sigue antes `docs/01-koreader-desde-cero.md` con la persona.

## 1. Averiguar cómo está conectada

- **Almacenamiento USB**: aparece montada (macOS `/Volumes/KOBOeReader`, Linux `/media/*/KOBOeReader`). Ruta base = el punto de montaje.
- **Red USB**: `ssh -o ConnectTimeout=5 kobo true` funciona. Ruta base = `kobo:/mnt/onboard` (copiar con `scp`).
- Ninguna: pide a la persona que conecte el cable y elija "almacenamiento USB" en la Kobo.

## 2. Confirmar que es una Glo HD

Debe existir `.adds/koreader/` en la memoria. Por SSH, además: `uname -r` debe ser `3.0.35+`. Si en `.adds/koreader/crash.log` aparece el modelo, debe ser `Kobo_alyssum`. Si es otra Kobo, **no copies `kobowake.ko`** y avisa que el resto no está probado.

## 3. Respaldar lo que se va a sobrescribir

Copia a la computadora (por ejemplo `~/kobo-respaldo-AAAAMMDD/`): `.adds/koreader/plugins/glohd.koplugin` (si existe), `.adds/koreader/patches/`, `.adds/koreader/defaults.custom.lua`, `.adds/koreader/settings.reader.lua` y `.adds/usbnet/`.

Si ya existe un `defaults.custom.lua` distinto, no lo pises: muéstrale a la persona las diferencias y junten los valores.

## 4. Copiar

Con almacenamiento USB (`KOBO` = punto de montaje):

```sh
mkdir -p "$KOBO/.adds/koreader/plugins" "$KOBO/.adds/koreader/patches" "$KOBO/.adds/usbnet/modulos" "$KOBO/Herramientas"
rm -rf "$KOBO/.adds/koreader/plugins/glohd.koplugin"
cp -R koreader/plugins/glohd.koplugin "$KOBO/.adds/koreader/plugins/"
cp koreader/patches/2-sistema-glohd.lua "$KOBO/.adds/koreader/patches/"
cp koreader/defaults.custom.lua "$KOBO/.adds/koreader/"
cp dist/kobowake.ko "$KOBO/.adds/usbnet/modulos/"
cp red-usb/red-usb-encender.sh red-usb/red-usb-apagar.sh "$KOBO/Herramientas/"
cp herramientas/tocar.lua "$KOBO/.adds/usbnet/"
dot_clean "$KOBO" 2>/dev/null || true
```

Llave SSH: si `.adds/usbnet/authorized_keys` no existe, pregunta qué llave pública usar (normalmente `~/.ssh/id_ed25519.pub`; si no hay, ofrece crearla con `ssh-keygen -t ed25519`) y cópiala ahí. Agrega el bloque `Host kobo` de `docs/03-red-usb-y-ssh.md` a `~/.ssh/config` si no está, con permiso de la persona.

Por red USB, lo mismo con `scp -r` hacia `kobo:/mnt/onboard/...` y `ssh kobo 'mkdir -p ...'`.

## 5. Reiniciar KOReader

Con almacenamiento USB: pide expulsar la Kobo y reiniciar KOReader (menú › Salir › Reiniciar) o la Kobo. Por red USB: usa la skill `manejar-kobo` (reinicio por toques), nunca `kill`.

## 6. Verificar

Con la red USB encendida:

```sh
ssh kobo 'lsmod | grep kobowake; dmesg | grep -i kobowake | tail -3; ls -la /mnt/onboard/.adds/usbnet/; grep -i -E "glohd|error" /mnt/onboard/.adds/koreader/crash.log | tail -20'
herramientas/kobo-captura.sh /tmp/kobo-cap/pantalla.png
```

Debe verse la Biblioteca en la captura y `kobowake` cargado. Si hay errores de Lua con `glohd` en `crash.log`, repórtalos con la línea exacta.

Prueba del botón (la hace la persona): desconectar el cable, dejar que se duerma, esperar 2 minutos y presionar el botón de encendido. Debe despertar.

## Opcional: arranque directo a KOReader

Solo si la persona lo pide explícitamente. Sigue el paso 2 de `docs/01-koreader-desde-cero.md`, compara antes con `diff` el `rcS` de la Kobo contra `sistema/rcS.anterior` y `sistema/rcS`, y guarda el original como `/etc/init.d/rcS.antes`. Explícale que no hay salida de emergencia a Nickel.
