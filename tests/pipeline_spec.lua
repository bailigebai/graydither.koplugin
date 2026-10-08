local BB = require("ffi/blitbuffer")
local Algorithm = require("graydither.algorithm")
local ok, Pipeline = pcall(require, "graydither.pipeline")
assert(ok, "Pipeline.attach is not implemented yet")
for _,name in ipairs({"cacheitem","configurable","document/doccache","ffi/drawcontext",
    "document/canvascontext","ui/geometry","optmath","document/tilecacheitem","libs/libkoreader-lfs"}) do
    package.preload[name]=function() return {} end
end
package.preload["logger"]=function() return {dbg=function() end} end
local Document=dofile(TEST_FIXTURES.."/koreader/document.lua")

local function make_doc(kind)
    local source=BB.new(8,6,kind or BB.TYPE_BB8)
    for y=0,5 do for x=0,7 do source:setPixel(x,y,BB.Color8((x*29+y*13)%256)) end end
    local doc={
        file="/books/test.CBZ",provider="mupdf",info={has_pages=true},
        render_color=kind==BB.TYPE_BBRGB32,color_bb_type=BB.TYPE_BBRGB32,
        configurable={text_wrap=0,auto_straighten=0,white_threshold=255},
        source=source,sw_dithering=nil,calls=0,
    }
    setmetatable(doc,{__index=Document})
    function doc:renderPage(pageno,rect,zoom,rotation,gamma,saturation)
        self.last_args={pageno,rect,zoom,rotation,gamma,saturation}
        return {bb=self.source,excerpt={x=0,y=0}}
    end
    function doc:drawPage(...)
        self.calls=self.calls+1;self.last_sw=self.sw_dithering
        if self.night then Document.drawPageInverted(self,...)
        else Document.drawPage(self,...) end
        return "draw-result",nil,97
    end
    return doc
end
local rect={x=1,y=1,w=4,h=3}

test("disabled controller calls original with unchanged parameters and return values",function()
    local doc=make_doc();local original=doc.drawPage
    local c=assert(Pipeline.attach(doc,function()return false end))
    local target=BB.new(8,8)
    local a,b,d=doc:drawPage(target,2,3,rect,5,1.5,2,1.2,0.8)
    eq(a,"draw-result");eq(b,nil);eq(d,97);eq(doc.calls,1);eq(doc.last_sw,nil)
    eq(doc.last_args[1],5);eq(doc.last_args[2],rect);eq(doc.last_args[3],1.5)
    eq(doc.last_args[4],2);eq(doc.last_args[5],1.2);eq(doc.last_args[6],0.8)
    c:detach();eq(doc.drawPage,original)
    doc.source:free();target:free()
end)

test("enabled page preserves cached source and repeated output",function()
    local doc=make_doc();doc.sw_dithering=true
    local before=BB.tostring(doc.source);local c=assert(Pipeline.attach(doc,function()return true end))
    local expected
    for _=1,20 do
        local target=BB.new(8,8);target:fill(BB.Color8(255))
        local a,b,d=doc:drawPage(target,2,3,rect,1,1,0,1,1)
        eq(a,"draw-result");eq(b,nil);eq(d,97);eq(doc.last_sw,false)
        eq(doc.sw_dithering,true);eq(BB.tostring(doc.source),before)
        if expected then eq(BB.tostring(target),expected) else expected=BB.tostring(target) end
        eq(target:getPixel(0,0).a,255);eq(target:getPixel(7,7).a,255)
        target:free()
    end
    eq(c.processed_pages,20);c:detach();doc.source:free()
end)

test("real Document path works for both page types night mode rotation and target inverse",function()
    for _,kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
        for rotation=0,3 do for inverse=0,1 do for _,night in ipairs({false,true}) do
            local doc=make_doc(kind);doc.night=night
            local c=assert(Pipeline.attach(doc,function()return true end))
            local target=BB.new(9,8,kind);target:setRotation(rotation);target:setInverse(inverse)
            target:fill(BB.Color8(255))
            local expected=target:copy()
            local scratch=BB.new(4,3,kind)
            if night then scratch:invertblitFrom(doc.source,0,0,1,1,4,3)
            else scratch:blitFrom(doc.source,0,0,1,1,4,3) end
            assert(Algorithm.apply(scratch))
            expected:blitFrom(scratch,-1,2,0,0,4,3)
            doc:drawPage(target,-1,2,rect,1,1,rotation,1,1)
            eq(BB.tostring(target),BB.tostring(expected),"actual Document copy mismatch")
            eq(c.processed_pages,1);eq(doc.sw_dithering,nil)
            c:detach();doc.source:free();scratch:free();target:free();expected:free()
        end end end
    end
end)

