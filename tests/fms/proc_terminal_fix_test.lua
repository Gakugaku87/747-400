-- Run from the repository root with LuaJIT: luajit tests/fms/proc_terminal_fix_test.lua
-- (2026-11-12 review FMC-5, FMC-6; REVIEW_2026-11-12.md case 9) A
-- procedure's waypoint is the airport's terminal waypoint, and the ILS
-- tuned is the approach's own localizer, in the FMS module as XTLua runs
-- it, on tests/fms/data/navdb_map (the synthetic nav data with an enroute
-- ZA009 far away listed before ZZAA's terminal ZA009, the STAR CHARL1 to
-- the terminal one, a second localizer IZB on ZZAA's 16R and the approach
-- I16RZ with IZB as its legs' recommended navaid).
-- Before: the first point of that identifier and region, the enroute one
-- (RJTT's SULP1D: D097V of Hokkaido, 439 NM to the next point, not RJTT's
-- at TTE R-097/22), and the first localizer of the runway (EDDF ILS 07L Z:
-- 110.30, not its IFNE on 111.75). Now the terminal point for a terminal
-- waypoint (the CIFP record's section P, subsection C) and of several the
-- nearest the airport; the localizer the approach's legs recommend
-- (FCOM p.1306: the ILS of the approach selected).
B747_NAVDB_FOLDER = "tests/fms/data/navdb_map/"
local T = dofile("tests/lib/check.lua")("proc_terminal_fix")
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
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
frames(4)
local db = fms.ns.B747_fmc_navdb
local n = 0
while not db.ready and n < 200000 do rt:frame(1 / 30); n = n + 1 end
local K = "laminar/B747/fms1/"
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for _ = 1, 30 do rt:command(K .. "key/clear") end
    frames(0.1)
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local R, ns = fms.ns.B747_route_model, fms.ns
local function leg_of(st, ident)
    for _, l in ipairs(R.shown(st).legs) do
        if l.fix and l.fix.ident == ident then return l end
    end
    return nil
end

-- the route ZZAA to ZZAA, DIRECT DELTA
key("func_key/index") enter("100", "L5") enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1") enter("ZZAA", "R1")
key("func_key/next_pg")
enter("DELTA", "R1")
local st = ns.B747_fmc_route_num(1)

-- the STAR CHARL1: its ZA009 ZZAA's terminal waypoint, not the enroute one
R.set_arrival(st, {name = "CHARL1"}, {id = "I16RZ"})
ns.B747_fmc_route_changed()
local z = leg_of(st, "ZA009")
T.check(z ~= nil, "the STAR's ZA009 in the route")
T.near(z and z.fix.lat or 0, 35.07, 1e-6, "ZA009's latitude: ZZAA's terminal waypoint (the enroute one is at 40 N)")
T.near(z and z.fix.lon or 0, 140.07, 1e-6, "ZA009's longitude")

-- the approach I16RZ: its localizer IZB tuned, not the runway's first (IZA)
key("func_key/fpln") key("ls_key/R6") key("key/execute")
frames(1)
T.check(st.active, "the route active")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 8000)
rt:set("sim/flightmodel/position/latitude", 35.3)
rt:set("sim/flightmodel/position/longitude", 140.3)
-- past the ten minutes after lift-off that hold the autotuning (FCOM p.1305)
frames(700, 0.5)
T.equal(rt:get("sim/cockpit/radios/nav1_freq_hz"), 11175, "NAV 1: I16RZ's localizer IZB (111.75), not IZA (109.50)")

-- the approach I16R: its localizer IZA
R.set_arrival(st, {name = "CHARL1"}, {id = "I16R"})
ns.B747_fmc_route_changed()
key("key/execute")
frames(10, 0.5)
T.equal(rt:get("sim/cockpit/radios/nav1_freq_hz"), 10950, "NAV 1: I16R's localizer IZA (109.50)")

T.done()
