--[[
Biblioteca: pantalla de inicio tipo Kindle para la Glo HD.

  - Portadas en mosaico (piezas del plugin CoverBrowser: CoverMenu + MosaicMenu).
  - Pestañas visibles bajo el título: Leyendo · Libros · Mangas (un toque, sin ventanas).
  - Arriba a la derecha, carpeta = Archivos (el administrador avanzado de KOReader).
    Arriba a la izquierda, dentro de una saga, regresar (‹). Los Atajos se abren deslizando
    hacia abajo desde arriba (sin ☰: el gesto ya está y el botón sobraba).
  - Sagas (subcarpetas de Mangas o de un tema de Libros; reglas en sagas.lua): una sola
    portada, la del tomo en que vas. Un toque abre ese tomo donde ibas (o el primero).
    Toque largo = página de la saga: arriba "Seguir · Tomo 1, pág. 14", abajo los tomos
    en orden. Ahí, toque largo en un tomo = marcar leído / no leído.
  - Libros: los temas (carpetas) se juntan; un libro en dos idiomas es una sola portada
    (la primera vez pregunta en cuál leer). Leyendo no muestra libros terminados.
  - Paginado sin << < > >>: puntitos (● ○ ○) y deslizar a los lados. Deslizar vertical en
    el cuarto izquierdo es el brillo, como en el lector.
]]
local Atajos = require("atajos")
local Estilo = require("estilo")
local Sagas = require("sagas")
local Hoja = require("hoja")
local BookList = require("ui/widget/booklist")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local LineWidget = require("ui/widget/linewidget")
local ReadHistory = require("readhistory")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local Screen = Device.screen

local RAIZ = Sagas.RAIZ
local SECCIONES = { "leyendo", "libros", "mangas" }
local NOMBRES = { leyendo = "Leyendo", libros = "Libros", mangas = "Mangas" }
local MAX_LEYENDO = 30
local MAX_PUNTOS = 12
-- Ícono vacío para la izquierda fuera de una saga (TitleBar busca los íconos por nombre
-- desde resources/icons/mdlight; esta ruta relativa llega a los del plugin).
local SIN_ICONO = "../../../plugins/glohd.koplugin/iconos/vacio"

-- Las piezas de CoverBrowser solo están en package.path mientras ese plugin carga.
local CB_DIR = "/mnt/onboard/.adds/koreader/plugins/coverbrowser.koplugin"
local function requireCB(nombre)
    if package.loaded[nombre] then return package.loaded[nombre] end
    local antes = package.path
    package.path = CB_DIR .. "/?.lua;" .. antes
    local ok, mod = pcall(require, nombre)
    package.path = antes
    if not ok then
        logger.warn("glohd biblioteca: no se pudo cargar", nombre, mod)
        return nil
    end
    return mod
end

local esDocumento, documentosEn, itemLibro, ordenar = Sagas.esDocumento, Sagas.documentosEn, Sagas.item, Sagas.ordenar

-- Elemento del mosaico para una saga: la portada es la del tomo en que vas.
local function itemSerie(saga)
    return {
        file = saga.tomos[saga.actual].file,
        text = saga.nombre,
        select_enabled = false,
        glohd_serie = saga,
    }
end

----------------------------------------------------------------------------------------
-- Secciones
----------------------------------------------------------------------------------------
local function itemsLeyendo()
    local items, vistas = {}, {}
    for _, h in ipairs(ReadHistory.hist) do
        if #items >= MAX_LEYENDO then break end
        if not h.dim and esDocumento(h.file) and lfs.attributes(h.file, "mode") == "file" then
            local dir, nombre = Sagas.carpeta(h.file)
            if dir then
                if not vistas[dir] then
                    vistas[dir] = true
                    local saga = Sagas.deCarpeta(dir, nombre)
                    if saga then table.insert(items, itemSerie(saga)) end
                end
            elseif Sagas.estado(h.file).tipo ~= "terminado" then
                table.insert(items, itemLibro(h.file))
            end
        end
    end
    return items
end

