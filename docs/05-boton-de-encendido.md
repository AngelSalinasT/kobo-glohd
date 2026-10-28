# 05 · Botón de encendido (`kobowake`)

Código en `modulos/kobowake/kobowake.c`, compilado en `dist/kobowake.ko`. El módulo de diagnóstico que sirvió para encontrar la causa está en `experimentos/kobowake_diag/`, y el parche que no funcionó en `experimentos/parches-probados/`.

Síntoma: después de dormir, el botón de encendido no despierta al Kobo; la cubierta sí.

Lo que se midió:

1. No era `state-extended`. KOReader escribe `1` en cada suspensión y eso anulaba el "power fix" del `rcS`, pero forzarlo a `0` con un parche tampoco hizo que el botón despertara.
2. La cubierta no despierta por el sensor magnético. La pantalla táctil de la Glo HD es infrarroja y al cerrar o abrir la cubierta se cortan los haces: lo que despierta al SoC es la interrupción del táctil (GPIO5_6). Por eso también funcionaba el truco de tocar la pantalla y luego el botón.
3. El botón (GPIO5_8) y el sensor de la cubierta (GPIO5_12) los registra `gpio-keys` con "ambos flancos". El driver GPIO de mxc no tiene `EDGE_SEL` en este kernel y lo emula con disparo por nivel (`GPIO_INT_LOW_LEV`). Con el SoC dormido ese disparo nunca se registra (ISR bit 8 = 0 aunque se presione). El táctil está por flanco de bajada y sí despierta.
4. Además, `gpio_keys_suspend` no arma los botones cuando `gSleep_Mode_Suspend` es 1, que es el modo normal de Kobo.

El arreglo (`kobowake`):

- Antes de dormir: `enable_irq_wake` sobre el IRQ del botón (392) y cambio de GPIO5_8 a flanco de bajada.
- Al despertar: si el ISR del botón quedó en 1, se restaura la configuración. Si el botón ya se soltó se inyecta `KEY_POWER` (presionar y soltar) por `gpio-keys`, para que KOReader lo tome como despertar legítimo y no como "unexpected wakeup"; si sigue presionado, o si `gpio-keys` reporta una pulsación real en 500 ms, no se inyecta (evita dobles al salir de la espera ligera).
- Lo carga `patches/2-sistema-glohd.lua` en cada arranque. Si una carga no termina (por ejemplo, un cuelgue del kernel) queda un marcador y no se reintenta.

Resultado: el botón despierta al Kobo por sí solo (verificado en `dmesg`: `isr=1` en el bit 8 y `despertó por el botón`).

## Compilar

```sh
./build.sh
```

Descarga el kernel que publica Kobo (`kobolabs/Kobo-Reader`, `hw/imx6sl-glohd/kernel.tar.bz2`), lo extrae en una imagen APFS case-sensitive (en `./.build`, o donde indique `WORK=`) y compila dentro de un contenedor Ubuntu 14.04 con gcc 4.8. La configuración del tarball es idéntica a la del Kobo, y las firmas (`modversions`) del `g_ether.ko` compilado coinciden con las del original, así que los módulos cargan sin forzar nada. El `LOCALVERSION=+` es necesario para que el vermagic sea `3.0.35+`.

Requiere macOS con Docker. En Linux basta con un sistema de archivos case-sensitive: puedes adaptar `build.sh` quitando la parte de `hdiutil`.
