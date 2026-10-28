--[[
Ajustes: página de configuración por secciones, al estilo de Ajustes de iOS.

  Ajustes                                        Listo
  LECTURA
  ┌──────────────────────────────────────────────────┐
  │ Pie de página                         Páginas  › │
  │ Barra de lectura simple                   (●━)   │
  └──────────────────────────────────────────────────┘
  PANTALLA ...

  - Tipos de fila: interruptor, opciones (abre una subpágina con ●/○), información y acción (›).
  - Paginado con puntitos y deslizar a los lados (nada de desplazamiento continuo).
  - Solo lo que se usa de verdad; todo lo demás sigue en "Menú completo de KOReader".
]]
local Apagado = require("apagado")
local Bateria = require("bateria")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local Device = require("device")
local Estilo = require("estilo")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Sistema = require("sistema")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen

local ALTO_FILA = Estilo.ALTO_BOTON
local ALTO_TITULO = Screen:scaleBySize(56)
local ALTO_PUNTOS = Screen:scaleBySize(40)
local ALTO_ENCABEZADO = Screen:scaleBySize(38)
local SEP_SECCION = Screen:scaleBySize(10)
local M = 2 * Estilo.MARGEN

----------------------------------------------------------------------------------------
-- Pie de página del lector
----------------------------------------------------------------------------------------
local PIES = {
    { "Nada", "nada" },
    { "Páginas", "paginas" },          -- 45 / 735
    { "Páginas y %", "paginas_pct" },  -- 45 / 735 • 6%
}
local APAGADOS = { "time", "battery", "book_time_to_read", "chapter_time_to_read", "pages_left",
    "pages_left_book", "bookmark_count", "frontlight", "frontlight_warmth", "mem_usage", "wifi_status",
    "book_title", "book_chapter", "book_author", "chapter_progress", "custom_text" }

-- Aplica el pie a la configuración global y, si hay un libro abierto, en vivo.
local function aplicarPie(opcion, ui)
    G_reader_settings:saveSetting("glohd_pie", opcion)
    local s = G_reader_settings:readSetting("footer")
    if not s then return end
    local modo = 0
    if opcion ~= "nada" then
        for _, k in ipairs(APAGADOS) do s[k] = false end
        s.disable_progress_bar = true
        s.all_at_once = true
        s.page_progress = true
        s.percentage = opcion == "paginas_pct"
        s.item_prefix = "compact_items"
        s.items_separator = "bullet"
        s.align = "center"
        modo = 1
    end
    G_reader_settings:saveSetting("reader_footer_mode", modo)
    local footer = ui and ui.document and ui.view and ui.view.footer
    if footer then
        footer:updateFooterTextGenerator()
        footer:applyFooterMode(modo)
        footer:refreshFooter(true, true)
    end
end

----------------------------------------------------------------------------------------
local Ajustes = InputContainer:extend{
    ui = nil,
    covers_fullscreen = true,
    abrirArchivos = nil, -- lo asigna main.lua
}

local function opcionActual(lista, valor)
    for _, op in ipairs(lista) do
        if op[2] == valor then return op[1] end
    end
    return "Personalizado"
end

-- Cambia un tiempo del plugin AutoSuspend en vivo (mismo procedimiento que su menú).
local function tiempoAutosuspend(ui, clave, valor)
    G_reader_settings:saveSetting(clave, valor)
    local as = ui and ui.autosuspend
    if not as then return end
    as[clave] = valor
    if clave == "auto_standby_timeout_seconds" then
        as:_unschedule_standby()
        as:toggleStandbyHandler(as:_enabledStandby())
        as:_start_standby()
    else
        as:_unschedule()
        as:_start()
    end
end

