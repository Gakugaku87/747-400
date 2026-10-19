-- Run from the repository root with Lua 5.1 or LuaJIT.
-- APPROACH REF (B744.fms.pages.approach.lua) shows VREF for flaps 25 and 30 in whole knots, and its 1R/2R keys bring
-- them to the scratchpad as 25/xxx and 30/xxx for the FLAP/SPD entry: rounded, as the FCOM's table gives them, where
-- %3d cut the instruments' speeds to the knot below (233.4 t: VREF25 143.69 and VREF30 137.69 showed 143 and 137;
-- cckit research_vref.md). The FLAP/SPD entry takes any VREF the page offers: VREF25 is over 180 kt from 356 t and
-- VREF30 from 385 t (192 and 184 at 400 t), which 180 kt as its top rejected. The production page and handler run in
-- XTLua's namespace against mocked datarefs.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua_keysystems/init.lua")), runtime)()
local pages = read(FMS.."B744.fms.pages.lua")
local first = assert(pages:find("function fmsFunctions.setdata(fmsO,value)", 1, true))
local last = assert(pages:find("function fmsFunctions.setDref(fmsO,value)", first, true))
local _, lines = pages:sub(1, first - 1):gsub("\n", "")
local setdata = string.rep("\n", lines)..pages:sub(first, last - 1)

-- The FMC with the instruments' VREF25 (Vf25) and VREF30 (Vf30) at a gross weight
local function fmc(weight, vf25, vf30)
    local ns = runtime.create_namespace()
    ns.fmsFunctions, ns.fmsPages, ns.fmsFunctionsDefs = {}, {}, {}
    for name, value in pairs({createPage = function(name) return {name = name} end,
            find_dataref = function() return 0 end, simConfigData = {data = {SIM = {weight_display_units = "KGS"}}},
            fmsModules = {data = {flapspeed = ""}}}) do
        ns[name] = value
    end
    setfenv(assert(loadstring(read(FMS.."activepages/B744.fms.pages.approach.lua"))), ns)()
    setfenv(assert(loadstring(setdata, "@"..FMS.."B744.fms.pages.lua")), ns)()
    -- the page binds the speeds with find_dataref at load: the instruments' values over them
    ns.simDR_acf_weight_total_kg, ns.B747DR_airspeed_Vf25, ns.B747DR_airspeed_Vf30 = weight, vf25, vf30
    return ns
end

-- 233.4 t: VREF25 143.69 and VREF30 137.69 show as 144 and 138
local ns = fmc(233400, 143.69, 137.69)
local ok, page = pcall(function() return ns.fmsPages["APPROACH"]:getPage(1, "fmsL") end)
check(ok and page[3]:match("144%s*$") and page[5]:match("138%s*$"), "APPROACH REF at 233.4 t: '"
    ..tostring(ok and page[3]).."' / '"..tostring(ok and page[5]).."' (25: 144, 30: 138)")
for _, case in ipairs({{"vref1", "25/144"}, {"vref2", "30/138"}}) do
    local fmsO = {scratchpad = "", notify = ""}
    local done, err = pcall(ns.fmsFunctions.setdata, fmsO, case[1])
    check(done and fmsO.scratchpad == case[2], string.format("%s: '%s' (%s)%s", case[1], tostring(fmsO.scratchpad),
        case[2], done and "" or " "..tostring(err)))
end
-- and a value just under a whole knot stays below it: 300 t 164.0 and 157.0
ns = fmc(300000, 164.0, 157.0)
ok, page = pcall(function() return ns.fmsPages["APPROACH"]:getPage(1, "fmsL") end)
check(ok and page[3]:match("164%s*$") and page[5]:match("157%s*$"), "APPROACH REF at 300 t: '"
    ..tostring(ok and page[3]).."' / '"..tostring(ok and page[5]).."' (25: 164, 30: 157)")

-- FLAP/SPD: 25/185 (VREF25 at 380 t is 187) taken, 30/205 and 25/100 not
for _, case in ipairs({{"25/185", 185, 1, ""}, {"30/183", 183, 2, ""}, {"30/205", 0, 0, "INVALID ENTRY"},
        {"25/100", 0, 0, "INVALID ENTRY"}}) do
    ns = fmc(380000, 187, 179)
    ns.B747DR_airspeed_Vref, ns.B747DR_airspeed_VrefFlap, ns.setFMSData = 0, 0, function() end
    local fmsO = {scratchpad = case[1], notify = ""}
    local done, err = pcall(ns.fmsFunctions.setdata, fmsO, "flapspeed")
    check(done and ns.B747DR_airspeed_Vref == case[2] and ns.B747DR_airspeed_VrefFlap == case[3]
        and fmsO.notify == case[4], string.format("FLAP/SPD %s: VREF %s, flaps %s, '%s' (%d, %d, '%s')%s", case[1],
        tostring(ns.B747DR_airspeed_Vref), tostring(ns.B747DR_airspeed_VrefFlap), tostring(fmsO.notify), case[2],
        case[3], case[4], done and "" or " "..tostring(err)))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("FMC APPROACH REF tests passed: "..checks)
