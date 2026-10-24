-- Run from the repository root with LuaJIT: luajit tests/fltctrls/fltctrls_module_test.lua
-- The flight controls module as XTLua runs it (tests/lib/xtlua.lua), with
-- the flap control units (B747.45.xt.fcu.lua, 4-1): the lever, the
-- hydraulic systems 1 and 4, the ducts, the buses and the airspeed in; the
-- surfaces for the hydraulics module, the FCUs' command, the indication,
-- the EICAS slots out; the SRMs (B747.45.xt.srm.lua, step 2a): the
-- outboard aileron lockout and the rudder ratios; and the flap lever
-- snapping to the nearest detent. The models' behaviour is tested in
-- fcu_model_test.lua and srm_model_test.lua; this checks the wiring and the
-- names (docs/overhaul/notes/ATA-27.md §4.1, §4.3-§4.4, §4.8).
local T = dofile("tests/lib/check.lua")("fltctrls_module")
local xtlua = dofile("tests/lib/xtlua.lua")
-- the ratio changer's schedule, from the model itself
B747_srm_model_test_rrc = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.srm_model.lua").rrc_in

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.xt.fltCtrls.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local LEVER = "sim/cockpit2/controls/flap_ratio"
local IAS = "laminar/B747/gauges/indicators/airspeed_kts_pilot"
local CMD = "laminar/B747/cablecontrols/flap_ratio"     -- the FCUs' command
local FCU = "laminar/B747/flt_ctrls/fcu/"
local CAUTION = "laminar/B747/CAS/caution_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"
local DISPLAY = "laminar/B747/flt_ctrls/flaps/EICAS1_display_status"
local TRANS = "laminar/B747/flt_ctrls/flap/transition_status"
local F20, F25, F30 = 4 / 6, 5 / 6, 1.0

-- power, hydraulics 1-4 and the ducts up, on the ground
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
rt:set("laminar/B747/air/duct_pressure_L", 35)
rt:set("laminar/B747/air/duct_pressure_R", 35)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
for i = 0, 2 do rt:set("sim/flightmodel2/gear/deploy_ratio", i, 1) end
frames(4)                       -- past the start (3 s)
T.equal(get(DISPLAY), 0, "flaps up: no indication")

-- lever 1: group A out in about 9 s, the TE stay up; the indication shows,
-- the lever mark magenta, then green (FCOM p.954)
rt:set(LEVER, 1 / 6)
frames(4)
T.check(get(FCU .. "slat", 0) > 0.3 and get(FCU .. "slat", 0) < 0.6, "lever 1, 4 s: group A on its way")
T.equal(get(FCU .. "slat", 1), 0, "group B in")
T.equal(get(DISPLAY), 1, "normal indication")
T.equal(get(TRANS), 1, "moving: magenta")
frames(6)
T.equal(get(FCU .. "slat", 0), 1, "lever 1, 10 s: group A out")
T.equal(get(FCU .. "te_deg", 1), 0, "TE up at flaps 1")
T.equal(get(TRANS), 0, "in place: green")
T.near(get("laminar/B747/gauges/indicators/flap_deployed_ratio"), 1 / 6, 1e-6, "tape at 1")
-- lever 5: TE 5 at the stock rate (30 degrees in 45 s), group B
rt:set(LEVER, 2 / 6)
frames(9.5)
for i = 0, 3 do T.near(get(FCU .. "te_deg", i), 5, 1e-6, "lever 5: TE panel " .. i .. " at 5 degrees") end
T.equal(get(FCU .. "slat", 1), 1, "group B out")
T.equal(get(FCU .. "te_moving"), 0, "TE at rest")
T.equal(get(FCU .. "te_down"), 1, "TE out: to the demand pumps")
T.near(get(CMD), 2 / 6, 1e-6, "the FCUs' command: lever 5")

