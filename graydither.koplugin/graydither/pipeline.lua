-- SPDX-License-Identifier: AGPL-3.0-only
local BB = require("ffi/blitbuffer")
local ffi = require("ffi")
local Algorithm = require("graydither.algorithm")
local Pipeline = {}
local Controller = {}
Controller.__index = Controller

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function integer(value)
    return finite(value) and value == math.floor(value)
end

function Pipeline.supportReason(doc)
    if type(doc) ~= "table" or doc.provider ~= "mupdf"
        or not doc.info or doc.info.has_pages ~= true then
        return "unsupported_document"
    end
    local extension = type(doc.file) == "string" and doc.file:match("%.([^./\\]+)$")
    if not extension or (extension:lower() ~= "cbz" and extension:lower() ~= "cbr") then
        return "unsupported_format"
    end
    local cfg = doc.configurable
    if not cfg or cfg.text_wrap ~= 0 or (cfg.page_opt ~= nil and cfg.page_opt ~= 0)
        or cfg.auto_straighten ~= 0 or cfg.white_threshold ~= 255 or doc.is_reflowable == true then
        return "optimized_mode"
    end
    if doc.render_color ~= nil and type(doc.render_color) ~= "boolean" then
        return "unsupported_color"
    end
    if doc.render_color and doc.color_bb_type ~= BB.TYPE_BBRGB32 then
        return "unsupported_color"
    end
end

local function geometryReason(target, x, y, rect)
    if target == nil or not (ffi.istype("BlitBuffer8", target)
        or ffi.istype("BlitBufferRGB32", target)) then
        return "unsupported_target"
    end
    if type(rect) ~= "table" or rect.scaled_rect ~= nil
        or not finite(x) or not finite(y)
        or not integer(rect.x) or not integer(rect.y)
        or not integer(rect.w) or not integer(rect.h)
        or rect.w < 1 or rect.h < 1 then
        return "unsupported_geometry"
    end
    -- Centered pages can have half-pixel destinations. With no target clipping,
    -- the host floors these offsets without changing the integer copy length.
    if (not integer(x) or not integer(y))
        and (x < 0 or y < 0 or x + rect.w > target:getWidth()
            or y + rect.h > target:getHeight()) then
        return "unsupported_geometry"
    end
    if rect.w > Algorithm.MAX_DIMENSION or rect.h > Algorithm.MAX_DIMENSION
        or rect.w * rect.h > Algorithm.MAX_PIXELS then
        return "page_too_large"
    end
end

function Controller:detach()
    if not self.active then return end
    self.active = false
    local doc = self.document
    if doc.drawPage == self.wrapper then doc.drawPage = self.previous_own end
    if rawget(doc, "_graydither_controller") == self then doc._graydither_controller = nil end
end

local function pack(...)
    return { n = select("#", ...), ... }
end

function Pipeline.attach(doc, is_enabled, on_error)
    if type(doc) ~= "table" or type(doc.drawPage) ~= "function"
        or type(doc.renderPage) ~= "function" or type(is_enabled) ~= "function" then
        return nil, "missing_draw_method"
    end
    local previous_controller = rawget(doc, "_graydither_controller")
    if previous_controller then previous_controller:detach() end
    local original = doc.drawPage
    local controller = setmetatable({
        document = doc, previous_own = rawget(doc, "drawPage"),
        active = true, processed_pages = 0,
    }, Controller)
    controller.wrapper = function(receiver, target, x, y, rect, ...)
        if not controller.active or receiver ~= doc or controller.busy or not is_enabled() then
            return original(receiver, target, x, y, rect, ...)
        end
        local reason = Pipeline.supportReason(doc) or geometryReason(target, x, y, rect)
        if reason then
            controller.last_reason = reason
            return original(receiver, target, x, y, rect, ...)
        end
        local args = pack(...)
        local previous_sw = doc.sw_dithering
        local scratch
        controller.busy = true
        local ok, result = pcall(function()
            local kind = doc.render_color and BB.TYPE_BBRGB32 or BB.TYPE_BB8
            doc.sw_dithering = false
            -- Borrow the cached tile only to validate its real format and painted bounds.
            -- The original draw below looks up this same tile; we never mutate or free it.
            local tile = doc:renderPage(args[1], rect, args[2], args[3], args[4], args[5])
            local source = tile and tile.bb
            if not source or not (ffi.istype("BlitBuffer8", source)
                or ffi.istype("BlitBufferRGB32", source)) or source:getType() ~= kind then
                return { bypass = "unsupported_color" }
            end
            local excerpt = tile.excerpt
            if not excerpt or not integer(excerpt.x) or not integer(excerpt.y) then
                return { bypass = "unsupported_geometry" }
            end
            local width, left = BB.checkBounds(rect.w, 0, rect.x - excerpt.x,
                rect.w, source:getWidth())
            local height, top = BB.checkBounds(rect.h, 0, rect.y - excerpt.y,
                rect.h, source:getHeight())
            if width <= 0 or height <= 0 then return { bypass = "empty_region" } end
            scratch = BB.new(rect.w, rect.h, kind)
            local returns = pack(original(receiver, scratch, 0, 0, rect, unpack(args, 1, args.n)))
            -- A viewport of our private scratch is safe; a viewport of the cached tile is not.
            local painted = scratch:viewport(left, top, width, height)
            local applied, why = Algorithm.apply(painted)
            if not applied then error("graydither: "..tostring(why)) end
            -- Copy only painted pixels: converting an untouched RGB background
            -- through a gray scratch would otherwise destroy its colors.
            target:blitFrom(scratch, math.floor(x) + left, math.floor(y) + top,
                left, top, width, height)
            return returns
        end)
        doc.sw_dithering = previous_sw
        if scratch then scratch:free() end
        controller.busy = false
        if ok and result.bypass then
            controller.last_reason = result.bypass
            return original(receiver, target, x, y, rect, unpack(args, 1, args.n))
        end
        if ok then
            controller.processed_pages = controller.processed_pages + 1
            controller.last_reason, controller.last_error = nil, nil
            return unpack(result, 1, result.n)
        end
        controller.last_reason, controller.last_error = "processing_failed", tostring(result)
        if on_error then pcall(on_error, controller.last_error) end
        return original(receiver, target, x, y, rect, unpack(args, 1, args.n))
    end
    doc.drawPage = controller.wrapper
    doc._graydither_controller = controller
    return controller
end

return Pipeline
