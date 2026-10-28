-- Run from the repository root with LuaJIT: luajit tests/hyd/hyd_module_test.lua
-- The hydraulic modules as XTLua runs them (tests/lib/xtlua.lua): the model
-- through its glue (B747.19.xt.hyd_power.lua) in the hydraulics module, with
-- B747.20 (selectors, EICAS memo). The panel, engines, buses and bleed ducts
-- in; the pressures, synoptic values, lights and EICAS slots out. The model's
-- behaviour itself is tested in hyd_model_test.lua; this checks the wiring
-- and the names the panels, the autopilot and the flight controls read
-- (docs/overhaul/notes/ATA-29.md §6.2).
local T = dofile("tests/lib/check.lua")("hyd_module")
local xtlua = dofile("tests/lib/xtlua.lua")

math.randomseed(1)
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulicsmodel.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.20.xt.hydraulics/B747.20.xt.hydraulics.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local HYD = "laminar/B747/hydraulics/"
local SEL = HYD .. "dmd_pump/sel_dial_pos"
local CAUTION = "laminar/B747/CAS/caution_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"
local SW = "laminar/B747/button_switch/position"

-- cold and dark, ENGINE pumps ON; then power and APU bleed
frames(0.5)
for i = 30, 33 do rt:set(SW, i, 1) end
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
end
rt:set("laminar/B747/electrical/bus/gnd_hdlg", 1)
rt:set("laminar/B747/electrical/bus/gnd_hdlg_dc", 1)
rt:set("laminar/B747/air/duct_pressure_L", 30)
rt:set("laminar/B747/air/duct_pressure_R", 30)
frames(3)
for n = 1, 4 do
    T.equal(get(HYD .. "pressure_" .. n), 0, "preflight: system " .. n .. " at 0 psi")
    T.equal(get(HYD .. "light/sys_fault", n - 1), 1, "preflight: SYS FAULT " .. n)
    T.equal(get(HYD .. "light/dem_press", n - 1), 1, "preflight: DEMAND PRESS " .. n .. " (selector OFF)")
    T.equal(get(HYD .. "light/eng_press", n - 1), 1, "preflight: ENGINE PRESS " .. n)
    T.equal(get(CAUTION, 39 + n), 1, "preflight: HYD PRESS SYS " .. n)
end
T.equal(get(CAUTION, 9), 1, "preflight: >BRAKE SOURCE")
T.equal(get(HYD .. "light/brake_source"), 1, "preflight: BRAKE SOURCE light")
T.equal(get(HYD .. "res_1"), 1, "preflight: quantity 1.00 (no random value, HYD-16)")
-- the custom acf's HYD synoptic (codes: B747.19.hyd_model.lua M.SYN_*)
local SYN = HYD .. "synoptic/"
for n = 1, 4 do
    T.equal(get(SYN .. "edp", n - 1), 1, "preflight: synoptic EDP " .. n .. " ON amber (engine stopped)")
    T.equal(get(SYN .. "dem", n - 1), 4, "preflight: synoptic DEM " .. n .. " OFF")
    T.equal(get(SYN .. "sov", n - 1), 1, "preflight: synoptic SOV " .. n .. " open")
    T.equal(get(SYN .. "rsvr_press", n - 1), 0, "preflight: no RSVR PRESS " .. n .. " with APU bleed")
end
T.equal(get(SYN .. "aux"), 0, "preflight: synoptic AUX OFF")
-- all four lost: every list (with THRUST REV: engine type 0 is P&W) and set
for n = 1, 4 do T.equal(get(SYN .. "inop", n - 1), 2, "preflight: inoperative items of system " .. n) end
for k = 1, 6 do T.equal(get(SYN .. "inop_set", k - 1), 1, "preflight: inoperative set " .. k) end
rt:set("laminar/B747/engines/type", 1)
frames(0.1)
T.equal(get(SYN .. "inop", 0), 1, "preflight, GE: the list without THRUST REV")
rt:set("laminar/B747/engines/type", 0)
frames(0.1)