-- system 1 lost with a command: the inboard TE to secondary after 4 s,
-- FLAPS PRIMARY, expanded indication; back with the pressure
rt:set("laminar/B747/hydraulics/pressure_1", 0)
rt:set(LEVER, 3 / 6)
frames(4.5)
T.equal(get(FCU .. "te_mode", 0), 1, "system 1 lost: inboard TE secondary")
T.equal(get(CAUTION, 30), 1, "FLAPS PRIMARY")
T.equal(get(DISPLAY), 2, "expanded indication")
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
frames(4.5)
T.equal(get(FCU .. "te_mode", 0), 0, "pressure back: primary")
frames(10)
T.equal(get(CAUTION, 30), 0, "no FLAPS PRIMARY")
T.near(get(FCU .. "te_deg", 1), 10, 1e-6, "flaps 10")

-- load relief (FCOM p.954; ATA27 p.288-289): lever 30, 30->25 at 178 kt,
-- 25->20 at 203 kt; back 20->25 at 195 kt, 25->30 at 170 kt; >FLAP RELIEF
local function at(kt)
    rt:set(IAS, kt)
    frames(0.2)
end
rt:set(LEVER, F30)
at(160)
T.near(get(CMD), F30, 0.001, "lever 30, 160 kt: flaps 30")
T.equal(get(ADVISORY, 142), 0, "no >FLAP RELIEF")
at(180)
T.near(get(CMD), F25, 0.001, "lever 30, 180 kt: relieved to 25")
T.equal(get(ADVISORY, 142), 1, ">FLAP RELIEF")
at(205)
T.near(get(CMD), F20, 0.001, "lever 30, 205 kt: relieved to 20")
at(200)
T.near(get(CMD), F20, 0.001, "lever 30, back to 200 kt: still 20 (195 kt)")
at(194)
T.near(get(CMD), F25, 0.001, "lever 30, 194 kt: back to 25")
at(172)
T.near(get(CMD), F25, 0.001, "lever 30, 172 kt: still 25 (170 kt)")
at(168)
T.near(get(CMD), F30, 0.001, "lever 30, 168 kt: back to 30")
T.equal(get(ADVISORY, 142), 0, ">FLAP RELIEF cleared")
rt:set(LEVER, F25)
at(205)
T.near(get(CMD), F20, 0.001, "lever 25, 205 kt: relieved to 20")
at(193)
T.near(get(CMD), F25, 0.001, "lever 25, 193 kt: back to 25")
at(140)

-- the failures X-Plane does not have: an LE pneumatic drive (electric after
-- 30 s, LE SINGLE DRIVE), an FCU (STATUS FLAP CONTROL L)
rt:set(LEVER, 0)
frames(60)
T.equal(get(FCU .. "slat", 0), 0, "UP: all in")
rt:set(FCU:gsub("fcu/$", "fail/") .. "le_primary", 2, 1)
rt:set(LEVER, 2 / 6)
frames(31)
T.equal(get(FCU .. "le_mode", 2), 1, "outboard LE pneumatic drive failed: electric")
T.equal(get(CAUTION, 30), 1, "FLAPS PRIMARY")
T.equal(get(STATUS, 82), 1, "STATUS LE SINGLE DRIVE")
rt:set(FCU:gsub("fcu/$", "fail/") .. "le_primary", 2, 0)
rt:set(FCU:gsub("fcu/$", "fail/") .. "fcu", 0, 1)
frames(1)
T.equal(get(STATUS, 84), 1, "FCU L failed: STATUS FLAP CONTROL L")
T.equal(get(CAUTION, 28), 0, "two FCUs left: no FLAPS CONTROL")
rt:set(FCU:gsub("fcu/$", "fail/") .. "fcu", 0, 0)

