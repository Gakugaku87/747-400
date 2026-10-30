-- Run from the repository root with LuaJIT: luajit tests/fms/pred_glue_test.lua
-- The FMC's trajectory predictions in the FMS module (6-1/6-2 step 8c;
-- notes/ATA-34-61-FMC.md §47) as XTLua runs it (tests/lib/xtlua.lua), on
-- the synthetic CIFP of ZZAA: the active route's legs ahead with their
-- distances and constraints, the E/D at the approach's runway (50 ft above
-- it: FCOM p.1258), the SID's constraints the climb's, the predictions'
-- T/D and destination on the CRZ page, UNABLE CRZ ALT for a cruise
-- altitude the short route cannot reach (FCOM p.1436), none without an
-- active route or with CRZ ALT above MAX (ATA34_2 p.611).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("pred_glue")
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 250000)
rt:set("sim/flightmodel/weight/m_fuel_total", 40000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
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
key("func_key/index")
enter("100", "L5")
enter("350", "R1")
frames(11)
T.equal(fms.ns.B747_fms_preds(), nil, "no active route: no predictions")

-- the route: ZZAA to ZZAA, DIRECT ALPHA, DELTA; ZULU1 from 34L by ALPHA;
-- ALPHA1 by DELTA to the ILS 16R; ACTIVATE and EXEC
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("DELTA", "R2")
key("func_key/clb")
key("ls_key/L1")                 -- DEPARTURES
key("ls_key/L1")                 -- ZULU1
key("ls_key/R2")                 -- 34L
key("ls_key/L2")                 -- ALPHA
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")                 -- ARRIVALS
key("ls_key/L1")                 -- ALPHA1
key("ls_key/L2")                 -- DELTA
key("ls_key/R1")                 -- ILS16R
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1)
T.check(fms.ns.B747_fmc_route.active, "the route active")

