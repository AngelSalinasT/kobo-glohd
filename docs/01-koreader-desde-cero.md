# 01 · KOReader desde cero

Cómo pasar de una Kobo Glo HD de fábrica (con Nickel, el sistema de Kobo) a una que arranca directo en KOReader. Si tu Kobo ya tiene KOReader, salta a [02 · Instalar](02-instalar.md).

Antes de empezar: esto es lo que se hizo en la Kobo donde se probó el proyecto. El primer paso (instalar KOReader) es el método estándar y no tiene riesgo. El segundo (arrancar sin Nickel) cambia un archivo del sistema; léelo completo antes de hacerlo.

## Paso 0 · Respaldo

Conecta la Kobo por USB y copia **toda** la memoria `KOBOeReader` a tu computadora, incluidas las carpetas ocultas `.kobo` y `.adds`. Si algo sale mal, con eso recuperas tus libros y tu progreso.

## Paso 1 · Instalar KOReader (con Nickel todavía)

El camino fácil es el paquete "one-click" de KOReader con KFMon, que mantiene NiLuJe:

1. Descarga el paquete `OCP-KOReader-*.zip` del [hilo de KFMon en MobileRead](https://www.mobileread.com/forums/showthread.php?t=314220) o sigue la [guía oficial de instalación en Kobo](https://github.com/koreader/koreader/wiki/Installation-on-Kobo-devices).
2. Descomprime el zip **en la raíz** de `KOBOeReader`. Deja `.adds/`, `.kobo/KoboRoot.tgz` y un `koreader.png`.
3. Expulsa la Kobo. Se reinicia sola y aplica el paquete.
4. En la biblioteca de Kobo aparece un "libro" llamado KOReader. Al abrirlo se lanza KOReader.

Después puedes actualizar KOReader desde su propio menú (la opción de buscar actualizaciones). Este proyecto se probó con v2026.03.

Con esto ya puedes instalar el resto del proyecto ([02 · Instalar](02-instalar.md)). El paso 2 es opcional.

## Paso 2 (opcional) · Arrancar directo en KOReader, sin Nickel

Por defecto la Kobo arranca en Nickel y tienes que abrir KOReader cada vez. Si solo usas KOReader, puedes cambiar el script de arranque del sistema (`/etc/init.d/rcS`) para que lance KOReader en lugar de Nickel. Así se hizo aquí, y por eso la Kobo prende directo en la Biblioteca.

**Lo que cambia frente al `rcS` de fábrica:**

- Ya no lanza `nickel`, `hindenburg` (el reporte de fallos) ni `on-animator.sh` (la animación de arranque).
- Inicializa la pantalla como lo haría `koreader.sh` (`./fbdepth -d 8 -R UR`) y lanza `./koreader.sh &` desde `/mnt/onboard/.adds/koreader`.
- Deja registro en `.kobo/fb-init.log` y `.kobo/koreader-boot.log`.
- La versión actual ([`sistema/rcS`](../sistema/rcS)) además monta la memoria antes de decidir si restaurar de fábrica. Solo restaura si la memoria no monta o falta `pickel`; si `dosfsck` no la deja limpia pero monta, arranca normal y lo anota en `.kobo/arranque-avisos.log`. Ver [06 · Batería y arranque](06-bateria-y-arranque.md).

**Cómo instalarlo:**

1. Parte del `rcS` de **tu misma** versión de firmware. Los de este repo salieron de un sistema con Nickel 4.38.23555; si tu Kobo tiene otra versión, compara con `diff` y aplica solo los cambios de arriba.
2. Empaquétalo con la ruta del sistema y sin archivos `._*` de macOS:

   ```sh
   mkdir -p paquete/etc/init.d
   cp sistema/rcS paquete/etc/init.d/rcS
   chmod 755 paquete/etc/init.d/rcS
   COPYFILE_DISABLE=1 tar -czf KoboRoot.tgz -C paquete etc
   ```

3. Copia `KoboRoot.tgz` a `KOBOeReader/.kobo/KoboRoot.tgz`, expulsa y espera. Nickel lo aplica al reiniciar.
4. Si ya tienes la red USB de este proyecto, también puedes copiarlo por SSH (`scp` a `/etc/init.d/rcS`, guardando antes el original como `rcS.antes`). Es más fácil de revertir.

**Riesgos que debes conocer:**

- Este `rcS` no tiene salida de emergencia a Nickel. Si KOReader no está o no arranca, la pantalla se queda en el arranque. Una buena mejora para tu fork: si existe `.kobo/USE_NICKEL`, lanzar Nickel en lugar de KOReader.
- Sin Nickel, el modo almacenamiento USB lo maneja KOReader. Si KOReader no arranca, tampoco puedes conectar la Kobo como memoria.
- Una actualización de firmware de Kobo sobrescribe el `rcS`.
- Con KOReader arrancando directo, KFMon y NickelMenu ya no hacen nada (dependen de Nickel). Puedes dejarlos o borrar `.adds/kfmon` y `.adds/nm`.

## Respaldo del sistema

[`red-usb/respaldar-sistema.sh`](../red-usb/respaldar-sistema.sh) copia el sistema interno (solo lectura) a `respaldo-sistema/` en la memoria. Se ejecuta desde KOReader: mantener presionado el archivo › Ejecutar script. Hazlo antes de tocar el `rcS`.
