# 02 · Instalar

Requisitos: Kobo Glo HD con KOReader (ver [01](01-koreader-desde-cero.md)). Probado con KOReader v2026.03.

## Qué va en dónde

Las rutas son relativas a la memoria de la Kobo (`KOBOeReader` en la computadora, `/mnt/onboard` dentro de la Kobo).

| Del repo | A la Kobo | Para qué |
|---|---|---|
| `koreader/plugins/glohd.koplugin/` | `.adds/koreader/plugins/glohd.koplugin/` | Toda la interfaz, batería segura y red USB. |
| `koreader/patches/2-sistema-glohd.lua` | `.adds/koreader/patches/2-sistema-glohd.lua` | Carga `kobowake` al arrancar y pone perfiles de lectura (solo si no existen). Solo actúa en la Glo HD (`Kobo_alyssum`). |
| `koreader/defaults.custom.lua` | `.adds/koreader/defaults.custom.lua` | Caché de 32 MB, pre-render de la página siguiente y zona del brillo. Si ya tienes uno, junta los valores a mano. |
| `dist/kobowake.ko` | `.adds/usbnet/modulos/kobowake.ko` | Arreglo del botón de encendido. |
| `red-usb/red-usb-encender.sh` y `red-usb-apagar.sh` | `Herramientas/` | Red USB + SSH. El plugin los llama desde ahí. |
| tu llave pública SSH | `.adds/usbnet/authorized_keys` | Solo si vas a usar la red USB. |
| `herramientas/tocar.lua` | `.adds/usbnet/tocar.lua` | Opcional: toques simulados por SSH (para agentes y pruebas). |

`CoverBrowser` (viene con KOReader) debe estar activado: la Biblioteca usa sus portadas.

## Pasos

1. Conecta la Kobo y elige almacenamiento USB.
2. Copia los archivos según la tabla. Desde una Mac o Linux, con la Kobo montada en `$KOBO`:

   ```sh
   KOBO=/Volumes/KOBOeReader
   mkdir -p "$KOBO/.adds/koreader/plugins" "$KOBO/.adds/koreader/patches" "$KOBO/.adds/usbnet/modulos" "$KOBO/Herramientas"
   cp -R koreader/plugins/glohd.koplugin "$KOBO/.adds/koreader/plugins/"
   cp koreader/patches/2-sistema-glohd.lua "$KOBO/.adds/koreader/patches/"
   cp koreader/defaults.custom.lua "$KOBO/.adds/koreader/"
   cp dist/kobowake.ko "$KOBO/.adds/usbnet/modulos/"
   cp red-usb/red-usb-*.sh "$KOBO/Herramientas/"
   cp herramientas/tocar.lua "$KOBO/.adds/usbnet/"
   cat ~/.ssh/id_ed25519.pub > "$KOBO/.adds/usbnet/authorized_keys"
   dot_clean "$KOBO" 2>/dev/null   # macOS: quita los archivos ._*
   ```

3. Expulsa la Kobo. En KOReader: menú › Salir › Reiniciar KOReader (o reinicia la Kobo).
4. Al volver debe aparecer la **Biblioteca**. Si sale el administrador de archivos de siempre, revisa que la carpeta del plugin se llame exactamente `glohd.koplugin`.

## Organiza tus libros

La Biblioteca lee dos carpetas en la raíz de la memoria:

```
Books/
  Psicologia/                       ← un tema = una carpeta
    El_poder_del_ahora.epub
    hard_things.epub                ← dos idiomas del mismo libro
    hard_things_español.epub           se muestran como una sola portada
  Fantasia/
    Mistborn/                       ← subcarpeta dentro de un tema = saga
      Mistborn 1.epub
Mangas/
  Nana/                             ← cada subcarpeta de Mangas = saga
    Nana Tomo 01.cbz
    Nana Tomo 02.cbz
```

Los tomos se ordenan por número ("Tomo 02", "Vol. 3"). Para mangas usa `herramientas/convertir-manga.sh` ([07](07-rendimiento.md)).

## Verificar

- **Botón:** deja que la Kobo se duerma sola, espera un par de minutos y presiona el botón de encendido. Debe despertar. Por SSH: `lsmod | grep kobowake` y `dmesg | grep kobowake`.
- **Batería:** después de unos minutos debe existir `.adds/usbnet/bateria.csv`.
- **Red USB:** ver [03](03-red-usb-y-ssh.md).

## Desinstalar

Borra lo que copiaste y reinicia KOReader. `kobowake` se descarga al reiniciar la Kobo. Si también cambiaste el `rcS`, regresa el original (ver [01](01-koreader-desde-cero.md)). Para volver solo a la interfaz de KOReader sin desinstalar: Ajustes › Sistema, o el menú "Glo HD", y apaga la Biblioteca de inicio y la barra de lectura simple.

## Otras Kobo

No está probado. Lo que depende de la Glo HD:

- `kobowake.ko` está compilado para su kernel exacto (3.0.35+) y toca registros GPIO del i.MX6SL. En otra Kobo **no lo cargues**; el parche ya lo evita porque solo corre en `Kobo_alyssum`.
- Coordenadas, tamaños y `tocar.lua` asumen 1072×1448 y el táctil zForce.
- El plugin de interfaz es Lua puro sobre KOReader y debería funcionar en otras Kobo con ajustes menores. Si lo pruebas, cuéntalo en un issue.
