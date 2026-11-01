-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_msgs_test.lua
-- VNAV's alerts from the predictions (6-1/6-2 step 11c2a; notes/
-- ATA-34-61-FMC.md §94; FCOM p.1431-1434; FMSPG p.117) in the FMS module as
-- XTLua runs it (tests/lib/xtlua.lua), ZZAA to ZZBB by ALPHA and BRAVO,
-- VNAV engaged in the climb after the takeoff: UNABLE NEXT ALT with FL250A
-- at ALPHA (38 NM out), none with 8000A, none with VNAV off; LIMIT ALT
-- FLXXX with CRZ ALT over MAX ALT; DESCENT PATH DELETED when BRAVO's
-- 10000, the only constraint and the E/D, is deleted.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("vnav_msgs")
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
rt:set("sim/cockpit2/clock_timer/zulu_time_hours", 16)
rt:set("sim/cockpit2/clock_timer/zulu_time_minutes", 30)
rt:set("sim/flightmodel/weight/m_total", 260000)
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
local NOTE = "laminar/B747/fms/notification"
local function preds() fms.ns.B747_fms_preds_now() frames(0.5) end

-- PERF INIT: ZFW 220 t, CI 100, CRZ ALT FL350; ZZAA ALPHA BRAVO ZZBB
key("func_key/index")
enter("220", "L3")
enter("100", "L5")
enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: ZZ's ALPHA
enter("BRAVO", "R2")
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(0.5)
T.check(fms.ns.B747_fmc_route.active, "the route active")

-- after the takeoff, 2,000 ft, VNAV engaged in the climb
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel/position/latitude", 35.02)
rt:set("sim/flightmodel/position/longitude", 140.02)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 2000)
rt:set("sim/flightmodel2/position/pressure_altitude", 2000)
rt:set("sim/flightmodel/position/elevation", 2000 * 0.3048)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 36000)
rt:set("laminar/B747/autopilot/vnav_state", 2)

-- ALPHA FL250A: the climb cannot make it (FMSPG p.117)
key("func_key/legs")
enter("/FL250A", "R1")
key("key/execute")
preds()
local r = fms.ns.B747_fms_preds()
T.check(r and r.pts[1] and r.pts[1].h < 25000, "ALPHA predicted under FL250: " .. tostring(r and r.pts[1] and math.floor(r.pts[1].h)))
T.equal(rt:get(NOTE, 47), 1, "UNABLE NEXT ALT (FCOM p.1434)")
frames(0.3)
T.equal(pad(), "UNABLE NEXT ALT", "on the CDU")
rt:set("laminar/B747/autopilot/vnav_state", 0)
frames(0.3)
T.equal(rt:get(NOTE, 47), 0, "VNAV off: none")
rt:set("laminar/B747/autopilot/vnav_state", 2)
frames(0.3)
T.equal(rt:get(NOTE, 47), 1, "VNAV again: UNABLE NEXT ALT")

-- an RTA at ALPHA at its predicted time: met, its crossing under FL250:
-- UNABLE FL250 AT RTA FIX (FCOM p.1434); DELETE of the time: gone
local R = fms.ns.B747_rta_model
local eta = 16 * 60 + 30 + r.pts[1].t / 60
key("func_key/prog")
key("func_key/prev_pg")
enter("ALPHA", "L1")
enter(R.time_text(eta):sub(1, 6), "R1")
key("key/execute")
preds()
T.check(fms.ns.B747_fms_rta().active ~= nil, "the RTA active")
T.equal(rt:get(NOTE, 48), 0, "its time met: not UNABLE RTA")
T.equal(pad(), "UNABLE FL250 AT RTA FIX", "UNABLE FL250 AT RTA FIX on top")
clear()
rt:command(K .. "key/del")
frames(0.1)
key("ls_key/R1")
preds()
T.check(fms.ns.B747_fms_rta().active == nil and pad() == "", "the RTA's time deleted: the message gone: " .. pad())
key("func_key/legs")
enter("/8000A", "R1")
key("key/execute")
clear()
preds()
T.equal(rt:get(NOTE, 47), 0, "8000A at ALPHA: made, none")

-- LIMIT ALT FLXXX: CRZ ALT FL450 over MAX ALT (the entry stands with MAX
-- ALT FLXXX: FMSPG p.131); in the air on the VNAV CLB page's 1L
local maxFt = fms.ns.B747_perf_db.max_alt(fms.ns.B747_fms_perf(), fms.ns.B747_fms_gw_kg(), fms.ns.B747_fms_isa_dev())
local fl = string.format("FL%03d", math.floor(maxFt / 100))
key("func_key/des")
T.check(line(1):find("CLB", 1, true) ~= nil, "the CLB page: " .. line(1))
enter("450", "L1")
frames(1.2)
T.equal(pad(), "LIMIT ALT " .. fl, "LIMIT ALT at the maximum " .. fl .. " (FCOM p.1433): " .. pad())
rt:set("laminar/B747/autopilot/vnav_state", 0)
frames(1.2)
T.equal(pad(), "MAX ALT " .. fl, "VNAV off: gone, the entry's MAX ALT under it (FMSPG p.131)")
rt:set("laminar/B747/autopilot/vnav_state", 2)
enter("350", "L1")
frames(1.2)
T.check(not pad():find("LIMIT ALT", 1, true), "CRZ ALT FL350: no LIMIT ALT (the short route's UNABLE CRZ ALT may show): " .. pad())

-- DESCENT PATH DELETED: BRAVO 10000, the E/D; deleted, no constraint left
key("func_key/legs")
clear()
rt:command(K .. "key/del")
frames(0.1)
key("ls_key/R1")                 -- ALPHA's 8000A deleted
enter("/10000", "R2")
key("key/execute")
clear()
preds()
T.check(fms.ns.B747_fmc_route.rte.legs[2].alt == 10000 and not fms.ns.B747_fmc_route.rte.legs[1].alt,
    "BRAVO 10000 alone")
T.check(fms.ns.B747_fms_vnav_td() ~= nil, "a descent path (the E/D at BRAVO)")
clear()
rt:command(K .. "key/del")
frames(0.1)
key("ls_key/R2")
key("key/execute")
preds()
T.check(fms.ns.B747_fms_vnav_td() == nil, "the path gone")
frames(0.3)
T.equal(pad(), "DESCENT PATH DELETED", "DESCENT PATH DELETED (FCOM p.1431)")
clear()
frames(0.3)
T.equal(pad(), "", "an event: cleared")

-- (step 11c2b) CHECK ALT TGT (FCOM p.1431): VNAV engaged at 2,000 ft with
-- the MCP altitude below (1,000) and the FMC's above: level, the message;
-- the MCP altitude reset above: gone
rt:set("laminar/B747/autopilot/vnav_state", 0)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 1000)
frames(0.3)
T.equal(rt:get(NOTE, 4), 0, "VNAV off: no CHECK ALT TGT")
rt:set("laminar/B747/autopilot/vnav_state", 2)
frames(0.3)
T.equal(rt:get(NOTE, 4), 1, "engaged between the MCP and FMC altitudes: CHECK ALT TGT")
T.check(rt:get("laminar/B747/fms/vnav/mode") == 2 and rt:get("laminar/B747/fms/vnav/alt") == 2000, "VNAV PTH level at 2,000 ft")
frames(0.3)
T.equal(pad(), "CHECK ALT TGT", "on the CDU")
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 20000)
frames(0.3)
T.equal(rt:get(NOTE, 4), 0, "the MCP altitude reset above: gone")
T.check(rt:get("laminar/B747/fms/vnav/alt") ~= 2000, "the climb's FMC altitude again")
T.done()
