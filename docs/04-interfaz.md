# 04 · Interfaz

Todo vive en `koreader/plugins/glohd.koplugin/`. Reemplaza la pantalla de inicio y los menús de KOReader por algo más simple; KOReader completo sigue disponible en Ajustes › Sistema y en Archivos.

## Biblioteca (pantalla de inicio tipo Kindle)

`koreader/plugins/glohd.koplugin/biblioteca.lua`. Se abre sola encima del administrador de archivos al arrancar KOReader y cada vez que se cierra un libro.

- Portadas en mosaico, con las piezas del plugin CoverBrowser (`CoverMenu` y `MosaicMenu`) aplicadas a un `BookList` propio, así hereda portadas, progreso y la caché de metadatos.
- Pestañas visibles bajo el título: Leyendo, Libros y Mangas. Se cambian con un toque.
- Arriba a la derecha una carpeta lleva a Archivos, que queda como administrador avanzado (su título dice "Archivos", ya no "KOReader"). Arriba a la izquierda no hay botón (los Atajos se abren deslizando hacia abajo); dentro de una saga, la flecha para regresar. Mantener presionado un libro o una saga abre la misma hoja de acciones que en Archivos.
- **Archivos** (`archivos.lua`, `hoja.lua`): "‹ Biblioteca" con texto arriba a la izquierda (siempre regresa al inicio) y "Opciones" a la derecha. Bajo el título, un resumen ("5 carpetas · 2 libros") y la ruta tocable ("Kobo › Books › Psicologia") en lugar de la tarjeta "⬆ ../"; paginado con puntitos. Opciones y mantener presionado abren hojas de acciones en español, con iconos y solo lo posible: nueva carpeta, pegar, elegir varios, buscar, ordenar, ver como portadas o lista; en un libro, abrir, información, cambiar nombre, mover, copiar y borrar (lo único que pide confirmación). En modo selección el botón pasa a "Acciones" (mover/copiar aquí, borrar, elegir todos, terminar).
- Sagas (`sagas.lua`): cada subcarpeta de `Mangas`, o una subcarpeta dentro de un tema de `Books` (`Books/Fantasia/Mistborn/`), es una saga y aparece como una sola portada: la del tomo en que vas. Un toque abre ese tomo donde ibas (o empieza el primero); un toque largo abre la página de la saga, con el botón "Seguir · Tomo 1, pág. 14" arriba y todos los tomos en orden abajo. Ahí, un toque largo en un tomo lo marca como leído o no leído. "Leyendo" también agrupa por saga.
  - Orden por número de tomo ("Tomo 02", "Vol. 3"); lo que no tiene número (Recopilatorio, Extra) va al final.
  - El tomo en que vas es el que está en curso (más de 3 páginas o del 3 %) y abriste más recientemente; si ninguno está en curso, el que sigue al último terminado. Solo abrir un tomo ya no lo cuenta: con Nana, abrir el 2 sin leerlo escondía el 1 (pág. 14) y el orden ponía "vas en el 3".
- Libros: los temas (carpetas de `Books`) se juntan en una sola lista; un libro en dos idiomas (`hard_things.epub` + `hard_things_español.epub`) es una sola portada, la versión que leíste más reciente. Si nunca lo abriste, el toque pregunta "Leer en español / en inglés". "Leyendo" ya no muestra los libros terminados.
- Sin barra de avance bajo las portadas (se probó y no gustó); el estado se ve con la esquina doblada (abierto) y la palomita (terminado).
- Paginado con puntitos (`● ○ ○`, o `3 / 15` si hay más de 12 páginas) y deslizando a los lados. Deslizar en vertical por el cuarto izquierdo es el brillo, igual que en el lector.
- Solo formatos de lectura (epub, pdf, cbz/cbr, mobi, azw3, fb2, djvu, txt…): los scripts que KOReader guarda en su historial no aparecen.
- Se puede desactivar como inicio desde el menú "Glo HD".

## Dentro del libro: barra, Atajos y Ajustes

Reemplazan al menú superior + panel de ajustes de KOReader (que se abrían juntos). Todo en blanco y negro, sin animaciones, objetivos de ~9-10 mm.

