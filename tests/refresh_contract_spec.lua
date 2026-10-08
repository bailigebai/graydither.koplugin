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

test("real UIManager submits both flash colors before their hold timers and restores reader",function()
    local c,reader=setup("flash");assert(c:request());at(0)
    eq(screen.frames[1].mode,"Full")
    assert(screen.frames[1].pixels==string.rep(string.char(0),63))
    at(0.299999);eq(#screen.frames,1)
    at(0.30);eq(screen.frames[2].mode,"Full")
    assert(screen.frames[2].pixels==string.rep(string.char(255),63))
    at(0.599999);eq(#screen.frames,2)
    at(0.60);eq(screen.frames[3].mode,"Full")
    assert(screen.frames[3].pixels==string.rep(string.char(52),63))
    eq(UI:getTopmostVisibleWidget(),reader);eq(c.completed,1);eq(#UI._task_queue,0)
    c:stop();screen.bb:free()
end)

test("real modal consumes input while lifecycle broadcast cancels pending flash",function()
    local c,reader=setup("flash")
    local taps=0
    reader.active_widgets={Widget:new{onGesture=function()taps=taps+1 end}}
    local listener=Widget:new{onRequestSuspend=function()c:suspend()end}
    table.insert(reader,listener)
    c:request();at(0);UI:sendEvent(Event:new("Gesture"));eq(taps,0)
    UI:broadcastEvent(Event:new("RequestSuspend"));UI:forceRePaint()
    eq(UI:getTopmostVisibleWidget(),reader);eq(#UI._task_queue,0)
    local frames=#screen.frames;at(2);eq(#screen.frames,frames)
    assert(screen.frames[#screen.frames].pixels==string.rep(string.char(52),63))
    c:stop();screen.bb:free()
end)

test("real UIManager receives native full only when controller is outside scrolling",function()
    local c,reader=setup("native")
    UI.currently_scrolling=true;eq(c:request(),false);at(0);eq(#screen.frames,0)
    UI.currently_scrolling=false;assert(c:request());at(0)
    eq(screen.frames[1].mode,"Full");eq(c.completed,1)
    assert(screen.frames[1].pixels==string.rep(string.char(52),63))
    c:stop();screen.bb:free()
end)

test("real ReaderRolling pan release completes pending refresh without another PosUpdate",function()
    local c,reader=setup("native")
    c.preferences:setEnabled(true);c.preferences:setInterval(1)
    local file=assert(io.open(TEST_FIXTURES.."/koreader/frontend/apps/reader/modules/readerrolling.lua","rb"))
    local source=file:read("*a");file:close()
    -- Load the unchanged, hash-pinned host method; gesture decoding is external.
    local method=assert(source:match("(function ReaderRolling:onPanRelease.-)\nfunction ReaderRolling:onHandledAsSwipe"))
    local ReaderRolling={}
    assert(loadstring("return function(ReaderRolling, UIManager) "..method.." end"))()(ReaderRolling,UI)
    local rolling=setmetatable({
        _pan_has_scrolled=true,_pan_to_scroll_later=0,view={dialog=reader},
        ui={document={getXPointer=function()return "page2" end},
            scrolling={startInertialScroll=function()return false end}},
    },{__index=ReaderRolling})
    UI.currently_scrolling=true;c:pageUpdate(2);at(0)
    eq(c.completed,0);eq(#UI._task_queue,1)
    rolling:onPanRelease();eq(UI.currently_scrolling,false)
    at(0.249999);eq(c.completed,0)
    at(0.25);eq(c.completed,1);eq(screen.frames[#screen.frames].mode,"Full")
    eq(#UI._task_queue,0);c:stop();screen.bb:free()
end)
