--[[
Atajos: pantalla tipo Centro de control de iOS, adaptada a tinta electrónica.

  - Fijos: estados (Wi-Fi, Red USB, Noche, Girar), módulo "Leyendo" y brillo.
  - Según dónde estés:
      libro de texto  → Limpiar, Ir a página, Marcar página, Biblioteca, Índice, Buscar,
                        Marcadores, Ajustes, Volver
      manga / PDF     → igual, con Hojear en lugar de Buscar
      Biblioteca      → Pasar libros por USB, Archivos, Buscar, Historial, Favoritos,
                        Colecciones, Limpiar, Ajustes, Dormir
    (El tamaño de letra no está aquí: ya lo tiene "Aa" en la barra de lectura. Dormir solo en
    la Biblioteca: dentro de un libro basta el botón físico.)
  - Vertical: 4 columnas; horizontal: 7 columnas (ver Atajos:construir).
  - Activo = círculo negro con icono blanco (el azul de iOS). Sin animaciones.
  - Mantener presionado un círculo muestra su nombre (como en iOS).
  - Tocar un espacio vacío, la barrita de abajo o deslizar hacia arriba cierra.
  - Si se abrió con un arrastre (el dedo sigue en la pantalla), ese arrastre se ignora hasta
    soltar: si no, el dedo pasaba por el deslizador de brillo y lo subía al 100 %.
Se abre deslizando hacia abajo desde el borde superior (en el libro y en la Biblioteca),
desde "Atajos" en la barra de lectura y deslizando hacia abajo desde arriba en la Biblioteca.
]]
local Apagado = require("apagado")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Estilo = require("estilo")
local Event = require("ui/event")
local Font = require("ui/font")
local Lectura = require("lectura")
local Sagas = require("sagas")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Notification = require("ui/widget/notification")
local OverlapGroup = require("ui/widget/overlapgroup")
local ReadHistory = require("readhistory")
local Sistema = require("sistema")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen

local M = Screen:scaleBySize(26)          -- margen lateral
local G = Screen:scaleBySize(12)          -- separación de la cuadrícula
local RADIO_MODULO = Screen:scaleBySize(26)

local function posicionar(widget, x, y)
    widget.overlap_offset = { x, y }
    return widget
end

----------------------------------------------------------------------------------------
-- Deslizador vertical (píldora): relleno negro desde abajo según el valor, icono abajo.
----------------------------------------------------------------------------------------
local Deslizador = InputContainer:extend{
    ancho = nil, alto = nil,
    valor = 0,           -- 0..1
    icono = nil,         -- nombre para Estilo.icono
    texto = nil,         -- alternativa al icono (p. ej. "Aa")
    al_cambiar = nil,    -- function(fraccion 0..1, en_vivo): en_vivo = el dedo sigue arrastrando
    ventana = nil,       -- widget de nivel superior, para repintar solo la píldora al arrastrar
}

function Deslizador:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.ancho, h = self.alto }
    local yo = self
    self.ges_events = {
        Tocar = { GestureRange:new{ ges = "tap", range = function() return yo.dimen end } },
        Arrastrar = { GestureRange:new{ ges = "pan", range = function() return yo.dimen end } },
        Soltar = { GestureRange:new{ ges = "pan_release", range = function() return yo.dimen end } },
        Deslizar = { GestureRange:new{ ges = "swipe", range = function() return yo.dimen end } },
    }
end

function Deslizador:getSize() return self.dimen end

function Deslizador:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local w, h = self.ancho, self.alto
    local r = math.floor(w / 2)
    local relleno = math.floor(h * math.max(0, math.min(1, self.valor)))
    Estilo.pintarForma(bb, x, y, w, h, r, false)
    Estilo.pintarRellenoInferior(bb, x, y, w, h, r, relleno)
    local lado = Screen:scaleBySize(26)
    local iy = y + h - lado - Screen:scaleBySize(22)
    local invertido = relleno > (h - (iy - y) - lado / 2)
    if self.icono then
        Estilo.icono(self.icono, lado, invertido):paintTo(bb, x + math.floor((w - lado) / 2), iy)
    elseif self.texto then
        local t = TextWidget:new{ text = self.texto, face = Font:getFace("cfont", 18), bold = true,
            fgcolor = invertido and Estilo.BLANCO or Estilo.NEGRO }
        local ts = t:getSize()
        t:paintTo(bb, x + math.floor((w - ts.w) / 2), iy + math.floor((lado - ts.h) / 2))
        t:free()
    end
