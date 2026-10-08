-- Test host for the unchanged, hash-pinned ImageWidget and real BlitBuffer.
-- Image loading is not needed: fixtures supply borrowed in-memory buffers.
-- The external MuPDF resampler is replaced by BB's real nearest-neighbour
-- scaler, so these tests cover Widget scaling order, not MuPDF filtering.
local BB = require("ffi/blitbuffer")
package.path = TEST_FIXTURES.."/koreader/frontend/?.lua;"..package.path
bit = require("bit")
local nop = function() end
package.preload["dbg"] = function() return {guard=nop, v=nop, is_on=false} end
local screen = {width=600, height=800, sw_dithering=false, night_mode=false}
function screen:getWidth() return self.width end
function screen:getHeight() return self.height end
function screen:scaleByDPI(value) return value end
package.preload["device"] = function() return {screen=screen} end
package.preload["logger"] = function() return {dbg=nop, warn=nop} end
package.preload["util"] = function() return {calcFreeMem=function() return nil end} end
package.preload["ui/uimanager"] = function() return {setDirty=nop} end
package.preload["cache"] = function()
    local Cache = {}
    function Cache:new() return setmetatable({items={}}, {__index=self}) end
    function Cache:check(key) return self.items[key] end
    function Cache:insert(key, value) self.items[key]=value end
    return Cache
end
package.preload["ui/renderimage"] = function()
    return {scaleBlitBuffer=function(_, source, width, height, disposable)
        local scaled = source:scale(width, height)
        if disposable then source:free() end
        return scaled
    end}
end
G_reader_settings = {isTrue=function() return false end}
local ImageWidget = require("ui/widget/imagewidget")
local Support = {BB=BB, screen=screen, ImageWidget=ImageWidget}

function Support.reset()
    screen.sw_dithering=false; screen.night_mode=false
end

function Support.image(width, height, kind, pixels)
    local source=BB.new(width,height,kind or BB.TYPE_BB8)
    for y=0,height-1 do for x=0,width-1 do
        local pixel=pixels[y*width+x+1]
        if type(pixel)=="number" then pixel=BB.Color8(pixel) end
        source:setPixel(x,y,pixel)
    end end
    return source
end

function Support.widget(source, options)
    options=options or {}
    options.image=source; options.image_disposable=false
    return ImageWidget:new(options)
end

function Support.target(width, height, kind, background, rotation, inverse)
    local target=BB.new(width,height,kind or BB.TYPE_BB8)
    target:setRotation(rotation or 0); target:setInverse(inverse or 0)
    -- BB:fill converts its argument to Color8 even for RGB32. Use setPixel
    -- to keep a real colored background for transparent-composition tests.
    for y=0,target:getHeight()-1 do for x=0,target:getWidth()-1 do
        target:setPixel(x,y,background or BB.Color8(85))
    end end
    return target
end

function Support.assertSame(actual, expected, message)
    if BB.tostring(actual)==BB.tostring(expected) then return end
    for y=0,actual:getHeight()-1 do for x=0,actual:getWidth()-1 do
        local a,b=actual:getPixel(x,y):getColorRGB32(),expected:getPixel(x,y):getColorRGB32()
        if a.r~=b.r or a.g~=b.g or a.b~=b.b or a.alpha~=b.alpha then
            error(string.format("%s at (%d,%d): rgba(%d,%d,%d,%d) ~= rgba(%d,%d,%d,%d)",
                message or "painted pixels differ",x,y,a.r,a.g,a.b,a.alpha,b.r,b.g,b.b,b.alpha))
        end
    end end
    error((message or "painted buffers differ")..": raw bytes differ outside logical pixels")
end

-- Oracle: unchanged host composition with native software dithering disabled,
-- followed by the independently golden-tested algorithm on the visible ROI.
-- Explicitly retained positions represent alpha=0 or source-clipped background.
function Support.expected(widget, target, x, y, roi, retained)
    local expected=target:copy()
    local original_sw=screen.sw_dithering
    screen.sw_dithering=false
    ImageWidget.paintTo(widget,expected,x,y)
    screen.sw_dithering=original_sw
    local normalized=BB.new(roi.w,roi.h,target:getType())
    normalized:blitFrom(expected,0,0,roi.x,roi.y,roi.w,roi.h)
    local original=normalized:copy()
    assert(require("graydither.algorithm").apply(normalized))
    for _,point in ipairs(retained or {}) do
        normalized:setPixel(point[1],point[2],original:getPixel(point[1],point[2]))
    end
    expected:blitFrom(normalized,roi.x,roi.y,0,0,roi.w,roi.h)
    normalized:free(); original:free()
    return expected
end

function Support.release(widget, source, ...)
    widget:free()
    if source:getAllocated()==1 then source:free() end
    for i=1,select("#",...) do
        local buffer=select(i,...)
        if buffer and buffer:getAllocated()==1 then buffer:free() end
    end
end
return Support