-- the predictions' input and result
local s = fms.ns.B747_fms_pred_input(35000)
local legs = fms.ns.B747_fmc_route.rte.legs
T.equal(#s.legs, #legs, "every leg ahead (" .. #legs .. ")")
local rwy, sid, star = nil, 0, false
for i, l in ipairs(legs) do
    if l.fix and l.fix.kind == "RWY" and l.proc ~= "SID" then rwy = i end
    if l.proc == "SID" then sid = i end
end
T.equal(s.ed, rwy, "the E/D: the approach's runway leg (" .. tostring(rwy) .. ")")
T.near(s.legs[rwy].con.a, (legs[rwy].fix.elev or 0) + 50, 1e-6, "its altitude 50 ft above the threshold")
T.equal(s.clb_last, sid, "the climb's legs the SID's (" .. sid .. ")")
local fixed = true
for i, l in ipairs(legs) do
    local prev = legs[i - 1] and legs[i - 1].fix
    local same = prev and l.fix and prev.ident == l.fix.ident
    if l.fix and i > 1 and not same and not (s.legs[i].dist > 0) then fixed = false end
end
T.check(fixed, "each leg with a point: its distance from the one before")
local total = 0
for _, l in ipairs(s.legs) do total = total + l.dist end
T.check(total > 20 and total < 400, string.format("the route %.0f NM", total))
T.check(s.clb.cas > 0 and s.des.cas > 0 and s.crzspd.mach, "the speeds from the FMC's data")

-- UNABLE CRZ ALT: at 390 t the route cannot reach FL320 (MAX FL326)
-- before its descent
rt:set("sim/flightmodel/weight/m_total", 390000)
key("func_key/index")
enter("320", "R1")
T.equal(pad(), "UNABLE CRZ ALT", string.format("CRZ ALT FL320 at 390 t over %.0f NM: UNABLE CRZ ALT", total))
clear()
frames(11)
local r = fms.ns.B747_fms_preds()
T.check(r ~= nil, "the predictions")
T.check(r.tc == nil and r.td and r.ed and r.crz < 32000, string.format("no T/C: the climb meets the descent at %.0f ft, T/D at %.0f NM", r.crz, r.td or -1))
T.near(r.dest.t, r.pts[#r.pts].t, 1e-6, "the destination's time: the last leg's")
T.check(r.dest.fuel < 40000 and r.dest.fuel > 25000, string.format("its fuel %.0f kg (40 t now)", r.dest.fuel))
-- 250 t, STEP SIZE 0, FL100: no message, T/C and T/D, every leg at or
-- below FL100
rt:set("sim/flightmodel/weight/m_total", 250000)
enter("0", "R5")
enter("FL100", "R1")
T.equal(pad(), "", "FL100: no message")
frames(11)
r = fms.ns.B747_fms_preds()
T.check(r.tc and r.td and r.tc < r.td, string.format("FL100: T/C %.0f NM before the T/D %.0f NM", r.tc or -1, r.td or -1))
for i, p in ipairs(r.pts) do
    T.check(p.h <= 10000 + 1, "leg " .. i .. " at or below FL100: " .. math.floor(p.h))
end

-- PROGRESS page 1 from the predictions (step 8d; FCOM p.1371-1373): TO
-- the first leg with a point, NEXT the one after, DEST; TO T/C on the
-- ground (the climb)
key("func_key/prog")
local legsR = fms.ns.B747_fmc_route.rte.legs
local to, nxt
for i, l in ipairs(legsR) do
    if l.fix and r.pts[i] then
        if not to then to = i elseif not nxt then nxt = i break end
    end
end
local function eta4(t) local _, h, m = fms.ns.get_ETA_for_Distance(0, t) return string.format("%02d%02d", h, m) end
local function row_ok(n, name, p)
    local tail = string.format("%4d %s  %5.1f", math.floor(p.x + 0.5), eta4(p.t), p.fuel / 1000)
    return line(n):find("^" .. name) and line(n):sub(-#tail) == tail
end
T.check(row_ok(5, legsR[to].fix.ident, r.pts[to]), "TO " .. legsR[to].fix.ident .. ": its distance, ETA and fuel predicted: " .. line(5))
T.check(row_ok(7, legsR[nxt].fix.ident, r.pts[nxt]), "NEXT " .. legsR[nxt].fix.ident .. ": " .. line(7))
T.check(row_ok(9, "ZZAA", r.dest), "DEST ZZAA: " .. line(9))
local tcText = string.format("%sz/%dNM", eta4(r.tc_t), math.floor(r.tc + 0.5))
T.check(small(10):find("TO T/C$") and line(11):sub(-#tcText) == tcText,
    "TO T/C: its ETA and distance: " .. small(10) .. "|" .. line(11))
T.check(small(10):find("^ ECON SPD"), "the speed's mode: ECON SPD: " .. small(10))

-- LEGS: the predicted speed and altitude in small font (step 8d; FCOM
-- p.1332): before an altitude constraint's slash the speed alone, without a
-- constraint speed/altitude, none under a speed and altitude constraint
key("func_key/legs")
local function spd_of(p) return p.machMode and string.format(".%03d", math.floor(p.mach * 1000 + 0.5)) or string.format("%3d", math.floor(p.cas + 0.5)) end
local function alt_of(p) return p.h > 18000 and string.format("FL%03d", math.floor(p.h / 100 + 0.5)) or string.format("%5d", math.floor(p.h / 10 + 0.5) * 10) end
local cons1 = fms.ns.B747_route_model.constraint_text(legsR[1], 18000)
T.equal(small(3), string.rep(" ", 24 - #cons1 - #spd_of(r.pts[1])) .. spd_of(r.pts[1]) .. string.rep(" ", #cons1),
    "(600) with " .. cons1 .. ": its predicted speed before the slash: " .. small(3) .. "|" .. line(3))
T.equal(small(5), string.rep(" ", 24 - #spd_of(r.pts[2]) - 1 - #alt_of(r.pts[2])) .. spd_of(r.pts[2]) .. "/" .. alt_of(r.pts[2]),
    "(INTC) without a constraint: speed/altitude: " .. small(5))
T.equal((small(7):gsub("%s+$", "")), "", "ZZV with 230/3000A: none: " .. line(7))
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(5):find("^RW16R") and small(5):find("240"), "the runway (the E/D): its speed: " .. small(5))
T.equal((small(7):gsub("%s+$", "")), "", "the missed approach after the E/D: none: " .. line(7))
key("func_key/legs")

-- the CRZ page: the destination's ETA and fuel the predictions'
key("func_key/des")
key("func_key/next_pg")
local _, eh, em = fms.ns.get_ETA_for_Distance(0, r.dest.t)
T.check(line(7):find(string.format("%02d%02dz/%.1f$", eh, em, r.dest.fuel / 1000)), "the destination's ETA and fuel: " .. line(7))
T.check(small(6):find("ZZAA ETA/FUEL"), "the destination's identifier: " .. small(6))

-- CRZ ALT above MAX: no predictions (ATA34_2 p.611)
rt:set("sim/flightmodel/weight/m_total", 390000)
key("func_key/index")
enter("FL410", "R1")
T.check(pad():find("^MAX ALT FL"), "FL410 at 390 t: MAX ALT: " .. pad())
clear()
frames(11)
T.equal(fms.ns.B747_fms_preds(), nil, "above MAX: no predictions")

T.done()
