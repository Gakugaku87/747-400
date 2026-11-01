-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_wpts_test.lua
-- The VNAV pages' waypoints (6-1/6-2 step 12b2; notes/ATA-34-61-FMC.md
-- §107) in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic CIFP of ZZAA (pred_glue_test's route): the CLB page's AT XXXXX,
-- the next waypoint constraint before the T/C (FCOM p.1328), and its ERROR
-- only when the prediction there is under it, feet low and NM long
-- (p.1329); the DES page's E/D AT, the E/D's altitude and waypoint, and AT
-- XXXXX, the next constraint after the T/D (p.1392); none without an active
-- route.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("vnav_wpts")
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
key("func_key/index")
enter("100", "L5")
enter("350", "R1")
frames(11)
T.equal(fms.ns.B747_fms_preds(), nil, "no active route: no predictions")
T.equal(rt:get("laminar/B747/fms/profile/kind", 0), 0, "nor the ND's profile points")

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


-- (step 12b2) the VNAV pages' waypoints from the active route and the
-- predictions: on the ground, CRZ ALT FL250
key("func_key/index")
enter("100", "L5")
enter("FL250", "R1")
frames(11)
local legs = fms.ns.B747_fmc_route.rte.legs
local r = fms.ns.B747_fms_preds()
T.check(r and r.tc and r.td, "the predictions: T/C and T/D")
local function idx(name, from)
    for i = from or 1, #legs do
        if legs[i].fix and legs[i].fix.ident == name then return i end
    end
end
local zzv, alpha = idx("ZZV"), idx("ALPHA")
local alpha2 = idx("ALPHA", alpha + 1)
local rwy = r.ed_i
local function rs(n) return (line(n):gsub("^%s+", ""):gsub("%s+$", "")) end
-- CLB: AT ZZV 230/3000A (the SID's first waypoint constraint; the
-- altitude-terminated leg before it has no waypoint), no ERROR (predicted
-- above it)
key("func_key/des")
T.check(line(1):find("CLB"), "the CLB page: " .. line(1))
T.check(small(2):find("AT ZZV$"), "AT ZZV (FCOM p.1328): " .. small(2))
T.check(line(3):find("230/3000A$"), "230/3000A: " .. line(3))
T.check(r.pts[zzv].h > 3000, string.format("ZZV predicted at %.0f ft, above 3000", r.pts[zzv].h))
T.check(not small(4):find("ERROR"), "no ERROR label without an error (p.1329): " .. small(4))
T.check(not line(5):find("LO"), "no error: " .. line(5))
-- the DES page: E/D AT the approach's runway 50 ft above it, AT the
-- first constraint after the T/D (the STAR's ALPHA window)
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(1):find("DES"), "the DES page: " .. line(1))
local ed = legs[rwy]
local edAlt = (ed.fix.elev or 0) + 50
T.check(line(3):find("^ *" .. edAlt .. " " .. ed.fix.ident), "E/D AT " .. edAlt .. " " .. ed.fix.ident .. " (p.1392): " .. line(3))
T.check(r.pts[alpha2].x >= r.td, "the STAR's ALPHA after the T/D")
T.check(small(2):find("AT ALPHA$"), "AT ALPHA: " .. small(2))
-- (above the transition level, TRANS LVL, a flight level: as the LEGS pages)
local tl = fms.ns.B747_fms_trans_lvl()
local upper = 15000 > tl and "FL150" or "15000"
T.check(line(3):find("/11000A" .. upper .. "B$"), "the window, TRANS LVL " .. tl .. ": " .. line(3))
-- an AT OR ABOVE FL200 at ZZV: predicted under it, the ERROR: feet low and
-- NM long where the climb reaches it (p.1329)
key("func_key/legs")
local row
for n = 1, 5 do
    if line(2 * n + 1):find("^ZZV") then row = n break end
end
T.check(row ~= nil, "ZZV on LEGS page 1")
enter("/20000A", "R" .. row)
key("key/execute")
frames(11)
r = fms.ns.B747_fms_preds()
local h = r.pts[zzv].h
local x0, reach = r.pts[zzv].x, nil
for j = zzv + 1, #legs do
    local q, p = r.pts[j], r.pts[j - 1]
    if q.h >= 20000 then reach = p.x + (20000 - p.h) / (q.h - p.h) * (q.x - p.x) break end
end
local ft = math.floor((20000 - h) / 10 + 0.5) * 10
local nm = math.max(1, math.floor(reach - x0 + 0.5))
key("func_key/des")
-- (above the CLB page's TRANS ALT a flight level)
local ta = tonumber(fms.ns.fmsModules.data.transalt) or 18000
T.check(line(3):find((20000 > ta and "/FL200A" or "/20000A") .. "$"), "the constraint, TRANS ALT " .. ta .. ": " .. line(3))
T.check(small(4):find("ERROR$"), "the ERROR label: " .. small(4))
T.check(line(5):find(string.format("%dLO %dLONG$", ft, nm)),
    string.format("%dLO %dLONG (%.0f ft predicted): %s", ft, nm, h, line(5)))
-- the descent from here (the predictions with no T/C nor T/D, an E/D:
-- s186 at the T/D): the DES page's AT the next constraint ahead
local realPreds = fms.ns.B747_fms_preds
local now = realPreds()
fms.ns.B747_fms_preds = function()
    return {pts = now.pts, tc = nil, td = nil, ed = now.ed, ed_i = now.ed_i}
end
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(1):find("DES"), "the DES page: " .. line(1))
T.check(small(2):find("AT ZZV$"), "no T/C or T/D, an E/D: AT the next constraint (ZZV): " .. small(2))
fms.ns.B747_fms_preds = realPreds
-- no active route: none
fms.ns.B747_fmc_route.active = false
frames(0.2)
T.check(not small(2):find("AT "), "no active route: no AT: " .. small(2))
T.check(not line(3):find("/"), "nor a constraint: " .. line(3))
fms.ns.B747_fmc_route.active = true

T.done()
