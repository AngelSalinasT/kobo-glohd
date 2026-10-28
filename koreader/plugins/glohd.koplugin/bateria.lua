--[[
Batería de la Glo HD: consumo medido, autonomía estimada y calibración del medidor.

Hardware (kernel de Kobo, drivers/power/ricoh619-battery.c y board-mx6sl_ntx.c):
  - PMIC Ricoh RC5T619 con medidor de carga (coulomb counter + tabla de voltaje en reposo).
  - Batería de 1510 mAh. Tabla de voltaje en reposo: 0 % = 3580 mV … 100 % = 4183 mV;
    el 0 % que muestra el sistema se ajusta a 3520 mV con carga (fg_poff_vbat).
  - Alarma del PMIC a 3400 mV: el kernel fuerza la capacidad a 0 % (critical_low_flag).
  - Calibración: al terminar una carga completa (estado "Full", ≥ 98,9 % y corriente
    < 64 mA) el driver reescala su tabla con el voltaje real de "lleno" (calib_ocvTable).
    No hace falta descargarla a 0 %: basta cargar hasta el final y dejarla conectada
    hasta que termine.

Datos: el CSV de glohd (fecha,epoch,evento,capacidad,voltaje_mv,cargador,detalle).
]]
local Sistema = require("sistema")

local Bateria = {
    DIAS_ANALISIS = 7,
    MAX_CSV = 256 * 1024, -- al superarlo se conserva la mitad más reciente
}

local function leerFilas(desde_epoch)
    local f = io.open(Sistema.CSV, "r")
    if not f then return {} end
    local filas = {}
    for linea in f:lines() do
        local fecha, epoch, evento, cap, mv, carg, detalle =
            linea:match("^([^,]*),(%d+),([^,]*),([^,]*),([^,]*),([^,]*),?(.*)$")
        epoch = tonumber(epoch)
        if epoch and epoch >= desde_epoch then
            table.insert(filas, { fecha = fecha, t = epoch, evento = evento, cap = tonumber(cap),
                mv = tonumber(mv), cargador = carg == "1", detalle = detalle })
        end
    end
    f:close()
    return filas
end

-- Consumo en %/hora dormido y despierto, a partir de tramos sin cargador.
-- Un tramo dormido va de "dormir" a "despertar" (las alarmas intermedias no lo cortan);
-- uno despierto, de "despertar"/"arranque" a "dormir". Solo cuentan tramos con cargador
-- desconectado en ambos extremos y de duración razonable.
local cache, cache_t
function Bateria.consumo(dias)
    -- Ajustes pide varias filas seguidas: se reutiliza el cálculo unos segundos.
    if cache and not dias and os.time() - cache_t < 30 then return cache end
    local r = Bateria._consumo(dias)
    if not dias then cache, cache_t = r, os.time() end
    return r
end

function Bateria._consumo(dias)
    local desde = os.time() - (dias or Bateria.DIAS_ANALISIS) * 86400
    local filas = leerFilas(desde)
    local dormido = { horas = 0, pct = 0, tramos = 0 }
    local despierto = { horas = 0, pct = 0, tramos = 0 }
    local inicio, modo
    for _, r in ipairs(filas) do
        if r.evento == "dormir" then
            if modo == "despierto" and inicio and not inicio.cargador and not r.cargador then
                local h = (r.t - inicio.t) / 3600
                if h >= 0.05 and inicio.cap and r.cap and r.cap <= inicio.cap then
                    despierto.horas = despierto.horas + h
                    despierto.pct = despierto.pct + (inicio.cap - r.cap)
                    despierto.tramos = despierto.tramos + 1
                end
            end
            inicio, modo = r, "dormido"
        elseif r.evento == "despertar" or r.evento == "arranque" then
            if modo == "dormido" and inicio and r.evento == "despertar"
                    and not inicio.cargador and not r.cargador then
                local h = (r.t - inicio.t) / 3600
                if h >= 0.5 and inicio.cap and r.cap and r.cap <= inicio.cap then
                    dormido.horas = dormido.horas + h
                    dormido.pct = dormido.pct + (inicio.cap - r.cap)
                    dormido.tramos = dormido.tramos + 1
                end
            end
            inicio, modo = r, "despierto"
        elseif r.cargador and inicio then
            -- Si se conectó el cargador a mitad del tramo, el tramo ya no sirve.
            inicio.cargador = true
        end
    end
    -- La capacidad viene en pasos de 1 %: con poco tiempo o poca bajada la cifra engaña
    -- (1 % en 1 h dormido parecería 24 %/día). Se exige un mínimo antes de dar una tasa.
    local function tasa(t, min_horas, min_pct)
        if t.horas < min_horas or t.pct < min_pct then return nil end
        return t.pct / t.horas
    end
    return {
        dormido = tasa(dormido, 12, 2), horas_dormido = dormido.horas, pct_dormido = dormido.pct,
        despierto = tasa(despierto, 2, 3), horas_despierto = despierto.horas,
    }