-- Libros: cada tema (Books/Psicologia…) aporta sus libros sueltos y sus sagas (subcarpetas);
-- las versiones de un libro en dos idiomas salen como una sola portada.
local function itemsLibros()
    local sueltos, sagas = {}, {}
    local ok, iter, dir_obj = pcall(lfs.dir, RAIZ.libros)
    if not ok then return {} end
    local function tema(dir)
        local ok2, it2, obj2 = pcall(lfs.dir, dir)
        if not ok2 then return end
        for nombre in it2, obj2 do
            if nombre ~= "." and nombre ~= ".." and not nombre:match("^[%._]") then
                local ruta = dir .. "/" .. nombre
                local modo = lfs.attributes(ruta, "mode")
                if modo == "file" and esDocumento(ruta) then
                    table.insert(sueltos, ruta)
                elseif modo == "directory" and not nombre:match("%.sdr$") then
                    local saga = Sagas.deCarpeta(ruta, nombre)
                    if saga then table.insert(sagas, itemSerie(saga)) end
                end
            end
        end
    end
    for nombre in iter, dir_obj do
        if nombre ~= "." and nombre ~= ".." and not nombre:match("^[%._]") then
            local ruta = RAIZ.libros .. "/" .. nombre
            local modo = lfs.attributes(ruta, "mode")
            if modo == "directory" and not nombre:match("%.sdr$") then
                tema(ruta)
            elseif modo == "file" and esDocumento(ruta) then
                table.insert(sueltos, ruta)
            end
        end
    end
    local items = Sagas.agruparIdiomas(sueltos)
    for _, s in ipairs(sagas) do table.insert(items, s) end
    return ordenar(items)
end

local function itemsMangas()
    local series, sueltos = {}, {}
    local ok, iter, dir_obj = pcall(lfs.dir, RAIZ.mangas)
    if not ok then return {} end
    for nombre in iter, dir_obj do
        if nombre ~= "." and nombre ~= ".." and not nombre:match("^[%._]") then
            local ruta = RAIZ.mangas .. "/" .. nombre
            local modo = lfs.attributes(ruta, "mode")
            if modo == "directory" and not nombre:match("%.sdr$") then
                local saga = Sagas.deCarpeta(ruta, nombre)
                if saga then table.insert(series, itemSerie(saga)) end
            elseif modo == "file" and esDocumento(ruta) then
                table.insert(sueltos, itemLibro(ruta))
            end
        end
    end
    ordenar(series)
    for _, s in ipairs(ordenar(sueltos)) do table.insert(series, s) end
    return series
end

local GENERADORES = { leyendo = itemsLeyendo, libros = itemsLibros, mangas = itemsMangas }

