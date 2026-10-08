-- SPDX-License-Identifier: AGPL-3.0-only
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Screen = require("device").screen
local Geom = require("ui/geometry")
local BB = require("ffi/blitbuffer")
local Refresh = {}
Refresh.__index = Refresh
local SCROLL_RETRY_SECONDS = 0.25

local FlashLayer = Widget:extend{ name = "graydither_flash", modal = true }
function FlashLayer:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
end
function FlashLayer:paintTo(bb)
    self.dimen.w, self.dimen.h = Screen:getWidth(), Screen:getHeight()
    bb:paintRect(0, 0, self.dimen.w, self.dimen.h, self.color)
end
function FlashLayer:onGesture() return true end
function FlashLayer:onKeyPress() return true end
function FlashLayer:onKeyRepeat() return true end

local function valid_page(page)
    return type(page) == "number" and page == page and page > 0
        and page ~= math.huge and page == math.floor(page)
end

function Refresh.new(reader_ui, preferences, on_error, is_ready)
    return setmetatable({ reader = reader_ui, preferences = preferences,
        on_error = on_error, generation = 0, count = 0, completed = 0,
        active = false, busy = false, suspended = false, is_ready = is_ready }, Refresh)
end

function Refresh:_report(error_value)
    self.last_error = tostring(error_value)
    if self.on_error then pcall(self.on_error, self.last_error) end
end

function Refresh:cancel()
    self.generation = self.generation + 1
    local task = self.task
    self.task, self.busy, self.automatic = nil, false, nil
    if task then
        local ok, err = pcall(UIManager.unschedule, UIManager, task)
        if not ok then self:_report(err) end
    end
    if self.layer then
        -- A transient close error must not strand a modal after tasks are cancelled.
        -- Keep the reference on persistent failure so a later cancellation can retry.
        for _ = 1, 2 do
            local ok, err = pcall(UIManager.close, UIManager, self.layer, "full")
            if ok then self.layer = nil; break end
            self:_report(err)
        end
    end
end

function Refresh:reset()
    self:cancel()
    self.count, self.deferred_reason = 0, nil
end

function Refresh:start(page)
    self:reset()
    self.active, self.suspended = true, false
    self.completed, self.last_error = 0, nil
    if valid_page(page) then self.last_page = page end
end

function Refresh:stop()
    self.active = false
    self:reset()
    self.last_page = nil
end

function Refresh:suspend()
    self.suspended = true
    self:reset()
end

function Refresh:resume(page)
    self:reset()
    self.suspended = false
    if valid_page(page) then self.last_page = page end
end

function Refresh:_ready()
    if not self.is_ready then return true end
    local ok, ready = pcall(self.is_ready)
    if not ok then self:_report(ready) end
    return ok and ready == true
end

function Refresh:_blocked()
    if not self:_ready() then return "not_ready" end
    if UIManager.currently_scrolling then return "scrolling" end
    local reader = self.reader.dialog or self.reader
    if UIManager:getTopmostVisibleWidget() ~= reader then return "covered" end
end

function Refresh:_queue(delay, action)
    local generation = self.generation
    local callback
    callback = function()
        if generation ~= self.generation then return end
        self.task = nil
        if not self.active or self.suspended or not self:_ready()
            or (self.automatic and not self.preferences:getEnabled()) then
            self:reset()
            return
        end
        local ok, err = pcall(action)
        if not ok then
            self:_report(err)
            self:cancel()
        end
    end
    self.task = callback
    if delay then UIManager:scheduleIn(delay, callback)
    else UIManager:nextTick(callback) end
end

function Refresh:_finish()
    if self.layer then
        UIManager:close(self.layer, "full")
        self.layer = nil
    end
    UIManager:setDirty(nil, "full")
    UIManager:forceRePaint()
    self.completed = self.completed + 1
    self.count, self.busy, self.automatic = 0, false, nil
    self.last_error, self.deferred_reason = nil, nil
end

function Refresh:_flash(hold)
    self.layer = FlashLayer:new{ color = BB.COLOR_BLACK }
    UIManager:show(self.layer, "full")
    -- nextTick does not promise a repaint between callbacks: submit each
    -- color before starting its hold timer, then restore via a full refresh.
    UIManager:forceRePaint()
    self:_queue(hold, function()
        if UIManager.currently_scrolling or UIManager:getTopmostVisibleWidget() ~= self.layer then
            self:cancel()
            return
        end
        self.layer.color = BB.COLOR_WHITE
        UIManager:setDirty(self.layer, "full")
        UIManager:forceRePaint()
        self:_queue(hold, function()
            if UIManager.currently_scrolling or UIManager:getTopmostVisibleWidget() ~= self.layer then
                self:cancel()
                return
            end
            self:_finish()
        end)
    end)
end

function Refresh:request(automatic)
    if not self.active or self.suspended or self.busy or not self:_ready() then return false end
    if self.layer then
        self:cancel()
        if self.layer then return false end
    end
    if UIManager.currently_scrolling and automatic ~= true then
        self.deferred_reason = "scrolling"
        return false
    end
    self.busy, self.automatic = true, automatic == true
    local mode, hold = self.preferences:getMode(), self.preferences:getHold()
    local ok, err = pcall(function()
        local attempt
        attempt = function()
            local reason = self:_blocked()
            if reason == "scrolling" and self.automatic then
                -- Pan release does not send another page notification. Keep
                -- exactly one cancellable, positive-delay task until scrolling ends.
                self.deferred_reason = reason
                self:_queue(SCROLL_RETRY_SECONDS, attempt)
                return
            end
            if reason then
                self.busy, self.automatic, self.deferred_reason = false, nil, reason
                return
            end
            if mode == "flash" then self:_flash(hold) else self:_finish() end
        end
        self:_queue(nil, attempt)
    end)
    if not ok then
        self:_report(err)
        self:cancel()
        return false
    end
    return true
end

function Refresh:pageUpdate(page)
    if not valid_page(page) then return end
    local changed = self.last_page ~= nil and self.last_page ~= page
    self.last_page = page
    if not self.active or self.suspended then return end
    if not self.preferences:getEnabled() then self.count = 0; return end
    local interval = self.preferences:getInterval()
    if changed then self.count = math.min(interval, self.count + 1) end
    if self.count >= interval and not self.busy then self:request(true) end
end

return Refresh
