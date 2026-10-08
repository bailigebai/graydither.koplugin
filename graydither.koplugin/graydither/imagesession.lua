-- SPDX-License-Identifier: AGPL-3.0-only
local UIManager = require('ui/uimanager')
local ImagePipeline = require('graydither.imagepipeline')
local Settings = require('graydither.settings')
local RefreshSettings = require('graydither.refreshsettings')
local Refresh = require('graydither.refresh')
local RefreshMenu = require('graydither.refreshmenu')
local logger = require('logger')
local _ = require('gettext')
local Session = {}; Session.__index = Session

function Session.new(options)
    assert(type(options)=='table' and options.owner and options.store,'missing image session owner/store')
    local self=setmetatable({owner=options.owner,options=options,closed=false,paused=false,ordinal=0,
        images=setmetatable({},{__mode='kv'}),widgets=setmetatable({},{__mode='k'})},Session)
    -- This store belongs to the source reader, never G_reader_settings.
    self.preferences=Settings.new(options.store)
    self.refresh_preferences=RefreshSettings.new(options.store)
    self.refresher=Refresh.new(options.owner,self.refresh_preferences,
        function(err)self:_report(err)end,function()return self:_ready()end)
    self.refresher:start()
    return self
end

function Session:_report(err)
    self.last_error=tostring(err);logger.warn('graydither image session failed:',self.last_error)
end

function Session:_run(fn,...)
    if self.closed then return false end
    local ok,err=pcall(fn,...)
    if not ok then self:_report(err) end
    return ok
end

function Session:_ready()
    if self.closed or self.paused then return false end
    if not self.options.is_ready then return true end
    local ok,ready=pcall(self.options.is_ready)
    if not ok then self:_report(ready) end
    return ok and ready==true
end

function Session:attachImage(widget,token)
    if self.closed then return false end
    assert(type(token)=='string' and token~='','missing logical screen token')
    local entry=self.images[widget]
    if entry then entry.token=token;return true end
    entry={token=token}
    entry.controller=assert(ImagePipeline.attach(widget,function()
        -- Pausing counting/refresh must not change the retained body while a
        -- foreground download or a small controls dialog covers the reader.
        return not self.closed and self.preferences:isEnabled()
    end,function()
        if not self:_ready() or UIManager:getTopmostVisibleWidget()~=self.owner then return end
        if self.last_token~=entry.token then
            self.ordinal=self.ordinal+1;self.last_token=entry.token
        end
        self.refresher:pageUpdate(self.ordinal)
    end,function(err)self:_report(err)end))
    self.images[widget]=entry
    return true
end

function Session:reset()
    if self.closed then return end
    self.refresher:reset();self.refresher.last_page=nil
    self.last_token,self.ordinal=nil,0
end

function Session:settingsChanged()
    if self.closed then return end
    self.last_error=nil
    self:reset()
    if self.options.redraw then self:_run(self.options.redraw) end
end

function Session:pause(preserve_progress)
    if self.closed then return end
    -- A later strong pause (settings/suspend) supersedes a transient loading pause.
    if self.paused and self.preserve_progress==false then return end
    self.paused=true;self.preserve_progress=preserve_progress==true
    if self.preserve_progress then self.refresher:cancel() else self:reset() end
    self.refresher.suspended=true
end

function Session:resume()
    if self.closed or not self.paused then return end
    if not self.preserve_progress then self:reset() end
    self.paused,self.preserve_progress=false,nil
    self.refresher.suspended=false
end

function Session:isRefreshManaged()
    return not self.closed and not self.paused and self.refresher.active and self.refresh_preferences:getEnabled()
end

function Session:requestRefresh()
    if self.closed then return false end
    return self.refresher:request()
end

function Session:_closeWidget(widget)
    self.widgets[widget]=nil
    if self.menu==widget then self.menu=nil end
    for _=1,2 do
        local ok,err=pcall(UIManager.close,UIManager,widget)
        if ok then return end
        self:_report(err)
    end
    self.widgets[widget]=true
end