-- ALTN FLAPS ARM: FLAPS CONTROL, expanded indication, the lever does
-- nothing; EXT drives all groups
rt:set("laminar/B747/button_switch/position", 0, 1)
frames(1)
T.equal(get(CAUTION, 28), 1, "ALTN ARM: FLAPS CONTROL")
T.equal(get(DISPLAY), 2, "expanded indication")
local was = get(FCU .. "te_deg", 1)
rt:set(LEVER, F30)
frames(3)
T.near(get(FCU .. "te_deg", 1), was, 1e-6, "the lever does nothing")
rt:set("laminar/B747/flt_ctrls/alt_flaps/sel_dial_pos", 1)
frames(3)
T.check(get(FCU .. "te_deg", 1) > was, "ALTN EXT: the TE move (electric)")
rt:set("laminar/B747/flt_ctrls/alt_flaps/sel_dial_pos", 0)
rt:set("laminar/B747/button_switch/position", 0, 0)
frames(1)
T.equal(get(CAUTION, 28), 0, "disarmed: no FLAPS CONTROL")

-- the SRMs (B747.45.xt.srm.lua, 4-1 step 2a): the outboard aileron
-- lockout and the rudder ratio changers from the airspeed, Mach and the
-- FCU's group A; RUD RATIO SNGL; the air data computer failure
local SRM_FAIL = "laminar/B747/flt_ctrls/fail/"
local function fly(kt, mach, seconds)
    rt:set(IAS, kt)
    rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", kt)
    rt:set("sim/cockpit2/gauges/indicators/mach_pilot", mach)
    rt:set("sim/cockpit2/gauges/indicators/mach_copilot", mach)
    frames(seconds)
end
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set(LEVER, 0)
fly(150, 0.25, 40)
T.equal(get(FCU .. "slat", 0), 0, "flaps up")
T.equal(get("laminar/B747/flt_ctrls/left_outer_aileron_lockout"), 1, "150 kt: outboard ailerons unlocked")
T.equal(get("laminar/B747/flt_ctrls/rudder_ratio_upr"), 1, "150 kt: full rudder (upper)")
T.equal(get("laminar/B747/flt_ctrls/rudder_ratio_lwr"), 1, "full rudder (lower)")
fly(300, 0.5, 6)
T.equal(get("laminar/B747/flt_ctrls/left_outer_aileron_lockout"), 0, "300 kt clean: locked")
T.equal(get("laminar/B747/flt_ctrls/right_outer_aileron_lockout"), 0, "right too (its scale is negative)")
local r300 = (32 - 27 * B747_srm_model_test_rrc(300)) / 32
T.near(get("laminar/B747/flt_ctrls/rudder_ratio_upr"), r300, 1e-6, "300 kt: the ratio changer's schedule")
T.near(get("laminar/B747/flt_ctrls/rudder_ratio"), r300, 1e-6, "rudder_ratio is the lower's")
rt:set(SRM_FAIL .. "rrc", 0, 1)
fly(200, 0.35, 4)
T.equal(get(ADVISORY, 262), 1, "upper ratio changer stuck: RUD RATIO SNGL")
T.equal(get(STATUS, 89), 1, "STATUS RUDDER RATIO")
T.near(get("laminar/B747/flt_ctrls/rudder_ratio_upr"), r300, 1e-6, "upper stays where it stuck")
rt:set(SRM_FAIL .. "rrc", 0, 0)
rt:set("sim/operation/failures/rel_adc_comp", 6)
fly(200, 0.35, 8)
T.near(get("laminar/B747/flt_ctrls/rudder_ratio_lwr"), (32 - 27 * B747_srm_model_test_rrc(209)) / 32, 1e-6,
    "air data computer failed: lower at the 209 kt position")
rt:set("sim/operation/failures/rel_adc_comp", 0)

-- the stabilizer trim (B747.45.xt.srm.lua, step 2b): X-Plane's trim (0-15
-- units on -1..1) followed when set from outside; the wheel switches'
-- commands (the captain's also hold X-Plane's pitch trim command, for the
-- click sound), X-Plane's pitch trim commands (the captain's), the
-- alternate and cutout commands; autotrim from the FCCs; the A/P
-- disengagement; >STAB TRIM, STAB TRIM UNSCHD and their STATUS
local TRIM = "sim/flightmodel2/controls/elevator_trim"
local STAB = "laminar/B747/flt_ctrls/stab_trim/"
local function units() return get(STAB .. "units") end
local function logged(name, phase)
    for _, e in ipairs(rt.command_log) do
        if e.name == name and e.phase == phase then return true end
    end
    return false
