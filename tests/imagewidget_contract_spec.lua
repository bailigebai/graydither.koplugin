-- Product image pipeline against the unchanged, fixed-version ImageWidget.
local Support=require("imagewidget_test_support")
local BB,Screen=Support.BB,Support.screen
local ok,ImagePipeline=pcall(require,"graydither.imagepipeline")
assert(ok,"ImagePipeline.attach is not implemented yet: "..tostring(ImagePipeline))

test("real ImageWidget paints FS golden pixels without changing borrowed image",function()
    Support.reset()
    local source=Support.image(2,2,nil,{8,9,128,246})
    local before=BB.tostring(source)
    local widget=Support.widget(source,{scale_factor=1})
    local target=Support.target(8,7)
    local notifications=0
    local controller=assert(ImagePipeline.attach(widget,function()return true end,
        function()notifications=notifications+1 end))
    widget:paintTo(target,3,2)
    for i,value in ipairs({0,17,136,238})do
        eq(target:getPixel(3+(i-1)%2,2+math.floor((i-1)/2)).a,value)
    end
    eq(target:getPixel(2,2).a,85);eq(target:getPixel(5,3).a,85)
    eq(notifications,1);eq(BB.tostring(source),before);eq(source:getAllocated(),1)
    controller:detach();Support.release(widget,source,target)
end)

test("real ImageWidget borrows a strided viewport without modifying its parent buffer",function()
    Support.reset()
    local pixels={}
    for i=1,48 do pixels[i]=(i*31)%256 end
    local owner=Support.image(8,6,nil,pixels)
    local before=BB.tostring(owner)
    local viewport=owner:viewport(1,1,3,3)
    local widget=Support.widget(viewport,{scale_factor=1})
    local target=Support.target(8,7)
    local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=3,h=3})
    local controller=assert(ImagePipeline.attach(widget,function()return true end))
    widget:paintTo(target,2,1)
    Support.assertSame(target,expected,"strided borrowed image changed output")
    eq(BB.tostring(owner),before);eq(viewport:getAllocated(),0)
    controller:detach();widget:free()
    eq(owner:getAllocated(),1);eq(BB.tostring(owner),before)
    owner:free();target:free();expected:free()
end)

test("real ImageWidget preserves letterbox background outside its painted source",function()
    Support.reset()
    local source=Support.image(2,2,nil,{8,9,128,246})
    local widget=Support.widget(source,{width=6,height=6,scale_factor=1})
    local target=Support.target(9,9,nil,BB.Color8(52))
    local expected=Support.expected(widget,target,1,1,{x=3,y=3,w=2,h=2})
    local controller=assert(ImagePipeline.attach(widget,function()return true end))
    widget:paintTo(target,1,1)
    Support.assertSame(target,expected,"letterbox or outside background was quantized")
    eq(target:getPixel(1,1).a,52);eq(target:getPixel(6,6).a,52)
    controller:detach();Support.release(widget,source,target,expected)
end)

test("real ImageWidget preserves source rotation and final offsets before FS",function()
    Support.reset()
    local source=Support.image(3,2,nil,{8,9,128,246,52,99})
    local before=BB.tostring(source)
    local widget=Support.widget(source,{rotation_angle=90,scale_factor=1,width=2,height=2})
    local target=Support.target(7,6)
    local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=2,h=2})
    local cached=widget._bb;local cached_before=BB.tostring(cached)
    local controller=assert(ImagePipeline.attach(widget,function()return true end))
    widget:paintTo(target,2,1)
    Support.assertSame(target,expected,"source rotation or source offset was lost")
    eq(widget._bb,cached);eq(BB.tostring(cached),cached_before);eq(BB.tostring(source),before)
    controller:detach();Support.release(widget,source,target,expected)
end)

