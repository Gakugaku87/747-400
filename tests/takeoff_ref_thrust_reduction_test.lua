-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Exercises the production TAKEOFF REF THR REDUCTION field: FCOM shows it as
-- either a height above the departure datum or a flap setting ("FLAPS 5"),
-- and PERF FACTORS documents the 1500 FT default.  Simulator interfaces are
-- mocked; this validates page text and entry handling only.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function load_in(path, runtime, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    if first_marker then
        local first = assert(source:find(first_marker, 1, true),
            "missing marker "..first_marker)
        local last = assert(source:find(last_marker, first, true),
            "missing marker "..last_marker)
        source = source:sub(first, last-1)
    end
    setfenv(assert(loadstring(source, "@"..path)), runtime)()
end

local step = dofile(FMS.."B744.fms.step.lua")

-- Defaults copied from defaultFMSData(); setFMSData keeps each field at its
-- declared width, so a two-digit flap must still fit.
local data = {accelht="1500", thrredht="1500", thrredflap="  ",
    cg_mac="22", stab_trim="11.3"}
local runtime = setmetatable({
    print=function() end,
    fmsFunctions={},
    fmsPages={},
    fmsFunctionsDefs={},
    fmsModules={data=data},
    createPage=function(name) return {name=name} end,
    deferred_dataref=function() return 0 end,
    find_dataref=function() return 0 end,
    getFMSData=function(id) return data[id] end,
    setFMSData=function(id, value)
        data[id] = step.fixed_width(value, string.len(data[id]))
    end,
    clbderate=1,
    B747DR_airspeed_flapsRef=20,
    B747DR_airspeed_V1=999
}, {__index=_G})

load_in(FMS.."B744.fms.pages.lua", runtime,
    "function validAccelHeight(value)", "function validateMachSpeed(value)")
load_in(FMS.."B744.fms.pages.lua", runtime,
    "function fmsFunctions.setdata(fmsO,value)",
    "function fmsFunctions.setDref(fmsO,value)")
load_in(FMS.."activepages/B744.fms.pages.takeoff.lua", runtime)
-- The page rebinds flapsRef from find_dataref at load; restore the takeoff
-- flap the scenarios below assume.
runtime.B747DR_airspeed_flapsRef = 20

local function thrustReductionLine()
    return runtime.fmsPages.TAKEOFF:getSmallPage(2, "fmsL")[7]
end
local function accelHeightLine()
    return runtime.fmsPages.TAKEOFF:getSmallPage(2, "fmsL")[3]
end
local function enter(text)
    local fmsO = {id="fmsL", scratchpad=text, notify=""}
    runtime.fmsFunctions.setdata(fmsO, "thrustReductionHeight")
    return fmsO
end

-- The FCOM PERF FACTORS defaults are THR RED 1500 and ACCEL HT 1500.
equal(thrustReductionLine(), "1500FT                  ",
    "default THR REDUCTION height")
equal(accelHeightLine(), "  /1500FT               ",
    "default FLAP/ACCEL HT small-font height")

equal(enter("FLAPS 5").notify, "", "FLAPS 5 is a valid THR REDUCTION entry")
equal(thrustReductionLine(), "FLAPS 5                 ",
    "flap schedule is shown as FLAPS 5")

-- A double-digit flap must survive the field's declared width.
equal(enter("10").notify, "", "a bare flap number is accepted")
equal(thrustReductionLine(), "FLAPS 10                ",
    "two-digit flap schedule is not truncated")
-- Climb thrust is set while retracting, so the schedule must name a flap
-- position below the takeoff flap setting (flaps 20 here).
equal(enter("F20").notify, "INVALID ENTRY",
    "the thrust reduction flap must be below the takeoff flap")
equal(thrustReductionLine(), "FLAPS 10                ",
    "a rejected flap leaves the schedule unchanged")
runtime.B747DR_airspeed_flapsRef = 0
equal(enter("F20").notify, "", "the F prefix is accepted")
equal(thrustReductionLine(), "FLAPS 20                ", "F20 selects flaps 20")
runtime.B747DR_airspeed_flapsRef = 20

-- Heights are at least 400 FT, so they never collide with a flap entry.
equal(enter("800").notify, "", "a height entry is accepted")
equal(thrustReductionLine(), "800FT                   ",
    "a height entry replaces the flap schedule")
equal(step.trim(data.thrredflap), "", "a height entry clears the flap schedule")

equal(enter("300").notify, "INVALID ENTRY", "below the minimum height")
equal(enter("2").notify, "INVALID ENTRY", "flaps 2 is not a 747-400 detent")
equal(thrustReductionLine(), "800FT                   ",
    "a rejected entry leaves the field unchanged")

-- Blank scratchpad recalls the current value onto the scratchpad.
local recall = {id="fmsL", scratchpad="", notify=""}
runtime.fmsFunctions.setdata(recall, "thrustReductionHeight")
equal(recall.scratchpad, "800", "blank line select recalls the height")

local deleted = {id="fmsL", scratchpad="DELETE", notify=""}
runtime.fmsFunctions.setdata(deleted, "thrustReductionHeight")
equal(thrustReductionLine(), "1500FT                  ",
    "DELETE restores the 1500 FT default")

enter("FLAPS 5")
recall = {id="fmsL", scratchpad="", notify=""}
runtime.fmsFunctions.setdata(recall, "thrustReductionHeight")
equal(recall.scratchpad, "FLAPS 5", "blank line select recalls the flap schedule")

-- FLAP/ACCEL HT still takes a flap, a height, or both.
local accel = {id="fmsL", scratchpad="20/2000", notify=""}
runtime.fmsFunctions.setdata(accel, "takeoffFlapAccel")
equal(accel.notify, "", "combined flap and acceleration height entry")
equal(runtime.B747DR_airspeed_flapsRef, 20, "takeoff flap is stored")
equal(accelHeightLine(), "  /2000FT               ",
    "acceleration height entry is displayed")
equal(runtime.fmsPages.TAKEOFF:getPage(2, "fmsL")[3]:sub(1, 2), "20",
    "takeoff flap is displayed in large font on FLAP/ACCEL HT")

print("TAKEOFF REF thrust reduction tests passed: "..checks)
