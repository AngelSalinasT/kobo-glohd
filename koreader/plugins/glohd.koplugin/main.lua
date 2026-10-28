--[[
Glo HD: batería segura.

Problema: KOReader no apaga el Kobo cuando la batería llega a nivel crítico (Nickel sí).
El kernel solo reporta capacity=0 (critical_low_flag en ricoh619-battery.c) y el equipo
sigue hasta que el PMU corta la corriente con /mnt/onboard montado. Si la FAT queda
dañada, dosfsck falla en el rcS y el Kobo pide restaurar de fábrica.

Como la batería es de 2015 y el porcentaje puede estar descalibrado, se usa también el
voltaje (el fuel gauge apunta 0% = 3300 mV, alarma del PMU = 3400 mV; board-mx6sl_ntx.c).

  - Despierto: cada 60 s; apaga si capacidad <= 3% o voltaje <= 3500 mV (2 lecturas seguidas).
  - Dormido: alarma RTC cada 4 h; apaga si <= 5% o <= 3600 mV.
  - Registro: /mnt/onboard/.adds/usbnet/bateria.csv (cada 10 min despierto, en cada alarma,
    y al arrancar el "POWER off history" del PMU para saber por qué se apagó la vez anterior).
]]
local Device = require("device")
if Device.model ~= "Kobo_alyssum" then
    return { disabled = true }
end

local WidgetContainer = require("ui/widget/container/widgetcontainer")
-- Se carga aquí: el package.path de la carpeta del plugin solo existe mientras KOReader lo carga.
local Sistema = require("sistema")
local Biblioteca = require("biblioteca")
local Barra = require("barra")
local Atajos = require("atajos")
local Ajustes = require("ajustes")
local Archivos = require("archivos")
local Bateria = require("bateria")
local Lectura = require("lectura")
local Indice = require("indice")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local logger = require("logger")

-- Umbrales (ver bateria.lua: el 0 % del medidor está en 3520 mV con carga y el PMIC marca
-- crítico a 3400 mV). Dormido el voltaje es casi el de reposo, por eso el umbral es más alto.
local DESPIERTO = { pct = 3, mv = 3500, cada = 60 }
local DORMIDO = { pct = 5, mv = 3600, cada = 4 * 3600 }
-- La alarma dormido revisa más seguido cuanto menos carga queda (a 3 %/día, de 15 % a 5 %
-- hay ~3 días; cada hora sobra margen para apagar antes de que la pila llegue al límite).
local function cadaDormido(cap)
    if cap and cap <= 15 then return 3600 end
    if cap and cap <= 30 then return 2 * 3600 end
    return DORMIDO.cada
end
local AVISOS = { 15, 8 } -- avisos de batería baja despierto (una vez por descarga)
local REGISTRO_CADA = 10      -- revisiones despierto entre líneas del CSV (10 min)
local CSV = Sistema.CSV
local estado = Sistema.estado

local function registrar(evento, extra)
    local cap, mv, cargador = estado()
    local nuevo = not io.open(CSV, "r")
    local f = io.open(CSV, "a")
    if not f then return end
    if nuevo then f:write("fecha,epoch,evento,capacidad,voltaje_mv,cargador,detalle\n") end
    f:write(string.format("%s,%d,%s,%s,%s,%s,%s\n", os.date("%Y-%m-%d %H:%M:%S"), os.time(),
        evento, tostring(cap), tostring(mv), cargador and 1 or 0, extra or ""))
    f:close()
end

local apagando = false
local function apagar_por_bateria(cap, mv)
    if apagando then return end
    apagando = true
    logger.warn("glohd: batería", cap, "% /", mv, "mV sin cargador; apagando limpio")
    registrar("apagado-bateria")
    os.execute("sync")
    local Screensaver = require("ui/screensaver")
    Screensaver:setup("poweroff", "Batería agotada.\nConecta el cargador para encender.")
    Screensaver:show()
    UIManager._entered_poweroff_stage = true
    UIManager:broadcastEvent(Event:new("PowerOff"))
    UIManager:broadcastEvent(Event:new("Close", { keep_screensaver = true }))
    UIManager:nextTick(function()
        Device:saveSettings()
        Device:powerOff()
        UIManager:quit(88)
    end)
end

