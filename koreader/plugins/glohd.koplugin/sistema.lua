--[[
Funciones de sistema compartidas por main.lua, los Atajos y Ajustes: batería, red USB,
estado del módulo kobowake y avisos.
]]
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local Sistema = {
    CSV = "/mnt/onboard/.adds/usbnet/bateria.csv",
}

local BAT = "/sys/class/power_supply/mc13892_bat/"
local RED_ON = "/mnt/onboard/Herramientas/red-usb-encender.sh"
local RED_OFF = "/mnt/onboard/Herramientas/red-usb-apagar.sh"

local function leer(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local v = f:read("*l")
    f:close()
    return v
end

function Sistema.ok(cmd)
    local r = os.execute(cmd)
    return r == 0 or r == true
end

-- capacidad (%), voltaje (mV), cargador conectado
function Sistema.estado()
    local cap = tonumber(leer(BAT .. "capacity"))
    local uv = tonumber(leer(BAT .. "voltage_now"))
    local cargador = leer("/sys/class/power_supply/usbpwr/online") == "1"
        or leer("/sys/class/power_supply/acpwr/online") == "1"
    return cap, uv and math.floor(uv / 1000), cargador
end

-- "85 % · 3,95 V · cargando". Con el cable puesto, el kernel dice "Charging" mientras carga
-- y "Full"/"Not charging" cuando ya terminó.
function Sistema.textoBateria()
    local cap, mv, cargador = Sistema.estado()
    local extra = ""
    if cargador then
        extra = leer(BAT .. "status") == "Charging" and " · cargando" or " · cargada"
    end
    local v = string.format("%.2f", (mv or 0) / 1000):gsub("%.", ",")
    return string.format("%s %% · %s V%s", tostring(cap), v, extra)
end

function Sistema.aviso(texto, segundos)
    UIManager:show(InfoMessage:new{ text = texto, timeout = segundos or 3 })
end

function Sistema.red_activa()
    return Sistema.ok("[ -f /tmp/dropbear_usbnet.pid ] && [ -d /proc/$(cat /tmp/dropbear_usbnet.pid) ]")
end

-- La espera ligera (autostandby) duerme el controlador USB y la Mac ve una desconexión:
-- mientras la red USB esté encendida se bloquea la espera (contador de UIManager, una sola vez).
local espera_bloqueada = false
function Sistema.bloquear_espera(bloquear)
    if bloquear and not espera_bloqueada then
        UIManager:preventStandby(); espera_bloqueada = true
    elseif not bloquear and espera_bloqueada then
        UIManager:allowStandby(); espera_bloqueada = false
    end
end

function Sistema.red(encender)
    local exito = Sistema.ok("sh " .. (encender and RED_ON or RED_OFF) .. " >/dev/null 2>&1")
    logger.info("glohd: red USB", encender and "encender" or "apagar", exito and "OK" or "FALLÓ")
    Sistema.bloquear_espera(Sistema.red_activa())
    return exito
end

-- Enciende o apaga la red USB con aviso. Devuelve el estado final.
-- corto = notificación pequeña arriba (en pantallas como los Atajos, donde el botón ya
-- muestra el estado y un cuadro grande taparía los controles).
function Sistema.alternarRed(corto)
    local function avisar(texto, segundos)
        if corto then
            require("ui/widget/notification"):notify((texto:gsub("\n", " · ")))
        else
            Sistema.aviso(texto, segundos)
        end
    end
    if Sistema.red_activa() then
        Sistema.red(false)
        avisar("Red USB apagada.")
    elseif Sistema.red(true) then
        avisar("Red USB encendida.\nEn la Mac: ssh kobo")
    else
        Sistema.aviso("No se pudo encender la red USB.\nRevisa .adds/usbnet/usbnet.log", 5)
    end
    return Sistema.red_activa()
end

function Sistema.kobowake_activo()
    return Sistema.ok("lsmod | grep -q '^kobowake '")
end

function Sistema.ultimo_arranque()
    local f = io.open(Sistema.CSV, "r")
    if not f then return "sin datos" end
    local ultima
    for linea in f:lines() do
        if linea:find(",arranque,") then ultima = linea end
    end
    f:close()
    if not ultima then return "sin datos" end
    local hist = ultima:match("POWER off history 0x0a is (0x%x+)")
    return (ultima:match("^([^,]+)") or "?") .. (hist and (" · PMU " .. hist) or "")
end

return Sistema
