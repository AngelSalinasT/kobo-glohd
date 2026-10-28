--[[
Sagas: tomos de una misma serie y en cuál vas. Lo usan la Biblioteca, la barra de lectura,
los Atajos y la hoja de "terminaste el tomo".

  - Saga = subcarpeta directa de Mangas (Mangas/Nana/…) o subcarpeta dentro de un tema de
    Libros (Books/Fantasia/Mistborn/…).
  - Orden por número de tomo ("Tomo 02", "Vol. 3", "03"); lo que no tiene número
    (Recopilatorio, Extra) va al final. Antes "Tomo Recopilatorio" salía primero y el
    tomo 2 se contaba como "el 3".
  - "En curso" = pasaste de la página 3 (o del 3 %). Solo abrir un tomo ya no lo vuelve
    el tomo en que vas: con Nana, abrir el 2 sin leerlo dejaba el 1 (pág. 14) escondido.
]]
local DocSettings = require("docsettings")
local DocumentRegistry = require("document/documentregistry")
local ReadHistory = require("readhistory")
local lfs = require("libs/libkoreader-lfs")
local sort = require("sort")

local Sagas = {}

Sagas.RAIZ = {
    libros = "/mnt/onboard/Books",
    mangas = "/mnt/onboard/Mangas",
}

local PAGINAS_EN_CURSO = 3   -- más de esto = lo estás leyendo
local PORCENTAJE_EN_CURSO = 0.03

-- Solo formatos de lectura: DocumentRegistry también "abre" scripts (.sh) con el editor,
-- y KOReader los guarda en el historial al ejecutarlos.
local FORMATOS = {
    epub = true, pdf = true, djvu = true, cbz = true, cbr = true, cbt = true, cb7 = true,
    fb2 = true, mobi = true, azw = true, azw3 = true, prc = true, txt = true, rtf = true,
    docx = true, doc = true,
}
function Sagas.esDocumento(ruta)
    local ext = ruta:match("%.([^./]+)$")
    return ext ~= nil and FORMATOS[ext:lower()] == true and DocumentRegistry:hasProvider(ruta)
end

function Sagas.documentosEn(dir, recursivo, salida)
    salida = salida or {}
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then return salida end
    for nombre in iter, dir_obj do
        if nombre ~= "." and nombre ~= ".." and not nombre:match("^%.") then
            local ruta = dir .. "/" .. nombre
            local modo = lfs.attributes(ruta, "mode")
            if modo == "file" and Sagas.esDocumento(ruta) then
                table.insert(salida, ruta)
            elseif modo == "directory" and recursivo and not nombre:match("%.sdr$") then
                Sagas.documentosEn(ruta, true, salida)
            end
        end
    end
    return salida
end

function Sagas.item(ruta)
    return { file = ruta, text = ruta:gsub(".*/", ""), select_enabled = true }
end

local natsort = sort.natsort_cmp()
function Sagas.ordenar(items)
    table.sort(items, function(a, b) return natsort(a.text, b.text) end)
    return items
end

----------------------------------------------------------------------------------------
-- Tomos
----------------------------------------------------------------------------------------
local function sinExtension(nombre) return (nombre:gsub("%.[^.]+$", "")) end

-- Número de tomo a partir del nombre del archivo, o nil.
function Sagas.numero(nombre)
    local base = sinExtension(nombre):gsub("%(#[^)]*%)", "")
    local n = base:match("[Tt]omo%s*0*(%d+)") or base:match("[Vv]ol%.?%s*0*(%d+)")
        or base:match("[Vv]olumen%s*0*(%d+)") or base:match("0*(%d+)%s*$")
    return n and tonumber(n)
end

function Sagas.ordenarTomos(tomos)
    for _, t in ipairs(tomos) do t.glohd_num = Sagas.numero(t.text) end
    table.sort(tomos, function(a, b)
        local na, nb = a.glohd_num or math.huge, b.glohd_num or math.huge
        if na ~= nb then return na < nb end
        return natsort(a.text, b.text)
    end)
    return tomos
end

-- "Tomo 1", o lo que quede del nombre sin la saga ni los capítulos ("Tomo Recopilatorio").
function Sagas.nombreTomo(tomo, saga)
    local n = tomo.glohd_num or Sagas.numero(tomo.text)
    if n then return "Tomo " .. n end
    local base = sinExtension(tomo.text):gsub("%s*%(#[^)]*%)", "")
    if saga then
        local prefijo = saga:gsub("%p", "%%%0")
        base = base:gsub("^" .. prefijo .. "%s*[-·:]?%s*", "")
    end
    base = base:gsub("_", " ")
    return base ~= "" and base or tomo.text
