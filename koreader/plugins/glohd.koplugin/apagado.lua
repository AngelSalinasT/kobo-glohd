--[[
Pantalla de apagado tipo iPhone: cada acción se confirma deslizando la bolita de la píldora
hasta el otro extremo (evita apagados por un toque accidental, sin ventana de "¿Seguro?").

  ( ⏻ )  desliza para apagar
  ( ↻ )  desliza para reiniciar el Kobo
  ( ↻ )  desliza para reiniciar KOReader

                  ( ✕ )
                 Cancelar

  - Mientras se arrastra, solo se repinta la píldora en modo rápido.
  - Si se suelta antes del 85 %, la bolita regresa al inicio.
]]
local Device = require("device")
local Estilo = require("estilo")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen

local UMBRAL = 0.85

----------------------------------------------------------------------------------------
-- Píldora deslizable
----------------------------------------------------------------------------------------
local Desliza = InputContainer:extend{
    ancho = nil, alto = nil,
    icono = nil, texto = nil,
    al_completar = nil,
    ventana = nil,
    avance = 0, -- 0..1
}

function Desliza:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.ancho, h = self.alto }
    local yo = self
    local rango = function() return yo.dimen end
    self.ges_events = {
        Arrastrar = { GestureRange:new{ ges = "pan", range = rango } },
        Soltar = { GestureRange:new{ ges = "pan_release", range = rango } },
        Deslizar = { GestureRange:new{ ges = "swipe", range = rango } },
        Tocar = { GestureRange:new{ ges = "tap", range = rango } },
    }
end

function Desliza:getSize() return self.dimen end

function Desliza:recorrido()
    return self.ancho - self.alto
end

function Desliza:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local w, h = self.ancho, self.alto
    local r = math.floor(h / 2)
    Estilo.pintarForma(bb, x, y, w, h, r, false)
    local t = TextWidget:new{ text = self.texto, face = Font:getFace("cfont", 19), fgcolor = Estilo.GRIS }
    local ts = t:getSize()
    t:paintTo(bb, x + h + math.floor((w - h - ts.w) / 2), y + math.floor((h - ts.h) / 2))
    t:free()
    -- Bolita negra con el icono en blanco.
    local m = Screen:scaleBySize(5)
    local d = h - 2 * m
    local bx = x + m + math.floor(self:recorrido() * self.avance)
    bb:paintRoundedRect(bx, y + m, d, d, Estilo.NEGRO, math.floor(d / 2))
    local lado = math.floor(d * 0.45)
    Estilo.icono(self.icono, lado, true):paintTo(bb, bx + math.floor((d - lado) / 2), y + m + math.floor((d - lado) / 2))
end

function Desliza:mover(avance, modo)
    self.avance = math.max(0, math.min(1, avance))
    local zona = self.dimen:copy()
    UIManager:setDirty(self.ventana, function() return modo, zona end)
end

function Desliza:terminar(avance)
    if avance >= UMBRAL then
        self:mover(1, "ui")
        if self.al_completar then UIManager:scheduleIn(0.2, self.al_completar) end
    else
        self:mover(0, "ui")
    end
end

-- Solo arrastres que empiezan en esta píldora (un dedo que pasa por encima no cuenta).
function Desliza:onArrastrar(_, ges)
    if not (ges.start_pos and self.dimen:contains(ges.start_pos)) then return false end
    self.arrastrando = true
    self:mover(ges.relative.x / self:recorrido(), "fast")
    return true
end

function Desliza:onSoltar(_, ges)
    if not self.arrastrando then return false end
    self.arrastrando = false
    self:terminar(self.avance)
    return true
end

function Desliza:onDeslizar(_, ges)
    if ges.direction == "east" then self:terminar(ges.distance / self:recorrido()) end
    return true
end

-- Un toque no hace nada (hay que deslizar), igual que en el iPhone.
function Desliza:onTocar() return true end

----------------------------------------------------------------------------------------
local Apagado = InputContainer:extend{
    covers_fullscreen = true,
}

function Apagado:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    local ancho = Screen:getWidth()
    local m = Screen:scaleBySize(26)
    local alto = Screen:scaleBySize(64)
    local yo = self
    local function desliza(icono, texto, accion)
        return Desliza:new{ ancho = ancho - 2 * m, alto = alto, icono = icono, texto = texto, ventana = self,
            al_completar = function() UIManager:close(yo); accion() end }
    end
    local lado_x = Screen:scaleBySize(60)
    local cancelar = Estilo.Tocable:new{
        al_tocar = function() UIManager:close(yo) end,
        VerticalGroup:new{
            align = "center",
            Estilo.Redondo:new{ ancho = lado_x, alto = lado_x, Estilo.icono("cerrar", math.floor(lado_x * 0.4)) },
            VerticalSpan:new{ width = Screen:scaleBySize(8) },
            TextWidget:new{ text = "Cancelar", face = Font:getFace("cfont", 18) },
        },
    }
    local separacion = Screen:scaleBySize(20)
    local grupo = OverlapGroup:new{ dimen = self.dimen:copy() }
    local lista = VerticalGroup:new{
        align = "center",
        -- Directo a la acción: askForPowerOff/askForReboot/askForRestart muestran otra
        -- confirmación, y el deslizador ya es la confirmación.
        desliza("apagar", "desliza para apagar", function() UIManager:nextTick(UIManager.poweroff_action) end),
        VerticalSpan:new{ width = separacion },
        desliza("reiniciar", "desliza para reiniciar el Kobo", function() UIManager:nextTick(UIManager.reboot_action) end),
        VerticalSpan:new{ width = separacion },
        desliza("limpiar", "desliza para reiniciar KOReader", function() UIManager:broadcastEvent(Event:new("Restart")) end),
    }
    lista.overlap_offset = { m, Screen:scaleBySize(70) }
    table.insert(grupo, lista)
    cancelar.overlap_offset = { math.floor((ancho - cancelar:getSize().w) / 2), Screen:getHeight() - Screen:scaleBySize(160) }
    table.insert(grupo, cancelar)
    self[1] = FrameContainer:new{ bordersize = 0, padding = 0, background = Estilo.BLANCO, grupo }
end

function Apagado:onShow()
    UIManager:setDirty(self, "ui")
end

function Apagado:onCloseWidget()
    UIManager:setDirty(nil, "ui")
end

function Apagado.mostrar()
    UIManager:show(Apagado:new{})
end

return Apagado