end

function Deslizador:fraccion(y)
    return math.max(0, math.min(1, 1 - (y - self.dimen.y) / self.alto))
end

function Deslizador:aplicar(f, en_vivo)
    self.valor = f
    if self.al_cambiar then self.al_cambiar(f, en_vivo) end
    if en_vivo and self.ventana then
        -- Mientras se arrastra: solo la píldora, en modo rápido (A2), sin destello.
        local zona = self.dimen:copy()
        UIManager:setDirty(self.ventana, function() return "fast", zona end)
    end
end

-- Como en el Centro de control de iOS: tocar no cambia nada; arrastrar mueve el valor en
-- relación a donde estaba (según cuánto se mueve el dedo), sin saltar al punto tocado.
function Deslizador:onTocar() return true end

function Deslizador:relativo(dy)
    return math.max(0, math.min(1, (self.valor_inicio or self.valor) - dy / self.alto))
end

-- Solo cuenta un arrastre que EMPEZÓ en la píldora: si no, un dedo que solo pasa por encima
-- (al abrir el panel, al subir desde la barrita) movía el brillo.
function Deslizador:onArrastrar(_, ges)
    if not (ges.start_pos and self.dimen:contains(ges.start_pos)) then return false end
    if not self.arrastrando then
        self.arrastrando = true
        self.valor_inicio = self.valor
    end
    self:aplicar(self:relativo(ges.pos.y - ges.start_pos.y), true)
    return true
end

function Deslizador:onSoltar(_, ges)
    if not self.arrastrando then return false end
    self.arrastrando = false
    local final = self.valor
    self.valor_inicio = nil
    self:aplicar(final, false)
    return true
end

-- Un deslizamiento rápido llega como swipe (sin pan): se mueve lo que recorrió el dedo.
function Deslizador:onDeslizar(_, ges)
    -- Si hubo arrastre, KOReader termina el gesto con un swipe en vez de pan_release:
    -- el valor ya está aplicado, solo se cierra (si no, el recorrido contaría dos veces).
    if self.arrastrando then return self:onSoltar(_, ges) end
    if not self.dimen:contains(ges.pos) then return false end
    local dy = 0
    if ges.direction == "north" then dy = -ges.distance
    elseif ges.direction == "south" then dy = ges.distance
    else return true end
    self.valor_inicio = nil
    self:aplicar(self:relativo(dy), false)
    return true
end

----------------------------------------------------------------------------------------
local Atajos = InputContainer:extend{
    ui = nil,
    covers_fullscreen = true,
    esperar_soltar = false,
    -- Se asignan desde main.lua para no crear dependencias circulares.
    abrirAjustes = nil,
    abrirArchivos = nil,
}

function Atajos:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Tocar = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Deslizar = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    self:construir()
end

function Atajos:enLibro()
    return self.ui and self.ui.document ~= nil
end

function Atajos:circulo(def, lado)
    local activo = def.activo and def.activo() or false
    return Estilo.Tocable:new{
        al_tocar = def.accion,
        al_mantener = function() Notification:notify(def.texto) end,
        Estilo.Redondo:new{
            ancho = lado, alto = lado, relleno = activo,
            Estilo.icono(def.icono, def.lado_icono or math.floor(lado * 0.36), activo),
        },
    }
end

function Atajos:modulo(ancho, alto, contenido, al_tocar)
    local marco = Estilo.Redondo:new{ ancho = ancho, alto = alto, radio = RADIO_MODULO, contenido }
    if al_tocar then return Estilo.Tocable:new{ al_tocar = al_tocar, marco } end
    return marco
end

