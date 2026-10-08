local Support=require('refresh_test_support')
local UI=require('ui/uimanager')
local BB=require('ffi/blitbuffer')
package.preload['ui/widget/buttondialog']=function()return Support.Widget end
local Session=require('graydither.imagesession')
local function setup(data)
    local owner={};Support.reset(owner)
    local ready=true;local draws=0;local store=Support.store(data)
    local session=Session.new{owner=owner,store=store,is_ready=function()return ready end,redraw=function()draws=draws+1 end}
    local source=BB.new(2,2);source:fill(BB.Color8(52))
    local image={getSize=function()return{w=2,h=2}end,paintTo=function(_,target,x,y)target:blitFrom(source,x,y,0,0,2,2)end}
    local target=BB.new(2,2)
    local function paint(token)session:attachImage(image,token);image:paintTo(target,0,0)end
    return session,store,paint,function(v)ready=v end,function()session:close();source:free();target:free()end,owner,image
end
test('external defaults are off and do not read host global true',function()
    G_reader_settings=Support.store{graydither_enabled=true,graydither_refresh_enabled=true}
    local session,store,paint,ready,close=setup()
    eq(session.preferences:isEnabled(),false);eq(session.refresh_preferences:getEnabled(),false)
    paint('one');eq(session.refresher.count,0);close()
end)
test('distinct successful screens count while repeated paints and covered content do not',function()
    local s,_,paint,ready,close=setup{graydither_refresh_enabled=true,graydither_refresh_interval=2}
    paint('one');paint('one');eq(s.refresher.count,0)
    ready(false);paint('two');eq(s.refresher.count,0);ready(true);paint('two');eq(s.refresher.count,1)
    paint('three');UI:advance(0);eq(s.refresher.completed,1);close()
end)
test('loading pause preserves screen count and token across fetching next page',function()
    local s,_,paint,_,close=setup{graydither_refresh_enabled=true,graydither_refresh_interval=2}
    paint('one');s:pause(true);s:resume();paint('two');eq(s.refresher.count,1)
    s:pause(true);s:resume();paint('three');UI:advance(0);eq(s.refresher.completed,1);close()
end)
test('normal pause resume and settings change rebuild the baseline and cancel tasks',function()
    local s,_,paint,_,close=setup{graydither_refresh_enabled=true,graydither_refresh_interval=1}
    paint('one');paint('two');eq(#UI.tasks,1);s:pause();eq(#UI.tasks,0)
    s:resume();paint('three');eq(s.refresher.count,0)
    paint('four');s:settingsChanged();eq(#UI.tasks,0);paint('four');eq(s.refresher.count,0);close()
end)
test('body ready becoming false during both flash phases cancels overlay',function()
    for _,delay in ipairs({0,0.1})do
        local s,_,paint,ready,close,owner=setup{graydither_refresh_mode='flash',graydither_refresh_hold=0.1}
        assert(s:requestRefresh());UI:advance(delay);ready(false);UI:advance(0.2)
        eq(UI:getTopmostVisibleWidget(),owner);eq(#UI.tasks,0);eq(s.refresher.completed,0);close()
    end
end)
test('session close restores only owned hooks and refuses stale callbacks',function()
    local s,store,paint,_,close,_,image=setup()
    local original=image.paintTo;paint('one');local items=s:getMenuItems();s:showMenu()
    eq(#UI.stack,2);close();eq(s.closed,true);eq(image.paintTo,original);eq(#UI.stack,1)
    eq(s:showMenu(),false);eq(s:isRefreshManaged(),false)
    items[1].callback();eq(store.data.graydither_enabled,nil)
end)
test('manual refresh closes common controls and returns to body before request',function()
    local s,_,_,ready,close,owner=setup();ready(false)
    local returned=0;s:showMenu(function()returned=returned+1;ready(true)end)
    s:getMenuItems()[2].sub_item_table[1].callback();UI:advance(0)
    eq(returned,1);eq(UI:getTopmostVisibleWidget(),owner);eq(s.refresher.completed,1);close()
end)
test('failed menu persistence keeps defaults and reports without crashing',function()
    local s,store,_,_,close=setup();store.saveSetting=function()error('disk full')end
    eq(pcall(s:getMenuItems()[1].callback),true);eq(s.preferences:isEnabled(),false);assert(s.last_error);close()
end)
test('two session stores stay independent',function()
    local a=Session.new{owner={},store=Support.store()};local b=Session.new{owner={},store=Support.store()}
    a:getMenuItems()[1].callback();eq(a.preferences:isEnabled(),true);eq(b.preferences:isEnabled(),false)
    a:getMenuItems()[2].sub_item_table[2].callback();eq(a.refresh_preferences:getEnabled(),true)
    eq(b.refresh_preferences:getEnabled(),false);a:close();b:close()
end)