function Ajustes:raiz()
    local ui = self.ui
    local NetworkMgr = require("ui/network/manager")
    local en_libro = ui and ui.document ~= nil

    local refrescos = { { "Cada página", 1 }, { "Cada 6 páginas", 6 }, { "Cada 20 páginas", 20 } }
    local fondos = { { "Imágenes", "random_image" }, { "Portada del libro", "cover" }, { "Nada", "disable" } }
    local dormir = { { "5 minutos", 300 }, { "10 minutos", 600 }, { "15 minutos", 900 },
        { "30 minutos", 1800 }, { "Nunca", -1 } }
    local apagar = { { "1 día", 86400 }, { "3 días", 259200 }, { "1 semana", 604800 }, { "Nunca", -1 } }

    -- Lo técnico (diagnóstico, red USB, detalle de la batería) va en "Avanzado": a diario
    -- no hace falta verlo.
    local avanzado = function()
        return { titulo = "Avanzado", secciones = {
            { titulo = "Batería en detalle", filas = {
                { texto = "Guardado gasta", info = Bateria.textoDormido },
                { texto = "Leyendo gasta", info = Bateria.textoDespierto },
                { texto = "Calibración", info = Bateria.ultimaCalibracion, accion = function()
                    Sistema.aviso("Para calibrar el medidor: carga hasta 100 % y deja el cable "
                        .. "conectado hasta que termine (unos 30-60 min más). No hace falta "
                        .. "descargarla a 0 %.", 10)
                end },
            }},
            { titulo = "Red USB (SSH desde la Mac)", filas = {
                { texto = "Red USB", interruptor = Sistema.red_activa, cambiar = Sistema.alternarRed },
                { texto = "Encender al conectar el cable",
                  interruptor = function() return G_reader_settings:isTrue("glohd_red_usb_al_conectar") end,
                  cambiar = function() G_reader_settings:flipNilOrFalse("glohd_red_usb_al_conectar") end },
            }},
            { titulo = "Diagnóstico", filas = {
                { texto = "Botón despierta", info = function() return Sistema.kobowake_activo() and "Activo" or "Inactivo" end },
                { texto = "Último arranque", info = Sistema.ultimo_arranque },
            }},
        }}
    end

    local sistema = {}
    if not en_libro then
        table.insert(sistema, { texto = "Archivos", accion = function()
            self:cerrar(); if Ajustes.abrirArchivos then Ajustes.abrirArchivos() end
        end })
    end
    table.insert(sistema, { texto = "Menú completo de KOReader", accion = function()
        self:cerrar(); UIManager:nextTick(function() ui.menu:onShowMenu() end)
    end })
    table.insert(sistema, { texto = "Apagar o reiniciar", accion = function()
        self:cerrar(); UIManager:nextTick(function() Apagado.mostrar() end)
    end })
    table.insert(sistema, { texto = "Avanzado", pagina = avanzado })

    return {
        titulo = "Ajustes",
        secciones = {
            { titulo = "Lectura", filas = {
                { texto = "Pie de página", opciones = PIES,
                  actual = function() return G_reader_settings:readSetting("glohd_pie") end,
                  elegir = function(v) aplicarPie(v, ui) end },
                { texto = "Barra de lectura simple",
                  interruptor = function() return G_reader_settings:nilOrTrue("glohd_barra_lectura") end,
                  cambiar = function() G_reader_settings:flipNilOrTrue("glohd_barra_lectura") end },
                { texto = "Limpiar pantalla", opciones = refrescos,
                  actual = function() return G_reader_settings:readSetting("full_refresh_count") or 6 end,
                  elegir = function(v)
                      G_reader_settings:saveSetting("full_refresh_count", v)
                      if not G_reader_settings:isTrue("night_mode") then UIManager.FULL_REFRESH_COUNT = v end
                  end },
            }},
            { titulo = "Pantalla", filas = {
                { texto = "Modo noche",
                  interruptor = function() return G_reader_settings:isTrue("night_mode") end,
                  cambiar = function() ui:handleEvent(Event:new("ToggleNightMode")) end },
                { texto = "Fondo al dormir", opciones = fondos,
                  actual = function() return G_reader_settings:readSetting("screensaver_type") end,
                  elegir = function(v) G_reader_settings:saveSetting("screensaver_type", v) end },
                { texto = "Biblioteca al iniciar",
                  interruptor = function() return G_reader_settings:nilOrTrue("glohd_biblioteca_inicio") end,
                  cambiar = function() G_reader_settings:flipNilOrTrue("glohd_biblioteca_inicio") end },
            }},
            { titulo = "Energía", filas = {
                { texto = "Dormir tras", opciones = dormir,
                  actual = function() return G_reader_settings:readSetting("auto_suspend_timeout_seconds") end,
                  elegir = function(v) tiempoAutosuspend(ui, "auto_suspend_timeout_seconds", v) end },
                { texto = "Apagar tras", opciones = apagar,
                  actual = function() return G_reader_settings:readSetting("autoshutdown_timeout_seconds") end,
                  elegir = function(v) tiempoAutosuspend(ui, "autoshutdown_timeout_seconds", v) end },
                { texto = "Ahorro entre páginas",
                  interruptor = function() return (G_reader_settings:readSetting("auto_standby_timeout_seconds") or -1) > 0 end,
                  cambiar = function()
                      local activo = (G_reader_settings:readSetting("auto_standby_timeout_seconds") or -1) > 0
                      tiempoAutosuspend(ui, "auto_standby_timeout_seconds", activo and -1 or 4)
                  end },
            }},
            { titulo = "Batería y conexión", filas = {
                { texto = "Ahora", info = Sistema.textoBateria },
                { texto = "Te alcanza para", info = Bateria.textoAutonomia },
                { texto = "Wi-Fi",
                  interruptor = function() return NetworkMgr:isWifiOn() end,
                  cambiar = function()
                      if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff() else NetworkMgr:toggleWifiOn() end
                  end },
            }},
            { titulo = "Sistema", filas = sistema },
        },
    }
