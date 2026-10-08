local BB = require("ffi/blitbuffer")
local ffi = require("ffi")
local ok, Algorithm = pcall(require, "graydither.algorithm")
assert(ok, "Algorithm.apply is not implemented yet")

local function mean(bb)
    local sum = 0
    for y=0,bb:getHeight()-1 do
        for x=0,bb:getWidth()-1 do sum=sum+bb:getPixel(x,y):getColor8().a end
    end
    return sum/(bb:getWidth()*bb:getHeight())
end

test("hand calculated 2x2 FS golden output", function()
    local bb=BB.new(2,2,BB.TYPE_BB8)
    local input={8,9,128,246}
    for i,v in ipairs(input) do bb:setPixel((i-1)%2,math.floor((i-1)/2),BB.Color8(v)) end
    assert(Algorithm.apply(bb))
    local expected={0,17,136,238}
    for i,v in ipairs(expected) do eq(bb:getPixel((i-1)%2,math.floor((i-1)/2)).a,v) end
    bb:free()
end)

test("all quantized gray levels remain exact", function()
    for k=0,15 do
        local bb=BB.new(8,8,BB.TYPE_BB8)
        bb:fill(BB.Color8(k*17))
        local before=BB.tostring(bb)
        assert(Algorithm.apply(bb));eq(BB.tostring(bb),before)
        bb:free()
    end
end)

test("uniform fixtures do not introduce systematic dark bias", function()
    for _,v in ipairs({51,52,128,200}) do
        local bb=BB.new(64,64,BB.TYPE_BB8)
        bb:fill(BB.Color8(v));assert(Algorithm.apply(bb))
        assert(math.abs(mean(bb)-v)<=0.15,"unexpected mean "..mean(bb))
        if v==51 then eq(mean(bb),51) end
        for y=0,63 do for x=0,63 do eq(bb:getPixel(x,y).a%17,0) end end
        bb:free()
    end
end)

test("RGB32 neutral gray 51 never darkens and alpha survives", function()
    local bb=BB.new(64,64,BB.TYPE_BBRGB32)
    for y=0,63 do for x=0,63 do bb:setPixel(x,y,BB.ColorRGB32(51,51,51,73)) end end
    local before=BB.tostring(bb)
    for _=1,3 do assert(Algorithm.apply(bb));eq(BB.tostring(bb),before) end
    bb:free()
end)

test("RGB32 primary red rounds to integer luminance 76", function()
    local bb=BB.new(64,64,BB.TYPE_BBRGB32)
    for y=0,63 do for x=0,63 do bb:setPixel(x,y,BB.ColorRGB32(255,0,0,91)) end end
    assert(Algorithm.apply(bb))
    assert(math.abs(mean(bb)-76)<=0.15)
    for y=0,63 do for x=0,63 do
        local p=bb:getPixel(x,y)
        eq(p.r,p.g);eq(p.g,p.b);eq(p.r%17,0);eq(p.alpha,91)
    end end
    bb:free()
end)

test("stride padding and RGB32 alpha are preserved", function()
    for _,kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
        local bpp=kind==BB.TYPE_BB8 and 1 or 4
        local bb=BB.new(7,5,kind,nil,7*bpp+4)
        ffi.fill(bb.data,tonumber(bb.stride)*5,0xA5)
        for y=0,4 do for x=0,6 do
            bb:setPixel(x,y,BB.ColorRGB32((x*31+y*7)%256,87,163,x+y+21))
        end end
        local raw=ffi.cast("uint8_t*",bb.data)
        local alpha={}
        if bpp==4 then for y=0,4 do for x=0,6 do alpha[y*7+x]=raw[y*bb.stride+x*4+3] end end end
        assert(Algorithm.apply(bb))
        for y=0,4 do
            for i=7*bpp,tonumber(bb.stride)-1 do eq(raw[y*bb.stride+i],0xA5) end
            if bpp==4 then for x=0,6 do eq(raw[y*bb.stride+x*4+3],alpha[y*7+x]) end end
        end
        bb:free()
    end
end)

test("processing fresh copies is deterministic and leaves source untouched", function()
    local source=BB.new(32,17,BB.TYPE_BB8)
    for y=0,16 do for x=0,31 do source:setPixel(x,y,BB.Color8((x*11+y*7)%256)) end end
    local before=BB.tostring(source)
    local expected
    for _=1,20 do
        local owned=source:copy();assert(Algorithm.apply(owned))
        if expected then eq(BB.tostring(owned),expected) else expected=BB.tostring(owned) end
        owned:free();eq(BB.tostring(source),before)
    end
    source:free()
end)

test("unsupported pixel formats are rejected before mutation", function()
    for _,kind in ipairs({BB.TYPE_BB4,BB.TYPE_BB8A,BB.TYPE_BBRGB16,BB.TYPE_BBRGB24}) do
        local bb=BB.new(3,2,kind);local before=BB.tostring(bb)
        local result,reason=Algorithm.apply(bb)
        eq(result,nil);assert(type(reason)=="string");eq(BB.tostring(bb),before)
        bb:free()
    end
end)

test("rotated or inverse buffers are rejected before mutation", function()
    for rotation=0,3 do for inverse=0,1 do
        if rotation~=0 or inverse~=0 then
            local bb=BB.new(3,2,BB.TYPE_BB8);bb:setRotation(rotation);bb:setInverse(inverse)
            local before=BB.tostring(bb);local result=Algorithm.apply(bb)
            eq(result,nil);eq(BB.tostring(bb),before);bb:free()
        end
    end end
end)

test("empty buffers are rejected", function()
    local bb=BB.new(0,0,BB.TYPE_BB8)
    eq(Algorithm.apply(bb),nil);bb:free()
end)

