-- SPDX-License-Identifier: AGPL-3.0-only
local Settings = {}
Settings.__index = Settings
local PREFIX = "graydither_refresh_"

local function in_range(value, minimum, maximum)
    return type(value) == "number" and value == value
        and value >= minimum and value <= maximum
end

local function valid_interval(value)
    return in_range(value, 1, 50) and value == math.floor(value)
end

local function valid_mode(value)
    return value == "native" or value == "flash"
end

function Settings.new(store)
    assert(store and type(store.readSetting) == "function", "missing reader settings")
    return setmetatable({ store = store }, Settings)
end

function Settings:getEnabled()
    return self.store:readSetting(PREFIX.."enabled") == true
end

function Settings:getInterval()
    local value = self.store:readSetting(PREFIX.."interval")
    return valid_interval(value) and value or 5
end

function Settings:getMode()
    local value = self.store:readSetting(PREFIX.."mode")
    return valid_mode(value) and value or "native"
end

function Settings:getHold()
    local value = self.store:readSetting(PREFIX.."hold")
    return in_range(value, 0.10, 1.00) and value or 0.30
end

function Settings:setEnabled(value)
    assert(type(value) == "boolean", "refresh enabled must be boolean")
    self.store:saveSetting(PREFIX.."enabled", value)
end

function Settings:setInterval(value)
    assert(valid_interval(value), "refresh interval must be an integer from 1 to 50")
    self.store:saveSetting(PREFIX.."interval", value)
end

function Settings:setMode(value)
    assert(valid_mode(value), "refresh mode must be native or flash")
    self.store:saveSetting(PREFIX.."mode", value)
end

function Settings:setHold(value)
    assert(in_range(value, 0.10, 1.00), "refresh hold must be from 0.10 to 1.00 seconds")
    self.store:saveSetting(PREFIX.."hold", value)
end

return Settings
