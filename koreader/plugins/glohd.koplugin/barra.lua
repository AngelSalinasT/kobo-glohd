--[[
Barra de lectura: lo que aparece al tocar arriba o abajo dentro de un libro.

Antes un toque abría a la vez el menú superior de KOReader (7 pestañas de iconos) y el panel
inferior de ajustes (6 pestañas), y regresar a la Biblioteca era encontrar el icono de
carpeta entre ellos. Ahora, como en Kindle/Kobo:

  arriba   [‹ Biblioteca]        título del libro        [Atajos]
  abajo    capítulo · página X de Y · quedan N en el capítulo
           ───────────── progreso ─────────────
           [ Índice ] [ Aa ] [ Ir a ] [ Marcar ]   (en un tomo de saga: [ Tomos ] en vez de/junto a Índice)

  - "Aa" cambia la parte de abajo por los ajustes básicos (tamaño, letra, márgenes,
    interlineado; en mangas/PDF, contraste) con "Más ajustes" para el panel completo.
  - "Atajos" abre el panel tipo Centro de control (atajos.lua), con acceso a Ajustes.
  - Tocar fuera de las barras las cierra. Deslizar hacia abajo desde arriba abre los Atajos.
  - Sin animaciones; una sola actualización "ui" de las zonas de las barras al abrir/cerrar.
]]
local Atajos = require("atajos")
local Biblioteca = require("biblioteca")
local Lectura = require("lectura")
local Sagas = require("sagas")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Notification = require("ui/widget/notification")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen

-- Opciones de "Aa". Márgenes y letra en las unidades sin escalar de KOReader.
-- "Normales" = la configuración de lectura base (perfiles de 2-sistema-glohd.lua).
local LETRAS = {
    { "Serif", "Noto Serif" },
    { "Sans", "Noto Sans" },
    { "Clásica", "FreeSerif" },
}
local MARGENES = {
    { "Estrechos", { h = 20, t = 30, b = 20 } },
    { "Normales", { h = 50, t = 70, b = 50 } },
    { "Amplios", { h = 80, t = 90, b = 70 } },
}
local INTERLINEADO = {
    { "Compacto", 90 },
    { "Normal", 100 },
    { "Amplio", 115 },
}
local CONTRASTE = {
    { "Normal", 1.0 },
    { "Alto", 1.5 },
    { "Muy alto", 2.0 },
}

local ALTO_BOTON = Screen:scaleBySize(54) -- ~9-10 mm en la Glo HD (300 ppi)
local MARGEN = Screen:scaleBySize(12)

local function marca(sel, texto)
    -- La selección no se indica solo con negritas: ● / ○ como en los puntitos de la Biblioteca.
    return (sel and "● " or "○ ") .. texto
end

local function linea(ancho, grueso)
    return LineWidget:new{
        background = Blitbuffer.COLOR_BLACK,
        dimen = Geom:new{ w = ancho, h = grueso or Screen:scaleBySize(2) },
    }
end

local Barra = InputContainer:extend{
    ui = nil,
    modo = "barra", -- "barra" | "aa"
}

function Barra:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Tocar = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Deslizar = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    self:construir()
end

function Barra:construir()
    local ancho = Screen:getWidth()
    self.arriba = self:barraSuperior(ancho)
    self.abajo = self.modo == "aa" and self:panelAa(ancho) or self:barraInferior(ancho)
    self[1] = OverlapGroup:new{
        dimen = self.dimen:copy(),
        self.arriba,
        BottomContainer:new{ dimen = self.dimen:copy(), self.abajo },
    }
end

function Barra:barraSuperior(ancho)
    local yo = self
    local izq = Button:new{
        text = "‹ Biblioteca",
        bordersize = 0,
        text_font_size = 20,
        text_font_bold = true,
        height = ALTO_BOTON,
        callback = function() yo:irABiblioteca() end,
        show_parent = self,
    }
    local der = Button:new{
        text = "Atajos",
        bordersize = 0,
        text_font_size = 20,
        text_font_bold = true,
        height = ALTO_BOTON,
        callback = function() yo:cerrarY(function() Atajos.mostrar(yo.ui) end) end,
        show_parent = self,
    }
    local libre = ancho - izq:getSize().w - der:getSize().w - 2 * MARGEN
    local props = self.ui.doc_props or {}
    local titulo = Sagas.tituloLectura(self.ui.document.file)
        or props.display_title or props.title or self.ui.document.file:gsub(".*/", "")
    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            HorizontalGroup:new{
                HorizontalSpan:new{ width = MARGEN },
                izq,
                CenterContainer:new{
                    dimen = Geom:new{ w = libre, h = ALTO_BOTON },
                    TextWidget:new{
                        text = titulo,
                        face = Font:getFace("cfont", 17),
                        max_width = libre - 2 * MARGEN,
                    },
                },
                der,
                HorizontalSpan:new{ width = MARGEN },
            },
            linea(ancho),
        },
    }
end

