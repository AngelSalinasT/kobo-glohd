-- Benchmark headless de render con el motor real de KOReader.
-- Uso: cd /mnt/onboard/.adds/koreader && ./luajit /mnt/onboard/.adds/usbnet/bench/bench.lua <archivo> [paginas] [desde]
package.path = "common/?.lua;frontend/?.lua;" .. package.path
package.cpath = "common/?.so;common/?.dll;/usr/lib/lua/?.so;" .. package.cpath
require("setupkoenv")
G_defaults = require("luadefaults"):open()
local DataStorage = require("datastorage")
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")

local Geom = require("ui/geometry")
local time = require("ui/time")
local fake_screen = { getWidth = function() return 1072 end, getHeight = function() return 1448 end, isColorEnabled = function() return false end, getDPI = function() return 300 end, scaleBySize = function(_, x) return x end, fb_bpp = 8 }
local fake = setmetatable({ screen = fake_screen, hasBGRFrameBuffer = function() return false end, hasEinkScreen = function() return true end, canHWDither = function() return false end }, { __index = function() return function() return false end end })
require("document/canvascontext"):init(fake)
local DocumentRegistry = require("document/documentregistry")

local file, n, from = arg[1], tonumber(arg[2]) or 10, tonumber(arg[3]) or 1
local W, H = 1072, 1448

local t0 = time.now()
local doc = DocumentRegistry:openDocument(file)
local t_open = time.to_ms(time.since(t0))
local pages = doc:getPageCount()
local results = {}
for p = from, math.min(from + n - 1, pages) do
    local dims = doc:getNativePageDimensions(p)
    local zoom = math.min(W / dims.w, H / dims.h)
    local rect = Geom:new{ x = 0, y = 0, w = dims.w * zoom, h = dims.h * zoom }
    local t = time.now()
    local tile = doc:renderPage(p, rect, zoom, 0, 1.0, true)
    table.insert(results, time.to_ms(time.since(t)))
    require("document/doccache"):clear()
end
doc:close()
table.sort(results)
local sum = 0 for _, v in ipairs(results) do sum = sum + v end
print(string.format("abrir=%dms paginas=%d media=%dms mediana=%dms min=%dms max=%dms",
    t_open, #results, sum / #results, results[math.ceil(#results / 2)], results[1], results[#results]))
