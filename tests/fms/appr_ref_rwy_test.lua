-- Run from the repository root with LuaJIT: luajit tests/fms/appr_ref_rwy_test.lua
-- APPROACH REF's runway length line (4L; 2026-11-19, notes/ATA-34-61-FMC.md
-- §170 1; FCOM p.1409-1411) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), from the synthetic ZZAA (RW34L, RW16R) to ZZBB
-- (RW09, its other end RW27 put in here): blank without an active route
-- or a departure runway; the departure runway's (header "ZZAA34L", the
-- length in FT and M as REF NAV DATA's); still the departure's with the
-- destination's approach selected near the origin, and far out without
-- one; the destination runway's once its approach is in the route and the
-- airplane is more than 50 NM from the departure airport or past halfway;
-- blank after the flight completion. Before: fixed boxes.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("appr_ref_rwy")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function at(lat, lon)
    rt:set("sim/flightmodel/position/latitude", lat)
    rt:set("sim/flightmodel/position/longitude", lon)
    frames(0.5)
end
local function approach_ref()
    key("func_key/index")
    if not line(1):find("APPROACH REF", 1, true) then
        key("ls_key/L6")         -- INIT/REF INDEX (the INIT REF key goes by context)
        key("ls_key/L6")         -- <APPROACH
    end
    T.check(line(1):find("APPROACH REF", 1, true) ~= nil, "APPROACH REF: " .. line(1))
end
local N, db = fms.ns.B747_navdb, fms.ns.B747_fmc_navdb
-- the length line's text for a runway: big digits, FT and M small
local function length_of(icao, id)
    local ft = N.runway_length(N.cifp(db, icao), id)
    return math.floor(ft + 0.5), math.floor(ft * 0.3048 + 0.5)
end
local function shows(hdr, icao, id, what)
    local ft, m = length_of(icao, id)
    local big = ft .. "  " .. m
    T.equal(small(8):sub(1, 14), " " .. string.format("%-13s", hdr), what .. ": the header " .. hdr)
    T.equal(small(8):sub(15), "FLAP/SPEED", what .. ": FLAP/SPEED kept")
    T.equal(line(9):sub(1, #big), big, what .. ": " .. big .. " (" .. line(9) .. ")")
    T.check(line(9):find("%-%-/%-%-%-$") ~= nil, what .. ": FLAP/SPEED's dashes at the end: " .. line(9))
    local units = string.rep(" ", #tostring(ft)) .. "FT" .. string.rep(" ", #tostring(m)) .. "M"
    T.equal(small(9):sub(1, #units), units, what .. ": FT and M small after the numbers")
end
local function blank(what)
    T.equal(small(8), "              FLAP/SPEED", what .. ": no header (" .. small(8) .. ")")
    T.check(not line(9):find("[%d%*]"), what .. ": no length nor boxes: " .. line(9))
    T.check(not small(9):find("%S"), what .. ": no FT, M: " .. small(9))
end

-- RW09's other end, for its length (the synthetic data has one end)
local bb = N.cifp(db, "ZZBB")
bb.runways.RW27 = {ident = "RW27", lat = 36.0, lon = 140.98, elev = 50, displaced = 0}
local ft09 = length_of("ZZBB", "RW09")
T.check(ft09 > 8000 and ft09 < 10000, "RW09's length from its other end: " .. ft09 .. " ft")

-- no active route: blank (before: boxes)
approach_ref()
blank("no active route")

-- ZZAA to ZZBB active, no runway yet: blank; RW34L: the departure runway's
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1.2)
T.check(fms.ns.B747_fmc_route.active, "the route active")
approach_ref()
blank("an active route without a runway")
key("func_key/clb")              -- DEPARTURES (the ground, an active route)
key("ls_key/R2")                 -- 34L
key("key/execute")
frames(0.5)
T.equal(fms.ns.B747_fmc_route.rte.runway and fms.ns.B747_fmc_route.rte.runway.ident, "RW34L", "the runway 34L active")
approach_ref()
shows("ZZAA34L", "ZZAA", "RW34L", "the departure runway")
local ft34, m34 = length_of("ZZAA", "RW34L")
T.check(ft34 > 10000 and ft34 < 11500 and math.abs(m34 - ft34 * 0.3048) < 1, "34L's length with its displaced threshold: " .. ft34 .. " ft " .. m34 .. " m")

-- in the air near the origin with ZZBB's approach selected: still the
-- departure's (neither 50 NM out nor halfway)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
at(35.2, 140.2)                  -- 15 NM from ZZAA, 62 to ZZBB
key("func_key/clb")              -- ARRIVALS (the air, an active route)
T.check(line(1):find("ZZBB ARRIVALS", 1, true) ~= nil, "ZZBB ARRIVALS: " .. line(1))
key("ls_key/R1")                 -- the approach R09
key("key/execute")
frames(0.5)
T.equal(fms.ns.B747_fmc_route.rte.appr and fms.ns.B747_fmc_route.rte.appr.rwy, "RW09", "the approach to RW09 active")
approach_ref()
shows("ZZAA34L", "ZZAA", "RW34L", "15 NM out with the approach")
at(35.45, 140.45)                -- 35 NM from ZZAA, 43 to ZZBB
shows("ZZAA34L", "ZZAA", "RW34L", "35 NM out, short of halfway")

-- past halfway inside 50 NM, and beyond 50 NM short of halfway: the
-- destination runway's (FCOM p.1411)
at(35.55, 140.55)                -- 43 NM from ZZAA, 35 to ZZBB
shows("ZZBB09", "ZZBB", "RW09", "past halfway inside 50 NM")
at(34.2, 139.2)                  -- 62 NM from ZZAA (away from ZZBB), 139 to ZZBB
shows("ZZBB09", "ZZBB", "RW09", "more than 50 NM out, short of halfway")
at(35.7, 140.7)                  -- 54 NM from ZZAA, 23 to ZZBB
shows("ZZBB09", "ZZBB", "RW09", "54 NM out past halfway")

-- no approach in the active route: the departure's again (FCOM: until the
-- destination runway or approach is in the active route)
fms.ns.B747_fmc_route.rte.appr = nil
frames(0.3)
shows("ZZAA34L", "ZZAA", "RW34L", "54 NM out, no approach in the route")

-- the flight completion: the route gone, the line blank
fms.ns.B747_fms_flight_complete()
frames(1.2)
approach_ref()
blank("after the flight completion")
T.done()