end

-- Texto corto para Ajustes: "≈ 2 %/día" o "midiendo…".
function Bateria.textoDormido()
    local c = Bateria.consumo()
    if not c.dormido then
        if c.horas_dormido >= 12 then
            -- Bajó menos de 2 % en todo lo medido: cota superior.
            return string.format("< %s %%/día", Bateria.redondear(2 / c.horas_dormido * 24))
        end
        return string.format("Midiendo (%d de 12 h)", math.floor(c.horas_dormido))
    end
    return string.format("≈ %s %%/día", Bateria.redondear(c.dormido * 24))
end

function Bateria.textoDespierto()
    local c = Bateria.consumo()
    if not c.despierto then return string.format("Midiendo (%d de 2 h)", math.min(2, math.floor(c.horas_despierto))) end
    return string.format("≈ %s %%/hora", Bateria.redondear(c.despierto))
end

function Bateria.redondear(x)
    if x >= 10 then return tostring(math.floor(x + 0.5)) end
    return (string.format("%.1f", x):gsub("%.", ","))
end

-- Autonomía: días si solo duerme, horas de lectura con la carga actual.
function Bateria.textoAutonomia()
    local cap = Sistema.estado()
    local c = Bateria.consumo()
    if not cap then return "—" end
    -- Hasta el apagado limpio (~5 %), no hasta 0 %.
    local util = math.max(0, cap - 5)
    local partes = {}
    if c.despierto and c.despierto > 0 then
        table.insert(partes, string.format("%d h leyendo", math.floor(util / c.despierto)))
    end
    if c.dormido and c.dormido > 0 then
        table.insert(partes, string.format("%d días guardado", math.floor(util / (c.dormido * 24))))
    end
    return #partes > 0 and table.concat(partes, " · ") or "Midiendo…"
end

-- Última calibración registrada (evento "calibracion" en el CSV).
function Bateria.ultimaCalibracion()
    local f = io.open(Sistema.CSV, "r")
    if not f then return "Nunca registrada" end
    local ultima
    for linea in f:lines() do
        if linea:find(",calibracion,", 1, true) then ultima = linea end
    end
    f:close()
    if not ultima then return "Nunca registrada" end
    local fecha = ultima:match("^(%d%d%d%d%-%d%d%-%d%d)")
    return fecha or "Registrada"
end

-- Busca en dmesg si el driver calibró su tabla (al terminar una carga completa) desde la
-- última revisión; devuelve el nuevo voltaje de 100 % en mV o nil.
local visto = {}
function Bateria.calibracionNueva()
    local p = io.popen("dmesg | grep 'calib_ocvTable : New OCV 100'")
    if not p then return nil end
    local nueva
    for linea in p:lines() do
        if not visto[linea] then
            visto[linea] = true
            local hex = linea:match("New OCV 100 = 0x(%x+)")
            if hex then nueva = math.floor(tonumber(hex, 16) / 1000) end
        end
    end
    p:close()
    return nueva
end

-- Si el CSV pasó de MAX_CSV, se conserva la mitad más reciente (con su encabezado).
function Bateria.rotarCSV()
    local f = io.open(Sistema.CSV, "r")
    if not f then return end
    local tam = f:seek("end")
    if tam <= Bateria.MAX_CSV then f:close(); return end
    f:seek("set", 0)
    local encabezado = f:read("*l")
    f:seek("set", tam - math.floor(Bateria.MAX_CSV / 2))
    f:read("*l") -- descartar la línea cortada
    local resto = f:read("*a")
    f:close()
    local tmp = Sistema.CSV .. ".tmp"
    local o = io.open(tmp, "w")
    if not o then return end
    o:write(encabezado, "\n", resto)
    o:close()
    os.rename(tmp, Sistema.CSV)
end

return Bateria
