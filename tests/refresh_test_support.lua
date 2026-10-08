local BB=require("ffi/blitbuffer")
local Support={}
local Widget={}
function Widget:extend(o)return setmetatable(o,{__index=self})end
function Widget:new(o)
    local obj=setmetatable(o or {},{__index=self})
    if obj.init then obj:init()end
    return obj
end
function Widget:handleEvent()end
Support.Widget=Widget
local screen={width=9,height=7}
function screen:getWidth()return self.width end
function screen:getHeight()return self.height end
local UI={}
function UI:getTopmostVisibleWidget()return self.stack[#self.stack]end
function UI:setDirty(widget,mode)
    self:maybeFail("dirty");self.refresh_mode=mode
    table.insert(self.dirty,{widget=widget,mode=mode})
end
function UI:show(widget,mode)
    self:maybeFail("show");table.insert(self.stack,widget);table.insert(self.shown,widget)
    self:setDirty(widget,mode)
end
function UI:close(widget,mode)
    self:maybeFail("close")
    for i=#self.stack,1,-1 do if self.stack[i]==widget then table.remove(self.stack,i)end end
    self:setDirty(nil,mode)
end
function UI:forceRePaint()
    self:maybeFail("paint")
    local bb=BB.new(screen.width,screen.height)
    for _,widget in ipairs(self.stack)do if widget.paintTo then widget:paintTo(bb,0,0)end end
    table.insert(self.frames,{at=self.now,mode=self.refresh_mode,pixels=BB.tostring(bb)})
    bb:free()
end
function UI:scheduleIn(delay,fn)
    self:maybeFail("schedule");table.insert(self.tasks,{at=self.now+delay,fn=fn})
end
function UI:nextTick(fn)self:scheduleIn(0,fn)end
function UI:unschedule(fn)
    for i=#self.tasks,1,-1 do if self.tasks[i].fn==fn then table.remove(self.tasks,i)end end
end
function UI:maybeFail(operation)
    if self.fail_once==operation then self.fail_once=nil;error("injected "..operation.." failure")end
end
function UI:advance(seconds)
    local finish=self.now+seconds
    while true do
        table.sort(self.tasks,function(a,b)return a.at<b.at end)
        local task=self.tasks[1]
        if not task or task.at>finish+1e-10 then break end
        table.remove(self.tasks,1);self.now=task.at;task.fn()
    end
    self.now=finish
end
package.preload["ui/widget/widget"]=function()return Widget end
package.preload["ui/widget/spinwidget"]=function()return Widget end
package.preload["ui/widget/infomessage"]=function()return Widget end
package.preload["ui/widget/container/widgetcontainer"]=function()return Widget end
package.preload["ui/geometry"]=function()return {new=function(_,o)return o end}end
package.preload["device"]=function()return {screen=screen}end
package.preload["ui/uimanager"]=function()return UI end
package.preload["gettext"]=function()return function(s)return s end end
package.preload["logger"]=function()return {warn=function()end}end
function Support.store(data)
    return {data=data or {},readSetting=function(self,k)return self.data[k]end,
        saveSetting=function(self,k,v)self.data[k]=v end,
        delSetting=function(self,k)self.data[k]=nil end}
end
function Support.reset(reader)
    UI.stack={};UI.tasks={};UI.frames={};UI.now=0;UI.currently_scrolling=false
    UI.dirty={};UI.shown={}
    UI.fail_once=nil;UI.refresh_mode=nil
    screen.width=9;screen.height=7
    if reader then UI.stack={reader}end
    return UI,screen
end
function Support.new(data)
    Support.reset()
    local reader={}
    function reader:paintTo(bb)bb:fill(BB.Color8(52))end
    UI.stack={reader}
    local prefs=require("graydither.refreshsettings").new(Support.store(data))
    local controller=require("graydither.refresh").new(reader,prefs)
    return controller,prefs,UI,reader,screen
end
return Support
