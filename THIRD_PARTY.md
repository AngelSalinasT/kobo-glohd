# Código y recursos de terceros / Third-party notices

## KOReader

Este proyecto es un plugin y un conjunto de scripts para [KOReader](https://github.com/koreader/koreader), que se distribuye bajo la GNU AGPL-3.0. Este repo no incluye código de KOReader; lo usa en tiempo de ejecución en el dispositivo.

This project is a plugin and a set of scripts for [KOReader](https://github.com/koreader/koreader), distributed under the GNU AGPL-3.0. This repo does not include KOReader code; it uses it at runtime on the device.

## Kernel de Linux de Kobo / Kobo Linux kernel

`build.sh` descarga el kernel que Kobo publica en [kobolabs/Kobo-Reader](https://github.com/kobolabs/Kobo-Reader) (GPL-2.0). `kernel/config-3.0.35+` es la configuración de ese kernel tal como corre en el dispositivo. Los módulos de `modulos/` y `experimentos/kobowake_diag/` se distribuyen bajo GPL-2.0.

`build.sh` downloads the kernel Kobo publishes at [kobolabs/Kobo-Reader](https://github.com/kobolabs/Kobo-Reader) (GPL-2.0). `kernel/config-3.0.35+` is that kernel's configuration as it runs on the device. The modules in `modulos/` and `experimentos/kobowake_diag/` are distributed under GPL-2.0.

## Script de arranque / Boot script

`sistema/rcS` y `sistema/rcS.anterior` son versiones modificadas del script de arranque del firmware de Kobo (`/etc/init.d/rcS`). Se incluyen como referencia para quien quiera replicar el arranque directo a KOReader.

`sistema/rcS` and `sistema/rcS.anterior` are modified versions of the Kobo firmware boot script (`/etc/init.d/rcS`), included as a reference for anyone who wants to boot straight into KOReader.

## Feather Icons

Los iconos de `koreader/plugins/glohd.koplugin/iconos/` están basados en [Feather](https://github.com/feathericons/feather). Las variantes `-blanco` son los mismos trazos en blanco.

The icons in `koreader/plugins/glohd.koplugin/iconos/` are based on [Feather](https://github.com/feathericons/feather). The `-blanco` variants are the same strokes in white.

```
The MIT License (MIT)

Copyright (c) 2013-2023 Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