end

-- Subpágina de una fila con opciones: ● la actual; tocar elige y regresa.
function Ajustes:paginaOpciones(fila)
    local yo = self
    local filas = {}
    local actual = fila.actual()
    for _, op in ipairs(fila.opciones) do
        table.insert(filas, {
            texto = Estilo.marca(op[2] == actual, op[1]),
            accion = function() fila.elegir(op[2]); yo:atras() end,
            sin_flecha = true,
        })
    end
    return { titulo = fila.texto, secciones = { { filas = filas } } }
end

----------------------------------------------------------------------------------------
-- Dibujo
----------------------------------------------------------------------------------------
function Ajustes:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Deslizar = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    -- pagina_inicial: otra vista con el mismo estilo (p. ej. el índice del libro, indice.lua).
    self.pila = { { pagina = self.pagina_inicial or self:raiz(), hoja = 1 } }
    self:construir()
end

function Ajustes:fila(def, ancho)
    local yo = self
    local derecha
    if def.interruptor then
        derecha = Estilo.interruptor(def.interruptor())
    else
        local valor = def.info and def.info()
            or def.opciones and opcionActual(def.opciones, def.actual())
        local partes = HorizontalGroup:new{ align = "center" }
        if valor then
            table.insert(partes, TextWidget:new{ text = valor, face = Font:getFace("cfont", 17),
                fgcolor = Estilo.GRIS, max_width = math.floor(ancho * 0.5) })
        end
        if (def.opciones or def.accion or def.pagina) and not def.sin_flecha then
            table.insert(partes, HorizontalSpan:new{ width = Screen:scaleBySize(8) })
            table.insert(partes, TextWidget:new{ text = "›", face = Font:getFace("cfont", 22), fgcolor = Estilo.GRIS })
        end
        derecha = partes
    end
    local interior = ancho - 2 * Estilo.MARGEN
    local ancho_der = derecha:getSize().w
    local contenido = HorizontalGroup:new{
        align = "center",
        HorizontalSpan:new{ width = Estilo.MARGEN },
        LeftContainer:new{
            dimen = Geom:new{ w = interior - ancho_der, h = ALTO_FILA },
            HorizontalGroup:new{
                HorizontalSpan:new{ width = def.sangria or 0 },
                TextWidget:new{ text = def.texto, face = Font:getFace("cfont", 18), bold = def.negrita,
                    max_width = interior - ancho_der - Estilo.MARGEN - (def.sangria or 0) },
            },
        },
        RightContainer:new{ dimen = Geom:new{ w = ancho_der, h = ALTO_FILA }, derecha },
        HorizontalSpan:new{ width = Estilo.MARGEN },
    }
    local al_tocar
    if def.interruptor then
        al_tocar = function() def.cambiar(); yo:actualizar() end
    elseif def.opciones then
        al_tocar = function() yo:abrir(yo:paginaOpciones(def)) end
    elseif def.pagina then
        al_tocar = function() yo:abrir(def.pagina()) end
    elseif def.accion then
        al_tocar = def.accion
    end
    return Estilo.Tocable:new{ al_tocar = al_tocar, contenido }
end