test("real ImageWidget fractional negative or clipped placement uses original geometry",function()
    for _,position in ipairs({{-0.5,1},{1,-0.5},{5.5,1},{1,5.5}})do
        Support.reset()
        local source=Support.image(3,3,nil,{52,99,128,200,31,74,141,224,8})
        local widget=Support.widget(source,{scale_factor=1})
        local target=Support.target(8,7)
        local expected=target:copy()
        Support.ImageWidget.paintTo(widget,expected,position[1],position[2])
        local painted=0
        local controller=assert(ImagePipeline.attach(widget,function()return true end,
            function()painted=painted+1 end))
        widget:paintTo(target,position[1],position[2])
        Support.assertSame(target,expected,"fractional fallback changed host clipping")
        eq(widget.dimen.x,position[1]);eq(widget.dimen.y,position[2]);eq(painted,1)
        controller:detach();Support.release(widget,source,target,expected)
    end
end)

test("real ImageWidget wholly contained half pixel centering keeps host placement",function()
    for _,position in ipairs({{1.5,1},{1,1.5},{1.5,1.5}})do
        Support.reset()
        local source=Support.image(2,2,nil,{8,9,128,246})
        local widget=Support.widget(source,{scale_factor=1})
        local target=Support.target(8,7)
        local roi={x=math.floor(position[1]),y=math.floor(position[2]),w=2,h=2}
        local expected=Support.expected(widget,target,position[1],position[2],roi)
        local controller=assert(ImagePipeline.attach(widget,function()return true end))
        widget:paintTo(target,position[1],position[2])
        Support.assertSame(target,expected,"half pixel centering moved painted pixels")
        eq(widget.dimen.x,position[1]);eq(widget.dimen.y,position[2])
        controller:detach();Support.release(widget,source,target,expected)
    end
end)

test("real ImageWidget runs FS after its final scaling and owns only scaled buffer",function()
    Support.reset()
    local source=Support.image(2,2,nil,{8,9,128,246})
    local before=BB.tostring(source)
    local widget=Support.widget(source,{scale_factor=2,width=4,height=4})
    local free_method=widget.free
    local target=Support.target(7,7)
    local controller=assert(ImagePipeline.attach(widget,function()return true end))
    widget:paintTo(target,1,1)
    -- Independent rational-arithmetic FS oracle for the nearest-neighbour
    -- 4x4 resized input. Diffusing before resizing gives a different pattern.
    local golden={0,17,0,17,17,0,17,0,119,136,238,255,136,119,255,238}
    for i,value in ipairs(golden)do
        eq(target:getPixel(1+(i-1)%4,1+math.floor((i-1)/4)).a,value)
    end
    eq(widget._bb:getWidth(),4);eq(widget._bb:getHeight(),4)
    eq(widget.dimen.x,1);eq(widget.dimen.y,1)
    eq(widget.free,free_method);eq(BB.tostring(source),before)
    local scaled=widget._bb
    controller:detach();widget:free()
    eq(scaled:getAllocated(),0);eq(source:getAllocated(),1)
    source:free();target:free()
end)

test("real ImageWidget software dither is bypassed locally before FS",function()
    Support.reset();Screen.sw_dithering=true
    local source=Support.image(4,3,nil,{52,99,128,200,31,74,141,224,8,9,167,246})
    local before=BB.tostring(source)
    local widget=Support.widget(source,{scale_factor=1})
    local target=Support.target(9,7)
    local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=4,h=3})
    local native=target:copy()
    Support.ImageWidget.paintTo(widget,native,2,1)
    assert(BB.tostring(native)~=BB.tostring(expected),"fixture must discriminate host dithering from FS")
    local host_paint=widget.paintTo
    widget.paintTo=function(self,...)
        eq(Screen.sw_dithering,true,"global software dithering was changed")
        eq(self.is_icon,false,"content was relabeled as an icon")
        return host_paint(self,...)
    end
    local controller=assert(ImagePipeline.attach(widget,function()return true end))
    widget:paintTo(target,2,1)
    Support.assertSame(target,expected,"host dithering happened before FS")
    eq(Screen.sw_dithering,true);eq(widget.is_icon,false);eq(BB.tostring(source),before)
    controller:detach();Support.release(widget,source,target,expected,native)
end)

