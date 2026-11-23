-- Run from the repository root with LuaJIT: luajit tests/hyd/afds_pitch_int_test.lua
-- The A/P's inner pitch loop in the hydraulics module as XTLua runs it
-- (tests/lib/xtlua.lua; B747.19.xt.afds_control.lua), 2026-11-24, the
-- 2026-11-23 review's FCTL-1 (docs/overhaul/notes/ATA-22.md §68):
--  * the attitude error's integral is a third of the proportional a second
--    (before, as much: with the flaps up from 195 to 240 kt the pitch swung
--    every 4.4 to 5.7 s in ALT HOLD and FLCH's descents);
--  * the command is in degrees of elevator the same both ways: the
--    elevator's travel is 22 degrees up and 17 down, and nose down the
--    pitch ratio is the command times 22 / 17 (before, the same ratio: 17 /
--    22 of the degrees, the loop's gain a quarter less with the elevator
--    trailing edge down of neutral).
local T = dofile("tests/lib/check.lua")("afds_pitch_int")
local xtlua = dofile("tests/lib/xtlua.lua")

math.randomseed(1)
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulicsmodel.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local ELEV = "laminar/B747/flt_ctrls/sim_pitch_ratio"
local PITCH, CMD = "sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", "laminar/B747/autopilot/pitch_cmd"
local function deg_of(r) return r >= 0 and r * 22 or r * 17 end
frames(0.5)
rt:set("sim/aircraft/controls/acf_elev_up", 22)
rt:set("sim/aircraft/controls/acf_elev_dn", 17)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 288)   -- the gains as set (from 250 kt up): 0.1 a degree
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 5000)
rt:set("sim/flightmodel2/controls/elevator_trim", 0)
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 9)
rt:set("laminar/B747/autopilot/pitch_law", 1)
rt:set(PITCH, 2)
rt:set(CMD, 2)
rt:set("laminar/B747/autopilot/servos_on", 1)
frames(2)
T.near(get(ELEV), 0, 0.002, "on the command, no rate: the elevator neutral (" .. get(ELEV) .. ")")

-- 0.2 degree of nose up asked and held: the proportional's 0.02 at once,
-- then the integral 0.2 x 0.1 / 3 a second (before 0.2 x 0.1)
rt:set(CMD, 2.2)
frames(1)
local a = get(ELEV)
frames(3)
local b = get(ELEV)
T.near((b - a) / 3, 0.2 * 0.1 / 3, 0.0008, string.format("0.2 degree of error held: the integral %.4f a second, a third of the proportional's 0.02 (before 0.02 a second)", (b - a) / 3))
T.near(a, 0.2 * 0.1 + 0.2 * 0.1 / 3 * 1, 0.004, "after a second: the proportional's 0.02 and a second of the integral (" .. a .. ")")

-- the same nose down: the up travel's units times 22 / 17, the same degrees
rt:set(CMD, 2)
rt:set("laminar/B747/autopilot/servos_on", 0)
frames(3)
rt:set("laminar/B747/autopilot/servos_on", 1)
frames(2)
T.near(get(ELEV), 0, 0.002, "engaged again on the command: neutral (" .. get(ELEV) .. ")")
rt:set(CMD, 1.8)
frames(1)
local c = get(ELEV)
frames(3)
local d = get(ELEV)
T.check(c < 0 and d < c, "0.2 degree of nose down asked: the elevator nose down (" .. c .. ", " .. d .. ")")
T.near((c - d) / 3, 0.2 * 0.1 / 3 * 22 / 17, 0.001, string.format("the ratio's rate %.4f a second: 22 / 17 of the nose-up one", (c - d) / 3))
T.near(deg_of(a), -deg_of(c), 0.02, string.format("a second after the step: %.3f degrees nose up, %.3f nose down (before, 17 / 22 as much nose down)", deg_of(a), deg_of(c)))
T.near(deg_of(b) - deg_of(a), deg_of(c) - deg_of(d), 0.02, "and the integral's degrees a second the same both ways")

-- the A/P off with the elevator nose down (the column held forward): the
-- integrator takes the surface's place in its own units, so the A/P goes
-- in holding the elevator where it is
rt:set("laminar/B747/autopilot/servos_on", 0)
rt:set(CMD, 2)
frames(3)
rt:set("sim/cockpit2/controls/yoke_pitch_ratio", -0.1)
frames(1)
rt:set("laminar/B747/autopilot/servos_on", 1)
rt:set("sim/cockpit2/controls/yoke_pitch_ratio", 0)
frames(0.2)
T.near(get(ELEV), -0.1, 0.01, "engaged with the column 0.1 forward: the elevator held there (" .. get(ELEV) .. ")")
T.done()
