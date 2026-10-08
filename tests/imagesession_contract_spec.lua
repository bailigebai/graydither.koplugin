-- Real UIManager scheduling/ownership and real ImageWidget body pixels together.
local Host=require('refresh_contract_support')
local UI,screen,Widget=Host.UI,Host.screen,Host.Widget
local BB=require('ffi/blitbuffer')
function screen:scaleByDPI(value)return value end
package.preload['cache']=function()
    return {new=function()return {check=function()end,insert=function()end}end}
end
package.preload['ui/renderimage']=function()return {scaleBlitBuffer=function(_,bb,w,h)return bb:scale(w,h)end}end
package.preload['ui/widget/spinwidget']=function()return Widget end
package.preload['ui/widget/infomessage']=function()return Widget end
local Dialog=Widget:extend{modal=true}
function Dialog:onClose()if self.tap_close_callback then self.tap_close_callback()end;UI:close(self)end
function Dialog:onCloseWidget()self.closes=(self.closes or 0)+1 end
package.preload['ui/widget/buttondialog']=function()return Dialog end
local ImageWidget=require('ui/widget/imagewidget')
local Session=require('graydither.imagesession')
local function setup(mode)
    local unused,owner=Host.setup(mode);unused:stop()
    local store=Host.store{graydither_enabled=true,graydither_refresh_enabled=true,
        graydither_refresh_interval=1,graydither_refresh_mode=mode,graydither_refresh_hold=0.1}
    local source=BB.new(2,2);source:fill(BB.Color8(52))
    local image=ImageWidget:new{image=source,image_disposable=false,scale_factor=1}
    local ready=true
    local s=Session.new{owner=owner,store=store,is_ready=function()return ready end}
    function owner:paintTo(bb)bb:fill(BB.Color8(85));image:paintTo(bb,1,1)end
    local function paint(token)s:attachImage(image,token);UI:setDirty(owner,'partial');UI:forceRePaint()end
    local function close()s:close();UI:close(owner);image:free();source:free();screen.bb:free()end
    return s,owner,paint,close,function(value)ready=value end
end
test('real host body pixels and loading screens only count successful visible logical changes',function()
    local s,owner,paint,close,ready=setup('native')
    paint('one');eq(screen.bb:getPixel(1,1).a%17,0);eq(s.refresher.count,0)
    s:pause(true);ready(false);paint('two');eq(s.last_token,'one');ready(true);s:resume();paint('two')
    Host.at(0);eq(s.refresher.completed,1);eq(UI:getTopmostVisibleWidget(),owner)
    paint('two');Host.at(0);eq(s.refresher.completed,1);close()
end)
test('real host closes both flash phases when same root switches to embedded settings',function()
    for _,delay in ipairs({0,0.1})do
        local s,owner,paint,close,ready=setup('flash')
        paint('one');paint('two');Host.at(delay);assert(s.refresher.layer)
        ready(false);Host.at(0.2);eq(s.refresher.layer,nil);eq(UI:getTopmostVisibleWidget(),owner)
        eq(s.refresher.completed,0);eq(#UI._task_queue,0);close()
    end
end)
test('real host manual action returns to page before submitting full and releases controls on shutdown',function()
    local s,owner,paint,close,ready=setup('native');paint('one');s:pause();ready(false)
    s:showMenu(function()ready(true);s:resume()end)
    local refresh=s:getMenuItems()[2].sub_item_table
    eq(refresh[1].enabled_func(),true);refresh[1].callback();Host.at(0)
    eq(UI:getTopmostVisibleWidget(),owner);eq(s.refresher.completed,1)
    s:showMenu();refresh=s:getMenuItems()[2].sub_item_table;refresh[3].callback()
    eq(#UI._window_stack,3);s:close();eq(#UI._window_stack,1);close()
end)
test('real dismiss handler closes its common dialog exactly once',function()
    local s,owner,paint,close=setup('native');paint('one');s:showMenu()
    local dialog=s.menu;dialog:onClose();eq(dialog.closes,1);eq(UI:getTopmostVisibleWidget(),owner);close()
end)
