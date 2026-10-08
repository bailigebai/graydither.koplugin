local Support=require("refresh_test_support")
local ok=pcall(require,"graydither.refresh")
assert(ok,"Refresh controller feature is missing")
local function auto(mode)
    return {graydither_refresh_enabled=true,graydither_refresh_interval=3,
        graydither_refresh_mode=mode or "native"}
end

test("initial and repeated page events do not count as page turns",function()
    local c,p,ui=Support.new(auto())
    c:pageUpdate(7);c:start(7);c:pageUpdate(7);c:pageUpdate(7)
    eq(c.count,0);eq(#ui.tasks,0)
    c:pageUpdate(8);c:pageUpdate(9);eq(#ui.tasks,0)
    c:pageUpdate(20);eq(#ui.tasks,1);ui:advance(0)
    eq(c.completed,1);eq(c.count,0);eq(ui.frames[1].mode,"full")
    eq(ui.frames[1].pixels,string.rep(string.char(52),63))
    c:stop()
end)

test("automatic default off still allows manual refresh and resets count",function()
    local c,p,ui=Support.new();c:start(1)
    for page=2,10 do c:pageUpdate(page)end
    eq(#ui.tasks,0);assert(c:request());ui:advance(0)
    eq(c.completed,1);eq(c.count,0)
    p:setEnabled(true);p:setInterval(3)
    c:pageUpdate(11);c:pageUpdate(12);eq(c.count,2)
    assert(c:request());ui:advance(0);eq(c.count,0)
    c:pageUpdate(13);eq(#ui.tasks,0);c:stop()
end)

test("rapid page turns and manual clicks share one pending refresh",function()
    local c,p,ui=Support.new(auto());c:start(1)
    for page=2,12 do c:pageUpdate(page)end
    eq(#ui.tasks,1);eq(c:request(),false)
    ui:advance(0);eq(c.completed,1);eq(#ui.tasks,0);eq(c.busy,false)
    c:stop()
end)

test("flash draws full black and white then restores reader after both holds",function()
    local c,p,ui,reader=Support.new(auto("flash"));c:start(1)
    assert(c:request());ui:advance(0)
    eq(ui.frames[1].pixels,string.rep(string.char(0),63));eq(ui.frames[1].mode,"full")
    eq(ui.stack[#ui.stack].modal,true);eq(c.completed,0)
    ui:advance(0.29);eq(#ui.frames,1)
    ui:advance(0.01);eq(ui.frames[2].pixels,string.rep(string.char(255),63))
    eq(ui.frames[2].mode,"full");eq(ui.frames[2].at,0.30)
    ui:advance(0.30);eq(ui.frames[3].pixels,string.rep(string.char(52),63))
    eq(ui.frames[3].mode,"full");eq(ui.frames[3].at,0.60)
    eq(ui.stack[#ui.stack],reader);eq(c.completed,1);eq(c.busy,false)
    c:stop()
end)

test("close cancels pending black and white stages including stale callbacks",function()
    for _,elapsed in ipairs({-1,0,0.30})do
        local c,p,ui,reader=Support.new(auto("flash"));c:start(1);c:request()
        if elapsed>=0 then ui:advance(elapsed)end
        local stale=ui.tasks[1].fn
        c:stop();eq(#ui.tasks,0);eq(ui.stack[#ui.stack],reader);eq(c.busy,false)
        local frames=#ui.frames;stale();ui:advance(3);eq(#ui.frames,frames)
        eq(c.completed,0)
    end
end)

test("suspend cancels flash and resume starts a fresh page interval",function()
    local c,p,ui,reader=Support.new(auto("flash"));c:start(1);c:request();ui:advance(0)
    c:suspend();eq(ui.stack[#ui.stack],reader);eq(#ui.tasks,0)
    c:pageUpdate(2);eq(#ui.tasks,0);eq(c:request(),false)
    c:resume(2);c:pageUpdate(3);c:pageUpdate(4);eq(#ui.tasks,0)
    c:pageUpdate(5);eq(#ui.tasks,1);c:stop()
end)

test("reset cancels active flash and keeps the current page as baseline",function()
    local c,p,ui,reader=Support.new(auto("flash"));c:start(1)
    c:pageUpdate(2);c:request();ui:advance(0.30)
    p:setEnabled(false);c:reset()
    eq(ui.stack[#ui.stack],reader);eq(#ui.tasks,0);eq(c.count,0)
    p:setEnabled(true);c:pageUpdate(2);eq(c.count,0)
    c:pageUpdate(3);eq(c.count,1);c:stop()
end)

test("scrolling or a dialog postpones automatic full without losing due count",function()
    for _,blocked in ipairs({"scroll","dialog"})do
        local c,p,ui,reader=Support.new(auto());c:start(1)
        if blocked=="scroll" then ui.currently_scrolling=true
        else table.insert(ui.stack,Support.Widget:new{})end
        c:pageUpdate(2);c:pageUpdate(3);c:pageUpdate(4);ui:advance(0)
        eq(c.completed,0);eq(c.count,3);eq(c.busy,blocked=="scroll")
        ui.currently_scrolling=false;ui.stack={reader}
        c:pageUpdate(4);ui:advance(0.25)
        eq(c.completed,1);eq(c.count,0);c:stop()
    end
end)

test("queued refresh rechecks reader visibility and automatic enabled state",function()
    for _,change in ipairs({"dialog","disable","scroll"})do
        local c,p,ui=Support.new(auto("flash"));c:start(1)
        c:pageUpdate(2);c:pageUpdate(3);c:pageUpdate(4)
        if change=="dialog" then table.insert(ui.stack,Support.Widget:new{})
        elseif change=="disable" then p:setEnabled(false)
        else ui.currently_scrolling=true end
        ui:advance(1);eq(c.completed,0);eq(#ui.frames,0)
        eq(c.busy,change=="scroll")
        c:stop();eq(#ui.tasks,0)
    end
end)

test("automatic due during scrolling retries after release without another page event",function()
    local c,p,ui=Support.new(auto());c:start(1)
    ui.currently_scrolling=true;c:pageUpdate(2);c:pageUpdate(3);c:pageUpdate(4)
    ui:advance(1);eq(c.completed,0)
    eq(#ui.tasks,1,"one cancellable retry should remain while scrolling")
    ui.currently_scrolling=false;ui:advance(0.25)
    eq(c.completed,1);eq(#ui.tasks,0);eq(ui.frames[1].mode,"full")
    c:stop()
end)

test("stop removes flash if the first close attempt fails",function()
    for _,elapsed in ipairs({0,0.30})do
        local c,p,ui,reader=Support.new(auto("flash"));c:start(1);c:request();ui:advance(elapsed)
        ui.fail_once="close";c:stop();ui:advance(2)
        eq(ui.stack[#ui.stack],reader,"cancel left the flash covering reader")
        eq(#ui.tasks,0);eq(c.active,false);eq(c.busy,false)
    end
end)

test("refresh failure releases state and a later manual request can recover",function()
    for _,operation in ipairs({"show","paint","schedule","close","dirty"})do
        local c,p,ui,reader=Support.new(auto("flash"));c:start(1)
        if operation=="schedule" then ui.fail_once=operation end
        c:request()
        if operation~="schedule" then ui.fail_once=operation end
        ui:advance(2)
        eq(c.busy,false);eq(#ui.tasks,0);eq(ui.stack[#ui.stack],reader)
        assert(c.last_error,"processing error must be reported")
        assert(c:request());ui:advance(2)
        eq(c.completed,1);eq(c.last_error,nil);c:stop()
    end
end)

test("invalid page notifications never trigger automatic refresh",function()
    local c,p,ui=Support.new(auto());c:start(1)
    for _,bad in ipairs({0,-1,1.5,"2",{},math.huge,0/0})do c:pageUpdate(bad)end
    eq(c.count,0);eq(#ui.tasks,0);c:stop()
end)

test("old task cannot cancel a new reader refresh",function()
    local c,p,ui=Support.new(auto("flash"));c:start(1);c:request()
    local stale=ui.tasks[1].fn;c:stop();c:start(100);assert(c:request())
    stale();eq(#ui.tasks,1);ui:advance(1)
    eq(c.completed,1);eq(c.busy,false);c:stop()
end)

test("flash covers the current screen if dimensions change before repaint",function()
    local c,p,ui,reader,screen=Support.new(auto("flash"));c:start(1)
    c:request();ui:advance(0)
    screen.width=11;screen.height=8;ui:advance(0.30)
    assert(ui.frames[2].pixels==string.rep(string.char(255),88),"resized flash left uncovered pixels")
    ui:advance(0.30);eq(ui.frames[3].pixels,string.rep(string.char(52),88))
    c:stop()
end)
