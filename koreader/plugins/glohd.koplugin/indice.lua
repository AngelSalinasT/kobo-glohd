--[[
Índice del libro con el estilo de Ajustes, en lugar de la lista de KOReader (líneas de
puntos, triángulos para abrir/cerrar partes, ☰ con opciones del índice y « ‹ › »).

  ┌ Primera parte: Técnicas fundamentales…   39 ┐   cada parte es un bloque con sus
  │    1. Si quieres recoger miel…            40 │   capítulos dentro, ya abiertos
  │    2. El gran secreto…                    58 │
  └──────────────────────────────────────────────┘
  ┌ 6. Cómo hacerse agradable…            ● 236 ┐   el capítulo en que vas, en negritas
  └──────────────────────────────────────────────┘

  - Abre en la hoja del capítulo actual; deslizar a los lados cambia de hoja (puntitos).
  - Tocar un capítulo va a él (y se puede volver con "Volver" de los Atajos).
  - Si el libro no tiene índice (mangas), se usa el de KOReader, que avisa.
]]
local Event = require("ui/event")
local Screen = require("device").screen

local Indice = {}

local function pagina(ui)
    local toc = ui.toc
    toc:fillToc()
    if not toc.toc or #toc.toc == 0 then return nil end
    local actual = toc:getTocIndexByPage(ui:getCurrentPage())
    local sangria = Screen:scaleBySize(22)
    local secciones = {}
    local sec, suelta
    local w
    for i, v in ipairs(toc.toc) do
        local aqui = i == actual
        local fila = {
            texto = toc:cleanUpTocTitle(v.title, true),
            info = function() return (aqui and "● " or "") .. tostring(v.page) end,
            negrita = aqui,
            aqui = aqui,
            sangria = (v.depth - 1) * sangria,
            sin_flecha = true,
            accion = function()
                if w then w:cerrar() end
                ui.link:addCurrentLocationToStack()
                if v.xpointer then
                    ui:handleEvent(Event:new("GotoXPointer", v.xpointer, v.xpointer))
                else
                    ui:handleEvent(Event:new("GotoPage", v.page))
                end
            end,
        }
        local siguiente = toc.toc[i + 1]
        if v.depth == 1 and siguiente and siguiente.depth > 1 then
            -- Parte con capítulos: su propio bloque.
            sec = { filas = { fila } }
            suelta = nil
            table.insert(secciones, sec)
        elseif v.depth == 1 then
            -- Capítulos sueltos seguidos van juntos en un bloque.
            if not suelta then
                suelta = { filas = {} }
                table.insert(secciones, suelta)
            end
            table.insert(suelta.filas, fila)
            sec = nil
        else
            local destino = sec or suelta
            if not destino then
                destino = { filas = {} }
                table.insert(secciones, destino)
                sec = destino
            end
            table.insert(destino.filas, fila)
        end
    end
    return { titulo = "Índice", secciones = secciones, partir = true }, function(widget) w = widget end
end

function Indice.instalar(Ajustes)
    local ReaderToc = require("apps/reader/modules/readertoc")
    if ReaderToc._glohd_indice then return end
    ReaderToc._glohd_indice = true
    local original = ReaderToc.onShowToc
    ReaderToc.onShowToc = function(self, ...)
        local ui = self.ui
        if not (G_reader_settings:nilOrTrue("glohd_barra_lectura") and ui and ui.document) then
            return original(self, ...)
        end
        local ok, p, poner = pcall(pagina, ui)
        if not ok or not p then return original(self, ...) end
        poner(Ajustes.mostrarPagina(ui, p))
        return true
    end
end

return Indice
