--[[
Hoja de acciones (como la de iOS) para sustituir los ButtonDialog de KOReader:

  ┌──────────────────────────────────┐
  │          Título · subtítulo      │
  │ [icono]  Acción                  │
  │ [icono]  Acción                  │
  └──────────────────────────────────┘
  ┌──────────────────────────────────┐
  │             Cancelar             │
  └──────────────────────────────────┘

  - Abajo, con filas grandes (~9 mm) y un icono que ayuda a reconocer cada acción.
  - Solo se muestran las acciones posibles (nada atenuado que no se pueda tocar).
  - Si no cabe en una columna (p. ej. en horizontal), se reparte en dos.
  - Tocar fuera de la hoja la cierra, igual que Cancelar.
]]
local Device = require("device")
local Estilo = require("estilo")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Size = require("ui/size")
local Screen = Device.screen

local ALTO_FILA = Estilo.ALTO_BOTON
local RADIO = Screen:scaleBySize(16)
local LADO_ICONO = Screen:scaleBySize(24)

local Hoja = InputContainer:extend{
    titulo = nil,
    subtitulo = nil,
    filas = nil,      -- { { icono =, texto =, accion =, peligro = } }
    cancelar = "Cancelar",
}

function Hoja:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Fuera = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
    self:construir()
end

function Hoja:fila(def, ancho)
    local yo = self
    local partes = HorizontalGroup:new{ align = "center", HorizontalSpan:new{ width = Estilo.MARGEN * 2 } }
    local ancho_texto = ancho - 4 * Estilo.MARGEN
    if def.icono then
        table.insert(partes, Estilo.icono(def.icono, LADO_ICONO))
        table.insert(partes, HorizontalSpan:new{ width = Estilo.MARGEN * 2 })
        ancho_texto = ancho_texto - LADO_ICONO - 2 * Estilo.MARGEN
    end
    table.insert(partes, TextWidget:new{ text = def.texto, face = Font:getFace("cfont", 19),
        bold = def.peligro, max_width = ancho_texto })
    return Estilo.Tocable:new{
        al_tocar = function()
            yo:cerrar()
            if def.accion then def.accion() end
        end,
        LeftContainer:new{ dimen = Geom:new{ w = ancho, h = ALTO_FILA }, partes },
    }
end

-- Columna de filas separadas por líneas finas.
function Hoja:columna(filas, ancho)
    local col = VerticalGroup:new{ align = "left" }
    for i, def in ipairs(filas) do
        if i > 1 then
            table.insert(col, HorizontalGroup:new{
                HorizontalSpan:new{ width = Estilo.MARGEN * 2 },
                Estilo.lineaFina(ancho - Estilo.MARGEN * 4),
            })
        end
        table.insert(col, self:fila(def, ancho))
    end
    return col
end

function Hoja:construir()
    local W, H = Screen:getWidth(), Screen:getHeight()
    local m = Estilo.MARGEN * 2
    local ancho = math.min(W - 2 * m, Screen:scaleBySize(560))
    local interior = ancho - 2 * Estilo.BORDE

    local cabecera = VerticalGroup:new{ align = "center" }
    if self.titulo then
        table.insert(cabecera, VerticalSpan:new{ width = Screen:scaleBySize(14) })
        table.insert(cabecera, TextWidget:new{ text = self.titulo, face = Font:getFace("cfont", 18),
            bold = true, max_width = interior - 2 * m })
        if self.subtitulo then
            table.insert(cabecera, VerticalSpan:new{ width = Screen:scaleBySize(4) })
            table.insert(cabecera, TextBoxWidget:new{ text = self.subtitulo, face = Font:getFace("cfont", 15),
                fgcolor = Estilo.GRIS, width = interior - 2 * m, alignment = "center" })
        end
        table.insert(cabecera, VerticalSpan:new{ width = Screen:scaleBySize(12) })
    end
    local alto_cabecera = cabecera:getSize().h

    -- Una columna si cabe; si no, dos (mitad y mitad).
    local alto_cancelar = ALTO_FILA
    local libre = H - 2 * m - alto_cancelar - m - alto_cabecera - 2 * Estilo.BORDE
    local n = #self.filas
    local cols = (n * (ALTO_FILA + Size.line.thin) > libre and n > 1) and 2 or 1
    if cols == 2 then
        ancho = math.min(W - 2 * m, Screen:scaleBySize(760))
        interior = ancho - 2 * Estilo.BORDE
    end
    local cuerpo
    if cols == 1 then
        cuerpo = self:columna(self.filas, interior)
    else
        local mitad = math.ceil(n / 2)
        local a, b = {}, {}
        for i, f in ipairs(self.filas) do table.insert(i <= mitad and a or b, f) end
        local w = math.floor(interior / 2)
        cuerpo = HorizontalGroup:new{ align = "top", self:columna(a, w), self:columna(b, interior - w) }
    end

    local contenido = VerticalGroup:new{ align = "center" }
    if self.titulo then
        table.insert(contenido, cabecera)
        table.insert(contenido, Estilo.lineaFina(interior))
    end
    table.insert(contenido, cuerpo)
    local alto_tarjeta = contenido:getSize().h + 2 * Estilo.BORDE
    local tarjeta = Estilo.Redondo:new{ ancho = ancho, alto = alto_tarjeta, radio = RADIO, contenido }
    self.tarjeta = tarjeta

    local yo = self
    local cancelar = Estilo.Tocable:new{
        al_tocar = function() yo:cerrar() end,
        Estilo.Redondo:new{ ancho = ancho, alto = alto_cancelar, radio = RADIO,
            TextWidget:new{ text = self.cancelar, face = Font:getFace("cfont", 19), bold = true } },
    }

    local x = math.floor((W - ancho) / 2)
    local y_cancelar = H - m - alto_cancelar
    local y_tarjeta = y_cancelar - m - alto_tarjeta
    tarjeta.overlap_offset = { x, y_tarjeta }
    cancelar.overlap_offset = { x, y_cancelar }
    self.zona = Geom:new{ x = x, y = y_tarjeta, w = ancho, h = H - y_tarjeta }
    self[1] = OverlapGroup:new{ dimen = self.dimen:copy(), tarjeta, cancelar }
end

-- Los toques que no caen en una fila (las filas los consumen antes) cierran la hoja
-- si son fuera de ella.
function Hoja:onFuera(_, ges)
    if not self.zona:contains(ges.pos) then self:cerrar() end
    return true
end

function Hoja:onShow()
    UIManager:setDirty(self, function() return "ui", self.zona end)
end

function Hoja:onCloseWidget()
    UIManager:setDirty(nil, function() return "ui", self.zona end)
end

function Hoja:cerrar()
    UIManager:close(self)
end

function Hoja.mostrar(opciones)
    local h = Hoja:new(opciones)
    UIManager:show(h)
    return h
end

-- Confirmación de una acción que no se puede deshacer: el botón dice lo que hace.
function Hoja.confirmar(titulo, subtitulo, texto_boton, icono, accion)
    return Hoja.mostrar{
        titulo = titulo, subtitulo = subtitulo,
        filas = { { icono = icono, texto = texto_boton, peligro = true, accion = accion } },
    }
end

return Hoja