-- system 4 AUX first (FCOM p.119)
rt:set(SEL, 3, -1)
frames(3)
T.check(get(HYD .. "aux_pressure") > 2900, "AUX: aux_pressure")
T.check(get(HYD .. "pressure_4") > 2900, "AUX: system 4 pressure")
T.equal(get(HYD .. "dem_mode_4"), -1, "AUX: synoptic selector")
T.equal(get(SYN .. "aux"), 2, "AUX: synoptic AUX running")
T.equal(get(SYN .. "dem", 3), 4, "AUX: synoptic DEM 4 OFF")
T.equal(get(SYN .. "inop", 3), 0, "AUX: system 4 not lost")
T.equal(get(SYN .. "inop", 2), 2, "AUX: system 3 still lost")
T.equal(get(SYN .. "inop_set", 2), 1, "AUX: set 2+3 still lost")
T.equal(get(SYN .. "inop_set", 3), 0, "AUX: no set 2+4")
T.equal(get(SYN .. "inop_set", 5), 0, "AUX: no set 1+2+4 (system 4 gives the brakes)")
T.equal(get(HYD .. "light/sys_fault", 3), 0, "AUX: SYS FAULT 4 out")
T.equal(get(HYD .. "light/dem_press", 3), 1, "AUX: DEMAND PRESS 4 on")
T.equal(get(ADVISORY, 209), 1, "AUX: HYD PRESS DEM 4")
T.equal(get(CAUTION, 43), 0, "AUX: no HYD PRESS SYS 4")
T.equal(get(CAUTION, 9), 0, "AUX: no >BRAKE SOURCE")
T.check(get(HYD .. "indicators/hydraulic_pressure_1_2_4") > 2500, "AUX: system 4 charges the accumulator")

-- 1-3 AUTO with the FUEL CONTROL CUTOFF
for i = 0, 2 do rt:set(SEL, i, 1) end
frames(5)
for n = 1, 3 do
    T.check(get(HYD .. "dem_pressure_" .. n) > 2900, "AUTO: demand pump " .. n .. " pressure")
    T.equal(get(HYD .. "light/sys_fault", n - 1), 0, "AUTO: SYS FAULT " .. n .. " out")
    T.equal(get(HYD .. "light/dem_press", n - 1), 0, "AUTO: DEMAND PRESS " .. n .. " out")
end
T.equal(get(ADVISORY, 210), 1, "AUTO: HYD PRESS ENG 1 raised (hidden before start by the alert model)")
T.equal(get(HYD .. "valve_1"), 1, "AUTO: synoptic supply valve open, engine pump on")

-- the engines start: engine pumps take over, demand pumps 2 and 3 stop 14 s
-- later; AUX pump 4 stops when EDP 4 pressurises
for i = 0, 3 do
    rt:set("sim/flightmodel/engine/ENGN_N2_", i, 65)
    rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", i, 1)
end
rt:set(SEL, 3, 1)
frames(16)
for n = 1, 4 do
    T.check(get(HYD .. "edp_pressure_" .. n) > 2900, "engines: EDP " .. n .. " pressure")
    T.equal(get(HYD .. "light/eng_press", n - 1), 0, "engines: ENGINE PRESS " .. n .. " out")
    T.equal(get(ADVISORY, 209 + n), 0, "engines: no HYD PRESS ENG " .. n)
end
T.equal(get(HYD .. "dem_pressure_2"), 0, "engines: ACMP 2 stopped")
T.equal(get(HYD .. "aux_pressure"), 0, "engines: AUX pump stopped")
T.check(get(HYD .. "pressure_dsp_1") >= 2800, "engines: synoptic pressure")
for n = 1, 4 do
    T.equal(get(SYN .. "edp", n - 1), 0, "engines: synoptic EDP " .. n .. " empty")
    T.equal(get(SYN .. "dem", n - 1), 3, "engines: synoptic DEM " .. n .. " AUTO (cyan)")
end

-- ENGINE pump 1 OFF: ADP 1 keeps system 1, ENGINE PRESS and HYD PRESS ENG
rt:set(SW, 30, 0)
frames(3)
T.equal(get(HYD .. "light/eng_press", 0), 1, "EDP 1 off: ENGINE PRESS 1")
T.equal(get(ADVISORY, 210), 1, "EDP 1 off: HYD PRESS ENG 1")
T.check(get(HYD .. "dem_pressure_1") > 2900 and get(HYD .. "pressure_1") > 2800, "EDP 1 off: ADP 1 holds system 1")
T.equal(get(HYD .. "valve_1"), 0, "EDP 1 off: synoptic shows the engine pump off")
T.equal(get(SYN .. "edp", 0), 4, "EDP 1 off: synoptic EDP 1 OFF")
T.equal(get(SYN .. "sov", 0), 1, "EDP 1 off: synoptic SOV 1 still open")
T.equal(get(SYN .. "dem", 0), 0, "EDP 1 off: synoptic DEM 1 running (empty)")
rt:set(SW, 30, 1)
frames(16)