-- "Capítulo · pág. X de Y · quedan N en el capítulo" y la barra de progreso.
function Barra:progreso(ancho)
    local ui = self.ui
    local pag = ui:getCurrentPage()
    local total = ui.document:getPageCount()
    local partes = {}
    local ok, cap = pcall(ui.toc.getTocTitleOfCurrentPage, ui.toc)
    local ok2, quedan = pcall(ui.toc.getChapterPagesLeft, ui.toc, pag)
    local texto_pag = string.format("Pág. %d de %d", pag, total)
    if ok2 and quedan then
        texto_pag = texto_pag .. (quedan == 0 and " · última del capítulo"
            or quedan == 1 and " · queda 1 en el capítulo"
            or string.format(" · quedan %d en el capítulo", quedan))
    end
    if ok and cap and cap ~= "" then
        table.insert(partes, TextWidget:new{
            text = cap, face = Font:getFace("cfont", 16), bold = true, max_width = ancho - 2 * MARGEN,
        })
    end
    table.insert(partes, TextWidget:new{
        text = texto_pag, face = Font:getFace("cfont", 16), max_width = ancho - 2 * MARGEN,
    })
    local grupo = VerticalGroup:new{ align = "left" }
    for _, w in ipairs(partes) do table.insert(grupo, w) end
    table.insert(grupo, VerticalSpan:new{ width = Screen:scaleBySize(6) })
    table.insert(grupo, ProgressWidget:new{
        width = ancho - 2 * MARGEN,
        height = Screen:scaleBySize(8),
        percentage = total > 0 and pag / total or 0,
        margin_h = 0,
        margin_v = 0,
    })
    return FrameContainer:new{
        bordersize = 0,
        padding = MARGEN,
        padding_bottom = Screen:scaleBySize(6),
        LeftContainer:new{ dimen = Geom:new{ w = ancho - 2 * MARGEN, h = grupo:getSize().h }, grupo },
    }
end

function Barra:marco(ancho, contenido)
    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{ linea(ancho), contenido },
    }
end

function Barra:barraInferior(ancho)
    local yo = self
    local ui = self.ui
    local marcado = ui.bookmark and ui.bookmark:isPageBookmarked() or false
    -- En un tomo de saga, "Tomos" lleva a la página de la saga. Los mangas no traen índice:
    -- ahí "Tomos" ocupa su lugar en vez de un botón que abre una lista vacía.
    local en_saga = Sagas.carpeta(ui.document.file) ~= nil
    local ok, hay_indice = pcall(function()
        ui.toc:fillToc()
        return ui.toc.toc ~= nil and #ui.toc.toc > 0
    end)
    hay_indice = ok and hay_indice
    local fila_botones = {}
    if hay_indice then
        table.insert(fila_botones, { text = "Índice", height = ALTO_BOTON, callback = function()
            yo:cerrarY(function() ui:handleEvent(Event:new("ShowToc")) end)
        end })
    end
    if en_saga then
        table.insert(fila_botones, { text = "Tomos", height = ALTO_BOTON, callback = function() yo:irATomos() end })
    end
    table.insert(fila_botones, { text = "Aa", font_bold = true, height = ALTO_BOTON, callback = function()
        yo:cambiarModo("aa")
    end })
    table.insert(fila_botones, { text = "Ir a", height = ALTO_BOTON, callback = function()
        yo:cerrarY(function() Lectura.irAPagina(ui) end)
    end })
    table.insert(fila_botones, { text = marcado and "Desmarcar" or "Marcar", height = ALTO_BOTON, callback = function()
        yo:cerrarY(function() ui.bookmark:onToggleBookmark() end)
    end })
    local botones = ButtonTable:new{
        width = ancho,
        zero_sep = true,
        show_parent = self,
        buttons = { fila_botones },
    }
    return self:marco(ancho, VerticalGroup:new{ self:progreso(ancho), linea(ancho, Size.line.thin), botones })
end

----------------------------------------------------------------------------------------
-- Panel "Aa"
----------------------------------------------------------------------------------------
local function fila(etiqueta, ancho)
    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = MARGEN,
        padding_top = Screen:scaleBySize(8),
        TextWidget:new{ text = etiqueta, face = Font:getFace("cfont", 15), fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            max_width = ancho - 2 * MARGEN },
    }
end

