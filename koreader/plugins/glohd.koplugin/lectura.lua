--[[
Lectura: acciones dentro de un libro que comparten la barra y los Atajos.

  - Ir a página: solo un número ("Estás en la 14 de 176"), Cancelar e Ir. El diálogo de
    KOReader traía porcentaje, fijar página, hojear e "Ir a %" en el mismo cuadro.
  - Tomo anterior / siguiente dentro de una saga.
  - Al terminar un libro, una hoja en español en lugar del diálogo de KOReader (6 botones
    en inglés, entre ellos "Delete file"): en una saga, "Seguir con el tomo 2"; en un libro,
    volver a la Biblioteca. Las dos marcan el libro como terminado.
]]
local Event = require("ui/event")
local Hoja = require("hoja")
local InputDialog = require("ui/widget/inputdialog")
local Sagas = require("sagas")
local UIManager = require("ui/uimanager")

local Lectura = {}

function Lectura.irAPagina(ui)
    local total = ui.document:getPageCount()
    local actual = ui:getCurrentPage()
    local dialogo
    local function ir()
        local n = tonumber(dialogo:getInputText())
        if not n then return end
        n = math.max(1, math.min(total, math.floor(n)))
        UIManager:close(dialogo)
        if ui.link then ui.link:addCurrentLocationToStack() end
        ui:handleEvent(Event:new("GotoPage", n))
    end
    dialogo = InputDialog:new{
        title = "Ir a página",
        description = string.format("Estás en la %d de %d.", actual, total),
        input_hint = string.format("1 – %d", total),
        input_type = "number",
        buttons = {{
            { text = "Cancelar", id = "close", callback = function() UIManager:close(dialogo) end },
            { text = "Ir", is_enter_default = true, callback = ir },
        }},
    }
    UIManager:show(dialogo)
    dialogo:onShowKeyboard()
end

-- Tomo vecino (delta = -1 / +1) del archivo abierto, o nil.
function Lectura.tomoVecino(ui, delta)
    local saga, k = Sagas.deArchivo(ui.document.file)
    if not saga then return nil end
    local t = saga.tomos[k + delta]
    return t, saga
end

function Lectura.cambiarTomo(ui, delta)
    local t = Lectura.tomoVecino(ui, delta)
    if t then UIManager:nextTick(function() ui:switchDocument(t.file) end) end
end

----------------------------------------------------------------------------------------
-- Fin del libro
----------------------------------------------------------------------------------------
function Lectura.instalarFinal()
    local ReaderStatus = require("apps/reader/modules/readerstatus")
    if ReaderStatus._glohd_final then return end
    ReaderStatus._glohd_final = true
    local original = ReaderStatus.onEndOfBook
    ReaderStatus.onEndOfBook = function(self)
        local ui = self.ui
        if not (ui and ui.document) then return original(self) end
        if Lectura.hoja_final then return true end -- ya está abierta (otro toque al final)
        local file = ui.document.file
        local saga, k = Sagas.deArchivo(file)
        local function terminar()
            local resumen = ui.doc_settings:readSetting("summary")
            if not (resumen and resumen.status == "complete") then self:markBook(true) end
        end
        local filas = {}
        local titulo, subtitulo
        if saga then
            titulo = "Terminaste el " .. Sagas.nombreTomo(saga.tomos[k], saga.nombre):lower()
            subtitulo = saga.nombre
            local sig = saga.tomos[k + 1]
            if sig then
                table.insert(filas, { icono = "abrir", texto = "Seguir con el " .. Sagas.nombreTomo(sig, saga.nombre):lower(),
                    accion = function()
                        terminar()
                        UIManager:nextTick(function() ui:switchDocument(sig.file) end)
                    end })
            else
                titulo = "Terminaste " .. saga.nombre
                subtitulo = "Era el último tomo"
            end
        else
            local props = ui.doc_props or {}
            titulo = "Terminaste el libro"
            subtitulo = props.display_title or props.title
        end
        table.insert(filas, { icono = "casa", texto = "Volver a la Biblioteca", accion = function()
            terminar()
            UIManager:nextTick(function()
                ui:onClose()
                ui:showFileManager(file)
            end)
        end })
        local h = Hoja.mostrar{ titulo = titulo, subtitulo = subtitulo, filas = filas, cancelar = "Seguir aquí" }
        Lectura.hoja_final = h
        local cerrar_original = h.onCloseWidget
        h.onCloseWidget = function(w, ...)
            Lectura.hoja_final = nil
            return cerrar_original(w, ...)
        end
        return true
    end
end

return Lectura