end
rt:set("laminar/B747/hydraulics/pressure_2", 3000)
rt:set("laminar/B747/hydraulics/pressure_3", 3000)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/stby_main", 1)
fly(200, 0.3, 1)
-- speed trim (step 2c): in the air for a minute at 200 kt, no autopilot
T.equal(get(STAB .. "speed_trim"), 1, "speed trim engaged")
rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", 215)
frames(0.2)
T.equal(get(STATUS, 93), 1, "the air data sides 15 kt apart: STATUS STAB SPEED TRIM")
T.equal(get(STAB .. "speed_trim"), 0, "and no speed trim")
rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", 200)
frames(0.2)
T.equal(get(STATUS, 93), 0, "agreeing: no STATUS STAB SPEED TRIM")
rt:set(TRIM, -1 / 3)
frames(0.2)
T.near(units(), 5, 1e-6, "X-Plane's trim set from outside: the stabilizer follows (5 units)")
rt:command("laminar/B747/flt_ctrls/stab_trim_up_capt", 2)
frames(0.1)
T.check(units() > 5.9 and units() < 6.1, "captain's switches 2 s at 200 kt: about 1 unit")
T.near(get(TRIM), units() / 7.5 - 1, 1e-6, "X-Plane's trim written")
T.check(logged("sim/flight_controls/pitch_trim_up", "start") and logged("sim/flight_controls/pitch_trim_up", "stop"),
    "the captain's switches hold X-Plane's pitch trim command (the click sound)")