test("real ImageWidget straight alpha is composed before FS and transparent color is retained",function()
    for _,kind in ipairs({BB.TYPE_BB8A,BB.TYPE_BBRGB32})do
        for _,target_kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32})do
            Support.reset();Screen.sw_dithering=true
            local pixels
            if kind==BB.TYPE_BB8A then
                pixels={BB.Color8A(231,0),BB.Color8A(100,128),BB.Color8A(70,255),BB.Color8A(120,128)}
            else
                pixels={BB.ColorRGB32(231,11,17,0),BB.ColorRGB32(100,140,60,128),
                    BB.ColorRGB32(70,15,200,255),BB.ColorRGB32(120,170,40,128)}
            end
            local source=Support.image(2,2,kind,pixels)
            local before=BB.tostring(source)
            local widget=Support.widget(source,{scale_factor=1,alpha=true,_is_straight_alpha=true})
            local target=Support.target(7,6,target_kind,BB.ColorRGB32(52,83,147,255))
            local original_transparent=target:getPixel(2,1):getColorRGB32()
            if target_kind==BB.TYPE_BBRGB32 then
                eq(original_transparent.r,52);eq(original_transparent.g,83);eq(original_transparent.b,147)
            end
            local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=2,h=2},{{0,0}})
            local controller=assert(ImagePipeline.attach(widget,function()return true end))
            widget:paintTo(target,2,1)
            Support.assertSame(target,expected,"straight-alpha composition or transparent background changed")
            eq(target:getPixel(2,1):getR(),original_transparent.r)
            eq(target:getPixel(2,1):getG(),original_transparent.g)
            eq(target:getPixel(2,1):getB(),original_transparent.b)
            eq(BB.tostring(source),before);eq(Screen.sw_dithering,true)
            controller:detach();Support.release(widget,source,target,expected)
        end
    end
end)

test("real ImageWidget premultiplied alpha is composed before FS without changing source",function()
    for _,kind in ipairs({BB.TYPE_BB8A,BB.TYPE_BBRGB32})do
        for _,target_kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32})do
            Support.reset();Screen.sw_dithering=true
            local pixels
            if kind==BB.TYPE_BB8A then
                pixels={BB.Color8A(0,0),BB.Color8A(50,128),BB.Color8A(70,255),BB.Color8A(60,128)}
            else
                pixels={BB.ColorRGB32(0,0,0,0),BB.ColorRGB32(50,70,30,128),
                    BB.ColorRGB32(70,15,200,255),BB.ColorRGB32(60,85,20,128)}
            end
            local source=Support.image(2,2,kind,pixels)
            local before=BB.tostring(source)
            local widget=Support.widget(source,{scale_factor=1,alpha=true,_is_straight_alpha=false})
            local target=Support.target(7,6,target_kind,BB.ColorRGB32(52,83,147,255))
            if target_kind==BB.TYPE_BBRGB32 then
                local background=target:getPixel(2,1)
                eq(background.r,52);eq(background.g,83);eq(background.b,147)
            end
            local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=2,h=2},{{0,0}})
            local controller=assert(ImagePipeline.attach(widget,function()return true end))
            widget:paintTo(target,2,1)
            Support.assertSame(target,expected,"premultiplied-alpha composition changed")
            eq(BB.tostring(source),before);eq(Screen.sw_dithering,true)
            controller:detach();Support.release(widget,source,target,expected)
        end
    end
end)

test("real ImageWidget keeps night inversion dimming and destination rotation semantics",function()
    for _,kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32})do
        for rotation=0,3 do for inverse=0,1 do
            for _,flags in ipairs({{}, {invert=true}, {dim=true}, {invert=true,dim=true}})do
                Support.reset();Screen.night_mode=true
                local source=Support.image(2,2,nil,{52,99,141,224})
                local before=BB.tostring(source)
                local widget=Support.widget(source,{scale_factor=1,invert=flags.invert,dim=flags.dim})
                local target=Support.target(8,7,kind,BB.ColorRGB32(52,83,147,255),rotation,inverse)
                local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=2,h=2})
                local controller=assert(ImagePipeline.attach(widget,function()return true end))
                widget:paintTo(target,2,1)
                Support.assertSame(target,expected,string.format(
                    "night/dim/invert or target orientation changed: type=%d rotation=%d inverse=%d invert=%s dim=%s",
                    kind,rotation,inverse,tostring(flags.invert),tostring(flags.dim)))
                eq(BB.tostring(source),before);eq(widget.dimen.x,2);eq(widget.dimen.y,1)
                controller:detach();Support.release(widget,source,target,expected)
            end
        end end
    end
