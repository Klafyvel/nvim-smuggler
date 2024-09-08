local M = {}
-- A thin wrapper around vim.mpack.decode to be able to decode only the first
-- object of a messagepack object.

local log = require("smuggler.log")

function length_4_bits(buffer, offset)
    local first_byte = string.byte(buffer, offset)
    if first_byte ~= nil then
        return bit.band(0xf, first_byte)
    else 
        return nil
    end
end
function length_5_bits(buffer, offset)
    local first_byte = string.byte(buffer, offset)
    if first_byte ~= nil then
        return bit.band(0x1f, first_byte)
    else 
        return nil
    end
end
function length_1_byte(buffer, offset)
    local second_byte = string.byte(buffer, offset+1)
    return second_byte
end
function length_2_bytes(buffer, offset)
    local a,b = string.byte(buffer, offset+1, offset+2)
    if a ~= nil and b ~= nil then
        return bit.bor(bit.lshift(a, 8), b)
    else 
        return nil
    end
end
function length_4_bytes(buffer, offset)
    local a,b,c,d = string.byte(buffer, offset+1, offset+2, offset+3, offset+4)
    if a ~= nil and b ~= nil and c ~= nil and d ~= nil then
        return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(c, 8), d)
    else 
        return nil
    end
end

BYTE_FORMATS = {
    ["positive_fixint"] = {tagmin=0x00, tagmax=0x7f, length=0, final=true, headerlength=1},
    ["fixmap"] =   {tagmin=0x80, tagmax=0x8f, length=function(buffer) return length_4_bits(buffer)*2 end, final=false, headerlength=1},
    ["fixarray"] = {tagmin=0x90, tagmax=0x9f, length=length_4_bits, final=false, headerlength=1},
    ["fixstr"]   = {tagmin=0xa0, tagmax=0xbf, length=length_5_bits, final=true, headerlength=1},
    ["nil"]      = {tag=0xc0, length=0, final=true, headerlength=1},
    ["false"]    = {tag=0xc2, length=0, final=true, headerlength=1},
    ["true"]     = {tag=0xc3, length=0, final=true, headerlength=1},
    ["bin8"]     = {tag=0xc4, length=length_1_byte, final=true, headerlength=2},
    ["bin16"]    = {tag=0xc5, length=length_2_bytes, final=true, headerlength=3},
    ["bin32"]    = {tag=0xc6, length=length_4_bytes, final=true, headerlength=5},
    ["ext8"]     = {tag=0xc7, length=length_1_byte, final=true, headerlength=3},
    ["ext16"]    = {tag=0xc8, length=length_2_bytes, final=true, headerlength=4},
    ["ext32"]    = {tag=0xc9, length=length_4_bytes, final=true, headerlength=6},
    ["float32"]  = {tag=0xca, length=4, final=true, headerlength=1},
    ["float64"]  = {tag=0xcb, length=8, final=true, headerlength=1},
    ["uint8"]    = {tag=0xcc, length=1, final=true, headerlength=1},
    ["uint16"]   = {tag=0xcd, length=2, final=true, headerlength=1},
    ["uint32"]   = {tag=0xce, length=4, final=true, headerlength=1},
    ["uint64"]   = {tag=0xcf, length=8, final=true, headerlength=1},
    ["int8"]     = {tag=0xd0, length=1, final=true, headerlength=1},
    ["int16"]    = {tag=0xd1, length=2, final=true, headerlength=1},
    ["int32"]    = {tag=0xd2, length=4, final=true, headerlength=1},
    ["int64"]    = {tag=0xd3, length=8, final=true, headerlength=1},
    ["fixext1"]  = {tag=0xd4, length=2, final=true, headerlength=1},
    ["fixext2"]  = {tag=0xd5, length=3, final=true, headerlength=1},
    ["fixext4"]  = {tag=0xd6, length=5, final=true, headerlength=1},
    ["fixext8"]  = {tag=0xd7, length=9, final=true, headerlength=1},
    ["fixext16"] = {tag=0xd8, length=17, final=true, headerlength=1},
    ["str8"]     = {tag=0xd9, length=length_1_byte, final=true, headerlength=2},
    ["str16"]    = {tag=0xda, length=length_2_bytes, final=true, headerlength=3},
    ["str32"]    = {tag=0xdb, length=length_4_bytes, final=true, headerlength=5},
    ["array16"]  = {tag=0xdc, length=length_2_bytes, final=false, headerlength=3},
    ["array32"]  = {tag=0xdd, length=length_4_bytes, final=false, headerlength=5},
    ["map16"]    = {tag=0xde, length=function(buffer) return length_2_bytes(buffer)*2 end, final=false, headerlength=3},
    ["map32"]    = {tag=0xdf, length=function(buffer) return length_4_bytes(buffer)*2 end, final=false, headerlength=5},
    ["negative_fixint"] = {tagmin=0xe0, tagmax=0xff, length=0, final=true, headerlength=1},
}

-- A 255 elements table that maps the first byte of the buffer to either the
-- number of elements to consume, or to a function that yields that answer.
local LENGTH_DISPATCH = {}

for k, v in pairs(BYTE_FORMATS) do
    if v.tag ~= nil then
        LENGTH_DISPATCH[v.tag] = {v.length, v.final, v.headerlength}
    else 
        for i=v.tagmin,v.tagmax do
            LENGTH_DISPATCH[i] = {v.length, v.final, v.headerlength}
        end
    end
end

function M.first_element_length(buffer, offset)
    if offset == nil then
        offset = 1
    end
    if #buffer < offset then
        return false, nil -- The buffer is incomplete.
    end
    local first_byte = string.byte(buffer, offset)
    local length, isfinal, headerlength = unpack(LENGTH_DISPATCH[first_byte])
    log.trace("First element length determination. First byte = ", first_byte, " length=", length)
    local result = 0
    local success = true
    if type(length) ~= "number" then
        length = length(buffer, offset)
        success = length ~= nil
    end
    if  success then
        if isfinal then -- The length is a length in bytes
            result = length + headerlength
            success = result <= #buffer-offset+1
        else -- This is a container, the length is in elements
            log.trace("Iterating through a container.")
            result = headerlength
            buffer_position = offset + headerlength
            for i=1,length do
                local element_success, element_length = M.first_element_length(buffer, buffer_position)
                if not element_success then
                    success = false
                    break
                end
                result = result + element_length
                buffer_position = buffer_position + element_length
            end
            if success then
                success = result <= #buffer-offset+1
            end
        end
    end
    return success, result
end

function M.decode_one(buffer)
    local result = nil
    local success, length = M.first_element_length(buffer)
    if success and (length <= #buffer) then
        log.trace("Decoding for length ", length)
        local chunk = string.sub(buffer, 1, length)
        success, result = pcall(vim.mpack.decode, chunk)
    else 
        success = false
        length = 0
    end
    return success, result, length
end

return M
