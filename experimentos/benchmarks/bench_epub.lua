-- Benchmark headless de epub (crengine) con el motor real de KOReader.
-- Uso: ./luajit bench_epub.lua <epub> <kerning 0-3> <hyph 0/1> <embedded 0/1> [paginas]
package.path = "common/?.lua;frontend/?.lua;" .. package.path
package.cpath = "common/?.so;common/?.dll;/usr/lib/lua/?.so;" .. package.cpath
require("setupkoenv")
G_defaults = require("luadefaults"):open()
local DataStorage = require("datastorage")
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
local fake_screen = { getWidth = function() return 1072 end, getHeight = function() return 1448 end,
    isColorEnabled = function() return false end, getDPI = function() return 300 end,
    scaleBySize = function(_, x) return x end, fb_bpp = 8 }
local fake = setmetatable({ screen = fake_screen, hasBGRFrameBuffer = function() return false end,
    hasEinkScreen = function() return true end, canHWDither = function() return false end },
    { __index = function() return function() return false end end })
require("document/canvascontext"):init(fake)
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local time = require("ui/time")
local DocumentRegistry = require("document/documentregistry")

local file, kern, hyph, emb, n = arg[1], tonumber(arg[2]), arg[3] == "1", arg[4] == "1", tonumber(arg[5]) or 15
local ms = function(t) return time.to_ms(time.since(t)) end

local t = time.now()
local doc = DocumentRegistry:openDocument(file)
local t_open = ms(t)
doc:setViewDimen(Geom:new{ w = 1072, h = 1448 })
doc:setFontFace("Noto Serif")
doc:setFontSize(23)
doc:setFontKerning(kern)
doc:setTextHyphenation(hyph)
doc:setEmbeddedFonts(emb and 1 or 0)
t = time.now(); doc:loadDocument(); local t_load = ms(t)
t = time.now(); doc:render(); local t_render = ms(t)
local bb = Blitbuffer.new(1072, 1448, Blitbuffer.TYPE_BB8)
local rect = Geom:new{ x = 0, y = 0, w = 1072, h = 1448 }
local res, sum = {}, 0
local start = 30
for p = start, start + n - 1 do
    doc:gotoPage(p)
    t = time.now()
    doc:drawCurrentView(bb, 0, 0, rect)
    local v = ms(t); table.insert(res, v); sum = sum + v
end
table.sort(res)
print(string.format("kern=%d hyph=%s emb=%s | abrir=%dms cargar=%dms maquetar=%dms paginas=%d | pag media=%dms mediana=%dms max=%dms",
    kern, tostring(hyph), tostring(emb), t_open, t_load, t_render, doc:getPageCount(), sum / #res, res[math.ceil(#res / 2)], res[#res]))
doc:close()
