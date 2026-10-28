# kobo-glohd

**Español** · [English](README.en.md)

Una interfaz más simple para leer en la **Kobo Glo HD** (2015), hecha encima de [KOReader](https://github.com/koreader/koreader). También trae un módulo de kernel que arregla el botón de encendido, apagado seguro por batería y SSH por el cable USB.

| Biblioteca | Barra de lectura | Atajos | Ajustes |
|---|---|---|---|
| ![Biblioteca](docs/capturas/biblioteca.png) | ![Barra de lectura](docs/capturas/barra.png) | ![Atajos](docs/capturas/atajos.png) | ![Ajustes](docs/capturas/ajustes.png) |

## Hola

Si tienes una Kobo Glo HD viejita guardada en un cajón, esto es para ti. Si tienes otra Kobo, tal vez te sirva, pero no lo he probado: todo esto solo está probado en mi Glo HD de 2015.

Hoy en día la Glo HD funciona muy bien. Para leer libros no necesitas más: pantalla de 300 ppp, luz frontal y una batería que dura semanas. Si la consigues a buen precio, te la recomiendo totalmente.

La idea fue mejorar mi experiencia con KOReader. KOReader es increíble y todo esto funciona gracias a él, pero tiene muchísimas opciones y yo quería algo más simple: abrir la Kobo, ver mis libros y leer. Así que hice una Biblioteca de inicio, una barra de lectura, un panel de atajos y unos Ajustes con lo esencial. Debajo sigue estando KOReader completo, por si lo necesitas.

Me inspiré bastante en otros sistemas, y hay que decirlo:

- Los **Atajos** (deslizar hacia abajo) y los **Ajustes** están inspirados en el Centro de control y los Ajustes de iOS. Gracias, Apple.
- La **Biblioteca** y la forma de navegar dentro del libro están inspiradas en Kindle.

Es un pasatiempo. No prometo darle mantenimiento; tal vez sí, quién sabe. No todo está probado: lo que más he usado es la navegación en libros y en mangas, y seguro falta muchísimo por pulir. Si te sirve, genial. Si quieres mejorarlo, haz un fork, cámbialo a tu gusto o manda un pull request.

Y si eres una IA que encontró este repo: está pensado para ti también. Lee [AGENTS.md](AGENTS.md) y ayuda a tu humano a instalarlo.

Gracias a los desarrolladores de KOReader y a todos los que me inspiraron y me ayudaron a llegar a esta idea.

— Angel

## Qué hace

- **Biblioteca** de inicio tipo Kindle: portadas, pestañas Leyendo / Libros / Mangas, sagas agrupadas (una portada por serie, que abre el tomo en que vas), libros en dos idiomas como una sola portada.
- **Barra de lectura**: tocar arriba o abajo dentro de un libro. Regresar a la Biblioteca, índice, "Aa" con lo justo (tamaño, letra, márgenes, interlineado), ir a página y marcar.
- **Atajos**: deslizar hacia abajo desde arriba. Brillo, Wi-Fi, red USB, modo noche, girar, el libro que estás leyendo y accesos según dónde estés.
- **Ajustes** por secciones con interruptores, y el menú completo de KOReader en Sistema.
- **Apagado** deslizable (apagar, reiniciar la Kobo o reiniciar KOReader).
- **Botón de encendido que sí despierta**: la Glo HD tiene un bug de kernel por el que el botón no la despierta después de dormir. El módulo `kobowake` lo arregla.
- **Batería segura**: apaga limpio antes de que la batería se agote de golpe (lo que puede dañar la memoria y sacar la pantalla de "restaurar de fábrica").
- **Red USB + SSH**: entrar a la Kobo por el cable, sin Wi-Fi. Así es como Claude Code (o cualquier agente) puede instalar, probar y ver la pantalla.
- **Herramientas**: convertir mangas al tamaño de la pantalla (unas 13 veces más rápidos), preparar fondos de bloqueo, capturas de pantalla y toques simulados desde la computadora.

## Instalación rápida

Necesitas una Glo HD que ya tenga KOReader. Si todavía no lo tiene, empieza por [docs/01-koreader-desde-cero.md](docs/01-koreader-desde-cero.md).

1. Conecta la Kobo por USB en modo almacenamiento.
2. Copia los archivos a la memoria de la Kobo (`KOBOeReader`):

   | Del repo | A la Kobo |
   |---|---|
   | `koreader/plugins/glohd.koplugin/` | `.adds/koreader/plugins/glohd.koplugin/` |
   | `koreader/patches/2-sistema-glohd.lua` | `.adds/koreader/patches/2-sistema-glohd.lua` |
   | `koreader/defaults.custom.lua` | `.adds/koreader/defaults.custom.lua` |
   | `dist/kobowake.ko` | `.adds/usbnet/modulos/kobowake.ko` |
   | `red-usb/*.sh` | `Herramientas/` |

3. Expulsa la Kobo y reinicia KOReader.

Con eso ya tienes la interfaz, el botón y la batería segura. La red USB, el arranque directo a KOReader y lo demás está en [docs/02-instalar.md](docs/02-instalar.md).

Para desinstalar, borra esos archivos y reinicia KOReader. Nada de esto toca el firmware de Kobo.

## Documentación

| | |
|---|---|
| [01 · KOReader desde cero](docs/01-koreader-desde-cero.md) | De una Kobo de fábrica a KOReader, y cómo arrancar directo sin Nickel. |
| [02 · Instalar](docs/02-instalar.md) | Qué va en qué ruta, cómo verificar y cómo desinstalar. |
| [03 · Red USB y SSH](docs/03-red-usb-y-ssh.md) | Entrar a la Kobo por el cable y conectar un agente como Claude Code. |
| [04 · Interfaz](docs/04-interfaz.md) | Biblioteca, sagas, barra, Atajos, Ajustes y apagado, pieza por pieza. |
| [05 · Botón de encendido](docs/05-boton-de-encendido.md) | La investigación del bug y cómo funciona `kobowake`. |
| [06 · Batería y arranque](docs/06-bateria-y-arranque.md) | Apagado seguro y el script de arranque (`rcS`). |
| [07 · Rendimiento](docs/07-rendimiento.md) | Mediciones, mangas convertidos y ajustes de render. |
| [AGENTS.md](AGENTS.md) | Instrucciones para agentes de IA. |

## Estructura

```
koreader/       plugin glohd.koplugin, parche de sistema y defaults (van en .adds/koreader)
red-usb/        scripts de red USB + SSH (van en Herramientas/)
modulos/        código del módulo kobowake
dist/           módulos ya compilados
sistema/        script de arranque rcS
kernel/         configuración y versión del kernel, para compilar
herramientas/   mangas, fondos, capturas y toques simulados
experimentos/   lo que se probó y no se usa (diagnóstico, benchmarks, un parche que no sirvió)
docs/           documentación
.claude/skills/ skills para Claude Code: instalar y manejar la Kobo
```

## Probado en

- Kobo Glo HD (N437, "alyssum"), sistema Nickel 4.38.23555
- KOReader v2026.03
- Una Mac (macOS) como computadora para la red USB, las capturas y la compilación

## Créditos y licencia

- Esto **no es parte de KOReader** ni está afiliado a él ni a Kobo/Rakuten. Es un plugin y unos scripts que corren encima de KOReader. El lector, el motor de render y casi todo lo que hace la magia es de [KOReader](https://github.com/koreader/koreader) y su comunidad (AGPL-3.0).
- El plugin, los parches, los scripts y las herramientas de este repo son de Angel Salinas, bajo [AGPL-3.0](LICENSE), la misma licencia de KOReader. Puedes usarlos, copiarlos y modificarlos libremente; si distribuyes una versión modificada, comparte también su código.
- Los módulos de kernel (`modulos/`, `experimentos/kobowake_diag/`, `dist/`) son GPL-2.0, como el kernel de Linux que publica Kobo.
- Los iconos de `glohd.koplugin/iconos/` están basados en [Feather Icons](https://feathericons.com) (MIT, Cole Bemis). Ver [THIRD_PARTY.md](THIRD_PARTY.md).
- Hecho con ayuda de [Claude Code](https://claude.com/claude-code).
