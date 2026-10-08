-- SPDX-License-Identifier: AGPL-3.0-only
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Pipeline = require("graydither.pipeline")
local Settings = require("graydither.settings")
local Refresh = require("graydither.refresh")
local RefreshSettings = require("graydither.refreshsettings")
local RefreshMenu = require("graydither.refreshmenu")
local ImageSession = require("graydither.imagesession")
local logger = require("logger")
local _ = require("gettext")

local GrayDither = WidgetContainer:extend{
    name = "graydither",
    is_doc_only = false,
}

local reasons = {
    unsupported_document = _("仅支持 MuPDF 分页漫画。"),
    unsupported_format = _("本版只处理 CBZ／CBR 漫画。"),
    optimized_mode = _("请关闭重排、页面优化、自动纠偏，并恢复默认白色阈值。"),
    unsupported_color = _("当前彩色页面格式超出本版支持范围。"),
    unsupported_target = _("当前屏幕缓冲格式超出本版支持范围。"),
    unsupported_geometry = _("当前页面区域超出本版支持范围，已显示原图。"),
    page_too_large = _("页面超过本版内存限制，已显示原图。"),
    empty_region = _("当前区域没有漫画像素，沿用阅读器绘制。"),
    processing_failed = _("上次处理失败，已显示原图。"),
    missing_draw_method = _("当前文档缺少可用的页面绘制入口。"),
    reader_not_ready = _("阅读页面尚未就绪。"),
}

local function current_page(ui)
    return (ui.paging and ui.paging.current_page) or (ui.rolling and ui.rolling.current_page)
end

function GrayDither:init()
    self.image_sessions = setmetatable({}, { __mode = "k" })
    self.stopped = false
    self.preferences = Settings.new(G_reader_settings, self.ui.doc_settings)
    self.refresh_preferences = RefreshSettings.new(G_reader_settings)
    self.refresher = Refresh.new(self.ui, self.refresh_preferences,
        function(err) logger.warn("graydither refresh failed:", err) end)
    self.attach_reason = "reader_not_ready"
    self.ui.menu:registerToMainMenu(self)
end

function GrayDither:createImageSession(options)
    if self.stopped then return nil end
    local session = ImageSession.new(options)
    self.image_sessions[session] = true
    return session
end

function GrayDither:stopPlugin()
    self.stopped = true
    self:onCloseDocument()
    for session in pairs(self.image_sessions) do session:close() end
    self.image_sessions = setmetatable({}, { __mode = "k" })
end

function GrayDither:onReaderReady()
    if self.controller then self.controller:detach(); self.controller = nil end
    self.refresher:start(current_page(self.ui))
    self.preferences = Settings.new(G_reader_settings, self.ui.doc_settings)
    local doc = self.ui.document
    local reason = Pipeline.supportReason(doc)
    if not self.ui.paging or reason == "unsupported_document" or reason == "unsupported_format" then
        self.attach_reason = reason or "unsupported_document"
        return
    end
    self.controller, self.attach_reason = Pipeline.attach(doc,
        function() return self.preferences:isEnabled() end,
        function(err) logger.warn("graydither processing failed:", err) end)
end

function GrayDither:onCloseDocument()
    self.refresher:stop()
    if self.controller then
        self.controller:detach()
        self.controller = nil
    end
end

function GrayDither:onPageUpdate(page)
    self.refresher:pageUpdate(page)
end

function GrayDither:onPosUpdate(_, page)
    self.refresher:pageUpdate(page)
end

function GrayDither:onSuspend()
    self.refresher:suspend()
end

function GrayDither:onRequestSuspend()
    self.refresher:suspend()
end

function GrayDither:onResume()
    self.refresher:resume(current_page(self.ui))
end

function GrayDither:onSetRotationMode()
    self.refresher:reset()
end

function GrayDither:onSetDimensions()
    self.refresher:reset()
end

function GrayDither:onScreenResize()
    self.refresher:reset()
end

function GrayDither:redraw()
    UIManager:setDirty(self.ui.dialog or self.ui, "partial")
end

function GrayDither:statusText()
    local reason = Pipeline.supportReason(self.ui.document) or self.attach_reason
    if not reason and self.controller then reason = self.controller.last_reason end
    local enabled = self.preferences:isEnabled()
    local lines = {
        _("漫画灰度抖动（设备测试版）"),
        enabled and _("当前设置：开启") or _("当前设置：关闭"),
        _("范围：CBZ／CBR，256 输入亮度 → 16 灰阶。"),
    }
    if reason then lines[#lines + 1] = reasons[reason] or _("当前页面使用原图。") end
    if self.controller then
        lines[#lines + 1] = _("本次成功处理次数：") .. self.controller.processed_pages
    end
    lines[#lines + 1] = _("全刷由墨水屏刷新菜单另行控制；真机画质与速度需要设备验证。")
    return table.concat(lines, "\n")
end

function GrayDither:addToMainMenu(menu_items)
    menu_items.graydither_refresh = RefreshMenu.build(self.refresher, self.refresh_preferences)
    local function set_override(value)
        self.preferences:setOverride(value)
        self:redraw()
    end
    menu_items.graydither = {
        text = _("漫画灰度抖动"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("全局默认启用"),
                checked_func = function() return self.preferences:getGlobal() end,
                callback = function()
                    self.preferences:setGlobal(not self.preferences:getGlobal())
                    self:redraw()
                end,
            },
            {
                text = _("本书：跟随全局"),
                radio = true,
                checked_func = function() return self.preferences:getOverride() == nil end,
                enabled_func = function() return self.ui.doc_settings ~= nil end,
                callback = function() set_override(nil) end,
            },
            {
                text = _("本书：开启"),
                radio = true,
                checked_func = function() return self.preferences:getOverride() == true end,
                enabled_func = function() return self.ui.doc_settings ~= nil end,
                callback = function() set_override(true) end,
            },
            {
                text = _("本书：关闭"),
                radio = true,
                checked_func = function() return self.preferences:getOverride() == false end,
                enabled_func = function() return self.ui.doc_settings ~= nil end,
                callback = function() set_override(false) end,
            },
            {
                text = _("状态与支持范围"),
                callback = function()
                    UIManager:show(InfoMessage:new{ text = self:statusText() })
                end,
            },
        },
    }
end

return GrayDither
