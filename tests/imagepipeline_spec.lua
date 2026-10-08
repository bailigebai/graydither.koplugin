local BB = require('ffi/blitbuffer')
local Pipeline = require('graydither.imagepipeline')
local function image(source)
    return {getSize=function() return {w=source:getWidth(),h=source:getHeight()} end,
        paintTo=function(_,target,x,y)
            target:blitFrom(source,x,y,0,0,source:getWidth(),source:getHeight())
            return 'painted',nil,7
        end}
end
test('disabled instance preserves pixels and all returns and notifies after paint',function()
    local src=BB.new(3,2);src:fill(BB.Color8(52));local target=BB.new(5,4)
    local widget=image(src);local notified=0
    local ctl=assert(Pipeline.attach(widget,function()return false end,function()notified=notified+1 end))
    local a,b,c=widget:paintTo(target,1,1);eq(a,'painted');eq(b,nil);eq(c,7)
    eq(target:getPixel(1,1).a,52);eq(notified,1);eq(ctl.processed_pages,0)
    ctl:detach();src:free();target:free()
end)
test('private body FS does not alter cache or surrounding color',function()
    local src=BB.new(3,2);src:fill(BB.Color8(52));local before=BB.tostring(src)
    local target=BB.new(5,4,BB.TYPE_BBRGB32)
    for y=0,3 do for x=0,4 do target:setPixel(x,y,BB.ColorRGB32(10,20,30,255)) end end
    local widget=image(src);local ctl=assert(Pipeline.attach(widget,function()return true end))
    widget:paintTo(target,1,1);eq(ctl.processed_pages,1);eq(BB.tostring(src),before)
    for y=1,2 do for x=1,3 do local p=target:getPixel(x,y);eq(p.r%17,0);eq(p.g,p.r);eq(p.b,p.r) end end
    eq(target:getPixel(0,0).r,10);eq(target:getPixel(4,3).g,20)
    ctl:detach();src:free();target:free()
end)
test('integer clipping and rotated target retain body boundaries',function()
    local src=BB.new(3,2);src:fill(BB.Color8(52));local target=BB.new(4,5)
    target:setRotation(1);target:fill(BB.Color8(90));local widget=image(src)
    local ctl=assert(Pipeline.attach(widget,function()return true end));widget:paintTo(target,-1,1)
    eq(ctl.processed_pages,1);eq(target:getPixel(0,1).a%17,0);eq(target:getPixel(2,1).a,90)
    ctl:detach();src:free();target:free()
end)
test('processing failure reports and falls back without scratch repaint drift',function()
    local src=BB.new(3,2);src:fill(BB.Color8(52));local target=BB.new(3,2)
    local widget=image(src);local report=0
    local ctl=assert(Pipeline.attach(widget,function()return true end,nil,function()report=report+1 end))
    local alg=require('graydither.algorithm');local apply=alg.apply
    alg.apply=function()error('injected processing failure')end
    local a,b,c=widget:paintTo(target,0,0);alg.apply=apply
    eq(a,'painted');eq(c,7);eq(report,1);eq(ctl.processed_pages,0);eq(target:getPixel(0,0).a,52)
    ctl:detach();src:free();target:free()
end)
test('detach preserves a later wrapper and repeated detach is safe',function()
    local src=BB.new(2,2);local widget=image(src);local original=widget.paintTo
    local ctl=assert(Pipeline.attach(widget,function()return true end));local wrapper=widget.paintTo
    local later=function(...)return wrapper(...)end;widget.paintTo=later
    ctl:detach();ctl:detach();eq(widget.paintTo,later)
    local target=BB.new(2,2);eq(widget:paintTo(target,0,0),'painted');eq(ctl.processed_pages,0)
    widget.paintTo=original;src:free();target:free()
end)
test('hidden or throwing original paint never notifies a page',function()
    local widget={hide=true,getSize=function()return{w=1,h=1}end,paintTo=function(self)if not self.hide then error('paint failed')end end}
    local notified=0;local ctl=assert(Pipeline.attach(widget,function()return true end,function()notified=notified+1 end))
    local target=BB.new(1,1);widget:paintTo(target,0,0);eq(notified,0)
    widget.hide=false;eq(pcall(widget.paintTo,widget,target,0,0),false);eq(notified,0)
    ctl:detach();target:free()
end)
test('a failed preference predicate preserves the original reading path',function()
    local src=BB.new(2,2);src:fill(BB.Color8(52));local target=BB.new(2,2)
    local widget=image(src);local errors=0
    local ctl=assert(Pipeline.attach(widget,function()error('preference unavailable')end,nil,function()errors=errors+1 end))
    eq(widget:paintTo(target,0,0),'painted');eq(target:getPixel(0,0).a,52);eq(errors,1)
    ctl:detach();src:free();target:free()
end)
