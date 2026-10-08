-- SPDX-License-Identifier: AGPL-3.0-only
-- Paint the existing ImageWidget into a private body region, after its final scale.
local BB = require('ffi/blitbuffer')
local ffi = require('ffi')
local Algorithm = require('graydither.algorithm')
local Pipeline = {}
local Controller = {}; Controller.__index = Controller
local floor, max, min = math.floor, math.max, math.min
local function pack(...) return {n=select('#',...),...} end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)~=math.huge end
local function integer(n) return finite(n) and n==floor(n) end

function Controller:detach()
    if not self.active then return end
    self.active=false
    local widget=self.widget
    if widget.paintTo==self.wrapper then widget.paintTo=self.previous_own end
    if rawget(widget,'_graydither_image_controller')==self then widget._graydither_image_controller=nil end
end

local function region(widget,target,x,y)
    if target==nil or not (ffi.istype('BlitBuffer8',target) or ffi.istype('BlitBufferRGB32',target)) then
        return nil,'unsupported_target'
    end
    if not finite(x) or not finite(y) then return nil,'unsupported_geometry' end
    local size=widget:getSize()
    if not size or not integer(size.w) or not integer(size.h) or size.w<1 or size.h<1 then
        return nil,'unsupported_geometry'
    end
    if (not integer(x) or not integer(y)) and
        (x<0 or y<0 or x+size.w>target:getWidth() or y+size.h>target:getHeight()) then
        return nil,'unsupported_geometry'
    end
    local left,top=max(0,floor(x)),max(0,floor(y))
    local right,bottom=min(target:getWidth(),floor(x)+size.w),min(target:getHeight(),floor(y)+size.h)
    local w,h=right-left,bottom-top
    if w<1 or h<1 then return nil,'empty_region' end
    if w>Algorithm.MAX_DIMENSION or h>Algorithm.MAX_DIMENSION or w*h>Algorithm.MAX_PIXELS then
        return nil,'page_too_large'
    end
    return {x=left,y=top,w=w,h=h}
end

local blits={blitFrom='blitFrom',ditherblitFrom='blitFrom',alphablitFrom='alphablitFrom',
    ditheralphablitFrom='alphablitFrom',pmulalphablitFrom='pmulalphablitFrom',
    ditherpmulalphablitFrom='pmulalphablitFrom'}
-- Only the target is adapted: Screen flags and cached/borrowed source buffers stay untouched.
local function paint_target(scratch,roi,painted)
    local proxy={}
    for requested,method in pairs(blits) do
        proxy[requested]=function(_,source,x,y,sx,sy,w,h)
            assert(not painted.source,'multiple_image_blits')
            local local_x,local_y=floor(x)-roi.x,floor(y)-roi.y
            local width,dx,ox=BB.checkBounds(w,local_x,sx,scratch:getWidth(),source:getWidth())
            local height,dy,oy=BB.checkBounds(h,local_y,sy,scratch:getHeight(),source:getHeight())
            if width>0 and height>0 then
                painted.source,painted.alpha=source,method~='blitFrom'
                painted.x,painted.y,painted.sx,painted.sy=dx,dy,ox,oy
                painted.w,painted.h=width,height
            end
            return scratch[method](scratch,source,local_x,local_y,sx,sy,w,h)
        end
    end
    proxy.invertRect=function(_,x,y,w,h)
        local dx,dy,width,height=scratch:getBoundedRect(floor(x)-roi.x,floor(y)-roi.y,w,h)
        -- Use the host's inversion blit: its Lua path also works on a full-width
        -- private BB when size_t is 64-bit (invertRect's stride loop does not).
        return scratch:invertblitFrom(scratch,dx,dy,dx,dy,width,height)
    end
    proxy.lightenRect=function(_,x,y,w,h,...)
        return scratch:lightenRect(floor(x)-roi.x,floor(y)-roi.y,w,h,...)
    end
    return proxy
end

function Pipeline.attach(widget,is_enabled,on_painted,on_error)
    if type(widget)~='table' or type(widget.paintTo)~='function' or
        type(widget.getSize)~='function' or type(is_enabled)~='function' then return nil,'missing_draw_method' end
    local old=rawget(widget,'_graydither_image_controller');if old then old:detach() end
    local original=widget.paintTo
    local controller=setmetatable({widget=widget,previous_own=rawget(widget,'paintTo'),active=true,processed_pages=0},Controller)
    local function notify()
        if controller.active and not widget.hide and on_painted then pcall(on_painted) end
    end
    controller.wrapper=function(receiver,target,x,y,...)
        local args=pack(...)
        local function plain()
            local result=pack(original(receiver,target,x,y,unpack(args,1,args.n)))
            if receiver==widget then notify() end
            return unpack(result,1,result.n)
        end
        if not controller.active or receiver~=widget or controller.busy or widget.hide then return plain() end
        local checked,enabled=pcall(is_enabled)
        if not checked then
            controller.last_reason,controller.last_error='processing_failed',tostring(enabled)
            if on_error then pcall(on_error,controller.last_error) end
            return plain()
        end
        if enabled~=true then return plain() end
        local scratch,preserved
        controller.busy=true
        local ok,result=pcall(function()
            local roi,reason=region(widget,target,x,y)
            if not roi then return {bypass=reason} end
            scratch=BB.new(roi.w,roi.h,target:getType())
            scratch:blitFrom(target,0,0,roi.x,roi.y,roi.w,roi.h)
            local painted={}
            local returns=pack(original(receiver,paint_target(scratch,roi,painted),x,y,unpack(args,1,args.n)))
            if painted.source then
                if painted.alpha then preserved=scratch:copy() end
                local body=scratch:viewport(painted.x,painted.y,painted.w,painted.h)
                local applied,why=Algorithm.apply(body);assert(applied,why)
                if preserved then
                    -- Fully transparent source pixels retain the original post-paint background,
                    -- including night-mode inversion/dimming, rather than becoming gray.
                    for py=0,painted.h-1 do for px=0,painted.w-1 do
                        if painted.source:getPixel(painted.sx+px,painted.sy+py):getAlpha()==0 then
                            local dx,dy=painted.x+px,painted.y+py
                            scratch:setPixel(dx,dy,preserved:getPixel(dx,dy))
                        end
                    end end
                end
            end
            target:blitFrom(scratch,roi.x,roi.y,0,0,roi.w,roi.h)
            returns.processed=painted.source~=nil
            return returns
        end)
        if preserved then preserved:free() end
        if scratch then scratch:free() end
        controller.busy=false
        if ok and not result.bypass then
            if result.processed then controller.processed_pages=controller.processed_pages+1 end
            controller.last_reason,controller.last_error=nil,nil
            notify();return unpack(result,1,result.n)
        end
        controller.last_reason=ok and result.bypass or 'processing_failed'
        controller.last_error=not ok and tostring(result) or nil
        if not ok and on_error then pcall(on_error,controller.last_error) end
        return plain()
    end
    widget.paintTo=controller.wrapper;widget._graydither_image_controller=controller
    return controller
end
return Pipeline
