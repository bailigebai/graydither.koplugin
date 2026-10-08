-- Product controller against pinned real UIManager/Widget/Event/Geom.
local BB=require("ffi/blitbuffer")
package.path=TEST_FIXTURES.."/koreader/frontend/?.lua;"..package.path
bit=require("bit")
table.pack=table.pack or function(...)return {n=select("#",...),...}end
local nop=function()end
package.preload["dbg"]=function()return {guard=nop,v=nop,is_on=false}end
package.preload["logger"]=function()return {dbg=nop,info=nop,warn=nop}end
package.preload["util"]=function()return {}end
package.preload["gettext"]=function()return function(s)return s end end
local clock_us=0
package.preload["ui/time"]=function()
    return {now=function()return clock_us end,s=function(seconds)return math.floor(seconds*1e6)end}
end
local screen={width=9,height=7,hw_dithering=false,beforePaint=nop,afterPaint=nop}
function screen:getWidth()return self.width end
function screen:getHeight()return self.height end
for _,name in ipairs({"A2","Fast","UI","Partial","NoMergeUI","NoMergePartial","FlashUI","FlashPartial","Full"})do
    screen["refresh"..name]=function()
        table.insert(screen.frames,{mode=name,pixels=BB.tostring(screen.bb),at=clock_us})
    end
end
package.preload["device"]=function()return {input={},screen=screen,_UIManagerReady=nop}end
local Support=require("graydither.refreshsettings")
local function store(data)
    return {data=data or {},isTrue=function(self,k)return self.data[k]==true end,
        readSetting=function(self,k)return self.data[k]end,
        saveSetting=function(self,k,v)self.data[k]=v end}
end
G_reader_settings=store()
local UI=require("ui/uimanager")
local Widget=require("ui/widget/widget")
local Container=require("ui/widget/container/widgetcontainer")
local Event=require("ui/event")
local Refresh=require("graydither.refresh")
local function setup(mode)
    clock_us=0;screen.frames={};screen.bb=BB.new(9,7)
    UI._window_stack={};UI._task_queue={};UI._dirty={};UI._refresh_stack={};UI._refresh_func_stack={}
    UI._task_queue_dirty=false;UI.currently_scrolling=false;UI._now=0
    local reader=Container:new{covers_fullscreen=true}
    function reader:paintTo(bb)bb:fill(BB.Color8(52))end
    UI:show(reader,"full");UI:forceRePaint();screen.frames={}
    local prefs=Support.new(store({graydither_refresh_mode=mode}))
    local c=Refresh.new(reader,prefs);c:start(1)
    return c,reader
end
local function at(seconds)
    clock_us=math.floor(seconds*1e6);UI:_checkTasks()
end


return {setup=setup,at=at,screen=screen,UI=UI,Widget=Widget,Container=Container,store=store}