-- Una sección (o parte de ella): encabezado gris y filas dentro de un marco redondeado.
function Ajustes:bloque(titulo, filas, ancho)
    local grupo = VerticalGroup:new{ align = "left", VerticalSpan:new{ width = SEP_SECCION } }
    if titulo then
        table.insert(grupo, LeftContainer:new{
            dimen = Geom:new{ w = ancho, h = ALTO_ENCABEZADO },
            TextWidget:new{ text = titulo, face = Font:getFace("cfont", 15), bold = true, fgcolor = Estilo.GRIS },
        })
    else
        table.insert(grupo, VerticalSpan:new{ width = Screen:scaleBySize(12) })
    end
    local interior = ancho - 2 * Estilo.BORDE
    local lista = VerticalGroup:new{ align = "left" }
    for i, def in ipairs(filas) do
        if i > 1 then
            table.insert(lista, HorizontalGroup:new{
                HorizontalSpan:new{ width = Estilo.MARGEN },
                Estilo.lineaFina(interior - Estilo.MARGEN),
            })
        end
        table.insert(lista, self:fila(def, interior))
    end
    table.insert(grupo, FrameContainer:new{
        bordersize = Estilo.BORDE, color = Estilo.NEGRO, radius = Estilo.RADIO, padding = 0, lista,
    })
    return grupo
end

