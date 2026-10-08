-- SPDX-License-Identifier: AGPL-3.0-only
-- Standard Floyd-Steinberg diffusion on a private, normalized page buffer.
local BB = require("ffi/blitbuffer")
local ffi = require("ffi")
local floor, min, max = math.floor, math.min, math.max
local Algorithm = { MAX_DIMENSION = 8192, MAX_PIXELS = 8 * 1024 * 1024 }

function Algorithm.apply(buffer)
    if buffer == nil or
        not (ffi.istype("BlitBuffer8", buffer) or ffi.istype("BlitBufferRGB32", buffer)) then
        return nil, "unsupported_buffer"
    end
    local kind = buffer:getType()
    if kind ~= BB.TYPE_BB8 and kind ~= BB.TYPE_BBRGB32 then
        return nil, "unsupported_buffer"
    end
    if buffer:getRotation() ~= 0 or buffer:getInverse() ~= 0 then
        return nil, "buffer_not_normalized"
    end
    local w, h, stride = tonumber(buffer.w), tonumber(buffer.h), tonumber(buffer.stride)
    local bpp = kind == BB.TYPE_BB8 and 1 or 4
    if w < 1 or h < 1 or w > Algorithm.MAX_DIMENSION or h > Algorithm.MAX_DIMENSION
        or w * h > Algorithm.MAX_PIXELS or stride < w * bpp or buffer.data == nil then
        return nil, "invalid_buffer_size"
    end
    local current = ffi.new("double[?]", w + 2)
    local next_row = ffi.new("double[?]", w + 2)
    local data = ffi.cast("uint8_t*", buffer.data)
    for y = 0, h - 1 do
        local row = data + y * stride
        for x = 0, w - 1 do
            local offset = x * bpp
            local gray
            if bpp == 1 then
                gray = row[offset]
            else
                -- Integer coefficients sum to 1000: equal RGB channels stay exact.
                gray = floor((299 * row[offset] + 587 * row[offset + 1]
                    + 114 * row[offset + 2] + 500) / 1000)
            end
            local i = x + 1
            local value = min(255, max(0, gray + current[i]))
            local quantized = 17 * floor(value / 17 + 0.5)
            local error_value = value - quantized
            row[offset] = quantized
            if bpp == 4 then
                row[offset + 1], row[offset + 2] = quantized, quantized
            end
            current[i + 1] = current[i + 1] + error_value * 7 / 16
            next_row[i - 1] = next_row[i - 1] + error_value * 3 / 16
            next_row[i] = next_row[i] + error_value * 5 / 16
            next_row[i + 1] = next_row[i + 1] + error_value / 16
        end
        current, next_row = next_row, current
        ffi.fill(next_row, (w + 2) * ffi.sizeof("double"), 0)
    end
    return true
end

return Algorithm

