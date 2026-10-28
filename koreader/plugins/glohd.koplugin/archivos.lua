--[[
Archivos: el administrador de archivos de KOReader, con la navegación y las opciones
de la Biblioteca.

  ‹ Biblioteca            Archivos            Opciones
  Kobo › Books › Psicologia                       ← cada parte se toca para ir ahí
  [portadas / lista]
                         ●  ○  ○

  - "‹ Biblioteca" con texto, como en la barra de lectura (siempre regresa al inicio).
  - La ruta sustituye la tarjeta "⬆ ../": se ve dónde estás y se sube con un toque.
  - "Opciones" y mantener presionado un libro o carpeta abren hojas en español con solo
    las acciones posibles; borrar es lo único que pide confirmación.
  - Modo selección: el subtítulo lo explica y el botón de la derecha pasa a "Acciones".
  - Paginado con puntitos, como en la Biblioteca.
]]
local Button = require("ui/widget/button")
local Device = require("device")
local Estilo = require("estilo")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local Hoja = require("hoja")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Notification = require("ui/widget/notification")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local Screen = Device.screen

local RAIZ = "/mnt/onboard"
local MAX_PUNTOS = 12
local ALTO_RUTA = Estilo.ALTO_BOTON

local ORDENES = {
    { "Nombre", "natural" },
    { "Leídos hace poco", "access" },
    { "Fecha en que llegó", "date" },
    { "Avance (sin empezar al final)", "percent_natural" },
}
local VISTAS = {
    { "Portadas", "mosaic_image", "cuadricula" },
    { "Lista con detalles", "list_image_meta", "lista" },
}

local Archivos = {
    irABiblioteca = nil, -- lo asigna main.lua
}