----------------------------------------------------------------------------------------
-- Acciones
----------------------------------------------------------------------------------------
function Atajos:defs()
    local yo = self
    local ui = self.ui
    local NetworkMgr = require("ui/network/manager")
    local function evento(nombre, ...)
        local args = { ... }
        return function() yo:cerrarY(function() ui:handleEvent(Event:new(nombre, table.unpack(args))) end) end
    end
    local d = {
        wifi = { icono = "wifi", texto = "Wi-Fi",
            activo = function() return NetworkMgr:isWifiOn() end,
            accion = function()
                yo:cerrarY(function()
                    if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff() else NetworkMgr:toggleWifiOn() end
                end)
            end },
        -- Encender la red tarda ~2 s (carga g_ether): el botón cambia en el acto y el
        -- script corre después del repintado, para que el toque tenga respuesta inmediata.
        usb = { icono = "usb", texto = "Red USB",
            activo = function()
                if yo.usb_destino ~= nil then return yo.usb_destino end
                return Sistema.red_activa()
            end,
            accion = function()
                if yo.usb_destino ~= nil then return end
                yo.usb_destino = not Sistema.red_activa()
                yo:actualizar()
                UIManager:scheduleIn(0.3, function()
                    Sistema.alternarRed(true)
                    yo.usb_destino = nil
                    yo:actualizar()
                end)
            end },
        noche = { icono = "luna", texto = "Modo noche",
            activo = function() return G_reader_settings:isTrue("night_mode") end,
            accion = function() ui:handleEvent(Event:new("ToggleNightMode")); yo:actualizar() end },
        girar = { icono = "girar", texto = "Girar",
            accion = function()
                yo:cerrarY(function()
                    ui:handleEvent(Event:new("SwapRotation"))
                    -- La Biblioteca vuelve a fm_rotation_mode cada vez que se crea (al cerrar
                    -- un libro): se guarda para que se quede como la dejaste. Cada libro ya
                    -- recuerda la suya.
                    if not ui.document then
                        G_reader_settings:saveSetting("fm_rotation_mode", Screen:getRotationMode())
                    end
                end)
            end },
        dormir = { icono = "dormir", texto = "Dormir", accion = evento("RequestSuspend") },
        limpiar = { icono = "limpiar", texto = "Limpiar pantalla",
            accion = function() yo:cerrarY(function() UIManager:setDirty(nil, "full") end) end },
        ajustes = { icono = "ajustes", texto = "Ajustes",
            accion = function() yo:cerrarY(function() if yo.abrirAjustes then yo.abrirAjustes(ui) end end) end },
    }
    local function biblioteca()
        local file = ui.document.file
        yo:cerrar()
        ui:onClose()
        ui:showFileManager(file)
    end
    local function archivos()
        yo:cerrarY(function() if yo.abrirArchivos then yo.abrirArchivos() end end)
    end
    -- d.pildoras: 2 acciones anchas; d.circulos: 7 (en vertical caben 6, en horizontal 7).
    if self:enLibro() then
        local marcar = { icono = "marcador", texto = "Marcar página",
            activo = function() return ui.bookmark:isPageBookmarked() end,
            accion = function() ui.bookmark:onToggleBookmark(); yo:actualizar() end }
        local casa = { icono = "casa", texto = "Biblioteca", accion = biblioteca }
        local indice = { icono = "indice", texto = "Índice", accion = evento("ShowToc") }
        local marcadores = { icono = "marcadores", texto = "Marcadores", accion = evento("ShowBookmark") }
        local volver = { icono = "volver", texto = "Volver (tras una nota o enlace)", accion = evento("GoBackLink") }
        if ui.rolling then
            -- Libro de texto
            d.pildoras = { d.limpiar, { icono = "ir", texto = "Ir a página", accion = function() yo:cerrarY(function() Lectura.irAPagina(ui) end) end } }
            d.circulos = { marcar, casa, indice,
                { icono = "buscar", texto = "Buscar en el libro", accion = evento("ShowFulltextSearchInput") },
                marcadores, d.ajustes, volver }
        else
            -- Manga / PDF: hojear en lugar de buscar (no hay texto)
            d.pildoras = { d.limpiar, { icono = "hojear", texto = "Hojear", accion = evento("ShowSkimtoDialog") } }
            d.circulos = { marcar, casa, indice,
                { icono = "ir", texto = "Ir a página", accion = function() yo:cerrarY(function() Lectura.irAPagina(ui) end) end },
                marcadores, d.ajustes, volver }
        end
    else
        d.pildoras = {
            { icono = "transferir", texto = "Pasar libros por USB", accion = evento("RequestUSBMS") },
            { icono = "carpeta", texto = "Archivos", accion = archivos },
        }
        d.circulos = {
            { icono = "buscar", texto = "Buscar archivos", accion = evento("ShowFileSearch") },
            { icono = "historial", texto = "Historial", accion = evento("ShowHist") },
            { icono = "estrella", texto = "Favoritos", accion = evento("ShowColl") },
            { icono = "colecciones", texto = "Colecciones", accion = evento("ShowCollList") },
            d.limpiar, d.ajustes,
            { icono = "dormir", texto = "Dormir", accion = evento("RequestSuspend") },
        }
    end
    return d