local u = units()
rt:command("sim/flight_controls/pitch_trim_down", 1)
frames(0.1)
T.check(units() < u - 0.4, "X-Plane's pitch trim down (a joystick): the captain's switches")
u = units()
rt:command("laminar/B747/flt_ctrls/stab_trim_up_fo", 1)
frames(0.1)
T.check(units() > u + 0.4, "F/O's switches")
u = units()
rt:command("laminar/B747/flt_ctrls/altn_stab_trim_dn", 1)
frames(0.1)
T.check(units() < u - 0.4, "the alternate switches' command")
T.equal(get(STAB .. "altn_sw"), 0, "released: the alternate switches back to 0")
rt:command("laminar/B747/flt_ctrls/stab_trim/cutout_2_dn", 0)
frames(0.2)
T.equal(get(STAB .. "cutout_sw", 0), -1, "cutout switch 2: CUTOUT")
T.equal(get(ADVISORY, 274), 1, ">STAB TRIM 2")
T.equal(get(STATUS, 90), 1, "STATUS STAB TRIM")
rt:command("laminar/B747/flt_ctrls/stab_trim/cutout_2_up", 0)
frames(5.2)
T.equal(get(STAB .. "cutout_sw", 0), 0, "back to AUTO")
T.equal(get(ADVISORY, 274), 0, "5 s at AUTO: >STAB TRIM 2 gone")
-- autotrim: the L A/P engaged, the FCCs' command nose up
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 1)
rt:set(STAB .. "autotrim_cmd", 1)
u = units()
frames(3)
T.near(units(), u, 1e-9, "autotrim, 3 s: waits")
frames(2)
T.check(units() > u + 0.2 and units() < u + 0.5, "then 0.25 units/s at 200 kt")
rt:set(STAB .. "autotrim_cmd", 0)
rt:command("laminar/B747/flt_ctrls/stab_trim_dn_capt", 0.2)
T.check(logged("laminar/B747/autopilot/trim_disengage", "once"), "one A/P and the wheel switches: disengage")
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 0)
frames(0.2)
-- system 3's module running away: the automatic cutout
rt:set(SRM_FAIL .. "stab_runaway", 1, 1)
frames(1)
T.equal(get(ADVISORY, 275), 1, "system 3's module running away: cut out, >STAB TRIM 3")
T.equal(get(CAUTION, 60), 0, "no STAB TRIM UNSCHD")
rt:set(SRM_FAIL .. "stab_runaway", 1, -1)
rt:set(STAB .. "cutout_sw", 1, 1)
frames(1)
T.equal(get(CAUTION, 60), 1, "at ON nothing cuts it out: STAB TRIM UNSCHD")
T.equal(get(STATUS, 91), 1, "STATUS STAB TRIM UNSCHD")
rt:set(SRM_FAIL .. "stab_runaway", 1, 0)
rt:set(STAB .. "cutout_sw", 1, 0)
-- X-Plane's elevator trim runaway: system 3's module runs nose up (cut out
-- at AUTO); X-Plane's own moves of the trim are put back
frames(1)
rt:set("sim/operation/failures/rel_elv_trim_run", 6)
u = units()
frames(1)
T.check(units() > u and units() < u + 0.2, "X-Plane's runaway: moves, then cut out")
T.equal(get(ADVISORY, 275), 1, ">STAB TRIM 3")
u = units()
rt:set(TRIM, 0.9)
frames(0.1)
T.near(get(TRIM), u / 7.5 - 1, 1e-6, "during X-Plane's runaway its own trim moves are put back")
rt:set("sim/operation/failures/rel_elv_trim_run", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
fly(0, 0, 1)

-- the takeoff greenband (B747.45.greenband_model.lua, step 2c): the FMC's
-- takeoff trim selects the band; the indicator shows it on the ground
-- below V1, otherwise the painted mid band
local G = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.greenband_model.lua")
local IND = "laminar/B747/flt_ctrls/elevator_trim/mid/indicator"
rt:set("laminar/B747/fmc/elevator_trim", 9.2)
frames(0.2)
T.near(get(IND), G.indicator(G.NOSE_UP, true), 1e-6, "FMC trim 9.2: the nose up band")
rt:set("laminar/B747/fmc/elevator_trim", 2.6)
frames(0.2)
T.near(get(IND), G.indicator(G.NOSE_DOWN, true), 1e-6, "FMC trim 2.6: the nose down band")
rt:set("laminar/B747/fmc/elevator_trim", 6.0)
frames(0.2)
T.near(get(IND), G.indicator(G.MID, true), 1e-6, "FMC trim 6.0: the mid band")
rt:set("laminar/B747/fmc/elevator_trim", 9.2)
rt:set("laminar/B747/airspeed/V1", 140)
fly(150, 0.22, 0.2)
T.near(get(IND), G.indicator(G.MID, true), 1e-6, "above V1: the lights out, the painted mid band")
rt:set("laminar/B747/airspeed/V1", 0)
rt:set("laminar/B747/fmc/elevator_trim", 0)
fly(0, 0, 0.2)

-- the speedbrakes (B747.45.xt.speedbrake.lua, step 3): armed on the ground
-- with thrust levers 1 and 3 idle, the auto speedbrake drives the lever to
-- UP and X-Plane's ratio follows (never -0.5: X-Plane's own auto speedbrake
-- stays out); thrust lever 1 advanced drives it to DN; >SPEEDBRAKES EXT;
-- SPEEDBRAKE AUTO; X-Plane's ratio moved by an axis moves the lever
local SB = "laminar/B747/flt_ctrls/speedbrake_lever"
local XSB = "sim/cockpit2/controls/speedbrake_ratio"
local MEMO = "laminar/B747/CAS/memo_status"
-- in the air: ARM, an axis, >SPEEDBRAKES EXT below 800 ft RA
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("laminar/B747/gear/air_ground/alt_gnd", 0)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 5000)
rt:set(SB, 0.125)
frames(0.2)
T.equal(get(MEMO, 45), 1, "lever at ARM: SPEEDBRAKE ARMED")
T.equal(get(XSB), 0, "X-Plane's ratio at ARM: 0, not armed (-0.5)")
T.equal(get(SB), 0.125, "in the air: stays at ARM")
rt:set(XSB, 0.5)
frames(0.2)
T.near(get(SB), 0.15 + 0.5 * (0.53 - 0.15), 1e-6, "X-Plane's ratio moved from outside (an axis): the lever follows (in-flight travel)")
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 500)
frames(0.2)
T.equal(get(CAUTION, 59), 1, "speedbrake out at 500 ft RA: >SPEEDBRAKES EXT")
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 5000)
frames(0.2)
T.equal(get(CAUTION, 59), 0, "5000 ft, idle, flaps up: none")
-- two thrust levers at climb thrust (35 of 50 degrees) with the speedbrake
-- out: >SPEEDBRAKES EXT; CONFIG SPOILERS in flight on the 405 and 570 only
-- (FCOM p.1558)
local WARNING = "laminar/B747/CAS/warning_status"
local THRUST = "laminar/B747/engine/throttle"
rt:set(THRUST, 0, 0.8)
rt:set(THRUST, 1, 0.8)
frames(0.2)
T.equal(get(CAUTION, 59), 1, "two thrust levers above the speedbrake power level: >SPEEDBRAKES EXT")
T.equal(get(WARNING, 6), 0, "the 109: no CONFIG SPOILERS in flight")
rt:set("laminar/B747/freighter", 1)
frames(0.2)
T.equal(get(WARNING, 6), 1, "the 405 and 570: CONFIG SPOILERS in flight")
rt:set(THRUST, 1, 0.6)
frames(0.2)
T.equal(get(WARNING, 6), 0, "three levers below climb thrust: none")
rt:set("laminar/B747/freighter", 0)
rt:set(THRUST, 0, 0)
rt:set(THRUST, 1, 0)
frames(0.2)
rt:set(SB, 0.125)
frames(0.2)
-- touchdown armed with thrust levers 1 and 3 idle: the auto speedbrake
-- drives the lever to UP; thrust lever 1 advanced drives it to DN
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("laminar/B747/gear/air_ground/alt_gnd", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 0)
frames(2.5)
T.equal(get(SB), 1, "touchdown, thrust levers idle: driven to UP")
T.near(get(XSB), 1, 1e-6, "X-Plane's ratio 1")
T.equal(get(MEMO, 45), 0, "no SPEEDBRAKE ARMED at UP")
rt:set("sim/cockpit2/engine/actuators/throttle_ratio", 0, 0.5)
frames(1)
T.equal(get(SB), 1, "X-Plane's throttle ratio is the input, not the lever (the EEC writes the levers' average there with the A/T on): stays UP")
rt:set("sim/cockpit2/engine/actuators/throttle_ratio", 0, 0)
rt:set(THRUST, 0, 0.5)
frames(2.5)
T.equal(get(SB), 0, "thrust lever 1 advanced: driven to DN")
T.equal(get(XSB), 0, "X-Plane's ratio 0")
rt:set(XSB, 1e-6)
frames(0.1)
T.equal(get(XSB), 0, "a residue near 0 (the lever passing the arm detent between frames): cleared")
rt:set(THRUST, 0, 0)
-- on the ground with the alternate sensing in the air: SPEEDBRAKE AUTO
rt:set("laminar/B747/gear/air_ground/alt_gnd", 0)
frames(3.5)
T.equal(get(ADVISORY, 272), 1, "primary and alternate ground sensing disagreeing: SPEEDBRAKE AUTO")
T.equal(get(STATUS, 94), 1, "STATUS SPEEDBRAKE AUTO")
rt:set("laminar/B747/gear/air_ground/alt_gnd", 1)
frames(3.5)
T.equal(get(ADVISORY, 272), 0, "agreeing: no SPEEDBRAKE AUTO")