-- an X-Plane leak failure drains one system in 15-30 s; >HYD QTY LOW and
-- SYS FAULT at LO; clearing the failure fills it again
rt:set("sim/operation/failures/rel_hydleak", 6)
frames(40)
local low1, low2 = get(HYD .. "res_1") <= 0.34, get(HYD .. "res_2") <= 0.34
T.check(low1 ~= low2, "leak: one of systems 1 and 2 drained")
local n = low1 and 1 or 2
T.equal(get(ADVISORY, 217 + n), 1, "leak: >HYD QTY LOW " .. n)
T.equal(get(HYD .. "light/sys_fault", n - 1), 1, "leak: SYS FAULT " .. n)
T.equal(get("laminar/B747/EICAS2/stat/LO", n), 1, "leak: LO on STATUS")
rt:set("sim/operation/failures/rel_hydleak", 0)
frames(1)
T.equal(get(HYD .. "res_" .. n), 1, "leak cleared: quantity back to 1.00")
T.equal(get(ADVISORY, 217 + n), 0, "leak cleared: no >HYD QTY LOW")

-- STATUS slots (laminar/B747/CAS/status_status, ATA29_32 p.137): engines
-- running, ENGINE pump 2 OFF: HYD PRESS ENG 2 (slot 1) and nothing else
rt:set(SW, 31, 0)
frames(4)
T.equal(get(STATUS, 1), 1, "STATUS: HYD PRESS ENG 2 with its pump OFF")
T.equal(get(STATUS, 0), 0, "STATUS: no HYD PRESS ENG 1")
for slot = 4, 19 do
    T.equal(get(STATUS, slot), 0, "STATUS: slot " .. slot .. " clear")
end
rt:set(SW, 31, 1)
frames(4)
T.equal(get(STATUS, 1), 0, "STATUS: HYD PRESS ENG 2 gone with its pump ON")

-- fire switch 3: the synoptic's SOV 3 closes; EDP 3 shows ON amber
rt:set("laminar/B747/fire/engine03/ext_switch/pos_arm", 1)
frames(4)
T.equal(get(SYN .. "sov", 2), 0, "fire 3: synoptic SOV 3 closed")
T.equal(get(SYN .. "edp", 2), 1, "fire 3: synoptic EDP 3 ON amber")
rt:set("laminar/B747/fire/engine03/ext_switch/pos_arm", 0)
-- no bleed: the reservoirs lose pressure (5 min, estimate): RSVR PRESS
rt:set("laminar/B747/air/duct_pressure_L", 0)
rt:set("laminar/B747/air/duct_pressure_R", 0)
frames(900)
T.equal(get(SYN .. "rsvr_press", 0), 1, "no bleed: synoptic RSVR PRESS 1")