end

-- Módulo "Leyendo": en un libro, título, página y capítulo anterior/siguiente;
-- en la Biblioteca, el último libro abierto (tocar = seguir leyendo).
function Atajos:leyendo(ancho, alto)
    local yo = self
    local ui = self.ui
    local interior = ancho - 2 * Screen:scaleBySize(22)
    local titulo, detalle, al_tocar, botones
    if self:enLibro() then
        local props = ui.doc_props or {}
        local _, saga, k = Sagas.tituloLectura(ui.document.file)
        local pagina = string.format("Pág. %d de %d", ui:getCurrentPage(), ui.document:getPageCount())
        if saga then
            -- Tomo de una saga: ‹ › cambian de tomo (los mangas no tienen capítulos).
            titulo = saga.nombre
            detalle = Sagas.nombreTomo(saga.tomos[k], saga.nombre) .. " de " .. #saga.tomos .. " · pág. " .. ui:getCurrentPage()
            local function tomo(delta)
                local hay = saga.tomos[k + delta] ~= nil
                return Button:new{ text = delta < 0 and "‹ Tomo" or "Tomo ›", text_font_size = 19,
                    text_font_bold = true, bordersize = 0, enabled = hay, width = math.floor(interior / 2),
                    height = Estilo.ALTO_BOTON, show_parent = self,
                    callback = function() yo:cerrarY(function() Lectura.cambiarTomo(ui, delta) end) end }
            end
            botones = HorizontalGroup:new{ tomo(-1), tomo(1) }
        else
            titulo = props.display_title or props.title or ui.document.file:gsub(".*/", "")
            detalle = pagina
            local function capitulo(nombre)
                return Button:new{ text = nombre == "GotoPrevChapter" and "‹‹" or "››", text_font_size = 22,
                    text_font_bold = true, bordersize = 0, width = math.floor(interior / 2), height = Estilo.ALTO_BOTON,
                    callback = function() ui:handleEvent(Event:new(nombre)); yo:actualizar() end, show_parent = self }
            end
            botones = HorizontalGroup:new{ capitulo("GotoPrevChapter"), capitulo("GotoNextChapter") }
        end
    else
        local ultimo = ReadHistory.hist[1]
        if ultimo then
            titulo = Sagas.tituloLectura(ultimo.file)
                or ultimo.file:gsub(".*/", ""):gsub("%.[^.]+$", ""):gsub("_", " ")
            detalle = "Seguir leyendo ›"
            al_tocar = function()
                yo:cerrarY(function()
                    require("apps/filemanager/filemanagerutil").openFile(ui, ultimo.file)
                end)
            end
        else
            titulo, detalle = "Sin lecturas", ""
        end
    end
    local grupo = VerticalGroup:new{
        align = "left",
        TextBoxWidget:new{ text = titulo, face = Font:getFace("cfont", 19), bold = true,
            width = interior, height = Screen:scaleBySize(54), height_overflow_show_ellipsis = true },
        VerticalSpan:new{ width = Screen:scaleBySize(4) },
        TextWidget:new{ text = detalle, face = Font:getFace("cfont", 16), fgcolor = Estilo.GRIS, max_width = interior },
    }
    if botones then table.insert(grupo, botones) end
    return self:modulo(ancho, alto, LeftContainer:new{ dimen = Geom:new{ w = interior, h = grupo:getSize().h }, grupo }, al_tocar)
end

function Atajos:deslizadorBrillo(ancho, alto)
    local yo = self
    local powerd = Device:getPowerDevice()
    local nivel = powerd:isFrontlightOn() and powerd:frontlightIntensity() or 0
    return Deslizador:new{
        ancho = ancho, alto = alto, valor = nivel / 100, icono = "sol", ventana = self,
        al_cambiar = function(f, en_vivo)
            local v = math.floor(100 * f + 0.5)
            if v <= 2 then
                powerd:turnOffFrontlight()
            else
                powerd:setIntensity(v)
                if not powerd:isFrontlightOn() then powerd:turnOnFrontlight() end
            end
            if not en_vivo then yo:actualizar() end
        end,
    }
end

