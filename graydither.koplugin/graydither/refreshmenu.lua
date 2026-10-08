-- SPDX-License-Identifier: AGPL-3.0-only
local UIManager = require("ui/uimanager")
local SpinWidget = require("ui/widget/spinwidget")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local Menu = {}

function Menu.build(controller, prefs, options)
    options = options or {}
    local show = options.show or function(widget) UIManager:show(widget) end
    local function mode_text()
        return prefs:getMode() == "flash" and _("黑白辅助") or _("原生全刷")
    end
    local function changed(menu)
        if options.on_change then options.on_change() else controller:reset() end
        if menu then menu:updateItems() end
    end
    return {
        text = _("墨水屏刷新"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("立即全刷"),
                enabled_func = options.can_request or function()
                    return controller.active and not controller.suspended and not controller.busy
                end,
                callback = options.request or function() controller:request() end,
            },
            {
                text = _("启用自动全刷"),
                checked_func = function() return prefs:getEnabled() end,
                callback = function(menu)
                    prefs:setEnabled(not prefs:getEnabled())
                    changed(menu)
                end,
                keep_menu_open = true,
            },
            {
                text_func = function()
                    return string.format(_("自动间隔：每 %d 次页面变化"), prefs:getInterval())
                end,
                callback = function(menu)
                    show(SpinWidget:new{
                        title_text = _("自动全刷间隔"),
                        info_text = _("初始页和同页重复更新不计数；跳页算一次页面变化。"),
                        value = prefs:getInterval(), value_min = 1, value_max = 50,
                        value_step = 1, value_hold_step = 5, default_value = 5,
                        ok_always_enabled = true,
                        callback = function(spin)
                            local value = spin.value
                            -- NumberPicker's text input accepts decimals even when step=1.
                            if type(value) ~= "number" or value < 1 or value > 50
                                or value ~= math.floor(value) then
                                show(InfoMessage:new{ text = _("请输入 1～50 的整数页数。") })
                                return
                            end
                            prefs:setInterval(value)
                            changed(menu)
                        end,
                    })
                end,
                keep_menu_open = true,
            },
            {
                text_func = function() return _("刷新方式：")..mode_text() end,
                sub_item_table = {
                    {
                        text = _("原生全刷"), radio = true,
                        checked_func = function() return prefs:getMode() == "native" end,
                        callback = function(menu) prefs:setMode("native"); changed(menu) end,
                    },
                    {
                        text = _("黑白辅助"), radio = true,
                        checked_func = function() return prefs:getMode() == "flash" end,
                        callback = function(menu) prefs:setMode("flash"); changed(menu) end,
                    },
                },
            },
            {
                text_func = function()
                    return string.format(_("黑白各保持：%.2f 秒"), prefs:getHold())
                end,
                enabled_func = function() return prefs:getMode() == "flash" end,
                callback = function(menu)
                    show(SpinWidget:new{
                        title_text = _("黑白保持时长"),
                        info_text = _("黑白两阶段分别保持此时长，结束后恢复阅读页面。"),
                        value = prefs:getHold(), value_min = 0.10, value_max = 1.00,
                        value_step = 0.05, value_hold_step = 0.25,
                        precision = "%0.2f", default_value = 0.30, ok_always_enabled = true,
                        callback = function(spin)
                            prefs:setHold(spin.value)
                            changed(menu)
                        end,
                    })
                end,
                keep_menu_open = true,
            },
            {
                text = _("刷新状态与说明"),
                callback = function()
                    local lines = {
                        _("墨水屏刷新（设备测试版）"),
                        prefs:getEnabled() and _("自动全刷：开启") or _("自动全刷：关闭"),
                        string.format(_("保存的间隔：%d 次页面变化"), prefs:getInterval()),
                        _("刷新方式：")..mode_text(),
                        _("本次已完成刷新次数：")..controller.completed,
                        options.scope_text or _("支持独立刷新当前阅读页面；灰度抖动仍限 CBZ／CBR。"),
                    }
                    if controller.busy then lines[#lines + 1] = _("刷新已排队或正在执行。") end
                    if controller.suspended then lines[#lines + 1] = _("阅读器休眠中，刷新已暂停。") end
                    if controller.deferred_reason == "scrolling" then
                        lines[#lines + 1] = _("滚动期间暂缓，停止后再尝试。")
                    elseif controller.deferred_reason == "covered" then
                        lines[#lines + 1] = _("窗口遮挡期间暂缓，后续页面更新再尝试。")
                    end
                    if controller.last_error then
                        lines[#lines + 1] = _("上次刷新未完成，可重试立即全刷；详情见阅读器日志。")
                    end
                    if options.error and options.error() then
                        lines[#lines + 1] = _("上次操作未完成，设置或灰度处理可能失败；详情见阅读器日志。")
                    end
                    lines[#lines + 1] = _("原生全刷由设备适配执行；黑白辅助会闪屏，实际残影效果需真机对照。")
                    show(InfoMessage:new{ text = table.concat(lines, "\n") })
                end,
            },
        },
    }
end

return Menu