-- the AFDS (B747.19.xt.afds_control.lua, 4-1 step 2b): with the A/P off
-- its elevator and aileron commands go back to neutral at 1 per second
-- (they stayed before), and there is no autotrim command
rt:set("laminar/B747/autopilot/servos_on", 0)
rt:set("laminar/B747/flt_ctrls/sim_pitch_ratio", 0.4)
rt:set("laminar/B747/flt_ctrls/sim_roll_ratio", -0.3)
frames(0.1)
T.near(get("laminar/B747/flt_ctrls/sim_pitch_ratio"), 0.3, 1e-6, "A/P off: the elevator command going back")
T.near(get("laminar/B747/flt_ctrls/sim_roll_ratio"), -0.2, 1e-6, "and the aileron command")
frames(0.5)
T.equal(get("laminar/B747/flt_ctrls/sim_pitch_ratio"), 0, "elevator command at neutral")
T.equal(get("laminar/B747/flt_ctrls/sim_roll_ratio"), 0, "aileron command at neutral")
T.equal(get("laminar/B747/flt_ctrls/stab_trim/autotrim_cmd"), 0, "no autotrim command")
-- the roll laws' command (6-3 step 2a): with roll_law 1 the servo law flies
-- roll_cmd, not X-Plane's F/D roll
rt:set("sim/time/total_running_time_sec", 1000)
rt:set("laminar/B747/autopilot/ap_monitor/servos_on_time", 0)
rt:set("laminar/B747/autopilot/servos_on", 1)
rt:set("laminar/B747/autopilot/FMA/active_roll_mode", 6)
rt:set("laminar/B747/autopilot/roll_law", 1)
rt:set("laminar/B747/autopilot/roll_cmd", 10)
rt:set("sim/cockpit2/autopilot/flight_director_roll_deg", -20)
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 0)
frames(0.2)
T.check(get("laminar/B747/flt_ctrls/sim_roll_ratio") > 0, "the roll law's 10 right, not X-Plane's 20 left: the ailerons right")
T.near(get("laminar/B747/autopilot/flight_director_roll_deg"), 10, 1e-6, "the F/D roll: the law's")
rt:set("laminar/B747/autopilot/servos_on", 0)
rt:set("laminar/B747/autopilot/roll_law", 0)
rt:set("laminar/B747/autopilot/FMA/active_roll_mode", 0)
frames(1)
T.equal(get("laminar/B747/flt_ctrls/sim_roll_ratio"), 0, "A/P off: back to neutral")
-- the A/P's attitude loop (6-3, after step 3b): the autotrim from 0.4
-- degrees of the elevator servo command until back within 0.25 (0.6 with
-- the G/S captured: ATA22 p.149; before, 0.005 of the travel in ALT HOLD,
-- no band), the travel X-Plane's (22 degrees up, 17 down); the
-- stabilizer's trim given back by the elevator integrator (ATA22 p.333)
local ELEV, AUTOTRIM = "laminar/B747/flt_ctrls/sim_pitch_ratio", "laminar/B747/flt_ctrls/stab_trim/autotrim_cmd"
rt:set("sim/aircraft/controls/acf_elev_up", 22)
rt:set("sim/aircraft/controls/acf_elev_dn", 17)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 5000)
rt:set("sim/flightmodel2/controls/elevator_trim", 0)
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 9)
rt:set("laminar/B747/autopilot/pitch_law", 1)
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 2)
rt:set("laminar/B747/autopilot/pitch_cmd", 2)
rt:set("laminar/B747/autopilot/servos_on", 1)
frames(1)
-- the servo command (degrees) one frame before against the autotrim command
local function deg_of(r) return r >= 0 and r * 22 or r * 17 end
local prev = get(ELEV)
local bad, on_at, held_at, off_at = nil, nil, nil, nil
local function step(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        rt:frame(1 / 30)
        local d, cmd = deg_of(prev), get(AUTOTRIM)
        if math.abs(d) > 0.4 and cmd ~= (d > 0 and 1 or -1) then bad = bad or ("not trimming at " .. d) end
        if math.abs(d) < 0.25 and cmd ~= 0 then bad = bad or ("trimming at " .. d) end
        if cmd == 1 and not on_at then on_at = d end
        if cmd == 1 and d > 0.25 and d < 0.4 then held_at = held_at or d end
        if on_at and cmd == 0 and not off_at then off_at = d end
        prev = get(ELEV)
    end
end
-- 0.5 degree of pitch up asked: the elevator up past 0.4 degrees
rt:set("laminar/B747/autopilot/pitch_cmd", 2.5)
step(3)
T.check(on_at ~= nil and on_at > 0.4, "the autotrim from 0.4 degrees up (" .. tostring(on_at) .. ")")
-- then 0.5 degree down: the elevator back through the band
rt:set("laminar/B747/autopilot/pitch_cmd", 1.5)
step(6)
T.check(held_at ~= nil, "trimming on between 0.4 and 0.25 degrees (the band: " .. tostring(held_at) .. ")")
T.check(off_at ~= nil and off_at < 0.25, "off within 0.25 degrees (" .. tostring(off_at) .. ")")
T.check(bad == nil, "the autotrim command by the band all along (" .. tostring(bad) .. ")")
-- the G/S captured: on from 0.6 degrees
rt:set("laminar/B747/autopilot/pitch_cmd", 2)
step(4)
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 2)
on_at = nil
local last_cmd = get(AUTOTRIM)
rt:set("laminar/B747/autopilot/pitch_cmd", 2.5)
for _ = 1, 150 do
    rt:frame(1 / 30)
    local d, cmd = deg_of(prev), get(AUTOTRIM)
    if cmd == 1 and last_cmd ~= 1 and not on_at then on_at = d end
    last_cmd = cmd
    prev = get(ELEV)
end
T.check(on_at ~= nil and on_at > 0.6, "G/S: the nose up autotrim from 0.6 degrees (" .. tostring(on_at) .. ")")
-- steady, the stabilizer trimmed 0.05 nose up: the elevator command 1.9
-- times that less
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 9)
rt:set("laminar/B747/autopilot/pitch_cmd", 2)
step(6)
local before = get(ELEV)
rt:set("sim/flightmodel2/controls/elevator_trim", 0.05)
frames(1)
T.near(before - get(ELEV), 1.9 * 0.05, 0.01, "the stabilizer 0.05 nose up: the elevator 0.095 less (" .. before .. " to " .. get(ELEV) .. ")")
rt:set("sim/flightmodel2/controls/elevator_trim", 0)
rt:set("laminar/B747/autopilot/servos_on", 0)
rt:set("laminar/B747/autopilot/pitch_law", 0)
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 0)
frames(1)