function Session:_closeControls()
    local previous=self.closing_controls;self.closing_controls=true
    local widgets={};for widget in pairs(self.widgets)do widgets[#widgets+1]=widget end
    for _,widget in ipairs(widgets)do self:_closeWidget(widget)end
    self.closing_controls=previous
end

function Session:_beginControls()
    self.controls_generation=(self.controls_generation or 0)+1
    if self.owner_modal or not self.owner.modal then return end
    -- KOReader puts normal dialogs below modal windows. Temporarily allow
    -- native spin/input/help children above our source-owned body window;
    -- leave the source's application root and the global UI stack untouched.
    self.owner_modal={value=rawget(self.owner,'modal')}
    self.owner.modal=false
end

function Session:_ownedCallback(widget,callback)
    local generation=self.controls_generation or 0
    return function(...)
        if not self.widgets[widget] or generation~=(self.controls_generation or 0) then return true end
        return self:_run(callback,...)
    end
end

function Session:_restoreOwnerModal()
    local saved=self.owner_modal;self.owner_modal=nil
    if saved and rawget(self.owner,'modal')==false then
        self.owner.modal=saved.value
    end
end

function Session:_showOwned(widget)
    if self.closed then return false end
    self.widgets[widget]=true
    local original=widget.onCloseWidget
    widget.onCloseWidget=function(receiver,...)
        local current_menu=self.menu==widget
        self.widgets[widget]=nil;if current_menu then self.menu=nil end
        -- UIManager removes the window only after CloseWidget handlers finish.
        -- A failing native cleanup must not abort that removal/event loop.
        if original then
            local ok,err=pcall(original,receiver,...)
            if not ok then self:_report(err) end
        end
        if current_menu and not self.closing_controls then self:_returnToReading() end
    end
    local handle_event=widget.handleEvent
    if handle_event then
        widget.handleEvent=function(receiver,event,...)
            local ok,result=pcall(handle_event,receiver,event,...)
            if ok then return result end
            -- Show failures must reach the registration rollback below.
            if event.handler=='onShow' then error(result,0) end
            self:_report(result)
            if event.handler=='onCloseWidget' and self.widgets[widget] then
                -- Container dispatch reaches children before the parent. A
                -- failing child must not skip our owner/return cleanup.
                local retired,err=pcall(widget.onCloseWidget,widget)
                if not retired then self:_report(err) end
            end
            return true
        end
    end
    if widget.callback then
        local callback=widget.callback
        widget.callback=self:_ownedCallback(widget,callback)
    end
    local ok,err=pcall(UIManager.show,UIManager,widget)
    if not ok then
        self:_closeWidget(widget)
        error(err,0)
    end
    return true
end

function Session:_returnToReading()
    self.controls_generation=(self.controls_generation or 0)+1
    self:_closeControls()
    self:_restoreOwnerModal()
    local callback=self.return_to_reading;self.return_to_reading=nil
    if callback then self:_run(callback) end
end

local function guarded_items(self,items)
    for _,item in ipairs(items)do
        if item.callback then
            local callback=item.callback
            item.callback=function(...)return self:_run(callback,...)end
        end
        if item.sub_item_table then guarded_items(self,item.sub_item_table) end
    end
    return items
end

function Session:getMenuItems()
    return guarded_items(self,{
        {text=_('启用漫画灰度抖动'),checked_func=function()return self.preferences:isEnabled()end,
            keep_menu_open=true,callback=function(menu)
                self.preferences:setGlobal(not self.preferences:isEnabled());self:settingsChanged()
                if menu then menu:updateItems() end
            end},
        RefreshMenu.build(self.refresher,self.refresh_preferences,{
            show=function(widget)return self:_showOwned(widget)end,
            on_change=function()self:settingsChanged()end,
            request=function()self:_returnToReading();self:requestRefresh()end,
            can_request=function()return not self.closed and not self.refresher.busy end,
            error=function()return self.last_error end,
            scope_text=_('仅控制当前来源的内置漫画阅读器；两个开关独立保存，默认关闭。'),
        }),
    })
end

function Session:_showItems(title,items)
    if self.closed then return false end
    local ButtonDialog=require('ui/widget/buttondialog')
    local buttons={}
    local dialog
    local generation=self.controls_generation or 0
    local function owned(callback)
        return function(...)
            if not dialog or not self.widgets[dialog]
                or generation~=(self.controls_generation or 0) then return true end
            return self:_run(callback,...)
        end
    end
    local facade={updateItems=function()
        if self.menu==dialog and self.widgets[dialog]
            and generation==(self.controls_generation or 0) then self:_showItems(title,items) end
    end}
    for _,item in ipairs(items)do
        local text=item.text_func and item.text_func() or item.text
        if item.checked_func then text=(item.checked_func() and '☑ ' or '☐ ')..text end
        buttons[#buttons+1]={{text=text,enabled=not item.enabled_func or item.enabled_func(),callback=owned(function()
            if item.sub_item_table then self:_showItems(text,item.sub_item_table)
            elseif item.callback then item.callback(facade) end
        end)}}
    end
    buttons[#buttons+1]={{text=_('返回阅读'),callback=owned(function()self:_returnToReading()end)}}
    dialog=ButtonDialog:new{title=title,buttons=buttons,modal=false,
        tap_close_callback=owned(function()
            -- ButtonDialog:onClose closes itself after this callback. Remove its
            -- ownership here so returning to the source does not close it twice.
            self.widgets[dialog]=nil;if self.menu==dialog then self.menu=nil end
            self:_returnToReading()
        end)}
    -- Build/show the replacement first so a failed child leaves its parent
    -- usable. Closing the old widget afterwards cannot hide the new one.
    self:_showOwned(dialog)
    if self.menu then self:_closeWidget(self.menu) end
    self.menu=dialog;return true
end

function Session:showMenu(return_to_reading)
    if self.closed then return false end
    self.refresher:cancel()
    self:_closeControls()
    self.return_to_reading=return_to_reading
    self:_beginControls()
    local ok=self:_run(function()
        self:_showItems(_('漫画灰度与全刷'),self:getMenuItems())
    end)
    if not ok then self:_returnToReading() end
    return ok
end

function Session:close()
    if self.closed then
        self.refresher:cancel();self:_closeControls()
        self:_restoreOwnerModal()
        return
    end
    self.closed=true;self.refresher:stop();self:_closeControls();self.return_to_reading=nil
    self:_restoreOwnerModal()
    for _,entry in pairs(self.images)do entry.controller:detach()end
    self.images={}
end
return Session
