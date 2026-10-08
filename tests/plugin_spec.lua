local BB=require("ffi/blitbuffer")
local Support=require("refresh_test_support")
local UI=require("ui/uimanager")
local function store()
    return {data={},readSetting=function(self,k)return self.data[k]end,
        saveSetting=function(self,k,v)self.data[k]=v end,
        delSetting=function(self,k)self.data[k]=nil end}
end
local function new_plugin(file)
    G_reader_settings=store()
    local source=BB.new(4,3);source:fill(BB.Color8(52))
    local doc={file=file or "/books/test.cbz",provider="mupdf",info={has_pages=true},
        configurable={text_wrap=0,page_opt=0,auto_straighten=0,white_threshold=255},
        color_bb_type=BB.TYPE_BBRGB32}
    function doc:renderPage()return {bb=source,excerpt={x=0,y=0}}end
    function doc:drawPage(target,x,y,rect)
        target:blitFrom(source,x,y,rect.x,rect.y,rect.w,rect.h)
    end
    local ui={document=doc,doc_settings=store(),paging={current_page=1},menu={}}
    function ui:paintTo(bb)bb:fill(BB.Color8(52))end
    ui.dialog=ui
    Support.reset(ui)
    function ui.menu:registerToMainMenu(plugin)self.plugin=plugin end
    local ok,Class=pcall(dofile,TEST_PLUGIN.."/main.lua")
    assert(ok,"Plugin main is not implemented yet: "..tostring(Class))
    return Class:new{ui=ui},doc,ui,source
end

test("menu registers and default global is off",function()
    local plugin,doc,ui,source=new_plugin()
    eq(ui.menu.plugin,plugin);eq(plugin.is_doc_only,true)
    local menu={};plugin:addToMainMenu(menu)
    assert(menu.graydither);eq(menu.graydither.sub_item_table[1].checked_func(),false)
    eq(plugin:onReaderReady(),nil)
    eq(plugin.preferences:isEnabled(),false)
    plugin:onCloseDocument();source:free()
end)

