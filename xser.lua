local TYPE_NIL = "\0"
local TYPE_U8 = "\1"
local TYPE_I8 = "\2"
local TYPE_U16 = "\3"
local TYPE_I16 = "\4"
local TYPE_U32 = "\5"
local TYPE_I32 = "\6"
local TYPE_U64 = "\7"
local TYPE_I64 = "\8"
local TYPE_F64 = "\9"
local TYPE_BOOL_FALSE = "\10"
local TYPE_BOOL_TRUE = "\11"
local TYPE_STRING = "\12"
local TYPE_CSTRING = "\13"
local TYPE_TABLE_EMPTY = "\14"
local TYPE_TABLE_ARRAY = "\15"
local TYPE_TABLE_MAP = "\16"
local TYPE_TABLE_ARRAY_MAP = "\17"

local pack, unpack, next, concat, sub, find, pairs = string.pack, string.unpack, next, table.concat, string.sub, string.find, pairs

--- Serialises a Lua value into a binary string that can be deserialised with `xser.unserialise`
---@param value nil|number|boolean|string|boolean|table the value to serialise
---@return string bin a binary string that replesents the serialised value
local function serialise(value)
    if type(value) == "nil" then
        return TYPE_NIL
    elseif type(value) == "number" then
        -- check if it's a floating point number
        if math.floor(value) ~= value then
            return TYPE_F64 .. pack("<d", value)
        end

        if value >= 0 then -- unsigned numbers
            if value <= 255 then
                return TYPE_U8 .. pack("<B", value)
            elseif value <= 65535 then
                return TYPE_U16 .. pack("<H", value)
            elseif value <= 4294967295 then
                return TYPE_U32 .. pack("<I", value)
            else -- 64 bit numbers cannot be represented in lua, so we use a double
                return TYPE_F64 .. pack("<d", value)
            end
        else -- signed numbers
            if value >= -128 then
                return TYPE_I8 .. pack("<b", value)
            elseif value >= -32768 then
                return TYPE_I16 .. pack("<h", value)
            elseif value >= -2147483648 then
                return TYPE_I32 .. pack("<i", value)
            else -- 64 bit numbers cannot be represented in lua, so we use a double
                return TYPE_F64 .. pack("<d", value)
            end
        end
    elseif type(value) == "boolean" then
        return value and TYPE_BOOL_TRUE or TYPE_BOOL_FALSE
    elseif type(value) == "string" then
        if find(value, "\0") then
            return TYPE_STRING .. pack("<s4", value)
        else
            return TYPE_CSTRING .. pack("z", value)
        end
    elseif type(value) == "table" then
        -- check empty table
        if next(value) == nil then return TYPE_TABLE_EMPTY end

        local buffer, k, v
        -- check only array
        if #value == 0 then -- this is a map
            buffer = {TYPE_TABLE_MAP}
            k, v = next(value)
            while k do
                buffer[#buffer+1] = serialise(k)
                buffer[#buffer+1] = serialise(v)
                k, v = next(value, k)
            end
            buffer[#buffer+1] = "\0"
            return concat(buffer)

        elseif next(value, #value) == nil then -- this is an array
            buffer = {TYPE_TABLE_ARRAY}
            for i=1, #value do
                buffer[#buffer+1] = serialise(value[i])
            end
            buffer[#buffer+1] = "\0"
            return concat(buffer)

        else -- this is an array and a map
            buffer = {TYPE_TABLE_ARRAY_MAP}
            for i=1, #value do
                buffer[#buffer+1] = serialise(value[i])
            end
            buffer[#buffer+1] = "\0"
            k, v = next(value, #value)
            while k do
                buffer[#buffer+1] = serialise(k)
                buffer[#buffer+1] = serialise(v)
                k, v = next(value, k)
            end
            buffer[#buffer+1] = "\0"
            return concat(buffer)
        end
    else
        error("Unsupported type: " .. type(value))
    end
end

--- Deserialises a binary string into a Lua value
--- @param bin string the binary string to deserialise
--- @param pos? number the position in the binary string to start deserialising from
--- @return nil|number|boolean|string|table value the deserialised valueany|nil value the deserialised value
--- @return integer pos the position in the binary string after deserialising
local function deserialise(bin, pos)
    pos = pos or 1
    local type = sub(bin, pos, pos)

    -- deserialise nil
    if type == TYPE_NIL then
        return nil, pos + 1

    -- deserialise numbers
    elseif type == TYPE_U8 then
        return unpack("<B", sub(bin, pos + 1)), pos + 2
    elseif type == TYPE_I8 then
        return unpack("<b", sub(bin, pos + 1)), pos + 2
    elseif type == TYPE_U16 then
        return unpack("<H", sub(bin, pos + 1)), pos + 3
    elseif type == TYPE_I16 then
        return unpack("<h", sub(bin, pos + 1)), pos + 3
    elseif type == TYPE_U32 then
        return unpack("<I", sub(bin, pos + 1)), pos + 5
    elseif type == TYPE_I32 then
        return unpack("<i", sub(bin, pos + 1)), pos + 5
    elseif type == TYPE_U64 then
        return unpack("<J", sub(bin, pos + 1)), pos + 9
    elseif type == TYPE_I64 then
        return unpack("<j", sub(bin, pos + 1)), pos + 9
    elseif type == TYPE_F64 then
        return unpack("<d", sub(bin, pos + 1)), pos + 9

    -- deserialise booleans
    elseif type == TYPE_BOOL_FALSE then
        return false, pos + 1
    elseif type == TYPE_BOOL_TRUE then
        return true, pos + 1

    -- deserialise strings
    elseif type == TYPE_STRING then
        local str, len = unpack("<s4", bin, pos + 1)
        return str, pos + len + 1
    elseif type == TYPE_CSTRING then
        local str, len = unpack("z", bin, pos + 1)
        return str, pos + len + 1

    -- deserialise tables
    elseif type == TYPE_TABLE_EMPTY then
        return {}, pos + 1
    elseif type == TYPE_TABLE_ARRAY then
        pos = pos + 1
        local array = {}
        while sub(bin, pos, pos) ~= "\0" do
            array[#array+1], pos = deserialise(bin, pos)
        end
        return array, pos
    elseif type == TYPE_TABLE_MAP then
        pos = pos + 1
        local map = {}
        local k
        while sub(bin, pos, pos) ~= TYPE_NIL do
            k, pos = deserialise(bin, pos)
            ---@diagnostic disable-next-line: need-check-nil
            map[k], pos = deserialise(bin, pos)
        end
        return map, pos
    elseif type == TYPE_TABLE_ARRAY_MAP then
        pos = pos + 1
        local arrayMap = {}
        while sub(bin, pos, pos) ~= TYPE_NIL do
            arrayMap[#arrayMap+1], pos = deserialise(bin, pos)
        end
        pos = pos + 1
        local k
        while sub(bin, pos, pos) ~= TYPE_NIL do
            k, pos = deserialise(bin, pos)
            ---@diagnostic disable-next-line: need-check-nil
            arrayMap[k], pos = deserialise(bin, pos)
        end
        return arrayMap, pos
    else
        error("Unrecognised type byte: " .. type:byte() .. " at position " .. pos)
    end
end

return {
    serialise = serialise,
    serialize = serialise,
    deserialise = deserialise,
    deserialize = deserialise
}