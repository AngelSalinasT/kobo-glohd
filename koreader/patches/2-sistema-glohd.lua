-- Ajustes de sistema para la Glo HD, aplicados cada vez que arranca KOReader (corre como root).
-- No toca el firmware ni el rcS. Para quitarlo: borrar este archivo.
local logger = require("logger")
local Device = require("device")
if Device.model ~= "Kobo_alyssum" then return end

local U = "/mnt/onboard/.adds/usbnet"

local function sh(cmd)
    local ok = os.execute(cmd)
    return ok == 0 or ok == true
end

-- 1) Módulo kobowake: el botón de encendido despierta el Kobo.
--    Protección: si una carga previa no terminó (marcador presente), no se reintenta.
local MARK = U .. "/kobowake.cargando"
if sh("lsmod | grep -q '^kobowake '") then
    logger.info("glohd: kobowake ya estaba cargado")
elseif sh("[ -e " .. MARK .. " ]") then
    sh("mv " .. MARK .. " " .. U .. "/kobowake.FALLO-$(date +%Y%m%d-%H%M%S)")
    logger.err("glohd: la carga anterior de kobowake no terminó; no se reintenta")
else
    sh("touch " .. MARK .. " && sync")
    local ok = sh("insmod " .. U .. "/modulos/kobowake.ko")
    sh("rm -f " .. MARK .. " && sync")
    logger.info("glohd: insmod kobowake", ok and "OK" or "FALLÓ")
end

-- 2) Perfiles predeterminados de lectura (solo para libros que se abren por primera vez).
--    Se escriben únicamente si no existen, así un "establecer como predeterminado" hecho
--    desde KOReader después no se pisa.
--    Libros (crengine, copt_*): la configuración probada en un libro real,
--      con interletrado rápido (medido: ~40% menos por página, la mitad al maquetar).
--    Manga/PDF (kopt_*): página completa con márgenes recortados, página por página, sin dithering.
local perfiles = {
    cre_font = "Noto Serif",
    copt_font_size = 23,
    copt_t_page_margin = 70,
    copt_b_page_margin = 50,
    copt_h_page_margins = { 50, 50 },
    copt_line_spacing = 100,
    copt_word_spacing = { 95, 75 },
    copt_font_kerning = 1,
    kopt_zoom_mode_genus = 3,   -- contenido
    kopt_zoom_mode_type = 2,    -- completo
    kopt_page_scroll = 0,       -- página por página
    kopt_trim_page = 1,
    kopt_sw_dithering = 0,
    kopt_hw_dithering = 0,
}
local escritos = 0
for k, v in pairs(perfiles) do
    if G_reader_settings:hasNot(k) then
        G_reader_settings:saveSetting(k, v)
        escritos = escritos + 1
    end
end
local pz = G_reader_settings:readSetting("panel_zoom_enabled") or {}
if pz.cbr == nil then pz.cbr = true; G_reader_settings:saveSetting("panel_zoom_enabled", pz) end
if escritos > 0 then logger.info("glohd: perfiles de lectura escritos:", escritos) end

-- 3) Espera ligera entre páginas (autostandby), 4 s como sugiere KOReader para Kobo.
--    Solo la primera vez: si el usuario la cambia o la apaga desde el menú, se respeta.
--    kobowake v2 evita pulsaciones dobles del botón al salir de esta espera.
if not G_reader_settings:has("glohd_autostandby_aplicado") then
    if G_reader_settings:readSetting("auto_standby_timeout_seconds", -1) <= 0 then
        G_reader_settings:saveSetting("auto_standby_timeout_seconds", 4)
        logger.info("glohd: autostandby activado (4 s)")
    end
    G_reader_settings:saveSetting("glohd_autostandby_aplicado", true)
end

-- 4) Sin "KOReader" como título del administrador de archivos (ahora es "Archivos").
require("apps/filemanager/filemanager").title = "Archivos"

-- 5) Brillo por gesto con respuesta lineal (antes cuadrática: un cuarto de pantalla = ~4%).
--    Ahora media pantalla = 30%, un cuarto = 15%. Registra "medir: brillo cambio" en crash.log.
do
    local DeviceListener = require("device/devicelistener")
    if Device:hasFrontlight() and DeviceListener.onChangeFlIntensity then
        DeviceListener.onChangeFlIntensity = function(self, ges, direction)
            local powerd = Device:getPowerDevice()
            local delta
            if type(ges) == "table" and ges.distance then
                local vertical = ges.direction == "north" or ges.direction == "south"
                local escala = vertical and Device.screen:getHeight() or Device.screen:getWidth()
                delta = math.max(1, math.floor(60 * math.min(1, ges.distance / escala) + 0.5))
            elseif type(ges) == "number" and ges > 0 then
                delta = ges
            else
                delta = 1
            end
            if direction ~= -1 then direction = 1 end
            local antes = powerd:frontlightIntensity()
            self:onSetFlIntensity(antes + direction * delta)
            self:onShowIntensity()
            logger.info(string.format("medir: brillo cambio %d -> %d (dist=%s)", antes,
                powerd:frontlightIntensity(), type(ges) == "table" and tostring(ges.distance) or tostring(ges)))
            return true
        end
    end
end