- **Barra de lectura** (`barra.lua`), tocar arriba o abajo: "‹ Biblioteca" (directo, sin pasar por Archivos), título, "Atajos"; abajo capítulo, página, páginas que quedan del capítulo y progreso, con Índice, Aa, Ir a y Marcar. En un tomo de saga el título es "Nana · Tomo 1 de 22" y aparece "Tomos" (a la página de la saga); en mangas, que no traen índice, "Tomos" ocupa su lugar. **Aa**: tamaño, letra, márgenes e interlineado con 3 opciones cada uno (en mangas, contraste) y "Más ajustes" para el panel completo.
- **Atajos** (`atajos.lua`), deslizar hacia abajo desde arriba (en un libro, también "Atajos" de la barra): estilo Centro de control de iOS, en vertical (4 columnas) y horizontal (7). Fijos: estados (Wi-Fi, Red USB, Noche, Girar), módulo "Leyendo" y brillo (sigue al dedo). Según el contexto: en un libro, Marcar página, Biblioteca, Índice, Buscar (Hojear en mangas), Marcadores, Ir a página y Volver; en la Biblioteca, Pasar libros por USB, Archivos, Buscar, Historial, Favoritos, Colecciones y Dormir. Sin tamaño de letra (ya está en "Aa" de la barra). Mantener presionado un círculo dice su nombre; barrita abajo para cerrar. "Girar" en la Biblioteca la rehace de lado (4×2 portadas) y la deja así al cerrar un libro o reiniciar; cada libro recuerda su propia orientación.
- **Lectura** (`lectura.lua`): "Ir a" es solo un número ("Estás en la 14 de 176", Cancelar e Ir), sin el porcentaje, fijar página y hojear del diálogo de KOReader. Al terminar un libro sale una hoja en español en lugar del diálogo de KOReader (seis botones en inglés, entre ellos "Delete file"): en una saga, "Seguir con el tomo 2"; en un libro, "Volver a la Biblioteca"; las dos lo marcan como terminado. "Seguir aquí" la cierra.
- **Índice** (`indice.lua`): con el estilo de Ajustes, sin líneas de puntos, triángulos ni ☰. Cada parte es un bloque con sus capítulos ya abiertos (con sangría), el número de página en gris y el capítulo en que vas en negritas con ●. Abre en la hoja de ese capítulo y las hojas se llenan completas (un bloque sigue en la siguiente). Los libros sin índice usan el de KOReader.
- En los Atajos, dentro de un tomo de saga, el módulo "Leyendo" dice "Tomo 1 de 22 · pág. 14" y ‹ › cambian de tomo en lugar de capítulo.
- KOReader quedó en español (`language = "es"`, solo si nunca se había elegido idioma): los diálogos propios de KOReader que quedan (buscar, hojear, teclado) ya no salen en inglés.
- **Apagado** (`apagado.lua`), botón ⏻ de los Atajos: deslizar para apagar, reiniciar el Kobo o reiniciar KOReader (sin ventana de confirmación extra).
- **Ajustes** (`ajustes.lua`): secciones como Ajustes de iOS (Lectura, Pantalla, Energía, Batería y conexión, Sistema) con interruptores y subpáginas de opciones, en 2 páginas; el menú completo de KOReader queda en Sistema. Lo técnico va en Sistema › Avanzado: detalle de la batería (gasto guardado/leyendo, calibración), red USB y diagnóstico (botón, último arranque). Pie de página por defecto solo con páginas (`45 / 735`).
- Piezas compartidas: `estilo.lua` (formas redondeadas con contorno sólido: `paintBorder` con radio sale doble), `sistema.lua` (batería, red USB), `iconos/` (SVG estilo Feather, MIT, con variante `-blanco` para fondo negro: invertir un icono con transparencia da un cuadro blanco).
- Interruptor "Barra de lectura simple" en el menú Glo HD / Ajustes para volver al comportamiento de KOReader.

## Mapa de archivos

| Archivo | Qué hace |
|---|---|
| `main.lua` | Arranque del plugin, menú "Glo HD", batería segura, red USB al conectar el cable. |
| `biblioteca.lua` | Biblioteca de inicio. |
| `sagas.lua` | Agrupar tomos, orden por número y "en qué tomo vas". |
| `archivos.lua`, `hoja.lua` | Archivos y hojas de acciones. |
| `barra.lua` | Barra de lectura y "Aa". |
| `atajos.lua` | Atajos tipo Centro de control. |
| `ajustes.lua` | Ajustes por secciones. |
| `lectura.lua` | "Ir a" y hoja de fin de libro. |
| `indice.lua` | Índice. |
| `apagado.lua` | Apagado deslizable. |
| `bateria.lua`, `sistema.lua` | Batería y red USB. |
| `estilo.lua` | Formas y estilos compartidos. |
| `iconos/` | Iconos SVG (Feather, MIT). |