test("temporary buffer is released and SW restored after algorithm failure",function()
    local doc=make_doc();doc.sw_dithering=true
    local target=BB.new(8,8);local expected=BB.new(8,8)
    doc:drawPage(expected,2,3,rect,1,1,0,1,1)
    local saved_apply=Algorithm.apply
    local saved_new=BB.new
    local owned
    BB.new=function(...)local bb=saved_new(...);owned=owned or bb;return bb end
    Algorithm.apply=function(bb) error("injected algorithm failure") end
    local notified
    local c=assert(Pipeline.attach(doc,function()return true end,function(err)notified=err end))
    doc:drawPage(target,2,3,rect,1,1,0,1,1)
    Algorithm.apply=saved_apply
    BB.new=saved_new
    eq(doc.sw_dithering,true);eq(owned:getAllocated(),0);assert(notified)
    eq(BB.tostring(target),BB.tostring(expected));eq(c.processed_pages,0)
    c:detach();doc.source:free();target:free();expected:free()
end)

test("render failure also restores SW and releases buffer before original fallback",function()
    local doc=make_doc();doc.sw_dithering=nil
    local previous=doc.drawPage;local first=true;local owned
    doc.drawPage=function(self,target,...)
        if first then first=false;owned=target;error("first draw failed") end
        return previous(self,target,...)
    end
    local c=assert(Pipeline.attach(doc,function()return true end))
    local target=BB.new(8,8);doc:drawPage(target,0,0,rect,1,1,0,1,1)
    eq(owned:getAllocated(),0);eq(doc.sw_dithering,nil);eq(doc.calls,1)
    c:detach();doc.source:free();target:free()
end)

test("unknown modes and color types go through original without processing",function()
    local mutations={
        function(d)d.file="/books/test.pdf"end,
        function(d)d.provider="other"end,
        function(d)d.configurable.text_wrap=1 end,
        function(d)d.configurable.page_opt=1 end,
        function(d)d.configurable.auto_straighten=2 end,
        function(d)d.configurable.white_threshold=250 end,
        function(d)d.render_color="yes"end,
        function(d)d.render_color=true;d.color_bb_type=BB.TYPE_BBRGB24 end,
    }
    for _,change in ipairs(mutations) do
        local doc=make_doc();change(doc)
        assert(Pipeline.supportReason(doc))
        local c=assert(Pipeline.attach(doc,function()return true end))
        local target=BB.new(8,8)
        doc:drawPage(target,0,0,rect,1,1,0,1,1)
        eq(doc.calls,1);eq(c.processed_pages,0)
        c:detach();doc.source:free();target:free()
    end
end)

test("fractional or scaled rectangle falls back unchanged",function()
    for _,r in ipairs({{x=1,y=1,w=3.5,h=2},{x=1,y=1,w=4,h=3,scaled_rect={}}}) do
        local doc=make_doc();local c=assert(Pipeline.attach(doc,function()return true end))
        local target=BB.new(8,8)
        doc:drawPage(target,0,0,r,1,1,0,1,1)
        eq(doc.calls,1);eq(c.processed_pages,0);assert(c.last_reason)
        c:detach();doc.source:free();target:free()
    end
end)

test("oversized rectangle is bypassed before allocating scratch",function()
    local doc=make_doc();local c=assert(Pipeline.attach(doc,function()return true end))
    local target=BB.new(8,8)
    doc:drawPage(target,0,0,{x=0,y=0,w=8193,h=1},1,1,0,1,1)
    eq(doc.calls,1);eq(c.processed_pages,0)
    c:detach();doc.source:free();target:free()
end)

test("detaching preserves later third party wrapper and makes old controller inert",function()
    local doc=make_doc();local c=assert(Pipeline.attach(doc,function()return true end))
    local captured=doc.drawPage;local third_calls=0
    local third=function(self,...)third_calls=third_calls+1;return captured(self,...)end
    doc.drawPage=third
    c:detach();c:detach();eq(doc.drawPage,third)
    local target=BB.new(8,8);doc:drawPage(target,0,0,rect,1,1,0,1,1)
    eq(third_calls,1);eq(doc.calls,1);eq(c.processed_pages,0)
    doc.source:free();target:free()
end)

test("repeated attachment does not stack active processors",function()
    local doc=make_doc()
    local a=assert(Pipeline.attach(doc,function()return true end))
    local b=assert(Pipeline.attach(doc,function()return true end))
    local target=BB.new(8,8);doc:drawPage(target,0,0,rect,1,1,0,1,1)
    eq(a.processed_pages,0);eq(b.processed_pages,1);eq(doc.calls,1)
    b:detach();doc.source:free();target:free()
end)

test("detaching inherited method restores the inheritance chain",function()
    local doc=make_doc();doc.drawPage=nil
    local inherited=doc.drawPage
    local c=assert(Pipeline.attach(doc,function()return false end))
    c:detach();eq(rawget(doc,"drawPage"),nil);eq(doc.drawPage,inherited)
    doc.source:free()
end)

