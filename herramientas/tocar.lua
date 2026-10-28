-- Simula un toque en la pantalla del Kobo Glo HD (pruebas por SSH).
-- Uso (en el Kobo): cd /mnt/onboard/.adds/koreader && ./luajit /mnt/onboard/.adds/usbnet/tocar.lua X Y [ms]
-- X, Y en coordenadas de pantalla (1072x1448, vertical). ms = duración (por defecto 80; >500 = toque largo).
-- Deslizar: tocar.lua X1 Y1 X2 Y2 desliz [ms por paso]  (lento, p. ej. 60 → arrastre "pan")
-- zForce (protocolo "phoenix" en KOReader): ejes cruzados y X espejo → raw_x = Y, raw_y = 1072 - X.
local ffi = require("ffi")
ffi.cdef[[
struct ev { long sec; long usec; unsigned short type; unsigned short code; int value; };
int open(const char *, int); int write(int, const void *, unsigned int); int close(int);
int usleep(unsigned int);
]]
local x, y, ms = tonumber(arg[1]), tonumber(arg[2]), tonumber(arg[3] or 80)
local deslizar = arg[5] == "desliz"
local x2, y2 = tonumber(arg[3]), tonumber(arg[4])
local paso_ms = tonumber(arg[6] or 15)
local fd = ffi.C.open("/dev/input/event1", 1)
assert(fd >= 0, "no se pudo abrir event1")
local e = ffi.new("struct ev")
local function emit(t, c, v) e.type, e.code, e.value = t, c, v; ffi.C.write(fd, e, ffi.sizeof(e)) end
local function dedo(major)
    emit(3, 0x39, 1); emit(3, 0x30, major); emit(3, 0x32, major)
    emit(3, 0x35, y); emit(3, 0x36, 1072 - x); emit(0, 2, 0); emit(0, 0, 0)
end
if deslizar then
    local x1, y1 = x, y
    for i = 0, 8 do
        x, y = math.floor(x1 + (x2 - x1) * i / 8), math.floor(y1 + (y2 - y1) * i / 8)
        dedo(1); ffi.C.usleep(paso_ms * 1000)
    end
    dedo(0)
else
    dedo(1); ffi.C.usleep(ms * 1000); dedo(0)
end
ffi.C.close(fd)