local voltaje_bajo_seguidas = 0
-- Devuelve true si apagó.
local function revisar(lim, origen)
    local cap, mv, cargador = estado()
    if cargador then
        voltaje_bajo_seguidas = 0
        return false
    end
    if cap and cap <= lim.pct then
        apagar_por_bateria(cap, mv)
        return true
    end
    if mv and mv <= lim.mv then
        voltaje_bajo_seguidas = voltaje_bajo_seguidas + 1
        -- En la alarma (dormido) una lectura basta: el equipo está en reposo, sin carga de pantalla.
        if origen == "alarma" or voltaje_bajo_seguidas >= 2 then
            apagar_por_bateria(cap, mv)
            return true
        end
    else
        voltaje_bajo_seguidas = 0
    end
    return false
end

-- Tareas a nivel de módulo: hay una instancia del plugin por UI (FileManager / Reader),
-- así que todo se desprograma antes de programar para no duplicar.
local contador = 0
local tarea_despierto
local avisado = {}
local function avisarBateriaBaja()
    local cap, _, cargador = estado()
    if cargador or not cap then avisado = {}; return end
    for _, nivel in ipairs(AVISOS) do
        if cap <= nivel and not avisado[nivel] then
            avisado[nivel] = true
            Sistema.aviso(string.format("Batería baja: %d %%.\nConecta el cargador pronto.", cap), 6)
            break
        end
    end
end

tarea_despierto = function()
    contador = contador + 1
    if contador % REGISTRO_CADA == 0 then registrar("despierto") end
    avisarBateriaBaja()
    -- Con el cargador conectado, el driver calibra su tabla al terminar la carga: se anota.
    local _, _, cargador = estado()
    if cargador then
        local mv100 = Bateria.calibracionNueva()
        if mv100 then registrar("calibracion", "100% = " .. mv100 .. " mV") end
    end
    if not revisar(DESPIERTO, "despierto") then
        UIManager:scheduleIn(DESPIERTO.cada, tarea_despierto)
    end
end

local tarea_dormido
tarea_dormido = function()
    registrar("alarma")
    if not revisar(DORMIDO, "alarma") and Device.wakeup_mgr then
        Device.wakeup_mgr:addTask(cadaDormido((estado())), tarea_dormido)
    end
end

-- Una vez por arranque: guardar por qué se apagó la vez anterior según el PMU.
local function registrar_arranque()
    local marca = "/tmp/glohd-arranque-registrado"
    if io.open(marca, "r") then return end
    io.open(marca, "w"):close()
    local p = io.popen("dmesg | grep -E 'POWER off history|off is .* on is' | tr ',' ' ' | tr '\\n' ' '")
    local hist = p and p:read("*a") or ""
    if p then p:close() end
    Bateria.rotarCSV()
    registrar("arranque", (hist:gsub("%s+", " ")))
end

-- Dentro de un libro: tocar arriba o abajo (o deslizar hacia arriba desde abajo) abre la barra
-- de lectura (barra.lua); deslizar hacia abajo desde arriba abre los Atajos (atajos.lua), como
-- el Centro de control de iOS. Ambos reemplazan al menú superior + panel de ajustes juntos.
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderConfig = require("apps/reader/modules/readerconfig")
if not ReaderMenu._glohd_barra then
    ReaderMenu._glohd_barra = true
    local function usarBarra(modulo)
        return modulo.activation_menu ~= "swipe" and G_reader_settings:nilOrTrue("glohd_barra_lectura")
            and modulo.ui and modulo.ui.document
    end
    local menu_original = ReaderMenu.onTapShowMenu
    ReaderMenu.onTapShowMenu = function(self, ges)
        if usarBarra(self) then Barra.mostrar(self.ui); return true end
        return menu_original(self, ges)
    end
    local config_original = ReaderConfig.onTapShowConfigMenu
    ReaderConfig.onTapShowConfigMenu = function(self, ges)
        if usarBarra(self) then Barra.mostrar(self.ui); return true end
        return config_original(self, ges)
    end
    local function usarBarraDeslizando(modulo)
        return modulo.activation_menu ~= "tap" and G_reader_settings:nilOrTrue("glohd_barra_lectura")
            and modulo.ui and modulo.ui.document
    end
    local swipe_menu_original = ReaderMenu.onSwipeShowMenu
    ReaderMenu.onSwipeShowMenu = function(self, ges)
        if ges.direction == "south" and usarBarraDeslizando(self) then
            -- Con "pan" el dedo sigue en la pantalla: los Atajos esperan a que se levante.
            Atajos.mostrar(self.ui, ges.ges == "pan")
            self.ui:handleEvent(Event:new("HandledAsSwipe"))
            return true
        end
        return swipe_menu_original(self, ges)
    end
    local swipe_config_original = ReaderConfig.onSwipeShowConfigMenu
    ReaderConfig.onSwipeShowConfigMenu = function(self, ges)
        if ges.direction == "north" and usarBarraDeslizando(self) then
            Barra.mostrar(self.ui)
            self.ui:handleEvent(Event:new("HandledAsSwipe"))
            return true
        end
        return swipe_config_original(self, ges)
    end