-- lateral control (B747.19.lateral_model.lua, 4-1 step 4): the controlObject
-- rows make the control wheel's angle from the pilots', the A/P's and the
-- aileron trim's inputs (run here as XTLua runs them); the hydraulics
-- module makes the aileron programmers' and the spoiler mixers' commands
-- through its pressure gates, and X-Plane's surfaces
local function co_frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        rt:apply_control_objects()
        rt:frame(1 / 30)
    end
end
local FC = "laminar/B747/flt_ctrls/"
local WHEEL = "laminar/B747/cablecontrols/wheel"
local share45 = (45 - 11) / (90 - 11)       -- the spoilers' share of roll at 45 degrees of wheel
rt:set(FC .. "left_outer_aileron_lockout", 1)
rt:set(FC .. "right_outer_aileron_lockout", -1)
rt:set("sim/cockpit2/controls/yoke_roll_ratio", 0.5)
co_frames(2)
T.near(get(WHEEL), 45, 1e-3, "half the wheel's travel: 45 degrees")
T.near(get(FC .. "l_aileron_inner"), 20, 0.05, "45 degrees of wheel: left inboard aileron full down (in proportion before: 10)")
T.near(get(FC .. "r_aileron_inner"), -20, 0.05, "right inboard aileron full up")
T.near(get(FC .. "l_aileron_outer"), 15, 0.05, "left outboard aileron 15 down")
T.near(get(FC .. "r_aileron_outer"), -24.65, 0.05, "right outboard aileron 24.65 up (25 at 47 degrees)")
T.near(get("sim/flightmodel/controls/wing2l_ail1def"), 20, 0.05, "X-Plane's left inboard aileron")
T.near(get("sim/flightmodel/controls/wing4r_ail2def"), -24.65, 0.05, "X-Plane's right outboard aileron")
T.near(get(FC .. "spoilers", 12), 45 * share45, 0.05, "roll right: right spoiler 12 up past the pickup")
T.near(get(FC .. "spoilers", 8), 20 * share45, 0.05, "right spoiler 8 (20 at most)")
T.near(get(FC .. "spoilers", 1), 0, 1e-3, "left spoiler 1 stays down")
T.near(get("sim/flightmodel/controls/wing2r_spo1def"), 45 * share45, 0.05, "X-Plane's wing 2 spoiler (spoiler 9: nothing moved it before)")
rt:set(FC .. "left_outer_aileron_lockout", 0)
co_frames(2)
T.near(get(FC .. "l_aileron_outer"), 0, 0.05, "outboard ailerons locked out: neutral")
rt:set(FC .. "left_outer_aileron_lockout", 1)
-- the aileron trim: 6 units (X-Plane's full trim) are 47 degrees of wheel
rt:set("sim/cockpit2/controls/yoke_roll_ratio", 0)
rt:set("sim/cockpit2/controls/aileron_trim", 1)
co_frames(2)
T.near(get(WHEEL), 47, 0.01, "full aileron trim: the wheel's neutral 47 degrees over (ATA27 p.76; a full wheel before)")
T.near(get(FC .. "l_aileron_inner"), 20, 0.05, "full trim: the inboard aileron at 20")
rt:set("sim/cockpit2/controls/aileron_trim", 0)
-- the speedbrakes at the flight detent with roll: the left wing's spoilers
-- go down from their speedbrake positions; spoilers 6 and 7 on X-Plane's
-- speedbrake 1 (no surface before)
rt:set("laminar/B747/flt_ctrls/speedbrake_lever", 0.53)
rt:set("sim/cockpit2/controls/yoke_roll_ratio", 0.5)
co_frames(2)
T.near(get(FC .. "spoilers", 3), 45 - 45 * share45, 0.05, "flight detent, roll right: left spoiler 3 lowered from 45")
T.near(get(FC .. "spoilers", 10), 45, 0.05, "right spoiler 10 at 45")
T.near(get(FC .. "spoilers", 5), 20 - 20 * share45, 0.05, "left spoiler 5 lowered from 20")
T.near(get(FC .. "spoilers", 6), 20, 0.05, "spoiler 6 at 20")
T.near(get("sim/flightmodel2/wing/speedbrake1_deg", 0), 20, 0.05, "X-Plane's speedbrake 1, left: spoiler 6")
T.near(get("sim/flightmodel2/wing/speedbrake1_deg", 1), 20, 0.05, "X-Plane's speedbrake 1, right: spoiler 7")
T.near(get("sim/flightmodel/controls/wing2l_spo1def"), 45 - 45 * share45, 0.05, "X-Plane's wing 2 spoiler, left: spoiler 4")
T.near(get("sim/flightmodel/controls/wing3l_spo2def"), 45 - 45 * share45, 0.05, "X-Plane's wing 3 spoiler 2, left: spoiler 3")
rt:set("sim/cockpit2/controls/yoke_roll_ratio", 0)
rt:set("laminar/B747/flt_ctrls/speedbrake_lever", 0)
-- (the spoilers follow by a tenth of the way each frame: 4 s for the last 0.05)
co_frames(4)
for n = 1, 12 do T.near(get(FC .. "spoilers", n), 0, 0.05, "lever DN, wheel centred: spoiler " .. n .. " down") end

-- FLT CONTROL HYD POWER (4-1 step 4): the switches by command (the 3D has
-- none), a valve's travel 2 s (estimate), >FLT CONT VLVS while one is not
-- fully open (FCOM p.940, p.957); the wing valves take their systems from
-- the ailerons and spoilers, the tail valves from the elevators, rudders
-- and yaw dampers
local HP = "laminar/B747/flt_ctrls/hyd_power/"
local hyd_ns = rt.modules[1].ns
rt:command(HP .. "wing_1")
co_frames(1)
T.equal(get(HP .. "wing_shut", 0), 1, "WING 1 switch at SHUT OFF")
T.near(get(HP .. "wing_valve_shut", 0), 0.5, 0.05, "its valve halfway after 1 s")
T.equal(get(ADVISORY, 143), 1, ">FLT CONT VLVS while a valve is not fully open")
co_frames(1.5)
T.equal(get(HP .. "wing_valve_shut", 0), 1, "the valve shut after 2 s")
rt:command(HP .. "wing_3")
co_frames(2.5)
rt:set("sim/cockpit2/controls/yoke_roll_ratio", 0.5)
co_frames(2)
T.near(get(FC .. "l_aileron_inner"), 0, 0.5, "WING 1 and 3 shut: the left inboard aileron (systems 1, 3) does not move")
T.near(get(FC .. "r_aileron_inner"), -20, 0.05, "the right inboard aileron (systems 2, 4) does")
rt:set("sim/cockpit2/controls/yoke_roll_ratio", 0)
rt:command(HP .. "wing_1")
rt:command(HP .. "wing_3")
co_frames(3)
T.equal(get(HP .. "wing_valve_shut", 0), 0, "WING 1 open again")
T.equal(get(ADVISORY, 143), 0, "all open: no >FLT CONT VLVS")
T.equal(hyd_ns.B747_fcsov_yaw_damper_hyd(3), true, "the upper yaw damper: system 3 through tail valve 3")
rt:command(HP .. "tail_3")
co_frames(2.5)
T.equal(hyd_ns.B747_fcsov_yaw_damper_hyd(3), false, "TAIL 3 shut: no hydraulics for the upper yaw damper")
T.equal(hyd_ns.B747_fcsov_yaw_damper_hyd(2), true, "the lower one keeps system 2")
rt:command(HP .. "tail_3")
co_frames(2.5)
T.equal(get(HP .. "tail_valve_shut", 2), 0, "TAIL 3 open again")

-- the old pitch law (B747.19.xt.afds_control.lua, until 6-3 step 3) with no
-- pitch mode (everything off: the AFDS model, 6-3 step 1a): its capture
-- window latches no ALT HOLD; with V/S inside it, it still does
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 0)
rt:set("laminar/B747/autopilot/altitude_hold_status", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 10000)
rt:set("laminar/B747/autopilot/altitude_dial_ft", 10050)
rt:set("laminar/B747/autopilot/ap_monitor/alt_capture_window", 500)
frames(3)
T.equal(get("laminar/B747/autopilot/altitude_hold_status"), 0, "no pitch mode: no ALT HOLD latched near the target")
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 7)
frames(3)
T.equal(get("laminar/B747/autopilot/altitude_hold_status"), 2, "V/S inside the window: ALT HOLD latched (the old capture)")

T.done()