test("fractional centering inside target matches original painted edges",function()
    local areas={{x=0,y=0,w=8,h=6},{x=-1,y=-1,w=10,h=8}}
    local positions={{0.5,0},{0,0.5},{0.5,0.5}}
    for _,source_kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
        for _,target_kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
            for rotation=0,3 do for inverse=0,1 do
                for _,r in ipairs(areas) do for _,position in ipairs(positions) do
                    local doc=make_doc(source_kind);doc.source:fill(BB.Color8(255))
                    doc.night=rotation%2==1
                    local target=BB.new(14,11,target_kind)
                    target:setRotation(rotation);target:setInverse(inverse)
                    target:fill(BB.Color8(52))
                    local expected=target:copy()
                    doc:drawPage(expected,position[1],position[2],r,1,1,rotation,1,1)
                    local c=assert(Pipeline.attach(doc,function()return true end))
                    doc:drawPage(target,position[1],position[2],r,1,1,rotation,1,1)
                    assert(BB.tostring(target)==BB.tostring(expected),"fractional centering moved painted edges")
                    eq(c.processed_pages,1,"ordinary centered page was bypassed")
                    c:detach();doc.source:free();target:free();expected:free()
                end end
            end end
        end
    end
    -- A real fit-page example: a 683-pixel page centered on a 758-pixel screen.
    local doc=make_doc();doc.source:free();doc.source=BB.new(683,1024)
    doc.source:fill(BB.Color8(255))
    local r={x=0,y=0,w=683,h=1024}
    local target=BB.new(758,1024);target:fill(BB.Color8(52))
    local expected=target:copy();doc:drawPage(expected,37.5,0,r,1,1,0,1,1)
    local c=assert(Pipeline.attach(doc,function()return true end))
    doc:drawPage(target,37.5,0,r,1,1,0,1,1)
    assert(BB.tostring(target)==BB.tostring(expected),"fit-page centering mismatch")
    eq(c.processed_pages,1)
    c:detach();doc.source:free();target:free();expected:free()
end)

test("fractional destination with target clipping falls back unchanged",function()
    for _,position in ipairs({{-0.5,0},{0,-0.5},{4.5,0},{0,5.5}}) do
        local doc=make_doc();local target=BB.new(8,8);target:fill(BB.Color8(52))
        local expected=target:copy()
        doc:drawPage(expected,position[1],position[2],rect,1,1,0,1,1)
        local c=assert(Pipeline.attach(doc,function()return true end))
        doc:drawPage(target,position[1],position[2],rect,1,1,0,1,1)
        assert(BB.tostring(target)==BB.tostring(expected),"fractional fallback altered original geometry")
        eq(c.processed_pages,0);eq(c.last_reason,"unsupported_geometry")
        c:detach();doc.source:free();target:free();expected:free()
    end
end)

test("clipped source leaves previously untouched gray background exact",function()
    local doc=make_doc();doc.source:fill(BB.Color8(255))
    local target=BB.new(14,11);target:fill(BB.Color8(52))
    local expected=target:copy()
    local clipped={x=-2,y=-1,w=12,h=9}
    doc:drawPage(expected,1,1,clipped,1,1,0,1,1)
    local c=assert(Pipeline.attach(doc,function()return true end))
    doc:drawPage(target,1,1,clipped,1,1,0,1,1)
    assert(BB.tostring(target)==BB.tostring(expected),"unpainted background was changed")
    eq(target:getPixel(1,1).a,52)
    c:detach();doc.source:free();target:free();expected:free()
end)

test("actual tile type mismatch is bypassed before inverted scratch copy",function()
    local doc=make_doc(BB.TYPE_BB8)
    doc.render_color=true;doc.night=true
    local c=assert(Pipeline.attach(doc,function()return true end))
    local target=BB.new(8,8,BB.TYPE_BB8)
    doc:drawPage(target,0,0,rect,1,1,0,1,1)
    eq(c.processed_pages,0);eq(c.last_reason,"unsupported_color")
    c:detach();doc.source:free();target:free()
end)

test("painted bounds preserve backgrounds across formats rotations and clipping",function()
    local areas={
        {x=-1,y=-1,w=10,h=8},{x=7,y=5,w=4,h=4},
        {x=-20,y=0,w=3,h=3},{x=20,y=0,w=3,h=3},
        {x=0,y=-20,w=3,h=3},{x=0,y=20,w=3,h=3},
    }
    for _,source_kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
        for _,target_kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32}) do
            for rotation=0,3 do for inverse=0,1 do
                for index,r in ipairs(areas) do
                    local doc=make_doc(source_kind);doc.source:fill(BB.Color8(255))
                    doc.night=rotation%2==1
                    local target=BB.new(14,11,target_kind)
                    target:setRotation(rotation);target:setInverse(inverse)
                    for y=0,target:getHeight()-1 do for x=0,target:getWidth()-1 do
                        target:setPixel(x,y,BB.ColorRGB32(52,83,147,91))
                    end end
                    local expected=target:copy()
                    doc:drawPage(expected,1,1,r,1,1,rotation,1,1)
                    local c=assert(Pipeline.attach(doc,function()return true end))
                    doc:drawPage(target,1,1,r,1,1,rotation,1,1)
                    assert(BB.tostring(target)==BB.tostring(expected),
                        string.format("background changed: %d/%d rotation%d inverse%d rect%d",
                            source_kind,target_kind,rotation,inverse,index))
                    c:detach();doc.source:free();target:free();expected:free()
                end
            end end
        end
    end
end)