end

-- Estado de lectura de un archivo: "terminado", "leyendo" o "nuevo", con página y total.
function Sagas.estado(ruta)
    local ok, ds = pcall(DocSettings.open, DocSettings, ruta)
    if not ok or not ds then return { tipo = "nuevo" } end
    local resumen = ds:readSetting("summary")
    local pf = ds:readSetting("percent_finished")
    local total = ds:readSetting("doc_pages")
    local pag = ds:readSetting("last_page")
    if not pag and pf and total then pag = math.floor(pf * total + 0.5) end
    local e = { pag = pag, total = total, pf = pf }
    if (resumen and resumen.status == "complete") or (pf and pf >= 0.995) then
        e.tipo = "terminado"
    elseif (pag and pag > PAGINAS_EN_CURSO) or (not pag and pf and pf >= PORCENTAJE_EN_CURSO) then
        e.tipo = "leyendo"
    else
        e.tipo = "nuevo"
    end
    return e
end

-- Índice del tomo en que vas:
--   1. el tomo en curso abierto más recientemente;
--   2. si no hay ninguno en curso, el que sigue al último terminado;
--   3. si no, el primero.
function Sagas.tomoActual(tomos)
    local pos = {}
    for i, h in ipairs(ReadHistory.hist) do
        if pos[h.file] == nil then pos[h.file] = i end
    end
    local actual, mejor, ultimo_terminado
    for k, t in ipairs(tomos) do
        t.glohd_estado = Sagas.estado(t.file)
        if t.glohd_estado.tipo == "leyendo" then
            local i = pos[t.file] or math.huge
            if not actual or i < mejor or (i == mejor and k > actual) then actual, mejor = k, i end
        elseif t.glohd_estado.tipo == "terminado" then
            ultimo_terminado = k
        end
    end
    if actual then return actual end
    if ultimo_terminado then return math.min(ultimo_terminado + 1, #tomos) end
    return 1
end

-- Saga completa de una carpeta: { nombre, dir, tomos, actual }.
function Sagas.deCarpeta(dir, nombre)
    local tomos = {}
    for _, r in ipairs(Sagas.documentosEn(dir, true)) do table.insert(tomos, Sagas.item(r)) end
    if #tomos == 0 then return nil end
    Sagas.ordenarTomos(tomos)
    return { nombre = nombre or dir:gsub(".*/", ""), dir = dir, tomos = tomos, actual = Sagas.tomoActual(tomos) }
end

-- Carpeta de saga a la que pertenece un archivo, o nil.
function Sagas.carpeta(ruta)
    local m = Sagas.RAIZ.mangas .. "/"
    if ruta:sub(1, #m) == m then
        local nombre = ruta:sub(#m + 1):match("^([^/]+)/")
        if nombre then return m .. nombre, nombre end
        return nil
    end
    local l = Sagas.RAIZ.libros .. "/"
    if ruta:sub(1, #l) == l then
        local tema, nombre = ruta:sub(#l + 1):match("^([^/]+)/([^/]+)/")
        if tema then return l .. tema .. "/" .. nombre, nombre end
    end
    return nil
end

-- Saga de un archivo y su posición en ella, o nil.
function Sagas.deArchivo(ruta)
    local dir, nombre = Sagas.carpeta(ruta)
    if not dir then return nil end
    local saga = Sagas.deCarpeta(dir, nombre)
    if not saga then return nil end
    for k, t in ipairs(saga.tomos) do
        if t.file == ruta then return saga, k end
    end
    return nil
end

-- "Seguir · Tomo 1, pág. 14" / "Empezar · Tomo 3" / "Saga terminada · releer el tomo 1".
function Sagas.textoSeguir(saga)
    local t = saga.tomos[saga.actual]
    local nombre = Sagas.nombreTomo(t, saga.nombre)
    local e = t.glohd_estado or Sagas.estado(t.file)
    if e.tipo == "leyendo" and e.pag then
        return "Seguir · " .. nombre .. ", pág. " .. e.pag
    elseif e.tipo == "terminado" then
        return "Terminaste la saga · " .. nombre
    end
    return "Empezar · " .. nombre
end

function Sagas.subtitulo(saga)
    local n = #saga.tomos
    local t = saga.tomos[saga.actual]
    return n .. " tomos · vas en el " .. Sagas.nombreTomo(t, saga.nombre):lower()
end

-- Título para la barra/Atajos dentro de un tomo: "Nana · Tomo 1 de 22".
function Sagas.tituloLectura(ruta)
    local saga, k = Sagas.deArchivo(ruta)
    if not saga then return nil end
    return saga.nombre .. " · " .. Sagas.nombreTomo(saga.tomos[k], saga.nombre) .. " de " .. #saga.tomos, saga, k
end

-- Marca un archivo como leído o no leído sin abrirlo.
function Sagas.marcar(ruta, leido)
    local ok, ds = pcall(DocSettings.open, DocSettings, ruta)
    if not ok or not ds then return end
    local resumen = ds:readSetting("summary") or {}
    resumen.status = leido and "complete" or "reading"
    resumen.modified = os.date("%Y-%m-%d", os.time())
    ds:saveSetting("summary", resumen)
    if not leido and (ds:readSetting("percent_finished") or 0) >= 0.995 then
        -- Si estaba en la última página seguiría contando como terminado: vuelve al inicio.
        ds:saveSetting("percent_finished", 0)
        if ds:readSetting("last_page") then ds:saveSetting("last_page", 1) end
    end
    ds:flush()
    -- La lista guarda el estado de cada libro en caché: sin esto la palomita no aparece.
    require("ui/widget/booklist").resetBookInfoCache(ruta)
end

----------------------------------------------------------------------------------------
-- Libros en dos idiomas (hard_things.epub + hard_things_español.epub)
----------------------------------------------------------------------------------------
-- En la FAT los acentos se guardan descompuestos: "español" puede venir como "espan" + ˜ + "ol".
local function esEspanol(base)
    local b = base:lower()
    return b:match("[_ %-]espa.-ol$") ~= nil or b:match("[_ %-]es$") ~= nil
end
local function esIngles(base)
    local b = base:lower()
    return b:match("[_ %-]english$") ~= nil or b:match("[_ %-]ingl.-s$") ~= nil or b:match("[_ %-]en$") ~= nil
end

-- Clave común de las versiones de un libro (sin sufijo de idioma) e idioma de este archivo.
function Sagas.claveIdioma(ruta)
    local dir = ruta:match("^(.*)/") or ""
    local base = sinExtension(ruta:gsub(".*/", ""))
    local idioma
    if esEspanol(base) then
        idioma = "Español"
        base = base:gsub("[_ %-][^_ %-]+$", "")
    elseif esIngles(base) then
        idioma = "Inglés"
        base = base:gsub("[_ %-][^_ %-]+$", "")
    end
    return dir .. "/" .. base:lower(), idioma
end

-- Agrupa las versiones en idiomas distintos de un mismo libro. Devuelve los elementos ya
-- agrupados: los pares llevan glohd_idiomas = { { idioma =, file = }, … }.
function Sagas.agruparIdiomas(rutas)
    local grupos, orden = {}, {}
    for _, r in ipairs(rutas) do
        local clave, idioma = Sagas.claveIdioma(r)
        if not grupos[clave] then grupos[clave] = {}; table.insert(orden, clave) end
        table.insert(grupos[clave], { idioma = idioma, file = r })
    end
    local pos = {}
    for i, h in ipairs(ReadHistory.hist) do
        if pos[h.file] == nil then pos[h.file] = i end
    end
    local items = {}
    for _, clave in ipairs(orden) do
        local g = grupos[clave]
        if #g == 1 then
            table.insert(items, Sagas.item(g[1].file))
        else
            for _, v in ipairs(g) do v.idioma = v.idioma or "Inglés" end
            table.sort(g, function(a, b) return a.idioma < b.idioma end) -- Español primero
            -- Portada: la versión que leíste más recientemente; si ninguna, la de español.
            local elegido = g[1]
            local mejor
            for _, v in ipairs(g) do
                local i = pos[v.file]
                if i and (not mejor or i < mejor) then elegido, mejor = v, i end
            end
            local it = Sagas.item(elegido.file)
            it.glohd_idiomas = g
            it.glohd_leido = mejor ~= nil
            table.insert(items, it)
        end
    end
    return items
end

return Sagas
