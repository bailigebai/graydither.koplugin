-- SPDX-License-Identifier: AGPL-3.0-only
local Settings = { KEY = "graydither_enabled" }
Settings.__index = Settings

function Settings.new(global_store, document_store)
    assert(global_store and type(global_store.readSetting) == "function", "missing reader settings")
    return setmetatable({ global = global_store, document = document_store }, Settings)
end

function Settings:getGlobal()
    return self.global:readSetting(self.KEY) == true
end

function Settings:getOverride()
    if not self.document then return nil end
    local value = self.document:readSetting(self.KEY)
    if type(value) == "boolean" then return value end
end

function Settings:isEnabled()
    local override = self:getOverride()
    if override ~= nil then return override end
    return self:getGlobal()
end

function Settings:setGlobal(value)
    assert(type(value) == "boolean", "global preference must be boolean")
    self.global:saveSetting(self.KEY, value)
end

function Settings:setOverride(value)
    assert(value == nil or type(value) == "boolean", "document preference must be boolean or nil")
    assert(self.document, "missing document settings")
    if value == nil then self.document:delSetting(self.KEY)
    else self.document:saveSetting(self.KEY, value) end
end

return Settings

