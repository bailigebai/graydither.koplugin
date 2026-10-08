local Host=require("refresh_contract_support")
local setup,at,screen,UI=Host.setup,Host.at,Host.screen,Host.UI
local Widget,Container=Host.Widget,Host.Container
local BB=require("ffi/blitbuffer")
local Event=require("ui/event")

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
