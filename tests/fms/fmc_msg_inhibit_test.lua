-- Run from the repository root with LuaJIT: luajit tests/fms/fmc_msg_inhibit_test.lua
-- The FMC's alerts held below 500 ft AGL in the approach phase with a
-- runway in the active route (6-1/6-2 step 11c1; notes/ATA-34-61-FMC.md
-- §92; ATA34_2 p.635; FCOM p.1236) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua): an alert (UNABLE NEXT ALT's flag) on the CDU and
-- FMC MESSAGE; not held after the takeoff; ZZAA to ZZBB with the approach
-- R09: held below 500 ft once its first waypoint is sequenced, an advisory
-- still shown; above 500 ft nothing changes; shown again after climbing
-- through 1,000 ft; held again on the next approach and shown at the
-- flight completion.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("fmc_msg_inhibit")
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
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local NOTE, ALERT = "laminar/B747/fms/notification", "UNABLE NEXT ALT"
local function fmc_message() return rt:get("laminar/B747/CAS/advisory_status", 145) end
local function air(ra)
    rt:set("sim/flightmodel/failures/onground_any", 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
    rt:set(RA, ra)
    frames(0.5)
end

-- the route ZZAA to ZZBB with the approach R09
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
clear()
key("func_key/clb")              -- DEPARTURES (the ground, an active route)
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")                 -- ZZBB ARRIVALS
key("ls_key/R1")                 -- R09
key("key/execute")
frames(0.5)
local st = fms.ns.B747_fmc_route
T.equal(st.rte.appr and st.rte.appr.rwy, "RW09", "the approach to RW09 active")

-- an alert, after the takeoff: shown
rt:set(NOTE, 47, 1)              -- UNABLE NEXT ALT (DRindex 46)
air(300)
T.equal(pad(), ALERT, "an alert after the takeoff below 500 ft: shown (not the approach phase)")
T.equal(fmc_message(), 1, "FMC MESSAGE")

-- the approach phase: held below 500 ft
clear()
rt:set(NOTE, 47, 0)
frames(0.3)
rt:set("sim/flightmodel/position/latitude", 35.95)
rt:set("sim/flightmodel/position/longitude", 140.8)
air(1500)
T.check(fms.ns.B747_route_model.sequence(st, 1), "the approach's first waypoint sequenced (FCOM p.1236)")
rt:set(NOTE, 47, 1)
air(600)
T.equal(pad(), ALERT, "above 500 ft in the approach phase: shown")
clear()
rt:set(NOTE, 47, 0)
frames(0.3)
air(450)
rt:set(NOTE, 47, 1)
frames(0.5)
T.equal(pad(), "", "below 500 ft in the approach phase: held (ATA34_2 p.635)")
T.equal(fmc_message(), 0, "no FMC MESSAGE while held")
clear()
enter("ZZZ", "L1")               -- an entry's message still shows
T.check(pad() ~= ALERT and pad() ~= "", "held: an entry's message still shows: " .. pad())
clear()
air(800)
T.equal(pad(), "", "climbing to 800 ft: still held")
air(1100)
T.equal(pad(), ALERT, "climbing through 1,000 ft: shown again")
T.equal(fmc_message(), 1, "FMC MESSAGE again")

-- held on the next approach, shown at the flight completion
clear()
rt:set(NOTE, 47, 0)
frames(0.3)
rt:set(NOTE, 47, 1)
air(200)
T.equal(pad(), "", "the next approach below 500 ft: held")
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
frames(0.5)
T.equal(pad(), "", "landed: still held")
fms.ns.B747_fms_flight_complete()
frames(0.5)
T.equal(pad(), ALERT, "the flight completion: shown (ATA34_2 p.635)")
T.done()