----------------------------------------------------------------------------------------
-- Ruta tocable
----------------------------------------------------------------------------------------
local function partesRuta(path)
    path = ffiUtil.realpath(path) or path
    local partes = {}
    if path == RAIZ or path:sub(1, #RAIZ + 1) == RAIZ .. "/" then
        table.insert(partes, { nombre = "Kobo", ruta = RAIZ })
        local acumulada = RAIZ
        for nombre in path:sub(#RAIZ + 2):gmatch("[^/]+") do
            acumulada = acumulada .. "/" .. nombre
            table.insert(partes, { nombre = nombre, ruta = acumulada })
        end
    else
        table.insert(partes, { nombre = "/", ruta = "/" })
        local acumulada = ""
        for nombre in path:gmatch("[^/]+") do
            acumulada = acumulada .. "/" .. nombre
            table.insert(partes, { nombre = nombre, ruta = acumulada })
        end
    end
    return partes
end

local function filaRuta(fm, ancho)
    local partes = partesRuta(fm.file_chooser.path)
    local cara = Font:getFace("cfont", 18)
    local sep_ancho = TextWidget:new{ text = "  ›  ", face = cara }:getSize().w
    local disponible = ancho - 4 * Estilo.MARGEN
    local function anchoDe(lista)
        local w = 0
        for i, p in ipairs(lista) do
            w = w + TextWidget:new{ text = p.nombre, face = cara, bold = i == #lista }:getSize().w
            if i > 1 then w = w + sep_ancho end
        end
        return w
    end
    -- Si no cabe, las carpetas intermedias se resumen en "…" (la primera y la última siempre).
    local mostradas = partes
    local quitar = 0
    while anchoDe(mostradas) > disponible and quitar < #partes - 2 do
        quitar = quitar + 1
        mostradas = { partes[1], { nombre = "…", ruta = partes[1 + quitar].ruta } }
        for i = 2 + quitar, #partes do table.insert(mostradas, partes[i]) end
    end
    local grupo = HorizontalGroup:new{ align = "center", HorizontalSpan:new{ width = 2 * Estilo.MARGEN } }
    for i, p in ipairs(mostradas) do
        if i > 1 then
            table.insert(grupo, TextWidget:new{ text = "  ›  ", face = cara, fgcolor = Estilo.GRIS })
        end
        local ultima = i == #mostradas
        local texto = TextWidget:new{ text = p.nombre, face = cara, bold = ultima,
            fgcolor = ultima and Estilo.NEGRO or Estilo.GRIS,
            max_width = ultima and math.max(disponible - anchoDe(mostradas) + 1, Screen:scaleBySize(80)) or nil }
        if ultima then
            table.insert(grupo, texto)
        else
            local ruta = p.ruta
            table.insert(grupo, Estilo.Tocable:new{
                al_tocar = function() fm.file_chooser:changeToPath(ruta) end,
                LeftContainer:new{ dimen = Geom:new{ w = texto:getSize().w, h = ALTO_RUTA }, texto },
            })
        end
    end
    return InputContainer:new{
        dimen = Geom:new{ w = ancho, h = ALTO_RUTA },
        LeftContainer:new{ dimen = Geom:new{ w = ancho, h = ALTO_RUTA }, grupo },
    }
end

-- "5 carpetas · 6 libros" (estado visible sin contar a ojo).
local function resumen(items)
    local carpetas, libros = 0, 0
    for _, it in ipairs(items or {}) do
        if it.is_file then libros = libros + 1 elseif not it.is_go_up then carpetas = carpetas + 1 end
    end
    local partes = {}
    if carpetas > 0 then table.insert(partes, carpetas == 1 and "1 carpeta" or (carpetas .. " carpetas")) end
    if libros > 0 then table.insert(partes, libros == 1 and "1 libro" or (libros .. " libros")) end
    return #partes > 0 and table.concat(partes, " · ") or "Vacía"
end

function Archivos.actualizarRuta(fm)
    local fc = fm.file_chooser
    if not (fc and fm.glohd_ruta) then return end
    local vieja = fm.glohd_ruta
    local nueva = filaRuta(fm, Screen:getWidth())
    for i, w in ipairs(fc.content_group) do
        if w == vieja then fc.content_group[i] = nueva end
    end
    fm.glohd_ruta = nueva
    fm.title_bar:setTitle("Archivos", true)
    fm.title_bar:setSubTitle(fm.selected_files and "Toca los libros para elegirlos" or resumen(fc.item_table), true)
    -- El menú ya se repintó al cambiar de carpeta; falta la fila nueva y el título.
    local zona = vieja.dimen and vieja.dimen:copy()
    UIManager:setDirty(fm, function()
        if zona then return "ui", zona:combine(fm.title_bar.dimen or zona) end
        return "ui"
    end)
end

----------------------------------------------------------------------------------------
-- Barra de título: "‹ Biblioteca" y "Opciones"/"Acciones" con texto
----------------------------------------------------------------------------------------
local function botonTitulo(fm, texto, alineacion, al_tocar)
    local b = Button:new{
        text = texto, bordersize = 0, text_font_size = 18, text_font_bold = true,
        -- Alto de todo el bloque título + subtítulo: el texto queda centrado entre ambos.
        height = math.max(fm.title_bar.titlebar_height or 0, Estilo.ALTO_BOTON),
        padding_h = 2 * Estilo.MARGEN,
        callback = al_tocar, show_parent = fm,
    }
    b.overlap_align = alineacion
    return b
end

local function cambiarBoton(fm, lado, nuevo)
    local tb = fm.title_bar
    local viejo = lado == "izq" and (fm.glohd_izq or tb.left_button) or (fm.glohd_der or tb.right_button)
    for i, w in ipairs(tb) do
        if w == viejo then tb[i] = nuevo end
    end
    if lado == "izq" then fm.glohd_izq = nuevo else fm.glohd_der = nuevo end
end

function Archivos.botonDerecho(fm)
    local seleccionando = fm.selected_files ~= nil
    cambiarBoton(fm, "der", botonTitulo(fm, seleccionando and "Acciones" or "Opciones", "right",
        function() Archivos.opciones(fm) end))
    UIManager:setDirty(fm, function() return "ui", fm.title_bar.dimen end)
end

----------------------------------------------------------------------------------------
-- Diálogos
----------------------------------------------------------------------------------------
local function pedirNombre(titulo, inicial, boton, al_aceptar)
    local dialogo
    dialogo = InputDialog:new{
        title = titulo,
        input = inicial or "",
        buttons = {{
            { text = "Cancelar", id = "close", callback = function() UIManager:close(dialogo) end },
            { text = boton, is_enter_default = true, callback = function()
                local nombre = dialogo:getInputText()
                if nombre == "" then return end
                UIManager:close(dialogo)
                al_aceptar(nombre)
            end },
        }},
    }
    UIManager:show(dialogo)
    dialogo:onShowKeyboard()
end

local function nombreDe(path)
    return ffiUtil.basename(path)
end

local function opcionActual(lista, valor)
    for _, op in ipairs(lista) do
        if op[2] == valor then return op[1] end
    end
    return lista[1][1]
end

function Archivos.ordenar(fm)
    local actual = G_reader_settings:readSetting("collate", "strcoll")
    if actual == "strcoll" then actual = "natural" end
    local filas = {}
    for _, op in ipairs(ORDENES) do
        table.insert(filas, { texto = Estilo.marca(op[2] == actual, op[1]),
            accion = function() fm:onSetSortBy(op[2]) end })
    end
    Hoja.mostrar{ titulo = "Ordenar por", filas = filas }
end

local function vistaActual(fm)
    local BookInfoManager = package.loaded["bookinfomanager"]
    local modo = BookInfoManager and BookInfoManager:getSetting("filemanager_display_mode")
    return modo == "list_image_meta" and VISTAS[2] or VISTAS[1]
end

-- Opciones de la carpeta, o acciones con lo elegido en modo selección.
function Archivos.opciones(fm)
    local fc = fm.file_chooser
    if fm.selected_files then
        local n = util.tableSize(fm.selected_files)
        local filas = {}
        if n > 0 then
            local cuantos = n == 1 and "1 libro" or (n .. " libros")
            table.insert(filas, { icono = "mover", texto = "Mover aquí", accion = function()
                fm.cutfile = true; fm:pasteSelectedFiles(false)
            end })
            table.insert(filas, { icono = "copiar", texto = "Copiar aquí", accion = function()
                fm.cutfile = false; fm:pasteSelectedFiles(false)
            end })
            table.insert(filas, { icono = "borrar", texto = "Borrar", peligro = true, accion = function()
                Hoja.confirmar("¿Borrar " .. cuantos .. "?", "Se borran para siempre, con sus notas y subrayados.",
                    "Borrar " .. cuantos, "borrar", function() fm:deleteSelectedFiles() end)
            end })
        end
        table.insert(filas, { icono = "seleccionar", texto = "Elegir todos los de aquí",
            accion = function() fc:selectAllFilesInFolder(true) end })
        table.insert(filas, { icono = "cerrar", texto = "Terminar de elegir",
            accion = function() fm:onToggleSelectMode() end })
        Hoja.mostrar{
            titulo = n == 0 and "Nada elegido" or (n == 1 and "1 libro elegido" or (n .. " libros elegidos")),
            subtitulo = n > 0 and "Para mover o copiar, ve primero a la carpeta destino." or nil,
            filas = filas,
        }
        return true
    end

    local carpeta = fc.path
    local filas = {}
    if fm.clipboard then
        table.insert(filas, { icono = "pegar", texto = "Pegar «" .. nombreDe(fm.clipboard) .. "» aquí",
            accion = function() fm:pasteFileFromClipboard() end })
    end
    table.insert(filas, { icono = "carpeta-nueva", texto = "Nueva carpeta", accion = function()
        pedirNombre("Nueva carpeta", "", "Crear", function(nombre)
            local ruta = carpeta .. "/" .. nombre
            if util.makePath(ruta) then fc:refreshPath()
            else Notification:notify("No se pudo crear la carpeta") end
        end)
    end })
    table.insert(filas, { icono = "seleccionar", texto = "Elegir varios", accion = function()
        fm:onToggleSelectMode()
    end })
    table.insert(filas, { icono = "buscar", texto = "Buscar", accion = function()
        fm.filesearcher:onShowFileSearch()
    end })
    local collate = G_reader_settings:readSetting("collate", "strcoll")
    table.insert(filas, { icono = "ordenar",
        texto = "Ordenar: " .. opcionActual(ORDENES, collate == "strcoll" and "natural" or collate),
        accion = function() Archivos.ordenar(fm) end })
    local vista = vistaActual(fm)
    local otra = vista == VISTAS[1] and VISTAS[2] or VISTAS[1]
    if fm.coverbrowser then
        table.insert(filas, { icono = otra[3], texto = "Ver como " .. otra[1]:lower(), accion = function()
            fm.coverbrowser:setDisplayMode(otra[2])
        end })
    end
    Hoja.mostrar{ titulo = nombreDe(carpeta) == "onboard" and "Kobo" or nombreDe(carpeta), filas = filas }
    return true
end

-- Mantener presionado un libro o una carpeta.
function Archivos.menuElemento(fm, item)
    local fc = fm.file_chooser
    local ruta = item.path
    local es_archivo = item.is_file
    local nombre = nombreDe(ruta)
    local filas = {}
    if es_archivo then
        table.insert(filas, { icono = "abrir", texto = "Abrir", accion = function()
            require("apps/filemanager/filemanagerutil").openFile(fm, ruta)
        end })
        table.insert(filas, { icono = "info", texto = "Información del libro", accion = function()
            fm.bookinfo:show(ruta)
        end })
        table.insert(filas, { icono = "seleccionar", texto = "Elegir varios", accion = function()
            fm:onToggleSelectMode()
            fm.selected_files[ruta] = true
            item.dim = true
            fc:updateItems(1, true)
        end })
    else
        table.insert(filas, { icono = "carpeta", texto = "Abrir", accion = function() fc:changeToPath(ruta) end })
    end
    table.insert(filas, { icono = "renombrar", texto = "Cambiar nombre", accion = function()
        pedirNombre("Cambiar nombre", nombre, "Guardar", function(nuevo)
            fm:renameFile(ruta, nuevo, es_archivo)
        end)
    end })
    table.insert(filas, { icono = "mover", texto = "Mover a otra carpeta", accion = function()
        fm:cutFile(ruta)
        Notification:notify("Ve a la carpeta destino y toca Opciones › Pegar")
    end })
    table.insert(filas, { icono = "copiar", texto = "Copiar", accion = function()
        fm:copyFile(ruta)
        Notification:notify("Ve a la carpeta destino y toca Opciones › Pegar")
    end })
    table.insert(filas, { icono = "borrar", texto = "Borrar", peligro = true, accion = function()
        local aviso = es_archivo and "Se borra para siempre, con sus notas y subrayados."
            or "Se borra para siempre, con todo lo que tiene dentro."
        Hoja.confirmar("¿Borrar «" .. nombre .. "»?", aviso, "Borrar", "borrar", function()
            if fm:deleteFile(ffiUtil.realpath(ruta) or ruta, es_archivo) then fc:refreshPath() end
        end)
    end })
    -- Título del libro (no el nombre del archivo) y, abajo, autor · formato · tamaño.
    local titulo, subtitulo = nombre, nil
    if es_archivo then
        local info = fm.coverbrowser and fm.coverbrowser:getBookInfo(ruta)
        local partes = {}
        if info and info.title and info.title ~= "" then titulo = info.title end
        if info and info.authors and info.authors ~= "" then
            table.insert(partes, (info.authors:gsub("\n", ", ")))
        end
        local ext = util.getFileNameSuffix(ruta)
        if ext and ext ~= "" then table.insert(partes, ext:lower()) end
        local tam = lfs.attributes(ruta, "size")
        if tam then table.insert(partes, util.getFriendlySize(tam)) end
        subtitulo = #partes > 0 and table.concat(partes, " · ") or nil
    end
    Hoja.mostrar{ titulo = titulo, subtitulo = subtitulo, filas = filas }
    return true
end

----------------------------------------------------------------------------------------
-- Instalación
----------------------------------------------------------------------------------------
function Archivos.adaptar(fm)
    local fc = fm.file_chooser
    if not (fc and fm.title_bar) then return end

    -- setupLayout (también al girar) crea una barra de título nueva: se olvidan los botones viejos.
    fm.glohd_izq, fm.glohd_der = nil, nil
    cambiarBoton(fm, "izq", botonTitulo(fm, "‹ Biblioteca", "left", function()
        if Archivos.irABiblioteca then Archivos.irABiblioteca(fm) end
    end))
    Archivos.botonDerecho(fm)
    fm.onShowPlusMenu = function(self) return Archivos.opciones(self) end
    fc.showFileDialog = function(_, item) return Archivos.menuElemento(fm, item) end

    -- Sin tarjeta "⬆ ../": la ruta hace ese papel.
    fc.genItemTable = function(self, ...)
        local items = getmetatable(self).genItemTable(self, ...)
        if items[1] and items[1].is_go_up then table.remove(items, 1) end
        return items
    end

    -- Fila de la ruta bajo el título; el mosaico/lista se calcula con ese alto menos.
    fm.glohd_ruta = filaRuta(fm, Screen:getWidth())
    table.insert(fc.content_group, 2, fm.glohd_ruta)
    fc._recalculateDimen = function(self, ...)
        local clase = getmetatable(self)
        if self.inner_dimen then self.inner_dimen.h = self.inner_dimen.h - ALTO_RUTA end
        clase._recalculateDimen(self, ...)
        if self.inner_dimen then self.inner_dimen.h = self.inner_dimen.h + ALTO_RUTA end
    end

    -- Puntitos en lugar de « ‹ Page 1 of 3 › ».
    fc.updatePageInfo = function(self, select_number)
        getmetatable(self).updatePageInfo(self, select_number)
        for _, c in ipairs({ "page_info_left_chev", "page_info_right_chev",
                             "page_info_first_chev", "page_info_last_chev" }) do
            if self[c] then self[c]:hide() end
        end
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
            texto = "Carpeta vacía"
        end
        self.page_info_text:setText(texto)
    end

    fc:refreshPath()
    Archivos.actualizarRuta(fm)
end

function Archivos.instalar()
    local FileManager = require("apps/filemanager/filemanager")
    if FileManager._glohd_archivos then return end
    FileManager._glohd_archivos = true

    local setup_original = FileManager.setupLayout
    FileManager.setupLayout = function(fm, ...)
        local r = setup_original(fm, ...)
        Archivos.adaptar(fm)
        return r
    end

    -- Al cambiar de carpeta: ruta nueva (sustituye la ruta "Home/…" del subtítulo).
    local function rutaCambiada(fm) Archivos.actualizarRuta(fm) end
    FileManager.updateTitleBarPath = rutaCambiada
    FileManager.onPathChanged = rutaCambiada

    local seleccion_original = FileManager.onToggleSelectMode
    FileManager.onToggleSelectMode = function(fm, ...)
        local r = seleccion_original(fm, ...)
        if fm.glohd_ruta then
            Archivos.botonDerecho(fm)
            Archivos.actualizarRuta(fm)
        end
        return r
    end
end

return Archivos
