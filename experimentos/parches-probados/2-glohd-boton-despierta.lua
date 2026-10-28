-- Glo HD (Kobo_alyssum): el botón de encendido no despierta del sueño profundo.
-- Con state-extended=1 el kernel deshabilita la IRQ "btn power" al suspender (verificado:
-- el contador de /proc/interrupts no sube durante la suspensión; la cubierta TLE4913 sí despierta).
-- Este parche hace que KOReader escriba "0" en vez de "1". Para quitarlo: borrar este archivo.
local Device = require("device")
if Device.model ~= "Kobo_alyssum" then return end

local logger = require("logger")
local ffiUtil = require("ffi/util")
local orig = ffiUtil.writeToSysfs

ffiUtil.writeToSysfs = function(val, file)
    if file == "/sys/power/state-extended" and tostring(val) == "1" then
        logger.info("glohd-boton: state-extended 1 -> 0 (botón como fuente de despertar)")
        val = "0"
    end
    return orig(val, file)
end