-- Píldora ancha (como "Enfoque" en iOS): círculo con icono + texto.
function Atajos:pildora(ancho, alto, def)
    local lado = alto - 2 * Screen:scaleBySize(14)
    local contenido = HorizontalGroup:new{
        align = "center",
        HorizontalSpan:new{ width = Screen:scaleBySize(14) },
        Estilo.Redondo:new{ ancho = lado, alto = lado, Estilo.icono(def.icono, math.floor(lado * 0.5)) },
        HorizontalSpan:new{ width = Screen:scaleBySize(16) },
        TextBoxWidget:new{ text = def.texto, face = Font:getFace("cfont", 19), bold = true,
            width = ancho - lado - Screen:scaleBySize(56) },
    }
    return Estilo.Tocable:new{
        al_tocar = def.accion,
        Estilo.Redondo:new{
            ancho = ancho, alto = alto,
            LeftContainer:new{ dimen = Geom:new{ w = ancho - 2 * Estilo.BORDE, h = alto - 2 * Estilo.BORDE }, contenido },
        },
    }
end

function Atajos:menuApagado()
    self:cerrarY(function() Apagado.mostrar() end)
end

----------------------------------------------------------------------------------------
-- Distribución. Unidades: celda de lado c, separación G.
--   Vertical (4 columnas):            Horizontal (7 columnas):
--   [Estados ][Leyendo ]               [Estados ][Leyendo ][B][1][2]
--   [Píldora 1    ][B][1]              [        ][        ][r][3][4]
--   [Píldora 2    ][r][2]              [Píldora 1][Píldora 2][5][6][7]
--   [3][4][5][6]
-- (B = brillo; números = círculos del contexto)
----------------------------------------------------------------------------------------
function Atajos:construir()
    local yo = self
    local ancho, alto = Screen:getWidth(), Screen:getHeight()
    local horizontal = ancho > alto
    local d = self:defs()
    local grupo = OverlapGroup:new{ dimen = self.dimen:copy() }
    local y = Screen:scaleBySize(16)

    -- Estado y apagado
    local cap, _, cargador = Sistema.estado()
    local estado = TextWidget:new{
        text = string.format("%s%%%s · %s", tostring(cap), cargador and " ⚡" or "", os.date("%H:%M")),
        face = Font:getFace("cfont", 18), bold = true,
    }
    local lado_apagar = Screen:scaleBySize(46)
    table.insert(grupo, posicionar(estado, M, y + math.floor((lado_apagar - estado:getSize().h) / 2)))
    table.insert(grupo, posicionar(self:circulo({ icono = "apagar", texto = "Apagar o reiniciar",
        lado_icono = Screen:scaleBySize(22), accion = function() yo:menuApagado() end }, lado_apagar),
        ancho - M - lado_apagar, y))
    y = y + lado_apagar + Screen:scaleBySize(18)

    local alto_barrita = Screen:scaleBySize(30)
    local columnas = horizontal and 7 or 4
    local filas = horizontal and 3 or 5
    local c = math.min(
        math.floor((ancho - 2 * M - (columnas - 1) * G) / columnas),
        math.floor((alto - y - alto_barrita - (filas - 1) * G) / filas))
    local doble = 2 * c + G
    -- Centrar la cuadrícula
    local x0 = math.floor((ancho - (columnas * c + (columnas - 1) * G)) / 2)
    local y0 = y + math.floor((alto - y - alto_barrita - (filas * c + (filas - 1) * G)) / 2)
    local function celda(col, fila) -- base 0
        return x0 + col * (c + G), y0 + fila * (c + G)
    end
    local function poner(widget, col, fila)
        local px, py = celda(col, fila)
        table.insert(grupo, posicionar(widget, px, py))
    end

    -- Módulo de estados (2x2) y módulo "Leyendo"
    local hueco = Screen:scaleBySize(14)
    local lado_mini = math.floor((doble - 2 * Estilo.BORDE - 3 * hueco) / 2)
    local estados = VerticalGroup:new{
        HorizontalGroup:new{ self:circulo(d.wifi, lado_mini), HorizontalSpan:new{ width = hueco }, self:circulo(d.usb, lado_mini) },
        VerticalSpan:new{ width = hueco },
        HorizontalGroup:new{ self:circulo(d.noche, lado_mini), HorizontalSpan:new{ width = hueco }, self:circulo(d.girar, lado_mini) },
    }
    poner(self:modulo(doble, doble, estados), 0, 0)
    poner(self:leyendo(doble, doble), 2, 0)

    local circulos = d.circulos
    if horizontal then
        poner(self:deslizadorBrillo(c, doble), 4, 0)
        poner(self:circulo(circulos[1], c), 5, 0)
        poner(self:circulo(circulos[2], c), 6, 0)
        poner(self:circulo(circulos[3], c), 5, 1)
        poner(self:circulo(circulos[4], c), 6, 1)
        poner(self:pildora(doble, c, d.pildoras[1]), 0, 2)
        poner(self:pildora(doble, c, d.pildoras[2]), 2, 2)
        for i = 5, 7 do poner(self:circulo(circulos[i], c), i - 1, 2) end
    else
        poner(self:pildora(doble, c, d.pildoras[1]), 0, 2)
        poner(self:pildora(doble, c, d.pildoras[2]), 0, 3)
        poner(self:deslizadorBrillo(c, doble), 2, 2)
        poner(self:circulo(circulos[1], c), 3, 2)
        poner(self:circulo(circulos[2], c), 3, 3)
        for i = 3, 6 do poner(self:circulo(circulos[i], c), i - 3, 4) end
    end

    -- Barrita para cerrar (como la de inicio de iOS): tocarla o arrastrar hacia arriba desde ella.
    local _, fin = celda(0, filas)
    local alto_zona = alto - fin + G
    local barrita = Estilo.Tocable:new{
        al_tocar = function() yo:cerrar() end,
        CenterContainer:new{
            dimen = Geom:new{ w = ancho, h = alto_zona },
            Estilo.Redondo:new{ ancho = Screen:scaleBySize(80), alto = Screen:scaleBySize(7), relleno = true },
        },
    }
    table.insert(grupo, posicionar(barrita, 0, fin - G))
    self.zona_barrita = Geom:new{ x = 0, y = fin - G, w = ancho, h = alto_zona }

    self[1] = FrameContainer:new{ bordersize = 0, padding = 0, background = Estilo.BLANCO, grupo }
