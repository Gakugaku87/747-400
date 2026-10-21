-- Run from the repository root with Lua 5.1 or LuaJIT.
-- APPROACH REF (B744.fms.pages.approach.lua) shows VREF for flaps 25 and 30 in whole knots, and its 1R/2R keys bring
-- them to the scratchpad as 25/xxx and 30/xxx for the FLAP/SPD entry: rounded, as the FCOM's table gives them, where
-- %3d cut the instruments' speeds to the knot below (233.4 t: VREF25 143.69 and VREF30 137.69 showed 143 and 137;
-- cckit research_vref.md). The FLAP/SPD entry takes any VREF the page offers: VREF25 is over 180 kt from 356 t and
-- VREF30 from 385 t (192 and 184 at 400 t), which 180 kt as its top rejected. The production page and handler run in
-- XTLua's namespace against mocked datarefs.
-- The VREFs are for the landing airport: the FCOM's table (PI.10.2) is for sea level, "Increase VREF 1 knot/4000 ft
-- above sea level" (none below it). The FMC takes the destination's (RTE DEST) elevation as the highest landing
-- threshold of its runways in X-Plane's CIFP (Custom Data first, then the default data), read once for each
-- destination; without a destination or a file the VREFs are the sea level ones, as before. The instruments' VREFs
-- (the flap bugs, VNAV, autoland) stay the gross weight's.
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
-- a source's slice from first to last (not included), on its own line numbers
local function slice(source, first_marker, last_marker)
    local first = source:find(first_marker, 1, true)
    local last = first and source:find(last_marker, first, true)
    if last == nil then return nil end
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1)
end

local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua_keysystems/init.lua")), runtime)()
local setdata = assert(slice(read(FMS.."B744.fms.pages.lua"), "function fmsFunctions.setdata(fmsO,value)",
    "function fmsFunctions.setDref(fmsO,value)"))
-- the FMC's landing airport elevation and VREF (B747.68.xt.fms.lua), from its locals to the next function
local landing = slice(read(FMS.."B747.68.xt.fms.lua"), "-- [P36] The landing airport's elevation",
    "function getFMSData(id)")
check(landing ~= nil, "B747.68.xt.fms.lua: the landing airport's elevation and VREF")
local performance = dofile(FMS.."B744.fms.performance.lua")

-- X-Plane's CIFP runway records (2610), CRLF as X-Plane's files
local SID = "SID:010,5,DEN6,ALL,DEN,K2,D, ,V,  , , , ,IF, ,,,,,,,,,,,,,,,,,,,,,,;"
local function cifp(records) return SID.."\r\n"..table.concat(records, "\r\n").."\r\n" end
local KDEN = cifp({
    "RWY:RW07 ,     ,      ,05350, ,IDZG,1,   ;N39502740,W104433596,0000;",
    "RWY:RW08 ,     ,      ,05354, ,IFUI,1,   ;N39523920,W104394403,0000;",
    "RWY:RW26 ,     ,      ,05294, ,IJOY,1,   ;N39523808,W104371015,0000;",
    "RWY:RW35L,     ,      ,05434, ,IAQD,3,   ;N39494193,W104393798,0000;",
    "RWY:RW35R,     ,      ,05370, ,IDPP,3,   ;N39495527,W104383016,0000;"})
local MMMX = cifp({
    "RWY:RW05L,     ,      ,07292, ,    , ,   ;N19254706,W099051201,1476;",
    "RWY:RW05R,     ,      ,07289, ,IMWX,1,   ;N19254479,W099045565,1877;"})
local EHAM = cifp({
    "RWY:RW04 ,     ,      ,-0013, ,    , ,   ;N52180135,E004470055,0000;",
    "RWY:RW06 ,     ,      ,-0011, ,KAG ,3,   ;N52172078,E004441401,0801;",
    "RWY:RW18R,+0010,      ,-0013, ,VPB ,3,   ;N52213693,E004424221,0886;"})

-- the correction: 1 kt per 4,000 ft above sea level, none below it
for _, case in ipairs({{0, 0}, {4000, 1}, {5434, 1.3585}, {-13, 0}, {nil, 0}}) do
    local ok, value = pcall(function() return performance.vref_elevation_correction_kts(case[1]) end)
    check(ok and math.abs(value - case[2]) < 1e-9, string.format("elevation %s ft: %s kt (%s)", tostring(case[1]),
        tostring(value), tostring(case[2])))
end
-- the airport's elevation: the highest landing threshold of its RWY records (the CIFP's fourth field)
for _, case in ipairs({{"KDEN", KDEN, 5434}, {"MMMX", MMMX, 7292}, {"EHAM", EHAM, -11},
        {"no RWY record", SID.."\r\n", nil}}) do
    local ok, value = pcall(function() return performance.cifp_airport_elevation_ft(case[2]) end)
    check(ok and value == case[3], string.format("%s: %s ft (%s)", case[1], tostring(value), tostring(case[3])))
end

