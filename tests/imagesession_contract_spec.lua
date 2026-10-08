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

test('native number dialogs and their input stay above common settings for both reader kinds',function()
    for _,modal in ipairs({false,true})do
        local s,owner,paint,close=setup('native')
        local library
        if modal then
            -- MangaWeb keeps an application root below its modal body window.
            UI:close(owner);library=Widget:new{modal=true};UI:show(library)
            owner.modal=true;UI:show(owner)
        end
        s:showMenu()
        s.menu.buttons[2][1].callback()
        local menu=s.menu
        menu.buttons[3][1].callback()
        local spin
        for widget in pairs(s.widgets)do if widget~=menu then spin=widget end end
        assert(spin,'interval dialog must be registered')
        eq(UI:getTopmostVisibleWidget(),spin,'interval dialog must accept input')
        local input=Widget:new{}
        UI:show(input)
        eq(UI:getTopmostVisibleWidget(),input,'native nested number input stays on top')
        UI:close(input)
        spin.value=4;spin.callback(spin);UI:close(spin)
        eq(s.refresh_preferences:getInterval(),4)
        eq(UI:getTopmostVisibleWidget(),s.menu,'apply returns to refreshed settings')
        s.menu.buttons[4][1].callback();s.menu.buttons[2][1].callback()
        s.menu.buttons[#s.menu.buttons][1].callback()
        eq(UI:getTopmostVisibleWidget(),owner)
        eq(owner.modal,modal and true or nil,'original modality restored after return')
        s:showMenu();s.menu.buttons[2][1].callback();s.menu.buttons[5][1].callback()
        eq(UI:getTopmostVisibleWidget().title_text,'黑白保持时长')
        s:close();eq(UI:getTopmostVisibleWidget(),owner)
        eq(owner.modal,modal and true or nil,'original modality restored on shutdown')
        close();if library then UI:close(library)end
    end
end)

test('submenu construction failures keep current settings and never escape an input callback',function()
    local s,owner,paint,close=setup('native');s:showMenu()
    local menu=s.menu
    local original=Dialog.new
    Dialog.new=function()error('injected dialog construction failure')end
    local ok=pcall(menu.buttons[2][1].callback)
    Dialog.new=original
    eq(ok,true,'submenu errors must not crash the host event loop')
    eq(UI:getTopmostVisibleWidget(),menu,'failed submenu preserves working parent')
    eq(s.menu,menu);assert(s.last_error)
    close()
end)

test('failed first menu restores owned modality and returns to the source',function()
    local s,owner,paint,close=setup('native');owner.modal=true
    local original=Dialog.new;local returned=0
    Dialog.new=function()error('injected dialog construction failure')end
    local ok,result=pcall(s.showMenu,s,function()returned=returned+1 end)
    Dialog.new=original
    eq(ok,true);eq(result,false);eq(owner.modal,true);eq(returned,1)
    eq(UI:getTopmostVisibleWidget(),owner);assert(s.last_error);close()
end)

test('registered menu show failure rolls back and restores the reading window',function()
    local s,owner,paint,close=setup('native');owner.modal=true
    local original=Dialog.onShow
    Dialog.onShow=function()error('injected onShow failure after registration')end
    local ok,result=pcall(s.showMenu,s)
    Dialog.onShow=original
    eq(ok,true);eq(result,false);eq(owner.modal,true)
    eq(#UI._window_stack,1);eq(UI:getTopmostVisibleWidget(),owner)
    eq(next(s.widgets),nil);assert(s.last_error);close()
end)

test('native close event failure does not escape the host or strand a settings window',function()
    local s,owner,paint,close=setup('native')
    local original=Dialog.onCloseWidget
    Dialog.onCloseWidget=function()error('injected native close event failure')end
    s:showMenu();Dialog.onCloseWidget=original
    local ok=pcall(UI.close,UI,s.menu)
    eq(ok,true,'native close must finish removing the widget')
    eq(UI:getTopmostVisibleWidget(),owner);eq(s.menu,nil)
    assert(s.last_error);close()
end)

test('settings restore inherited modality without overwriting a later owner change',function()
    for _,changed in ipairs({false,true})do
        local s,old_owner,paint,close=setup('native');UI:close(old_owner)
        local owner=Host.Container:extend{modal=true}:new{}
        s.owner=owner;s.refresher.reader=owner;UI:show(owner)
        s:showMenu();eq(rawget(owner,'modal'),false)
        if changed then owner.modal='later owner policy' end
        s.menu.buttons[#s.menu.buttons][1].callback()
        if changed then eq(owner.modal,'later owner policy')
        else eq(rawget(owner,'modal'),nil);eq(owner.modal,true)end
        UI:close(owner);close()
    end
end)

test('external menu close restores the source and allows opening settings again',function()
    local s,owner,paint,close=setup('native');owner.modal=true
    local returned=0;s:showMenu(function()returned=returned+1 end)
    UI:close(s.menu);eq(owner.modal,true);eq(returned,1)
    s:showMenu();eq(UI:getTopmostVisibleWidget(),s.menu)
    s:close();eq(owner.modal,true);close()
end)

test('retired menu and spin callbacks cannot save settings or close a newer menu',function()
    local s,owner,paint,close=setup('native');owner.modal=true
    s:showMenu();local root=s.menu
    root.buttons[2][1].callback();s.menu.buttons[3][1].callback()
    local spin=UI:getTopmostVisibleWidget();spin.value=9
    local old_return=s.menu.buttons[#s.menu.buttons][1].callback
    old_return();root.buttons[1][1].callback();spin.callback(spin)
    eq(s.preferences:isEnabled(),true);eq(s.refresh_preferences:getInterval(),1)
    eq(#UI._window_stack,1);eq(owner.modal,true)
    s:showMenu();local current=s.menu
    old_return();eq(s.menu,current);eq(UI:getTopmostVisibleWidget(),current)
    root.tap_close_callback();eq(s.menu,current);eq(UI:getTopmostVisibleWidget(),current)
    close()
end)

test('native flush failure during dismiss is reported and the window still closes',function()
    local s,owner,paint,close=setup('native');owner.modal=true;s:showMenu()
    s.menu.onFlushSettings=function()error('injected child flush failure')end
    local ok=pcall(s.menu.onClose,s.menu)
    eq(ok,true);eq(UI:getTopmostVisibleWidget(),owner);eq(owner.modal,true)
    assert(s.last_error);close()
end)

test('child close event failure still retires controls and restores the source owner',function()
    local s,owner,paint,close=setup('native');owner.modal=true
    local original=Dialog.handleEvent
    local propagate=Dialog.propagateEvent
    Dialog.handleEvent=Host.Container.handleEvent
    Dialog.propagateEvent=Host.Container.propagateEvent
    s:showMenu();Dialog.handleEvent=original
    s.menu.propagateEvent=Host.Container.propagateEvent;Dialog.propagateEvent=propagate
    s.menu[1]=Widget:new{onCloseWidget=function()error('injected child close failure')end}
    local returned=0;s.return_to_reading=function()returned=returned+1 end
    UI:close(s.menu)
    eq(owner.modal,true);eq(returned,1);eq(s.menu,nil);eq(next(s.widgets),nil)
    eq(UI:getTopmostVisibleWidget(),owner);assert(s.last_error);close()
end)

test('number controls use bounded native choices without creating hidden keyboard descendants',function()
    local s,owner,paint,close=setup('native');s:showMenu()
    s.menu.buttons[2][1].callback();s.menu.buttons[3][1].callback()
    local spin=UI:getTopmostVisibleWidget()
    assert(spin.value_table,'native table picker must disable its anonymous InputDialog')
    eq(#spin.value_table,50);eq(spin.value_table[1],1);eq(spin.value_table[50],50)
    eq(spin.value_hold_step,5);eq(spin.info_text,nil)
    spin.value=4;spin.callback(spin);UI:close(spin)
    s.menu.buttons[4][1].callback();s.menu.buttons[2][1].callback()
    s:showMenu();s.menu.buttons[2][1].callback()
    s.menu.buttons[5][1].callback();spin=UI:getTopmostVisibleWidget()
    assert(spin.value_table);eq(tonumber(spin.value_table[1]),0.10)
    eq(tonumber(spin.value_table[#spin.value_table]),1.00)
    eq(tonumber(spin.value_table[spin.default_value]),0.30);eq(spin.info_text,nil)
    spin.value='0.45';spin.callback(spin);eq(s.refresh_preferences:getHold(),0.45)
    close()
end)
test('real host destroying the owner cancels queued black and white phases',function()
    for _,delay in ipairs({0,0.1})do
        local s,owner,paint,close=setup('flash');paint('one');paint('two');Host.at(delay)
        UI:close(owner);Host.at(0.2)
        eq(s.refresher.layer,nil);eq(#UI._window_stack,0);eq(#UI._task_queue,0)
        eq(s.refresher.completed,0);close()
    end
end)