end

function Atajos:actualizar()
    self:construir()
    UIManager:setDirty(self, "ui")
end

-- Tocar un espacio vacío (nada lo atendió antes) cierra, como en iOS.
function Atajos:onTocar()
    self:cerrar()
    return true
end

function Atajos:onDeslizar(_, ges)
    if ges.direction == "north" then self:cerrar() end
    return true
end

-- Mientras el dedo que abrió el panel no se levante, se ignoran sus gestos. Un arrastre que
-- empieza en la zona de la barrita es para cerrar (no llega a los demás controles). Va en
-- handleEvent porque los hijos (deslizadores, círculos) reciben el gesto antes que onGesture.
function Atajos:handleEvent(event)
    if event.handler == "onGesture" and self.zona_barrita then
        local ges = event.args and event.args[1]
        local g = ges and ges.ges
        if g == "pan" and ges.start_pos and self.zona_barrita:contains(ges.start_pos) then
            self.arrastre_barrita = ges.pos.y < ges.start_pos.y - Screen:scaleBySize(20)
            return true
        elseif g == "pan_release" and self.arrastre_barrita ~= nil then
            local cerrar = self.arrastre_barrita
            self.arrastre_barrita = nil
            if cerrar then self:cerrar() end
            return true
        elseif g == "swipe" and ges.pos and self.zona_barrita:contains(ges.pos) then
            if ges.direction == "north" then self:cerrar() end
            return true
        end
    end
    if self.esperar_soltar and event.handler == "onGesture" then
        local ges = event.args and event.args[1]
        local g = ges and ges.ges
        if g == "pan_release" or g == "swipe" or g == "hold_release" then
            self.esperar_soltar = false
            return true
        end
        if g ~= "tap" then return true end
        self.esperar_soltar = false
    end
    return InputContainer.handleEvent(self, event)
end

function Atajos:onShow()
    UIManager:setDirty(self, "ui")
end

function Atajos:onCloseWidget()
    UIManager:setDirty(nil, "ui")
    if Atajos.actual == self then Atajos.actual = nil end
end

function Atajos:cerrar()
    UIManager:close(self)
end

function Atajos:cerrarY(accion)
    self:cerrar()
    UIManager:nextTick(accion)
end

-- esperar_soltar: true si se abre en medio de un arrastre (gesto "pan").
function Atajos.mostrar(ui, esperar_soltar)
    if Atajos.actual then return end
    Atajos.actual = Atajos:new{ ui = ui, esperar_soltar = esperar_soltar or false }
    UIManager:show(Atajos.actual)
end

return Atajos
