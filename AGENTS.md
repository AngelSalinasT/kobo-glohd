# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor, etc.). Code, comments and the on-device UI are in Spanish; the docs are in Spanish with an English README.

## What this is

A KOReader plugin + system tweaks for the **Kobo Glo HD** (N437, codename `alyssum`, i.MX6SL, 512 MB RAM, 1072×1448 screen, zForce IR touch, kernel 3.0.35+). Tested on Nickel 4.38.23555 with KOReader v2026.03. It replaces KOReader's home screen and menus with a simpler, Kindle/iOS-like UI and fixes hardware quirks (power button wake, safe low-battery shutdown, SSH over the USB cable).

## Map

| Path | Goes to on the device (`/mnt/onboard` = USB storage root) |
|---|---|
| `koreader/plugins/glohd.koplugin/` | `.adds/koreader/plugins/glohd.koplugin/` |
| `koreader/patches/2-sistema-glohd.lua` | `.adds/koreader/patches/` |
| `koreader/defaults.custom.lua` | `.adds/koreader/defaults.custom.lua` |
| `dist/kobowake.ko` | `.adds/usbnet/modulos/kobowake.ko` |
| `red-usb/red-usb-{encender,apagar}.sh` | `Herramientas/` |
| user's SSH public key | `.adds/usbnet/authorized_keys` |
| `herramientas/tocar.lua` | `.adds/usbnet/tocar.lua` |
| `sistema/rcS` | `/etc/init.d/rcS` (optional, system partition, see below) |

Full guide: `docs/02-instalar.md`. Starting from a stock Kobo: `docs/01-koreader-desde-cero.md`.

## Skills

Claude Code picks these up automatically from `.claude/skills/`. Other agents: read them as runbooks.

- `.claude/skills/instalar-glohd/SKILL.md`: install/update on a connected Kobo and verify.
- `.claude/skills/manejar-kobo/SKILL.md`: operate the device over SSH (screenshots, simulated taps/swipes, logs, restarting KOReader).

## Rules

1. **Confirm the device first.** `ssh kobo 'cat /proc/cpuinfo | grep Hardware; uname -r'` or check for `Kobo_alyssum` in KOReader's log. Never load `kobowake.ko` on anything else: it is built for this exact kernel and pokes i.MX6SL GPIO registers.
2. **Back up before writing.** Copy the user's `.adds/koreader/settings.reader.lua`, `settings/`, and any file you will overwrite to the computer first.
3. **The system partition is opt-in.** Everything except `sistema/rcS` lives on the user storage and is undone by deleting files. Only touch `/etc/init.d/rcS` if the user explicitly asks, keep the original as `/etc/init.d/rcS.antes`, and read the risks in `docs/01-koreader-desde-cero.md` (no fallback to Nickel).
4. **Never flash firmware or update KOReader** without asking. A Kobo firmware update overwrites `rcS`.
5. **Don't kill KOReader over SSH** to restart it (it doesn't handle SIGTERM cleanly). Restart it through the UI with simulated touches (see `manejar-kobo`) or ask the user.
6. **Sleep tests need the cable unplugged**: with USB connected the kernel refuses to suspend. Unplug, wait, plug back in, then read `dmesg` and `.adds/usbnet/bateria.csv`.
7. **macOS + FAT32:** remove `._*` files after copying (`dot_clean`), and filenames with accents are stored in NFD; prefer `find -name ... -exec` over shell globs.
8. **Verify on the screen.** After a UI change, take a screenshot (`herramientas/kobo-captura.sh`) and look at it before claiming it works.

## Building

`./build.sh` cross-compiles the kernel modules in Docker (Ubuntu 14.04, gcc 4.8) against Kobo's published kernel source. macOS needs the case-sensitive sparse image the script creates in `./.build` (~6 GB). Prebuilt modules are in `dist/`, so most users never need this.

## Contributing

Forks and pull requests are welcome. Keep the style: Spanish identifiers and comments, black and white UI, no animations, touch targets around 9–10 mm, nothing that requires flashing firmware. The author does not promise maintenance.