end

-- Atajos y Ajustes se conocen a través de main.lua (evita requires circulares).
Atajos.abrirAjustes = function(ui) Ajustes.mostrar(ui) end
Atajos.abrirArchivos = function() Biblioteca:irAArchivos() end
Ajustes.abrirArchivos = Atajos.abrirArchivos
Archivos.irABiblioteca = function(fm)
    Biblioteca.en_archivos = false
    Biblioteca:mostrar(fm)
end
Archivos.instalar()
Ajustes.pieInicial()
Lectura.instalarFinal()
Indice.instalar(Ajustes)

-- KOReader en español: sin "language" usaba inglés y salían en inglés "Ir a", buscar y el
-- final del libro. Solo si nunca se eligió idioma; se aplica desde el siguiente arranque.
if G_reader_settings:hasNot("language") then
    G_reader_settings:saveSetting("language", "es")
end

-- Biblioteca sin pasar por Archivos: el nextTick de GloHD:init corre después del primer
-- repintado, así que al cerrar un libro se alcanzaba a ver el administrador de archivos.
-- Mostrándola aquí, en la misma vuelta en que se crea el administrador, se pintan juntos.
local FileManager = require("apps/filemanager/filemanager")
if not FileManager._glohd_biblioteca then
    FileManager._glohd_biblioteca = true
    local show_files_original = FileManager.showFiles
    FileManager.showFiles = function(...)
        show_files_original(...)
        local fm = FileManager.instance
        if fm and fm.file_chooser and Biblioteca.debeMostrarse() then
            Biblioteca:mostrar(fm)
        end
    end
    -- Al girar, FileManager:rotate (= reinit) rehace solo su propio acomodo; la Biblioteca va
    -- encima como ventana aparte y se quedaba con las medidas de antes: se rehace también.
    local reinit_original = FileManager.reinit
    local function reinit(fm, ...)
        reinit_original(fm, ...)
        Biblioteca:rehacer()
    end
    FileManager.reinit = reinit
    FileManager.rotate = reinit
end

local GloHD = WidgetContainer:extend{
    name = "glohd",
    is_doc_only = false,
}

function GloHD:init()
    if self.ui and self.ui.menu then self.ui.menu:registerToMainMenu(self) end
    registrar_arranque()
    UIManager:unschedule(tarea_despierto)
    UIManager:scheduleIn(10, tarea_despierto)
    if Sistema.red_activa() then Sistema.bloquear_espera(true) end
    -- Biblioteca como inicio: cada vez que se crea el administrador de archivos (al arrancar
    -- o al cerrar un libro) se muestra encima, como el inicio de una Kindle.
    -- (file_chooser aún no existe cuando los plugins se inician: se revisa en el siguiente tick.)
    if self.ui and not self.ui.document then
        Biblioteca.en_archivos = false
        local ui = self.ui
        UIManager:nextTick(function()
            local es_fm = ui.file_chooser ~= nil and not ui.tearing_down
            logger.info("glohd: biblioteca inicio, administrador:", es_fm, "mostrar:", Biblioteca.debeMostrarse())
            if es_fm and Biblioteca.debeMostrarse() then
                Biblioteca:mostrar(ui)
            end
        end)
    end
end

function GloHD:onSuspend()
    UIManager:unschedule(tarea_despierto)
    registrar("dormir")
    if Device.wakeup_mgr then
        Device.wakeup_mgr:removeTasks(nil, tarea_dormido)
        Device.wakeup_mgr:addTask(cadaDormido((estado())), tarea_dormido)
    end
end

function GloHD:onResume()
    if Device.wakeup_mgr then
        Device.wakeup_mgr:removeTasks(nil, tarea_dormido)
    end
    registrar("despertar")
    voltaje_bajo_seguidas = 0
    UIManager:unschedule(tarea_despierto)
    UIManager:scheduleIn(5, tarea_despierto)
end

