-- Run from the repository root with LuaJIT: luajit tests/fms/proc_msgs_test.lua
-- The procedures' advisories (6-1/6-2 step 11c4; notes/ATA-34-61-FMC.md
-- §97; FCOM p.1435; FMSPG p.79) in the FMS module as XTLua runs it (tests/
-- lib/xtlua.lua), on the synthetic ZZAA (its YANKE1 serves 16R only, its
-- STAR BRAVO1 34L only): RUNWAY N/A FOR SID for the RTE page's RUNWAY 34L
-- with YANKE1 (the entry rejected), 16R taken; ARR N/A FOR RUNWAY for
-- BRAVO1 with the ILS16R selected and for the ILS16R with BRAVO1 (rejected),
-- ALPHA1 (all runways) taken.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("proc_msgs")
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
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
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
local function pad() return (line(14):gsub("%s+$", "")) end
local st = fms.ns.B747_fmc_route
local function rte() return fms.ns.B747_route_model.shown(st) end

-- ZZAA to ZZAA; DEPARTURES: YANKE1 (16R only)
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/clb")              -- DEP/ARR INDEX (no active route)
key("ls_key/L1")                 -- ZZAA DEPARTURES
T.check(line(5):find("^YANKE1"), "YANKE1 the second SID: " .. line(5))
key("ls_key/L2")
T.equal(rte().sid and rte().sid.name, "YANKE1", "YANKE1 selected")

-- the RTE page's RUNWAY (FMSPG p.79)
key("func_key/fpln")
enter("34L", "L2")
T.equal(pad(), "RUNWAY N/A FOR SID", "34L with YANKE1: RUNWAY N/A FOR SID")
T.check(rte().runway == nil and rte().sid.name == "YANKE1", "rejected: no runway, YANKE1 kept")
enter("16R", "L2")
T.equal(pad(), "", "16R: taken")
T.equal(rte().runway and rte().runway.ident, "RW16R", "the runway 16R")

-- ARRIVALS: the ILS16R, then BRAVO1 (34L only): ARR N/A FOR RUNWAY (FCOM p.1435)
clear()
key("func_key/clb")              -- DEP/ARR INDEX
key("ls_key/R2")                 -- ZZAA ARRIVALS
T.check(line(1):find("ZZAA ARRIVALS"), "ZZAA ARRIVALS: " .. line(1))
key("ls_key/R1")                 -- ILS16R
T.equal(rte().appr and rte().appr.id, "I16R", "ILS16R selected")
T.check(line(5):find("^BRAVO1"), "BRAVO1 the second STAR: " .. line(5))
key("ls_key/L2")
T.equal(pad(), "ARR N/A FOR RUNWAY", "BRAVO1 with the ILS16R: ARR N/A FOR RUNWAY")
T.check(rte().star == nil and rte().appr.id == "I16R", "rejected: no STAR, the ILS16R kept")
clear()
key("ls_key/L1")                 -- ALPHA1 (all runways)
T.equal(rte().star and rte().star.name, "ALPHA1", "ALPHA1 with the ILS16R: taken")

-- the other way: BRAVO1 first, then the ILS16R
key("func_key/fpln")
enter("ZZBB", "R1")
enter("ZZAA", "R1")
T.check(rte().star == nil and rte().appr == nil, "a new destination: no arrival")
key("func_key/clb")
key("ls_key/R2")
key("ls_key/L2")                 -- BRAVO1
T.equal(rte().star and rte().star.name, "BRAVO1", "BRAVO1 selected")
T.check(line(3):find("ILS16R$"), "the ILS16R at 1R: " .. line(3))
key("ls_key/R1")
T.equal(pad(), "ARR N/A FOR RUNWAY", "the ILS16R with BRAVO1: ARR N/A FOR RUNWAY")
T.check(rte().appr == nil, "rejected: no approach")
T.done()
