-- Pinned official NumberPicker consumes the product's public Spin options.
local Host=require('refresh_contract_support')
local Base=Host.Container:extend{}
function Base:getSize()return {w=self.width or 1,h=self.height or 1}end
function Base:refocusWidget()end
function Base:setText(text)self.text=text end
for _,name in ipairs({'focusmanager','button','container/centercontainer',
    'container/framecontainer','verticalgroup','verticalspan'})do
    package.preload['ui/widget/'..name]=function()return Base end
end
local input_count=0
package.preload['ui/widget/inputdialog']=function()
    return {new=function()input_count=input_count+1;error('unowned input constructed')end}
end
package.preload['ui/widget/infomessage']=function()return Base end
package.preload['ui/widget/spinwidget']=function()return Base end
package.preload['ui/font']=function()return {getFace=function()return {font='test',orig_size=14}end}end
package.preload['ui/size']=function()
    return {border={default=1},margin={default=0},padding={default=0,large=1}}
end
local Picker=require('ui/widget/numberpickerwidget')
local RefreshMenu=require('graydither.refreshmenu')
local Prefs=require('graydither.refreshsettings')

test('official number picker applies bounded intervals without opening native input',function()
    local controller,owner=Host.setup('native')
    local prefs=Prefs.new(Host.store{})
    local spin
    local menu=RefreshMenu.build(controller,prefs,{show=function(widget)spin=widget end})
    menu.sub_item_table[3].callback()
    local picker=Picker:new{value_table=spin.value_table,value_index=spin.value_index,
        value_step=spin.value_step,value_hold_step=spin.value_hold_step,wrap=false,show_parent=owner}
    eq(picker.value,5);eq(picker.text_value.callback,nil)
    picker.layout[2][1].callback();eq(picker.value,4)
    picker.layout[1][1].hold_callback();eq(picker.value,9)
    spin.value=picker:getValue();spin.callback(spin);eq(prefs:getInterval(),9)
    for _=1,20 do picker.layout[1][1].hold_callback()end;eq(picker.value,50)
    for _=1,20 do picker.layout[2][1].hold_callback()end;eq(picker.value,1)
    eq(input_count,0);controller:stop();Host.UI:close(owner);Host.screen.bb:free()
end)

test('official table picker preserves a saved custom hold and applies its selected numeric value',function()
    for _,current in ipairs({0.23,0.10+0.05,0.30+0.05+0.05})do
    local controller,owner=Host.setup('native')
    local prefs=Prefs.new(Host.store{graydither_refresh_hold=current})
    local spin
    local menu=RefreshMenu.build(controller,prefs,{show=function(widget)spin=widget end})
    menu.sub_item_table[5].callback()
    local picker=Picker:new{value_table=spin.value_table,value_index=spin.value_index,
        value_step=spin.value_step,value_hold_step=spin.value_hold_step,wrap=false,show_parent=owner}
    eq(tonumber(picker.value),current);eq(prefs:getHold(),current)
    eq(picker.text_value.callback,nil);eq(tonumber(spin.value_table[spin.default_value]),0.30)
    spin.value=picker:getValue();spin.callback(spin);eq(prefs:getHold(),current)
    picker.layout[1][1].callback()
    spin.value=picker:getValue();spin.callback(spin);eq(prefs:getHold(),tonumber(picker.value))
    eq(input_count,0);controller:stop();Host.UI:close(owner);Host.screen.bb:free()
    end
end)