-- The FMC with the instruments' VREF25 (Vf25) and VREF30 (Vf30) at a gross weight, the RTE's destination and
-- X-Plane's CIFP files (path -> text); opened lists the files the FMC opened
local function fmc(weight, vf25, vf30, destination, files)
    local ns = runtime.create_namespace()
    ns.fmsFunctions, ns.fmsPages, ns.fmsFunctionsDefs = {}, {}, {}
    local opened = {}
    local function open(path)
        opened[#opened + 1] = path
        local text = (files or {})[path]
        if text == nil then return nil end
        return {read = function() return text end, close = function() end}
    end
    for name, value in pairs({createPage = function(name) return {name = name} end,
            find_dataref = function() return 0 end, simConfigData = {data = {SIM = {weight_display_units = "KGS"}}},
            fmsModules = {data = {flapspeed = "", fltdst = destination or "****"}}, fmsPerformance = performance,
            io = {open = open}}) do
        ns[name] = value
    end
    if landing ~= nil then setfenv(assert(loadstring(landing, "@"..FMS.."B747.68.xt.fms.lua")), ns)() end
    setfenv(assert(loadstring(read(FMS.."activepages/B744.fms.pages.approach.lua"))), ns)()
    setfenv(assert(loadstring(setdata, "@"..FMS.."B744.fms.pages.lua")), ns)()
    -- the page binds the speeds with find_dataref at load: the instruments' values over them
    ns.simDR_acf_weight_total_kg, ns.B747DR_airspeed_Vf25, ns.B747DR_airspeed_Vf30 = weight, vf25, vf30
    return ns, opened
end
-- the page's two VREFs and the 1R/2R scratchpads
local function approach_ref(ns)
    local ok, page = pcall(function() return ns.fmsPages["APPROACH"]:getPage(1, "fmsL") end)
    local shown = ok and {page[3]:match("(%d+)%s*$"), page[5]:match("(%d+)%s*$")} or {tostring(page), ""}
    for _, key in ipairs({"vref1", "vref2"}) do
        local fmsO = {scratchpad = "", notify = ""}
        local done, err = pcall(ns.fmsFunctions.setdata, fmsO, key)
        shown[#shown + 1] = done and fmsO.scratchpad or tostring(err)
    end
    return table.concat(shown, " ")
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

-- The landing airport's elevation at 300 t (VREF25 164.0, VREF30 157.0): KDEN 5,434 ft +1.36 kt (Custom Data),
-- MMMX 7,292 ft +1.82 kt (the default data when Custom Data has none), EHAM -11 ft none, no destination, and a
-- destination without a CIFP file. Each destination's files are looked up once (Custom Data, then the default data),
-- however often the pages ask.
local custom, default = "Custom Data/CIFP/", "Resources/default data/CIFP/"
for _, case in ipairs({
        {"KDEN", {[custom.."KDEN.dat"] = KDEN}, "165 158 25/165 30/158", 5434, 1},
        {"MMMX", {[default.."MMMX.dat"] = MMMX}, "166 159 25/166 30/159", 7292, 2},
        {"EHAM", {[custom.."EHAM.dat"] = EHAM}, "164 157 25/164 30/157", -11, 1},
        {"****", {[custom.."KDEN.dat"] = KDEN}, "164 157 25/164 30/157", nil, 0},
        {"ZZZZ", {}, "164 157 25/164 30/157", nil, 2}}) do
    local opened
    ns, opened = fmc(300000, 164.0, 157.0, case[1], case[2])
    local shown = approach_ref(ns)
    check(shown == case[3], string.format("APPROACH REF at %s: %s (%s)", case[1], shown, case[3]))
    local elevation_ok, elevation = pcall(function() return ns.B747_destination_elevation_ft() end)
    check(elevation_ok and elevation == case[4], string.format("%s's elevation: %s (%s)", case[1],
        tostring(elevation), tostring(case[4])))
    local opens = #opened
    check(opens == case[5], string.format("%s: %d files opened (%d): %s", case[1], opens, case[5],
        table.concat(opened, ", ")))
end
-- a new destination is read again: KDEN, then EHAM
ns = fmc(300000, 164.0, 157.0, "KDEN", {[custom.."KDEN.dat"] = KDEN, [custom.."EHAM.dat"] = EHAM})
local before = approach_ref(ns)
ns.fmsModules.data.fltdst = "EHAM"
local after = approach_ref(ns)
check(before == "165 158 25/165 30/158" and after == "164 157 25/164 30/157", "KDEN then EHAM: "..before.." / "
    ..after.." (165 158 25/165 30/158 / 164 157 25/164 30/157)")
-- the instruments' VREFs stay the gross weight's
check(ns.B747DR_airspeed_Vf25 == 164.0 and ns.B747DR_airspeed_Vf30 == 157.0, "instruments' VREF25/VREF30: "
    ..tostring(ns.B747DR_airspeed_Vf25).."/"..tostring(ns.B747DR_airspeed_Vf30).." (164/157)")

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
