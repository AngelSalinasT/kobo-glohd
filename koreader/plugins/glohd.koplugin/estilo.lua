--[[
Piezas visuales compartidas (Barra, Atajos, Ajustes). Reglas para tinta electrónica:
blanco y negro, sin sombras ni animaciones, objetivos de ~9-10 mm y estado visible sin
depender de negritas (● ○, interruptor relleno/vacío, ficha invertida).
]]
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local Screen = Device.screen

local Estilo = {
    ALTO_BOTON = Screen:scaleBySize(54), -- ~9-10 mm en la Glo HD (300 ppi)
    MARGEN = Screen:scaleBySize(12),
    RADIO = Screen:scaleBySize(10),
    BORDE = Screen:scaleBySize(2),
    NEGRO = Blitbuffer.COLOR_BLACK,
    BLANCO = Blitbuffer.COLOR_WHITE,
    GRIS = Blitbuffer.COLOR_DARK_GRAY,
}

local ICONOS = "/mnt/onboard/.adds/koreader/plugins/glohd.koplugin/iconos/"

function Estilo.marca(sel, texto)
    return (sel and "● " or "○ ") .. texto
end

function Estilo.linea(ancho, grueso, color)
    return LineWidget:new{
        background = color or Blitbuffer.COLOR_BLACK,
        dimen = Geom:new{ w = ancho, h = grueso or Screen:scaleBySize(2) },
    }
end

function Estilo.lineaFina(ancho)
    return Estilo.linea(ancho, Size.line.thin, Blitbuffer.COLOR_GRAY)
end

-- Icono propio: iconos/<nombre>.svg (trazo negro) o <nombre>-blanco.svg sobre fondo negro.
-- (Invertir un icono con transparencia en KOReader da un cuadro blanco; por eso hay dos archivos.)
-- alpha: sin recuadro blanco detrás del icono.
function Estilo.icono(nombre, lado, blanco)
    return IconWidget:new{
        file = ICONOS .. nombre .. (blanco and "-blanco" or "") .. ".svg",
        width = lado, height = lado, alpha = true,
    }
end

-- Radio para un FrameContainer de alto `alto` y borde `borde` que quede como píldora/círculo:
-- FrameContainer dibuja con radio + borde, así que hay que restarlo (si no, el borde sale doble).
function Estilo.radioPildora(alto, borde)
    return math.floor(alto / 2) - (borde or Estilo.BORDE)
end

-- Interruptor estilo iOS: relleno negro con la bolita a la derecha = activado.
function Estilo.interruptor(activo)
    local alto = Screen:scaleBySize(26)
    local ancho = Screen:scaleBySize(46)
    local d = alto - 2 * Estilo.BORDE -- alto interior de la píldora = diámetro de la bolita
    local bolita = FrameContainer:new{
        bordersize = Estilo.BORDE,
        color = Estilo.NEGRO,
        background = Estilo.BLANCO,
        radius = Estilo.radioPildora(d),
        padding = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = d - 2 * Estilo.BORDE, h = d - 2 * Estilo.BORDE },
            HorizontalSpan:new{ width = 0 },
        },
    }
    local hueco = HorizontalSpan:new{ width = ancho - 2 * Estilo.BORDE - d }
    return FrameContainer:new{
        bordersize = Estilo.BORDE,
        color = Estilo.NEGRO,
        background = activo and Estilo.NEGRO or Estilo.BLANCO,
        radius = Estilo.radioPildora(alto),
        padding = 0,
        HorizontalGroup:new{
            align = "center",
            activo and hueco or bolita,
            activo and bolita or hueco,
        },
    }
end

-- Contorno redondeado sólido: forma negra y encima la misma en blanco, más chica.
-- (paintBorder con radio solo traza las dos orillas del arco y en radios grandes el borde
-- sale doble; FrameContainer usa lo mismo.)
function Estilo.pintarForma(bb, x, y, w, h, r, relleno)
    local b = Estilo.BORDE
    bb:paintRoundedRect(x, y, w, h, Estilo.NEGRO, r)
    if not relleno then
        bb:paintRoundedRect(x + b, y + b, w - 2 * b, h - 2 * b, Estilo.BLANCO, math.max(0, r - b))
    end
end

-- Relleno negro de la parte de abajo (alto `alto_relleno`) de una forma ya pintada.
-- Se dibuja la forma interior completa en un recorte (viewport) de esa franja.
function Estilo.pintarRellenoInferior(bb, x, y, w, h, r, alto_relleno)
    if alto_relleno <= 0 then return end
    local b = Estilo.BORDE
    local franja = bb:viewport(x, y + h - alto_relleno, w, alto_relleno)
    franja:paintRoundedRect(b, b - (h - alto_relleno), w - 2 * b, h - 2 * b, Estilo.NEGRO, math.max(0, r - b))
end

-- Forma redondeada (círculo, píldora, módulo) con contorno sólido.
local WidgetContainer = require("ui/widget/container/widgetcontainer")
Estilo.Redondo = WidgetContainer:extend{
    ancho = nil, alto = nil,
    radio = nil,          -- nil = píldora/círculo (mitad del lado menor)
    relleno = false,      -- true = fondo negro
}

function Estilo.Redondo:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.ancho, h = self.alto }
end

function Estilo.Redondo:getSize() return self.dimen end

function Estilo.Redondo:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local r = self.radio or math.floor(math.min(self.ancho, self.alto) / 2)
    Estilo.pintarForma(bb, x, y, self.ancho, self.alto, r, self.relleno)
    local hijo = self[1]
    if hijo then
        local s = hijo:getSize()
        hijo:paintTo(bb, x + math.floor((self.ancho - s.w) / 2), y + math.floor((self.alto - s.h) / 2))
    end
end

-- Contenedor que llama a `al_tocar` al tocarlo (ficha, fila de Ajustes).
Estilo.Tocable = InputContainer:extend{
    al_tocar = nil,
    al_mantener = nil,
}

function Estilo.Tocable:init()
    local yo = self
    self.ges_events = {
        Tocar = { GestureRange:new{ ges = "tap", range = function() return yo.dimen end } },
        Mantener = { GestureRange:new{ ges = "hold", range = function() return yo.dimen end } },
    }
end

function Estilo.Tocable:onTocar(_, ges)
    if self.al_tocar then self.al_tocar(ges) end
    return true
end

function Estilo.Tocable:onMantener(_, ges)
    if self.al_mantener then self.al_mantener(ges) end
    return true
end

return Estilo