test("per document force on works while global is disabled",function()
    local plugin,doc,ui,source=new_plugin()
    local before=BB.tostring(source);plugin:onReaderReady()
    local menu={};plugin:addToMainMenu(menu)
    menu.graydither.sub_item_table[3].callback()
    eq(G_reader_settings.data.graydither_enabled,nil)
    eq(ui.doc_settings.data.graydither_enabled,true)
    local target=BB.new(4,3)
    doc:drawPage(target,0,0,{x=0,y=0,w=4,h=3},1,1,0,1,1)
    eq(plugin.controller.processed_pages,1);eq(BB.tostring(source),before)
    for y=0,2 do for x=0,3 do eq(target:getPixel(x,y).a%17,0) end end
    eq(UI.dirty[#UI.dirty].widget,ui.dialog);eq(UI.dirty[#UI.dirty].mode,"partial")
    plugin:onCloseDocument();source:free();target:free()
end)

test("global toggle and per book off then follow affect actual drawing",function()
    local plugin,doc,ui,source=new_plugin();plugin:onReaderReady()
    local menu={};plugin:addToMainMenu(menu);local items=menu.graydither.sub_item_table
    items[1].callback();eq(G_reader_settings.data.graydither_enabled,true)
    items[4].callback();eq(ui.doc_settings.data.graydither_enabled,false)
    local target=BB.new(4,3)
    doc:drawPage(target,0,0,{x=0,y=0,w=4,h=3},1,1,0,1,1)
    eq(plugin.controller.processed_pages,0)
    items[2].callback();eq(ui.doc_settings.data.graydither_enabled,nil)
    doc:drawPage(target,0,0,{x=0,y=0,w=4,h=3},1,1,0,1,1)
    eq(plugin.controller.processed_pages,1)
    plugin:onCloseDocument();source:free();target:free()
end)

test("closing and repeated ReaderReady restore document method",function()
    local plugin,doc,ui,source=new_plugin()
    local original=doc.drawPage
    plugin:onReaderReady();plugin:onReaderReady()
    eq(plugin:onCloseDocument(),nil)
    eq(doc.drawPage,original);eq(plugin.controller,nil)
    source:free()
end)

test("unsupported formats are explained and their methods are unchanged",function()
    local plugin,doc,ui,source=new_plugin("/books/test.pdf");local original=doc.drawPage
    plugin:onReaderReady();eq(doc.drawPage,original);eq(plugin.controller,nil)
    local menu={};plugin:addToMainMenu(menu);menu.graydither.sub_item_table[3].callback()
    menu.graydither.sub_item_table[5].callback()
    assert(UI.shown[#UI.shown].text:find("CBZ",1,true))
    plugin:onCloseDocument();source:free()
end)

test("runtime mode changes are reflected by status and draw bypass",function()
    local plugin,doc,ui,source=new_plugin();plugin:onReaderReady()
    plugin.preferences:setOverride(true)
    doc.configurable.text_wrap=1
    local target=BB.new(4,3);doc:drawPage(target,0,0,{x=0,y=0,w=4,h=3})
    eq(plugin.controller.processed_pages,0)
    assert(plugin:statusText():find("优化",1,true))
    plugin:onCloseDocument();source:free();target:free()
end)

test("refresh menu controls automatic interval mode and hold via actual callbacks",function()
    local plugin,doc,ui,source=new_plugin();plugin:onReaderReady()
    local menu={};plugin:addToMainMenu(menu)
    assert(menu.graydither_refresh,"refresh menu is missing")
    local items=menu.graydither_refresh.sub_item_table
    eq(items[2].checked_func(),false);items[2].callback()
    eq(plugin.refresh_preferences:getEnabled(),true)
    items[3].callback();local spin=UI.shown[#UI.shown]
    eq(spin.value_min,1);eq(spin.value_max,50);spin.value=3;spin.callback(spin)
    UI:close(spin)
    eq(plugin.refresh_preferences:getInterval(),3)
    items[4].sub_item_table[2].callback();eq(plugin.refresh_preferences:getMode(),"flash")
    items[5].callback();spin=UI.shown[#UI.shown]
    eq(spin.value_min,0.10);eq(spin.value_max,1.00);spin.value=0.10;spin.callback(spin)
    UI:close(spin);eq(plugin.refresh_preferences:getHold(),0.10)
    plugin:onPageUpdate(2);plugin:onPageUpdate(3);eq(#UI.tasks,0)
    plugin:onPageUpdate(4);eq(#UI.tasks,1);UI:advance(0.20)
    eq(plugin.refresher.completed,1)
    items[2].callback();items[2].callback();eq(plugin.refresh_preferences:getInterval(),3)
    items[6].callback();assert(UI.shown[#UI.shown].text:find("黑白",1,true))
    plugin:onCloseDocument();source:free()
end)

test("refresh is independent of gray format support and initial events do not count",function()
    local plugin,doc,ui,source=new_plugin("/books/test.pdf")
    plugin.refresh_preferences:setEnabled(true);plugin.refresh_preferences:setInterval(3)
    eq(plugin:onPageUpdate(50),nil);ui.paging.current_page=50
    eq(plugin:onReaderReady(),nil);eq(plugin.controller,nil)
    eq(plugin:onPageUpdate(50),nil);eq(plugin.refresher.count,0)
    plugin:onPageUpdate(51);plugin:onPageUpdate(52);plugin:onPageUpdate(53);UI:advance(0)
    eq(plugin.refresher.completed,1)
    local menu={};plugin:addToMainMenu(menu)
    menu.graydither_refresh.sub_item_table[1].callback();UI:advance(0)
    eq(plugin.refresher.completed,2)
    plugin:onCloseDocument();source:free()
end)

test("Android pause resume rotation and document close cancel refresh without consuming events",function()
    local plugin,doc,ui,source=new_plugin();plugin:onReaderReady()
    plugin.refresh_preferences:setMode("flash")
    for _,event in ipairs({"onRequestSuspend","onSuspend","onSetRotationMode","onSetDimensions","onScreenResize"})do
        plugin:onResume();assert(plugin.refresher:request());UI:advance(0)
        eq(plugin[event](plugin),nil);eq(#UI.tasks,0);eq(UI.stack[#UI.stack],ui)
        eq(plugin.refresher.busy,false)
    end
    plugin:onResume();plugin.refresher:request();eq(plugin:onCloseDocument(),nil)
    eq(#UI.tasks,0);eq(plugin.refresher.active,false)
    source:free()
end)

test("rolling EPUB PosUpdate counts page changes and defers during scrolling",function()
    local plugin,doc,ui,source=new_plugin("/books/test.epub")
    ui.paging=nil;ui.rolling={current_page=10}
    plugin.refresh_preferences:setEnabled(true);plugin.refresh_preferences:setInterval(1)
    plugin:onPosUpdate(500,10);plugin:onReaderReady()
    plugin:onPosUpdate(510,10);eq(plugin.refresher.count,0)
    UI.currently_scrolling=true;eq(plugin:onPosUpdate(900,11),nil)
    eq(plugin.refresher.count,1)
    UI.currently_scrolling=false;UI:advance(0.25)
    eq(plugin.refresher.completed,1)
    plugin:onCloseDocument();source:free()
end)

test("fractional interval input shows a useful message without changing settings",function()
    local plugin,doc,ui,source=new_plugin();plugin:onReaderReady()
    local menu={};plugin:addToMainMenu(menu)
    menu.graydither_refresh.sub_item_table[3].callback()
    local spin=UI.shown[#UI.shown];spin.value=2.5
    local accepted=pcall(spin.callback,spin)
    eq(accepted,true,"decimal input crashed the menu callback")
    eq(plugin.refresh_preferences:getInterval(),5)
    assert(UI.shown[#UI.shown].text:find("整数",1,true))
    plugin:onCloseDocument();source:free()
end)