-- Reparte las secciones en hojas. Cada sección va completa en una hoja (no se parte entre
-- páginas); solo si una sección no cabe sola se divide.
function Ajustes:hojas(pagina, alto_disponible)
    local hojas, actual, usado = {}, {}, 0
    local function altoBloque(titulo, n)
        return SEP_SECCION + (titulo and ALTO_ENCABEZADO or Screen:scaleBySize(12))
            + 2 * Estilo.BORDE + n * (ALTO_FILA + Size.line.thin)
    end
    local function nuevaHoja()
        if #actual > 0 then table.insert(hojas, actual) end
        actual, usado = {}, 0
    end
    -- pagina.partir: las secciones llenan cada hoja y siguen en la siguiente (listas largas
    -- como el índice; en Ajustes cada sección se queda completa).
    if pagina.partir then
        for _, sec in ipairs(pagina.secciones) do
            local filas = {}
            for _, f in ipairs(sec.filas) do
                if usado + altoBloque(sec.titulo, #filas + 1) > alto_disponible then
                    if #filas > 0 then table.insert(actual, { titulo = sec.titulo, filas = filas }) end
                    nuevaHoja()
                    filas = {}
                end
                table.insert(filas, f)
            end
            if #filas > 0 then
                table.insert(actual, { titulo = sec.titulo, filas = filas })
                usado = usado + altoBloque(sec.titulo, #filas)
            end
        end
        nuevaHoja()
        return hojas
    end
    for _, sec in ipairs(pagina.secciones) do
        local alto = altoBloque(sec.titulo, #sec.filas)
        if usado + alto > alto_disponible then nuevaHoja() end
        if alto <= alto_disponible then
            table.insert(actual, { titulo = sec.titulo, filas = sec.filas })
            usado = usado + alto
        else
            local filas = {}
            for _, f in ipairs(sec.filas) do
                if altoBloque(sec.titulo, #filas + 1) > alto_disponible then
                    table.insert(actual, { titulo = sec.titulo, filas = filas })
                    nuevaHoja()
                    filas = {}
                end
                table.insert(filas, f)
            end
            table.insert(actual, { titulo = sec.titulo, filas = filas })
            usado = altoBloque(sec.titulo, #filas)
        end
    end
    nuevaHoja()
    return hojas
end

function Ajustes:construir()
    local yo = self
    local ancho = Screen:getWidth()
    local nivel = self.pila[#self.pila]
    local pagina = nivel.pagina
    local interior = ancho - 2 * M

    -- Barra de título: "‹ Ajustes" en subpáginas, "Listo" en la raíz.
    local izq, der
    if #self.pila > 1 then
        izq = Button:new{ text = "‹ " .. self.pila[#self.pila - 1].pagina.titulo, bordersize = 0,
            text_font_size = 18, text_font_bold = true, height = ALTO_TITULO,
            callback = function() yo:atras() end, show_parent = self }
    end
    der = Button:new{ text = "Listo", bordersize = 0, text_font_size = 18, text_font_bold = true,
        height = ALTO_TITULO, callback = function() yo:cerrar() end, show_parent = self }
    local barra_titulo = OverlapGroup:new{
        dimen = Geom:new{ w = ancho, h = ALTO_TITULO },
        CenterContainer:new{ dimen = Geom:new{ w = ancho, h = ALTO_TITULO },
            TextWidget:new{ text = pagina.titulo, face = Font:getFace("cfont", 20), bold = true,
                max_width = math.floor(ancho * 0.5) } },
        RightContainer:new{ dimen = Geom:new{ w = ancho - Estilo.MARGEN, h = ALTO_TITULO }, der },
    }
    if izq then
        table.insert(barra_titulo, HorizontalGroup:new{ HorizontalSpan:new{ width = Estilo.MARGEN },
            LeftContainer:new{ dimen = Geom:new{ w = izq:getSize().w, h = ALTO_TITULO }, izq } })
    end

    local alto_contenido = Screen:getHeight() - ALTO_TITULO - ALTO_PUNTOS - Screen:scaleBySize(16)
    local hojas = self:hojas(pagina, alto_contenido)
    nivel.total = #hojas
    -- La primera vez, abrir en la hoja que tiene la fila marcada como "aqui" (el capítulo actual).
    if not nivel.ubicada then
        nivel.ubicada = true
        for i, h in ipairs(hojas) do
            for _, b in ipairs(h) do
                for _, f in ipairs(b.filas) do
                    if f.aqui then nivel.hoja = i end
                end
            end
        end
    end
    nivel.hoja = math.max(1, math.min(nivel.hoja, #hojas))
    local cuerpo = VerticalGroup:new{ align = "left" }
    for _, b in ipairs(hojas[nivel.hoja] or {}) do
        table.insert(cuerpo, self:bloque(b.titulo, b.filas, interior))
    end

    local puntos = ""
    if #hojas > 1 then
        local p = {}
        for i = 1, #hojas do p[i] = (i == nivel.hoja) and "●" or "○" end
        puntos = table.concat(p, "  ")
    end

    self[1] = FrameContainer:new{
        bordersize = 0, padding = 0, background = Estilo.BLANCO,
        OverlapGroup:new{
            dimen = self.dimen:copy(),
            VerticalGroup:new{
                align = "left",
                barra_titulo,
                Estilo.lineaFina(ancho),
                HorizontalGroup:new{ HorizontalSpan:new{ width = M }, cuerpo },
            },
            BottomContainer:new{
                dimen = self.dimen:copy(),
                CenterContainer:new{
                    dimen = Geom:new{ w = ancho, h = ALTO_PUNTOS },
                    TextWidget:new{ text = puntos, face = Font:getFace("cfont", 18) },
                },
            },
        },
    }
end

function Ajustes:actualizar()
    self:construir()
    UIManager:setDirty(self, "ui")
end

function Ajustes:abrir(pagina)
    table.insert(self.pila, { pagina = pagina, hoja = 1 })
    self:actualizar()
end

function Ajustes:atras()
    if #self.pila > 1 then
        table.remove(self.pila)
        -- La raíz se reconstruye para mostrar los valores nuevos.
        if #self.pila == 1 and not self.pagina_inicial then self.pila[1].pagina = self:raiz() end
        self:actualizar()
    else
        self:cerrar()
    end
end

function Ajustes:onDeslizar(_, ges)
    local nivel = self.pila[#self.pila]
    if ges.direction == "west" and nivel.hoja < (nivel.total or 1) then
        nivel.hoja = nivel.hoja + 1
        self:actualizar()
    elseif ges.direction == "east" then
        if nivel.hoja > 1 then
            nivel.hoja = nivel.hoja - 1
            self:actualizar()
        else
            self:atras()
        end
    end
    return true
end

function Ajustes:onShow()
    UIManager:setDirty(self, "ui")
end

function Ajustes:onCloseWidget()
    UIManager:setDirty(nil, "ui")
    if Ajustes.actual == self then Ajustes.actual = nil end
end

function Ajustes:cerrar()
    UIManager:close(self)
end

-- Una vista propia con el estilo de Ajustes (título, bloques redondeados, puntitos).
function Ajustes.mostrarPagina(ui, pagina)
    local w = Ajustes:new{ ui = ui, pagina_inicial = pagina }
    UIManager:show(w)
    return w
end

function Ajustes.mostrar(ui)
    if Ajustes.actual then return end
    Ajustes.actual = Ajustes:new{ ui = ui }
    UIManager:show(Ajustes.actual)
end

-- La primera vez: pie de página solo con páginas (sin la barra de progreso con marcas).
function Ajustes.pieInicial()
    if G_reader_settings:hasNot("glohd_pie") then aplicarPie("paginas") end
end

return Ajustes