-- the lever between detents snaps to the nearest one 2 s after it stops
rt:set(LEVER, 0.31)
frames(1)
T.near(get(LEVER), 0.31, 0.001, "lever between detents: not yet")
frames(1.5)
T.near(get(LEVER), 0.333, 0.001, "2 s later: snapped to flaps 5")


-- the yaw dampers (4-1 step 4): the switch, the FCE power (upper: the AC
-- standby and battery buses; lower: AC 1 and DC 1, ATA27 p.20-22), an IRU
-- aligned in NAV or ATT, no fault; otherwise INOP and >YAW DAMPER UPR, LWR
-- (FCOM p.931, p.958)
local YD_SW = "laminar/B747/button_switch/position"
-- (the IRUs' attitude: the navigation sensors module, laminar/B747/irs/att_valid)
local IRU_ATT = "laminar/B747/irs/att_valid"
local UPR, LWR = "laminar/B747/flt_ctrls/yaw_damper_upr_on", "laminar/B747/flt_ctrls/yaw_damper_lwr_on"
local YD_FAIL = "laminar/B747/flt_ctrls/fail/yaw_damper"
rt:set(YD_SW, 82, 1)
rt:set(YD_SW, 83, 1)
rt:set("laminar/B747/electrical/bus/stby_main", 1)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
for i = 0, 2 do rt:set(IRU_ATT, i, 0) end
frames(0.2)
T.equal(get(UPR), 0, "IRUs aligning: upper yaw damper inoperative")
T.equal(get(ADVISORY, 301), 1, ">YAW DAMPER UPR")
T.equal(get(ADVISORY, 300), 1, ">YAW DAMPER LWR")
rt:set(IRU_ATT, 1, 1)
frames(0.2)
T.equal(get(UPR), 1, "an IRU's attitude (NAV, or ATT after its 30 s): upper on")
T.equal(get(LWR), 1, "lower on")
T.equal(get(ADVISORY, 301), 0, "no >YAW DAMPER UPR")
rt:set("laminar/B747/electrical/bus/stby_main", 0)
frames(0.2)
T.equal(get(UPR), 0, "AC standby bus lost: upper inoperative (left FCE power supplies)")
T.equal(get(LWR), 1, "the lower one stays on")
rt:set("laminar/B747/electrical/bus/stby_main", 1)
rt:set("laminar/B747/electrical/bus/ac", 0, 0)
frames(0.2)
T.equal(get(LWR), 0, "AC bus 1 lost: lower inoperative (right FCE power supply 1R)")
T.equal(get(ADVISORY, 300), 1, ">YAW DAMPER LWR")
T.equal(get(UPR), 1, "the upper one stays on")
rt:set("laminar/B747/electrical/bus/ac", 0, 1)
rt:set(YD_FAIL, 0, 1)
frames(0.2)
T.equal(get(UPR), 0, "upper module fault: inoperative")
rt:set(YD_FAIL, 0, 0)
rt:set(YD_SW, 83, 0)
frames(0.2)
T.equal(get(LWR), 0, "lower switch OFF: inoperative")
rt:set(YD_SW, 83, 1)
frames(0.2)
T.equal(get(UPR) + get(LWR), 2, "both on again")

-- CONFIG GEAR CTR (4-2 step 4): a body gear truck unlocked (the gear
-- module's steering), on the ground under V1, three fuel control switches in
-- RUN, engine 2 or 3 in the takeoff range (FCOM p.1603)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/airspeed/V1", 150)
rt:set(IAS, 0)
for i = 0, 3 do rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", i, 1) end
rt:set("laminar/B747/engines/display_N1", 1, 98)
rt:set("laminar/B747/gear/steering/body_unlocked", 1)
frames(0.2)
T.equal(get(WARNING, 4), 1, "body gear unlocked, engine 2 at takeoff thrust: CONFIG GEAR CTR")
rt:set("laminar/B747/engines/display_N1", 1, 30)
rt:set("laminar/B747/engines/display_N1", 2, 98)
frames(0.2)
T.equal(get(WARNING, 4), 1, "engine 3 alone: CONFIG GEAR CTR (2 or 3)")
rt:set("laminar/B747/gear/steering/body_unlocked", 0)
frames(0.2)
T.equal(get(WARNING, 4), 0, "locked: none")
rt:set("laminar/B747/engines/display_N1", 2, 0)
rt:set("laminar/B747/airspeed/V1", 0)
T.done()