----------------------------------------------------------------------------------------
-- Pestañas
----------------------------------------------------------------------------------------
local function pestanas(ancho, actual, al_tocar)
    local fila = HorizontalGroup:new{}
    local subrayado = HorizontalGroup:new{}
    local ancho_pestana = math.floor(ancho / #SECCIONES)
    local grueso = Screen:scaleBySize(3)
    for _, clave in ipairs(SECCIONES) do
        local sel = clave == actual
        table.insert(fila, CenterContainer:new{
            dimen = Geom:new{ w = ancho_pestana, h = Screen:scaleBySize(36) },
            Button:new{
                text = NOMBRES[clave],
                bordersize = 0,
                text_font_bold = sel,
                text_font_size = 20,
                callback = function() al_tocar(clave) end,
            },
        })
        table.insert(subrayado, LineWidget:new{
            background = sel and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
            dimen = Geom:new{ w = ancho_pestana, h = grueso },
        })
    end
    return VerticalGroup:new{
        fila,
        subrayado,
        LineWidget:new{
            background = Blitbuffer.COLOR_GRAY,
            dimen = Geom:new{ w = ancho, h = Size.line.thin },
        },
        VerticalSpan:new{ width = Screen:scaleBySize(4) },
    }
end

----------------------------------------------------------------------------------------
local Biblioteca = {}

local function claseLista()
    local CoverMenu = requireCB("covermenu")
    local MosaicMenu = requireCB("mosaicmenu")
    local BookInfoManager = requireCB("bookinfomanager")
    if not (CoverMenu and MosaicMenu and BookInfoManager) then return nil end
    -- Sin barra de avance bajo las portadas (se probó y no gustó); el estado se ve
    -- con la esquina doblada (abierto) y la palomita (terminado). Deshace la prueba de ese día.
    if G_reader_settings:isTrue("glohd_progreso_mosaico") then
        BookInfoManager:saveSetting("show_progress_in_mosaic", false)
        G_reader_settings:delSetting("glohd_progreso_mosaico")
    end

    local Lista = BookList:extend{
        updateItems = CoverMenu.updateItems,
        onCloseWidget = CoverMenu.onCloseWidget,
        _updateItemsBuildUI = MosaicMenu._updateItemsBuildUI,
        _do_cover_images = true,
        _do_center_partial_rows = true,
        _do_hint_opened = true,
        display_mode_type = "mosaic",
        nb_cols_portrait = BookInfoManager:getSetting("nb_cols_portrait") or 3,
        nb_rows_portrait = BookInfoManager:getSetting("nb_rows_portrait") or 3,
        nb_cols_landscape = BookInfoManager:getSetting("nb_cols_landscape") or 4,
        nb_rows_landscape = BookInfoManager:getSetting("nb_rows_landscape") or 2,
    }

    -- El mosaico calcula su alto con título + pie; se le resta la fila de pestañas.
    function Lista:_recalculateDimen(...)
        local extra = self.glohd_alto_pestanas or 0
        if extra > 0 and self.inner_dimen then self.inner_dimen.h = self.inner_dimen.h - extra end
        MosaicMenu._recalculateDimen(self, ...)
        if extra > 0 and self.inner_dimen then self.inner_dimen.h = self.inner_dimen.h + extra end
    end

    function Lista:init()
        self.glohd_pestanas = pestanas(Screen:getWidth(), self.glohd_seccion, self.glohd_al_tocar)
        self.glohd_alto_pestanas = self.glohd_pestanas:getSize().h
        BookList.init(self)
        table.insert(self.content_group, 2, self.glohd_pestanas)
        self.title_bar:setRightIcon("appbar.filebrowser")
        self:updateItems()
    end

    -- La fila bajo el título: pestañas en la Biblioteca, botón "Seguir" dentro de una saga.
    -- Mide lo mismo que las pestañas para que el mosaico no cambie de tamaño.
    function Lista:glohdPonerFila(nueva)
        for i, w in ipairs(self.content_group) do
            if w == self.glohd_pestanas then self.content_group[i] = nueva end
        end
        self.glohd_pestanas = nueva
    end

    function Lista:glohdCambiarPestanas(seccion)
        self.glohd_seccion = seccion
        self:glohdPonerFila(pestanas(Screen:getWidth(), seccion, self.glohd_al_tocar))
    end

    function Lista:glohdBotonSeguir(texto, al_tocar)
        local ancho = Screen:getWidth()
        local alto = self.glohd_alto_pestanas
        local alto_boton = alto - Screen:scaleBySize(10)
        local ancho_boton = ancho - 2 * Estilo.MARGEN * 2
        self:glohdPonerFila(CenterContainer:new{
            dimen = Geom:new{ w = ancho, h = alto },
            Estilo.Tocable:new{
                al_tocar = al_tocar,
                Estilo.Redondo:new{
                    ancho = ancho_boton, alto = alto_boton, relleno = true,
                    TextWidget:new{ text = texto, face = Font:getFace("cfont", 19), bold = true,
                        fgcolor = Blitbuffer.COLOR_WHITE, max_width = ancho_boton - 2 * Estilo.MARGEN },
                },
            },
        })
    end

    -- Paginado con puntitos en lugar de << < Página 1 de 3 > >>.
    function Lista:updatePageInfo(select_number)
        BookList.updatePageInfo(self, select_number)
        self.page_info_left_chev:hide()
        self.page_info_right_chev:hide()
        self.page_info_first_chev:hide()
        self.page_info_last_chev:hide()
        local texto = ""
        if self.page_num and self.page_num > 1 then
            if self.page_num <= MAX_PUNTOS then
                local p = {}
                for i = 1, self.page_num do p[i] = (i == self.page) and "●" or "○" end
                texto = table.concat(p, "  ")
            else
                texto = self.page .. " / " .. self.page_num
            end
        elseif #self.item_table == 0 then
            texto = "Sin libros"
        end
        self.page_info_text:setText(texto)
    end

    -- A los lados = páginas. Vertical en el cuarto izquierdo = brillo. Hacia abajo desde el
    -- borde superior = Atajos (como el Centro de control de iOS).
    function Lista:onSwipe(arg, ges_ev)
        local d = ges_ev.direction
        if d == "south" and ges_ev.pos and ges_ev.pos.y < Screen:getHeight() / 8 then
            Atajos.mostrar(self.ui)
        elseif d == "north" or d == "south" then
            if ges_ev.pos and ges_ev.pos.x < Screen:getWidth() / 4 and self.ui
                    and self.ui.devicelistener and Device:hasFrontlight() then
                self.ui.devicelistener:onChangeFlIntensity(ges_ev, d == "north" and 1 or -1)
            end
        elseif d == "west" then
            self:onNextPage()
        elseif d == "east" then
            self:onPrevPage()
        else
            UIManager:setDirty(nil, "full")
        end
        return true
    end

    -- Carpeta (derecha): dentro de una saga regresa; en la Biblioteca va a Archivos.
    function Lista:onClose()
        if #self.item_table_stack > 0 then
            Biblioteca:salirDeSerie()
        else
            Biblioteca:irAArchivos()
        end
        return true
    end

    function Lista:onLeftButtonTap()
        if #self.item_table_stack > 0 then Biblioteca:salirDeSerie() end
    end

    return Lista
end

function Biblioteca:mostrar(ui, al_cerrar)
    if self.lista then return end
    local Lista = claseLista()
    if not Lista then return end
    self.ui = ui
    local seccion = G_reader_settings:readSetting("glohd_biblioteca_seccion", "leyendo")
    if NOMBRES[seccion] == nil then seccion = "leyendo" end
    if seccion == "leyendo" and #itemsLeyendo() == 0 then seccion = "libros" end
    self.seccion = seccion

    local yo = self
    self.lista = Lista:new{
        name = "glohd_biblioteca",
        title = "Biblioteca",
        title_bar_fm_style = true,
        title_bar_left_icon = SIN_ICONO,
        onMenuSelect = function(_, item) yo:abrir(item) end,
        onMenuHold = function(_, item) yo:opciones(item) end,
        ui = ui,
        _manager = self,
        glohd_seccion = seccion,
        glohd_al_tocar = function(clave) yo:cargarSeccion(clave) end,
    }
    self.lista.close_callback = function()
        UIManager:close(yo.lista)
        yo.lista = nil
        if al_cerrar then al_cerrar() end
    end
    self:cargarSeccion(seccion)
    -- Desde un tomo, "Tomos" en la barra de lectura abre directo la página de su saga.
    local pendiente = Biblioteca.serie_pendiente
    Biblioteca.serie_pendiente = nil
    if pendiente then
        local saga = Sagas.deCarpeta(pendiente)
        if saga then self:verSerie(saga) end
    end
    UIManager:show(self.lista)
end

-- Vuelve a crear la Biblioteca con las medidas actuales de la pantalla (tras girar),
-- en la misma sección; dentro de una saga regresa a la sección.
function Biblioteca:rehacer()
    local l = self.lista
    if not l then return end
    local ui = self.ui
    UIManager:close(l)
    self.lista = nil
    self:mostrar(ui)
end

local function subtitulo(seccion, n)
    if seccion == "mangas" then return n == 1 and "1 saga" or (n .. " sagas") end
    if seccion == "leyendo" then return n == 1 and "1 en curso" or (n .. " en curso") end
    return n == 1 and "1 libro" or (n .. " libros")
end

function Biblioteca:cargarSeccion(seccion)
    self.seccion = seccion
    self.serie = nil
    G_reader_settings:saveSetting("glohd_biblioteca_seccion", seccion)
    local l = self.lista
    l.item_table_stack = {}
    l.title_bar:setLeftIcon(SIN_ICONO)
    l:glohdCambiarPestanas(seccion)
    local items = GENERADORES[seccion]()
    l:switchItemTable("Biblioteca", items, 1, nil, subtitulo(seccion, #items))
end

-- Página de una saga: arriba "Seguir · Tomo 1, pág. 14"; abajo los tomos en orden, con su
-- avance (barra = en curso, palomita = terminado). Regresar a cualquier tomo es un toque.
function Biblioteca:verSerie(serie)
    local l = self.lista
    if #l.item_table_stack == 0 then
        local actual = l.item_table
        actual.title = "Biblioteca"
        table.insert(l.item_table_stack, actual)
    end
    self.serie = serie
    local yo = self
    l.title_bar:setLeftIcon("chevron.left")
    l:glohdBotonSeguir(Sagas.textoSeguir(serie), function()
        yo:abrirArchivo(serie.tomos[serie.actual].file)
    end)
    l:switchItemTable(serie.nombre, serie.tomos, serie.actual, nil, Sagas.subtitulo(serie))
end

-- Vuelve a leer la saga abierta (tras marcar un tomo como leído / no leído).
function Biblioteca:refrescarSerie()
    local s = self.serie
    if not s then return end
    local nueva = Sagas.deCarpeta(s.dir, s.nombre)
    if nueva then self:verSerie(nueva) end
end

function Biblioteca:salirDeSerie()
    -- Se recarga la sección: el tomo "actual" puede haber cambiado.
    self.serie = nil
    self:cargarSeccion(self.seccion)
end

function Biblioteca:abrirArchivo(ruta)
    local yo = self
    require("apps/filemanager/filemanagerutil").openFile(self.ui, ruta, function()
        if yo.lista then
            UIManager:close(yo.lista)
            yo.lista = nil
        end
    end)
end

function Biblioteca:abrir(item)
    if item.glohd_serie then
        -- Un toque: directo a donde ibas (o al primer tomo). Toque largo = todos los tomos.
        local s = item.glohd_serie
        self:abrirArchivo(s.tomos[s.actual].file)
    elseif item.glohd_idiomas and not item.glohd_leido then
        -- Nunca abierto en ningún idioma: preguntar en cuál.
        self:opciones(item)
    else
        self:abrirArchivo(item.file)
    end
    return true
end

local function infoLibro(ui, file, texto)
    local info = ui.coverbrowser and ui.coverbrowser:getBookInfo(file)
    local titulo = info and info.title and info.title ~= "" and info.title or texto
    local autor = info and info.authors and info.authors ~= "" and (info.authors:gsub("\n", ", ")) or nil
    return titulo, autor
end

-- Mantener presionado: la misma hoja de acciones que en Archivos.
function Biblioteca:opciones(item)
    local yo = self
    if item.glohd_serie then
        self:verSerie(item.glohd_serie)
        return true
    end
    local titulo, autor = infoLibro(yo.ui, item.file, item.text)
    local filas = {}
    if item.glohd_idiomas then
        for _, v in ipairs(item.glohd_idiomas) do
            table.insert(filas, { icono = "abrir", texto = "Leer en " .. v.idioma:lower(), accion = function()
                yo:abrirArchivo(v.file)
            end })
        end
    else
        table.insert(filas, { icono = "abrir", texto = "Abrir", accion = function() yo:abrirArchivo(item.file) end })
    end
    if self.serie then
        -- Tomo dentro de una saga: marcar leído / no leído.
        local e = Sagas.estado(item.file)
        local leido = e.tipo == "terminado"
        table.insert(filas, { icono = leido and "volver" or "marcador",
            texto = leido and "Marcar como no leído" or "Marcar como leído",
            accion = function()
                Sagas.marcar(item.file, not leido)
                yo:refrescarSerie()
            end })
        titulo = Sagas.nombreTomo(item, self.serie.nombre)
        autor = self.serie.nombre
    end
    table.insert(filas, { icono = "info", texto = "Información del libro", accion = function() yo.ui.bookinfo:show(item.file) end })
    table.insert(filas, { icono = "carpeta", texto = "Ver en Archivos", accion = function()
        yo:irAArchivos(ffiUtil.dirname(item.file))
    end })
    Hoja.mostrar{ titulo = titulo, subtitulo = autor, filas = filas }
    return true
end

function Biblioteca:irAArchivos(carpeta)
    Biblioteca.en_archivos = true
    if self.lista then self.lista:onCloseAllMenus() end
    if carpeta and self.ui and self.ui.file_chooser then
        self.ui.file_chooser:changeToPath(carpeta)
    end
end

-- true si al volver al administrador de archivos debe abrirse la Biblioteca.
function Biblioteca.debeMostrarse()
    return G_reader_settings:nilOrTrue("glohd_biblioteca_inicio") and not Biblioteca.en_archivos
end

return Biblioteca