function GloHD:onCloseWidget()
    UIManager:unschedule(tarea_despierto)
    -- Si se cierra el administrador de archivos (p. ej. se abrió un libro por otra vía),
    -- la Biblioteca no debe quedarse encima del lector.
    if self.ui and self.ui.file_chooser and Biblioteca.lista then
        UIManager:close(Biblioteca.lista)
        Biblioteca.lista = nil
    end
end


----------------------------------------------------------------------------------------
-- Red USB (SSH por el cable) y menú "Glo HD".
-- Al conectar el cable KOReader llama MassStorage:start() sin argumento; desde el menú o
-- atajos lo llama con true/false. Así se distingue "cable conectado" de "lo pidió el usuario".
----------------------------------------------------------------------------------------
local MassStorage = require("ui/elements/mass_storage")
local red_activa, red, aviso = Sistema.red_activa, Sistema.red, Sistema.aviso

if not MassStorage._glohd_envuelto then
    MassStorage._glohd_envuelto = true
    local start_original = MassStorage.start
    MassStorage.start = function(self, with_confirmation)
        if with_confirmation == nil and G_reader_settings:isTrue("glohd_red_usb_al_conectar") then
            if red_activa() or red(true) then
                aviso("Red USB encendida.\nEn la Mac: ssh kobo")
            else
                aviso("No se pudo encender la red USB.\nRevisa .adds/usbnet/usbnet.log", 5)
            end
            return
        end
        -- Almacenamiento USB y red USB no pueden convivir: apagar la red antes.
        if red_activa() then red(false) end
        return start_original(self, with_confirmation)
    end
end

-- Al desconectar el cable, la red USB ya no sirve y, encendida, impide la espera ligera
-- entre páginas (una noche se quedó encendida sin cable): se apaga sola.
if not Device._glohd_desconectar then
    Device._glohd_desconectar = true
    local plug_out_original = Device.usbPlugOut
    Device.usbPlugOut = function(dev, ...)
        plug_out_original(dev, ...)
        if red_activa() then
            UIManager:nextTick(function()
                if red_activa() and red(false) then aviso("Cable desconectado: red USB apagada.") end
            end)
        end
    end
end

function GloHD:addToMainMenu(menu_items)
    menu_items.glohd = {
        text = "Glo HD",
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = "Ajustes",
                callback = function() Ajustes.mostrar(self.ui) end,
            },
            {
                text = "Abrir Biblioteca",
                enabled_func = function() return self.ui and self.ui.file_chooser ~= nil end,
                callback = function() Biblioteca.en_archivos = false; Biblioteca:mostrar(self.ui) end,
            },
            {
                text = "Biblioteca como pantalla de inicio",
                checked_func = function() return G_reader_settings:nilOrTrue("glohd_biblioteca_inicio") end,
                callback = function() G_reader_settings:flipNilOrTrue("glohd_biblioteca_inicio") end,
            },
            {
                text = "Barra de lectura simple",
                help_text = "Tocar arriba o abajo dentro de un libro: Biblioteca, índice, Aa y progreso. Deslizar hacia abajo desde arriba: Atajos. El menú completo de KOReader queda en Ajustes > Sistema.",
                checked_func = function() return G_reader_settings:nilOrTrue("glohd_barra_lectura") end,
                callback = function() G_reader_settings:flipNilOrTrue("glohd_barra_lectura") end,
                separator = true,
            },
            {
                text = "Red USB (SSH)",
                checked_func = red_activa,
                keep_menu_open = true,
                callback = function() Sistema.alternarRed() end,
            },
            {
                text = "Encender la red al conectar el cable",
                help_text = "Al conectar el cable se enciende la red USB en lugar de preguntar por el almacenamiento USB. El almacenamiento sigue disponible desde el menú.",
                checked_func = function() return G_reader_settings:isTrue("glohd_red_usb_al_conectar") end,
                callback = function() G_reader_settings:flipNilOrFalse("glohd_red_usb_al_conectar") end,
            },
            {
                text_func = function() return "Batería: " .. Sistema.textoBateria() end,
                keep_menu_open = true,
                callback = function() end,
                separator = true,
            },
            {
                text_func = function()
                    return "Botón despierta: " .. (Sistema.kobowake_activo() and "activo" or "inactivo")
                end,
                keep_menu_open = true,
                callback = function() end,
            },
            {
                text_func = function() return "Último arranque: " .. Sistema.ultimo_arranque() end,
                keep_menu_open = true,
                callback = function() end,
            },
        },
    }
end


return GloHD
