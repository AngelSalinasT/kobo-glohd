# 07 · Rendimiento

Mediciones con el motor real de KOReader dentro de la Kobo. Los scripts están en `experimentos/benchmarks/`.

Mediciones con el motor real de KOReader dentro del Kobo (`herramientas/bench.lua` y `bench_epub.lua`):

- La CPU no es cuello de botella: `interactive` sube a 996 MHz igual que `performance`.
- Un manga a 1072x1448 en grises renderiza unas 13 veces más rápido que el original a color de 1726x2667 (de ~1130 ms a ~86 ms por página). `herramientas/convertir-manga.sh` hace la conversión.
- En epub, el interletrado "rápido" baja ~40% por página y la mitad al maquetar; partición de palabras y fuentes incrustadas no cambian nada.

Ajustes aplicados:

- Pre-render de la página siguiente (`DHINTCOUNT = 1`) con caché de 32 MB.
- Perfiles predeterminados (solo si no existen): libros con Noto Serif 23, márgenes 50/70/50, interlineado 100 e interletrado rápido; manga y PDF a página completa con márgenes recortados, página por página y sin dithering.
- Espera ligera entre páginas (autostandby) de 4 s.
- Brillo por gesto: zona del borde izquierdo de 1/8 a 1/4 de pantalla (4 de 9 intentos medidos empezaban fuera) y respuesta lineal (media pantalla = 30%) en lugar de cuadrática.
- Fondos de bloqueo aleatorios en `/mnt/onboard/screensavers`, preparados con `herramientas/preparar-fondo.sh` (1072x1448, 16 grises con dithering; `RECORTAR=1` quita bordes lisos).