end)

test("real ImageWidget integer negative placement processes clipped visible pixels only",function()
    for _,kind in ipairs({BB.TYPE_BB8,BB.TYPE_BBRGB32})do
        for rotation=0,3 do for inverse=0,1 do
            Support.reset()
            local source=Support.image(5,3,nil,{52,99,128,200,31,74,141,224,8,9,167,246,42,89,151})
            local before=BB.tostring(source)
            local widget=Support.widget(source,{scale_factor=1})
            local target=Support.target(8,7,kind,BB.ColorRGB32(52,83,147,255),rotation,inverse)
            local expected=Support.expected(widget,target,-1,1,{x=0,y=1,w=4,h=3})
            local controller=assert(ImagePipeline.attach(widget,function()return true end))
            widget:paintTo(target,-1,1)
            Support.assertSame(target,expected,"negative clipping changed image placement or outside pixels")
            eq(widget.dimen.x,-1);eq(widget.dimen.y,1);eq(BB.tostring(source),before)
            controller:detach();Support.release(widget,source,target,expected)
        end end
    end
end)

test("real ImageWidget repeats painting from unchanged borrowed and scaled cache",function()
    Support.reset();Screen.sw_dithering=true
    local source=Support.image(2,2,BB.TYPE_BBRGB32,{BB.ColorRGB32(52,89,147,255),
        BB.ColorRGB32(99,14,50,255),BB.ColorRGB32(141,224,8,255),BB.ColorRGB32(167,246,42,255)})
    local before=BB.tostring(source)
    local widget=Support.widget(source,{scale_factor=2,width=4,height=4})
    widget:getSize()
    local cached=widget._bb;local cached_before=BB.tostring(cached)
    local target=Support.target(8,7,BB.TYPE_BBRGB32)
    local expected=Support.expected(widget,target,2,1,{x=2,y=1,w=4,h=4})
    local controller=assert(ImagePipeline.attach(widget,function()return true end))
    for _=1,3 do
        target:fill(BB.Color8(85));widget:paintTo(target,2,1)
        Support.assertSame(target,expected,"repeat painting drifted")
        eq(widget._bb,cached);eq(BB.tostring(cached),cached_before);eq(BB.tostring(source),before)
    end
    controller:detach();widget:free()
    eq(cached:getAllocated(),0);eq(source:getAllocated(),1)
    source:free();target:free();expected:free()
end)

test("real ImageWidget hides without notifying and preserves original paint returns",function()
    Support.reset()
    local source=Support.image(2,2,nil,{8,9,128,246})
    local widget=Support.widget(source,{scale_factor=1,hide=true})
    local target=Support.target(8,7);local before=BB.tostring(target)
    local calls=0;local marker={}
    local host_paint=widget.paintTo
    widget.paintTo=function(self,...)
        host_paint(self,...)
        return marker,nil,42
    end
    local original=widget.paintTo
    local enabled=false
    local controller=assert(ImagePipeline.attach(widget,function()return enabled end,
        function()calls=calls+1 end))
    local first,second,third=widget:paintTo(target,2,1)
    eq(first,marker);eq(second,nil);eq(third,42);eq(calls,0)
    eq(BB.tostring(target),before)
    widget.hide=false
    first,second,third=widget:paintTo(target,2,1)
    eq(first,marker);eq(second,nil);eq(third,42);eq(calls,1)
    enabled=true
    first,second,third=widget:paintTo(target,2,1)
    eq(first,marker);eq(second,nil);eq(third,42);eq(calls,2)
    controller:detach();controller:detach();eq(widget.paintTo,original)
    Support.release(widget,source,target)
end)
