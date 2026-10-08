local BB=require("ffi/blitbuffer")
local Pipeline=require("graydither.pipeline")
local Algorithm=require("graydither.algorithm")
for _,name in ipairs({"configurable","document/doccache","ffi/drawcontext","document/canvascontext",
    "ui/geometry","optmath","document/tilecacheitem","libs/libkoreader-lfs","dbg","persist","ffi/utf8proc","util","ffi/koptcontext"}) do
    package.preload[name]=function()return {}end
end
package.preload["cacheitem"]=function()return {new=function(_,o)return o or {}end}end
package.preload["logger"]=function()return {dbg=function()end}end
package.preload["datastorage"]=function()return {getDataDir=function()return "mock-data"end}end
local screen={night_mode=false}
package.preload["device"]=function()return {screen=screen}end
local Document=dofile(TEST_FIXTURES.."/koreader/document.lua")
package.preload["document/document"]=function()return Document end
local Kopt=dofile(TEST_FIXTURES.."/koreader/koptinterface.lua")

test("fixed Kopt router and actual Document agree with page and screen night settings",function()
    for _,kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
        for _,screen_night in ipairs({false,true}) do for doc_night=0,1 do
            screen.night_mode=screen_night
            local source=BB.new(4,3,kind)
            for y=0,2 do for x=0,3 do source:setPixel(x,y,BB.Color8(x*31+y*43))end end
            local doc={
                file="/books/check.cbr",provider="mupdf",info={has_pages=true},
                color_bb_type=BB.TYPE_BBRGB32,render_color=kind==BB.TYPE_BBRGB32,
                configurable={text_wrap=0,auto_straighten=0,white_threshold=255,nightmode_document=doc_night},
                renderPage=function()return {bb=source,excerpt={x=0,y=0}}end,
                drawPage=function(self,...)return Kopt:drawPage(self,...)end,
            }
            local target=BB.new(4,3,kind);local expected=BB.new(4,3,kind)
            local r={x=0,y=0,w=4,h=3}
            if doc_night==1 and screen_night then expected:invertblitFrom(source,0,0,0,0,4,3)
            else expected:blitFrom(source,0,0,0,0,4,3)end
            assert(Algorithm.apply(expected))
            local c=assert(Pipeline.attach(doc,function()return true end))
            doc:drawPage(target,0,0,r,1,1,0,1,1)
            assert(BB.tostring(target)==BB.tostring(expected),"night routing mismatch")
            eq(c.processed_pages,1);eq(doc.sw_dithering,nil)
            c:detach();source:free();target:free();expected:free()
        end end
    end
end)