function Barra:panelAa(ancho)
    local yo = self
    local ui = self.ui
    local cfg = ui.document.configurable
    local grupos = {}
    local function opciones(etiqueta, lista, actual, aplicar)
        table.insert(grupos, fila(etiqueta, ancho))
        local fila_botones = {}
        for _, op in ipairs(lista) do
            local nombre, valor = op[1], op[2]
            table.insert(fila_botones, {
                text = marca(actual(valor), nombre),
                height = ALTO_BOTON,
                callback = function() aplicar(valor); yo:actualizar() end,
            })
        end
        table.insert(grupos, ButtonTable:new{ width = ancho, zero_sep = true, show_parent = self,
            buttons = { fila_botones } })
    end

    if ui.rolling then
        table.insert(grupos, fila("Tamaño de letra", ancho))
        table.insert(grupos, ButtonTable:new{ width = ancho, zero_sep = true, show_parent = self, buttons = {{
            { text = "A−", height = ALTO_BOTON, callback = function()
                ui:handleEvent(Event:new("SetFontSize", cfg.font_size - 1)); yo:actualizar()
            end },
            { text = tostring(cfg.font_size), font_bold = true, height = ALTO_BOTON, callback = function() end },
            { text = "A+", font_bold = true, height = ALTO_BOTON, callback = function()
                ui:handleEvent(Event:new("SetFontSize", cfg.font_size + 1)); yo:actualizar()
            end },
        }}})
        opciones("Letra", LETRAS,
            function(v) return ui.font.font_face == v end,
            function(v) ui:handleEvent(Event:new("SetFont", v)) end)
        opciones("Márgenes", MARGENES,
            function(v) return cfg.h_page_margins and cfg.h_page_margins[1] == v.h and cfg.t_page_margin == v.t end,
            function(v)
                -- SetPageMargins no actualiza configurable (lo hace ConfigDialog); se hace aquí
                -- para que se guarde con el libro.
                cfg.h_page_margins = { v.h, v.h }
                cfg.t_page_margin = v.t
                cfg.b_page_margin = v.b
                if v.t ~= v.b then cfg.sync_t_b_page_margins = 0 end
                ui.typeset.unscaled_margins = { v.h, v.t, v.h, v.b }
                ui:handleEvent(Event:new("SetPageMargins", { v.h, v.t, v.h, v.b }))
            end)
        opciones("Interlineado", INTERLINEADO,
            function(v) return cfg.line_spacing == v end,
            function(v) ui:handleEvent(Event:new("SetLineSpace", v)) end)
    else
        opciones("Contraste", CONTRASTE,
            function(v) return cfg.contrast == v end,
            function(v) cfg.contrast = v; ui:handleEvent(Event:new("GammaUpdate", v)) end)
    end

    table.insert(grupos, VerticalSpan:new{ width = Screen:scaleBySize(8) })
    table.insert(grupos, linea(ancho, Size.line.thin))
    table.insert(grupos, ButtonTable:new{ width = ancho, zero_sep = true, show_parent = self, buttons = {{
        { text = "Más ajustes", height = ALTO_BOTON, callback = function()
            yo:cerrarY(function() ui.config:onShowConfigMenu() end)
        end },
        { text = "Usar en todos", height = ALTO_BOTON, callback = function()
            ui.menu:saveDocumentSettingsAsDefault()
            Notification:notify("Estos ajustes se usarán en los libros nuevos.")
        end },
        { text = "Listo", font_bold = true, height = ALTO_BOTON, callback = function() yo:cerrar() end },
    }}})
    local grupo = VerticalGroup:new{ align = "left" }
    for _, w in ipairs(grupos) do table.insert(grupo, w) end
    return self:marco(ancho, grupo)
end

----------------------------------------------------------------------------------------
-- Pintado y gestos
----------------------------------------------------------------------------------------
function Barra:zona()
    local a, b = self.arriba.dimen, self.abajo.dimen
    if a and b then return a:combine(b) end
    return self.dimen
end

function Barra:actualizar()
    local antes = self:zona()
    self:construir()
    -- Un repintado para que dimen quede calculado antes de pedir la actualización de pantalla.
    UIManager:setDirty(self, function() return "ui", antes:combine(self:zona()) end)
end

function Barra:cambiarModo(modo)
    self.modo = modo
    self:actualizar()
end

function Barra:dentro(pos)
    for _, w in ipairs({ self.arriba, self.abajo }) do
        if w.dimen and pos:intersectWith(w.dimen) then return true end
    end
    return false
end

function Barra:onTocar(_, ges)
    if not self:dentro(ges.pos) then self:cerrar() end
    return true
end

function Barra:onDeslizar(_, ges)
    if not self:dentro(ges.pos) then self:cerrar() end
    return true
end

function Barra:onShow()
    UIManager:setDirty(self, function() return "ui", self:zona() end)
end

function Barra:onCloseWidget()
    local zona = self:zona()
    UIManager:setDirty(nil, function() return "ui", zona end)
    if Barra.actual == self then Barra.actual = nil end
end

function Barra:cerrar()
    UIManager:close(self)
end

function Barra:cerrarY(accion)
    self:cerrar()
    UIManager:nextTick(accion)
end

-- Todo en la misma vuelta (como el icono de carpeta del menú de KOReader): si se cierra la
-- barra y el libro en vueltas distintas, la página se repinta un instante antes de la Biblioteca.
function Barra:irABiblioteca()
    local ui = self.ui
    local file = ui.document.file
    self:cerrar()
    ui:onClose()
    ui:showFileManager(file)
end

-- A la página de la saga de este tomo, en la Biblioteca.
function Barra:irATomos()
    local ui = self.ui
    local file = ui.document.file
    Biblioteca.serie_pendiente = (Sagas.carpeta(file))
    Biblioteca.en_archivos = false
    self:cerrar()
    ui:onClose()
    ui:showFileManager(file)
end

function Barra.mostrar(ui)
    if Barra.actual then return end
    Barra.actual = Barra:new{ ui = ui }
    UIManager:show(Barra.actual)
end

return Barra
