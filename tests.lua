-- This test can only be run in Lua 5.3 or later, because it has string.pack and string.unpack
local xser = require("xser")
local serialise, deserialise = xser.serialise, xser.deserialise
local format, pack, unpack = string.format, string.pack, string.unpack
local write = io.write
local xtest = require("xtest")

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

local function printBytes(bytes)
    write("\"")
    for i = 1, #bytes do
        write("\\" .. tostring(bytes:byte(i)))
    end
    write("\"\n")
end

xtest.run{
    "nil (de)serialization",
    function()
        xtest.assertEq("\0", serialise(nil))
        xtest.assertEq(nil, deserialise("\0"))
    end,
    "number (de)serialization",
    function()
        -- u8
        xtest.assertEq(TYPE_U8 .. "\0", serialise(0))
        xtest.assertEq(0, deserialise(TYPE_U8 .. "\0"))
        xtest.assertEq(TYPE_U8 .. "\255", serialise(255))
        xtest.assertEq(255, deserialise(TYPE_U8 .. "\255"))
        -- u16
        xtest.assertEq(TYPE_U16 .. "\0\1", serialise(256))
        xtest.assertEq(256, deserialise(TYPE_U16 .. "\0\1"))
        xtest.assertEq(30000, deserialise(TYPE_U16 .. "0u"))
        xtest.assertEq(TYPE_U16 .. "\255\255", serialise(65535))
        -- u32
        xtest.assertEq(TYPE_U32 .. "\0\0\1\0", serialise(65536))
        xtest.assertEq(65536, deserialise(TYPE_U32 .. "\0\0\1\0"))
        xtest.assertEq(TYPE_U32 .. "\255\255\255\255", serialise(4294967295))
        xtest.assertEq(4294967295, deserialise(TYPE_U32 .. "\255\255\255\255"))
        -- u64 cannot be represented in lua
        -- i8
        xtest.assertEq(TYPE_I8 .. "\255", serialise(-1))
        xtest.assertEq(-1, deserialise(TYPE_I8 .. "\255"))
        xtest.assertEq(TYPE_I8 .. "\128", serialise(-128))
        xtest.assertEq(-128, deserialise(TYPE_I8 .. "\128"))
        -- i16
        xtest.assertEq(TYPE_I16 .. "\127\255", serialise(-129))
        xtest.assertEq(-129, deserialise(TYPE_I16 .. "\127\255"))
        xtest.assertEq(TYPE_I16 .. "\0\128", serialise(-32768))
        xtest.assertEq(-32768, deserialise(TYPE_I16 .. "\0\128"))
        -- i32
        xtest.assertEq(TYPE_I32 .. "\255\127\255\255", serialise(-32769))
        xtest.assertEq(-32769, deserialise(TYPE_I32 .. "\255\127\255\255"))
        xtest.assertEq(TYPE_I32 .. "\0\0\0\128", serialise(-2147483648))
        xtest.assertEq(-2147483648, deserialise(TYPE_I32 .. "\0\0\0\128"))
        -- i64 cannot be represented in lua
        -- f64
        xtest.assertEq(TYPE_F64 .. "\0\0\0\0\0\0\224\63", serialise(0.5))
        xtest.assertEq(0.5, deserialise(TYPE_F64 .. "\0\0\0\0\0\0\224\63"))
        xtest.assertEq(TYPE_F64 .. "\0\0\0\0\0\0\224\191", serialise(-0.5))
        xtest.assertEq(-0.5, deserialise(TYPE_F64 .. "\0\0\0\0\0\0\224\191"))
        write"pi = "
        printBytes(serialise(3.14))
        xtest.assertEq(TYPE_F64 .. "\31\133\235\81\184\30\9\64", serialise(3.14))
        xtest.assertEq(3.14, deserialise(TYPE_F64 .. "\31\133\235\81\184\30\9\64"))
        local googol = 10 ^ 100
        write"googol = "
        printBytes(serialise(googol))
        xtest.assertEq(TYPE_F64 .. "\125\195\148\37\173\73\178\84", serialise(googol))
        xtest.assertEq(googol, deserialise(TYPE_F64 .. "\125\195\148\37\173\73\178\84"))
        googol = -googol
        write"-googol = "
        printBytes(serialise(googol))
        xtest.assertEq(TYPE_F64 .. "\125\195\148\37\173\73\178\212", serialise(googol))
        xtest.assertEq(googol, deserialise(TYPE_F64 .. "\125\195\148\37\173\73\178\212"))
    end,
    "string (de)serialization",
    function()
        xtest.assertEq(TYPE_CSTRING .. "\0", serialise(""))
        xtest.assertEq("", deserialise(TYPE_CSTRING .. "\0"))
        xtest.assertEq(TYPE_CSTRING .. "Hello, world!\0", serialise("Hello, world!"))
        xtest.assertEq("Hello, world!", deserialise(TYPE_CSTRING .. "Hello, world!\0"))
        -- A string containing null bytes cannot be terminated with a null byte, so we instead provide a 4 byte length    
        xtest.assertEq(TYPE_STRING .. "\1\0\0\0\0", serialise("\0"))
    end,
    "boolean (de)serialization",
    function()
        xtest.assertEq(TYPE_BOOL_FALSE, serialise(false))
        xtest.assertEq(false, deserialise(TYPE_BOOL_FALSE))
        xtest.assertEq(TYPE_BOOL_TRUE, serialise(true))
        xtest.assertEq(true, deserialise(TYPE_BOOL_TRUE))
    end,
    "table (de)serialization",
    function()
        xtest.assertEq(TYPE_TABLE_EMPTY, serialise({}))
        xtest.assertShallowEq({}, deserialise(TYPE_TABLE_EMPTY))
        write"array = "
        printBytes(serialise({1, 2, 3, 4, 5}))
        xtest.assertShallowEq({1, 2, 3, 4, 5}, deserialise(serialise({1, 2, 3, 4, 5})))
        write"map = "
        printBytes(serialise({a = 1, b = 2, c = 3, d = 4, e = 5}))
        xtest.assertShallowEq({a = 1, b = 2, c = 3, d = 4, e = 5}, deserialise(serialise({a = 1, b = 2, c = 3, d = 4, e = 5})))
        local mapArray = {1, 2, 3, d = 4, e = 5, f = 6}
        write"map array = "
        printBytes(serialise(mapArray))
        xtest.assertShallowEq(mapArray, deserialise(serialise(mapArray)))
    end
}