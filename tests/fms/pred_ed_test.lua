-- Run from the repository root with LuaJIT: luajit tests/fms/pred_ed_test.lua
-- The predictions' E/D on a route without procedures (notes/ATA-34-61-FMC.md
-- §108) in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic data (ZZAA to ZZBB via BRAVO, CHARL, DELTA): a constraint in
-- the route's first half is the climb's, not the E/D (before, the last
-- constraint anywhere was: one 20 NM out on the climb made the T/D before
-- it, s185), so the CLB page shows it with its ERROR; one in the second
-- half is the E/D.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("pred_ed")
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
rt:set("sim/flightmodel/weight/m_total", 250000)
rt:set("sim/flightmodel/weight/m_fuel_total", 40000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
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
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function pad() return (line(14):gsub("%s+$", "")) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end

-- no route: no predictions

-- a route without procedures: ZZAA to ZZBB via BRAVO, CHARL and DELTA;
-- CRZ ALT FL350; in the air at 11,000 ft south of BRAVO
key("func_key/index")
enter("100", "L5")
enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("func_key/next_pg")
enter("BRAVO", "R1")
enter("CHARL", "R2")
enter("DELTA", "R3")
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1)
T.check(fms.ns.B747_fmc_route.active, "the route active")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/flightmodel/position/latitude", 35.7)
rt:set("sim/flightmodel/position/longitude", 140.5)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 11000)
local function idx(name)
    for i, l in ipairs(fms.ns.B747_fmc_route.rte.legs) do
        if l.fix and l.fix.ident == name then return i end
    end
end
local function legs_row(name)
    key("func_key/legs")
    for n = 1, 5 do
        if line(2 * n + 1):find("^" .. name) then return n end
    end
end
-- AT OR ABOVE FL300 at BRAVO (about 18 NM out, the route's first half): a
-- climb constraint, not the E/D (before, the predictions took it as the
-- E/D, the T/D before it: s185); the CLB page's AT BRAVO and ERROR
local row = legs_row("BRAVO")
T.check(row ~= nil, "BRAVO on LEGS")
enter("/30000A", "R" .. row)
key("key/execute")
frames(12)
local s = fms.ns.B747_fms_pred_input(35000)
T.equal(s.ed, nil, "BRAVO's constraint in the route's first half: no E/D")
local r = fms.ns.B747_fms_preds()
T.check(r and r.tc and r.tc > r.pts[idx("BRAVO")].x, "a T/C after BRAVO: " .. tostring(r and r.tc))
T.equal(r.td, nil, "no T/D (no E/D)")
key("func_key/des")
T.check(small(2):find("AT BRAVO$"), "CLB: AT BRAVO: " .. small(2))
T.check(line(3):find("/FL300A$"), "/FL300A: " .. line(3))
T.check(line(5):find("%d+LO %d+LONG$"), "the ERROR: " .. line(5))
-- in the cruise (FL350) BRAVO's constraint is the descent's: the E/D (as
-- before; the first half's rule only in the climb)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
frames(1)
T.equal(fms.ns.B747_fms_vnav_phase(), "CRZ", "at FL350 the cruise")
s = fms.ns.B747_fms_pred_input(35000)
T.equal(s.ed, idx("BRAVO"), "in the cruise BRAVO's constraint: the E/D")
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 11000)
frames(1)
-- AT 10000 at DELTA (the route's second half): the E/D
row = legs_row("DELTA")
T.check(row ~= nil, "DELTA on LEGS")
enter("/10000", "R" .. row)
key("key/execute")
frames(12)
s = fms.ns.B747_fms_pred_input(35000)
T.equal(s.ed, idx("DELTA"), "DELTA's constraint in the second half: the E/D")

T.done()
