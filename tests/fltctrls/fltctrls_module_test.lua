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
-- (2026-11-12 review FG-5) the air data module's ADC L, C, R valid (the SRMs
-- and FCUs read them; that module is not loaded here)
local AD_VALID = "laminar/B747/airdata/valid"
for i = 0, 2 do rt:set(AD_VALID, i, 1) end
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
local LE_BOX, TE_TAPE = "laminar/B747/flt_ctrls/flaps/le_box", "laminar/B747/flt_ctrls/flaps/te_tape"
local ALTN_DISPLAY = "laminar/B747/flt_ctrls/flaps/altn_display"
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
-- (2026-11-12 review FG-5) the FCUs' air data (ATA27 p.288, p.337): ADC L
-- failed, the F/O's side's speed instead (the captain's, failed, reads 190
-- kt); both failed: no load relief and STATUS FLAP LOAD RELIEF. Before,
-- the captain's speed always, valid always
rt:set(AD_VALID, 0, 0)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", 160)
at(190)
T.near(get(CMD), F30, 0.001, "ADC L failed (190 kt on its side), the F/O's 160 kt: flaps 30, no relief")
rt:set(AD_VALID, 2, 0)
at(210)
T.near(get(CMD), F30, 0.001, "both ADCs failed: no load relief (ATA27 p.337)")
T.equal(get(STATUS, 87), 1, "both ADCs failed: STATUS FLAP LOAD RELIEF")
for i = 0, 2 do rt:set(AD_VALID, i, 1) end
at(168)
T.equal(get(STATUS, 87), 0, "the ADCs back: no STATUS FLAP LOAD RELIEF")
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
-- the expanded display (FCTL-12): the outboard boxes striped while the
-- electric drive moves them, the inboard ones green
T.equal(get(DISPLAY), 2, "outboard LE electric: expanded indication")
T.equal(get(LE_BOX, 0), 1, "L outboard LE box striped (in transit)")
T.equal(get(LE_BOX, 5), 1, "R outboard LE box striped")
T.equal(get(LE_BOX, 2), 2, "L inboard LE box green (extended)")
T.equal(get(TE_TAPE, 0), 0, "TE tapes white")
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
T.equal(get(ALTN_DISPLAY), 1, "ALTN ARM: the alternate display (no lever mark, the flap scale)")
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
T.equal(get(ALTN_DISPLAY), 0, "disarmed: no alternate display")

-- a TE position sensor without data: its tape's amber X, STATUS FLAP SYS
-- MONITOR; the standby power system alone: the left wing's tapes (ATA27 p.320)
rt:set("laminar/B747/flt_ctrls/fail/te_sensor", 2, 1)
frames(1)
T.equal(get(TE_TAPE, 2), 2, "R IB sensor failed: amber X")
T.equal(get(STATUS, 99), 1, "STATUS FLAP SYS MONITOR")
T.equal(get(DISPLAY), 2, "expanded indication")
rt:set("laminar/B747/flt_ctrls/fail/te_sensor", 2, 0)
frames(1)
T.equal(get(STATUS, 99), 0, "data back: no FLAP SYS MONITOR")
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/ac", i, 0) end
rt:set("laminar/B747/electrical/bus/stby_main", 1)
frames(1)
T.equal(get(TE_TAPE, 0), 2, "standby power alone: L OB tape amber X")
T.equal(get(TE_TAPE, 1), 2, "L IB tape amber X")
T.equal(get(TE_TAPE, 3), 0, "R OB tape white")
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/ac", i, 1) end
frames(1)
T.equal(get(TE_TAPE, 0), 0, "AC back: L OB tape white")

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
-- (2026-11-12 review FG-5) ADC L failed (the air data module's validity):
-- the SRMs go on with ADC R (ATA27 p.104), the ratio by the speed as
-- before; both failed: the lower at the 209 kt position. Before, X-Plane's
-- ADC 1 failure alone took both sides away (the 209 kt position)
rt:set(AD_VALID, 0, 0)
fly(200, 0.35, 8)
T.near(get("laminar/B747/flt_ctrls/rudder_ratio_lwr"), (32 - 27 * B747_srm_model_test_rrc(200)) / 32, 1e-6, "ADC L failed: ADC R still gives the speed (200 kt), the schedule's ratio")
T.equal(get(STATUS, 93), 0, "ADC L failed: no STATUS STAB SPEED TRIM")
rt:set(AD_VALID, 2, 0)
fly(200, 0.35, 8)
T.near(get("laminar/B747/flt_ctrls/rudder_ratio_lwr"), (32 - 27 * B747_srm_model_test_rrc(209)) / 32, 1e-6,
    "ADC L and R failed: lower at the 209 kt position")
for i = 0, 2 do rt:set(AD_VALID, i, 1) end

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
-- (2026-11-12 review D-1) X-Plane standing still 10 s (XTLua's worker goes
-- on ticking: init.lua's gate): the stabilizer 0.12 s worth at most (before,
-- 10 s worth at once when X-Plane went on), then nothing more while it stays
-- still. (Before, 2026-10-31, one frame of SIM_PERIOD 2 was tested: XTLua's
-- SIM_PERIOD is always 0.02.)
local u2 = units()
rt:still(10)
T.check(units() - u2 <= 0.25 * 0.13 + 1e-6, string.format("X-Plane still 10 s: %.4f units, 0.12 s worth at most", units() - u2))
local u3 = units()
rt:still(10)
T.near(units(), u3, 1e-9, "still 10 s more: the stabilizer does not move")
frames(0.5)
T.check(units() > u3 + 0.05, "X-Plane going on: the autotrim goes on")
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
-- the flight's start: X-Plane's trim followed on the ground; an air start
-- keeps 7.5 units (X-Plane trims for its own trim there: 0.5 at FL350)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:callout("flight_start")
rt:set(TRIM, 0.2)
frames(1)
T.near(units(), 9, 1e-6, "a start on the ground: the stabilizer follows X-Plane's trim (9 units)")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:callout("flight_start")
rt:set(TRIM, 0.5)
frames(1)
T.near(units(), 7.5, 1e-6, "an air start: X-Plane's trim 0.5 not followed (7.5 units)")
T.near(get(TRIM), 0, 1e-6, "X-Plane's trim written back to 0")
frames(4)
T.near(units(), 7.5, 1e-6, "after the start's 3 s: still 7.5 units")
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)

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
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
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
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
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


-- >YAW DAMPER UPR, LWR (FCOM p.958): the yaw damper modules' INOP, which
-- the yaw damper model writes (the hydraulics module, 6-3 step 6a:
-- tests/autopilot/yd_model_test.lua, tests/hyd/hyd_module_test.lua; before,
-- this module decided it)
local UPR, LWR = "laminar/B747/flt_ctrls/yaw_damper_upr_on", "laminar/B747/flt_ctrls/yaw_damper_lwr_on"
rt:set(UPR, 0)
rt:set(LWR, 1)
frames(0.2)
T.equal(get(ADVISORY, 301), 1, "upper INOP: >YAW DAMPER UPR")
T.equal(get(ADVISORY, 300), 0, "no >YAW DAMPER LWR")
rt:set(UPR, 1)
rt:set(LWR, 0)
frames(0.2)
T.equal(get(ADVISORY, 301), 0, "no >YAW DAMPER UPR")
T.equal(get(ADVISORY, 300), 1, "lower INOP: >YAW DAMPER LWR")
rt:set(LWR, 1)
frames(0.2)
T.equal(get(ADVISORY, 300), 0, "both engaged: none")

-- CONFIG GEAR CTR (4-2 step 4): a body gear truck unlocked (the gear
-- module's steering), on the ground under V1, three fuel control switches in
-- RUN, engine 2 or 3 in the takeoff range (FCOM p.1603)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
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

-- CONFIG GEAR (GEAR-17; FCOM p.1557-1558): in flight with a gear not down
-- and locked (the PSEU's ALL GR DN). For a thrust lever closed below 800 ft
-- it stays until the levers are advanced or the gear is down; for the
-- landing flaps until the gear is down or GND PROX GEAR OVRD is pushed
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local THROTTLE = "laminar/B747/engine/throttle"
local GEAR_OVRD = 5                    -- button_switch/position: GND PROX GEAR OVRD
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
for i = 0, 3 do rt:set(THROTTLE, i, 0.5) end
rt:set(RA, 300)
frames(0.2)
-- the liftoff: inhibited until 800 ft or 140 s (FCOM p.1594-1595)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("laminar/B747/gear/air_ground/all_gear_down", 0)
rt:set(IAS, 150)
rt:set(THROTTLE, 1, 0)
frames(10)
T.equal(get(WARNING, 3), 0, "10 s after the liftoff, 300 ft, a thrust lever closed, gear up: inhibited")
rt:set(RA, 900)
frames(0.2)
rt:set(THROTTLE, 1, 0.5)
rt:set(RA, 700)
frames(0.2)
T.equal(get(WARNING, 3), 0, "gear up at 700 ft, thrust levers advanced: no CONFIG GEAR")
rt:set(THROTTLE, 1, 0)
frames(0.2)
T.equal(get(WARNING, 3), 1, "a thrust lever closed below 800 ft: CONFIG GEAR")
rt:set(RA, 1500)
frames(0.2)
T.equal(get(WARNING, 3), 1, "above 800 ft with the lever still closed: CONFIG GEAR stays")
rt:set(THROTTLE, 1, 0.5)
frames(0.2)
T.equal(get(WARNING, 3), 0, "the thrust levers advanced: gone")
rt:set("laminar/B747/button_switch/position", GEAR_OVRD, 1)
rt:set(THROTTLE, 1, 0)
rt:set(RA, 500)
frames(0.2)
T.equal(get(WARNING, 3), 1, "GND PROX GEAR OVRD: the thrust lever's CONFIG GEAR stays")
rt:set("laminar/B747/gear/air_ground/all_gear_down", 1)
frames(0.2)
T.equal(get(WARNING, 3), 0, "gear down and locked: gone")
rt:set("laminar/B747/button_switch/position", GEAR_OVRD, 0)
rt:set(THROTTLE, 1, 0.5)
rt:set("laminar/B747/gear/air_ground/all_gear_down", 0)
rt:set(RA, 1500)
rt:set(LEVER, F25)
frames(40)
T.equal(get(WARNING, 3), 1, "flaps 25 with the gear up: CONFIG GEAR")
rt:set("laminar/B747/button_switch/position", GEAR_OVRD, 1)
frames(0.2)
T.equal(get(WARNING, 3), 0, "GND PROX GEAR OVRD pushed: the flaps' CONFIG GEAR gone")
rt:set("laminar/B747/button_switch/position", GEAR_OVRD, 0)
frames(0.2)
T.equal(get(WARNING, 3), 1, "the switch back with the flaps still at 25: CONFIG GEAR again")
rt:set(LEVER, F20)
frames(20)
-- (2026-11-12 review SF-2) the flaps out of the landing range: gone
-- (ATA31 p.212); before, kept until the gear was down
T.equal(get(WARNING, 3), 0, "flaps back to 20: the flaps' CONFIG GEAR gone (ATA31 p.212)")
rt:set("laminar/B747/gear/air_ground/all_gear_down", 1)
frames(0.2)
T.equal(get(WARNING, 3), 0, "gear down: gone")
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set(IAS, 0)
for i = 0, 3 do rt:set(THROTTLE, i, 0) end
rt:set(RA, 0)

-- CONFIG FLAPS (WARN-11; FCOM p.1603, ATA27 p.730, ATA31 p.193): the
-- trailing edge at 10 or 20 by the FCU's flap position in the detents'
-- numbers (X-Plane's wing flap angles differ since the lift correction:
-- flaps 20 is 15.1 degrees there, notes/AERO.md §3.12), all leading edge
-- groups out and the lever there too; armed by engine 2 or 3 at takeoff
-- thrust (N1 66.5 on the P&W), also without a V1 (until 5 degrees of
-- pitch); the FMC's takeoff flaps are not compared (no source)
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
rt:set(LEVER, F20)
frames(90)
T.near(get(FCU .. "flap_pos"), 20, 1e-6, "lever 20: the flaps' position 20")
rt:set("sim/flightmodel2/wing/flap1_deg", 0, 15.1)
rt:set("laminar/B747/airspeed/V1", 150)
rt:set("laminar/B747/engines/display_N1", 1, 70)
rt:set("laminar/B747/airspeed/flapsRef", 10)
frames(0.2)
T.equal(get(WARNING, 2), 0, "flaps 20 (X-Plane's wing at 15.1 degrees), engine 2 at N1 70: no CONFIG FLAPS (the FMC's 10 not compared)")
rt:set(LEVER, 0.5)
frames(2)
T.equal(get(WARNING, 2), 1, "the lever at 10, the flaps still near 20: CONFIG FLAPS (lever and flaps apart)")
frames(60)
T.near(get(FCU .. "flap_pos"), 10, 1e-6, "lever 10: 10")
T.equal(get(WARNING, 2), 0, "flaps 10: none")
rt:set("laminar/B747/airspeed/flapsRef", 0)
rt:set(LEVER, F25)
frames(60)
T.near(get(FCU .. "flap_pos"), 25, 1e-6, "lever 25 (the panels at 22 degrees): 25")
T.equal(get(WARNING, 2), 1, "flaps 25: CONFIG FLAPS")
rt:set("laminar/B747/airspeed/V1", 0)
frames(0.2)
T.equal(get(WARNING, 2), 1, "no V1: still armed (ATA31 p.188)")
rt:set("laminar/B747/engines/display_N1", 1, 30)
frames(9)
T.equal(get(WARNING, 2), 1, "the takeoff thrust gone: CONFIG FLAPS stays 10 s (ATA27 p.730)")
frames(1.5)
T.equal(get(WARNING, 2), 0, "10 s after: gone")
rt:set("laminar/B747/engines/display_N1", 1, 0)

-- the configuration warning card failed (the failure window, notes/
-- ATA-27.md §20; FCOM p.1558, p.1604, ATA31 p.270): no CONFIG warnings,
-- >CONFIG WARN SY and the STATUS CONFIG WARN SY, the greenband lamps out
local CFG_FAIL = "laminar/B747/flt_ctrls/fail/config_warn"
rt:set("laminar/B747/engines/display_N1", 1, 70)
rt:set("laminar/B747/fmc/elevator_trim", 9.2)
frames(0.2)
T.equal(get(WARNING, 2), 1, "flaps 25 at takeoff thrust: CONFIG FLAPS")
T.equal(get(ADVISORY, 52), 0, "the card working: no >CONFIG WARN SY")
T.near(get(IND), G.indicator(G.NOSE_UP, true), 1e-6, "the nose up band lit")
rt:set(CFG_FAIL, 1)
frames(0.2)
T.equal(get(WARNING, 2), 0, "the card failed: no CONFIG FLAPS")
T.equal(get(ADVISORY, 52), 1, "the card failed: >CONFIG WARN SY")
T.equal(get(STATUS, 146), 1, "the STATUS CONFIG WARN SY")
T.near(get(IND), G.indicator(G.MID, false), 1e-6, "the card failed: the lamps out, the painted mid band")
rt:set(CFG_FAIL, 0)
frames(0.2)
T.equal(get(WARNING, 2), 1, "repaired: CONFIG FLAPS again")
T.equal(get(ADVISORY, 52), 0, "repaired: no >CONFIG WARN SY")
T.equal(get(STATUS, 146), 0, "repaired: no STATUS")
T.near(get(IND), G.indicator(G.NOSE_UP, true), 1e-6, "repaired: the nose up band lit again")
rt:set("laminar/B747/engines/display_N1", 1, 0)
frames(11)
T.equal(get(WARNING, 2), 0, "the thrust gone 10 s: CONFIG FLAPS gone")

-- the greenband nose gear pressure switch failed (ATA27 p.510, ATA31
-- p.201-202, FCOM p.958): reading AFT CG against the nose up band or FWD
-- CG against the nose down band, >STAB GREENBAND and its STATUS; the mid
-- band is not compared, nor in the air
local GB_SW = "laminar/B747/flt_ctrls/fail/greenband_switch"
rt:set(GB_SW, 1)
frames(0.2)
T.equal(get(ADVISORY, 273), 0, "the nose up band, the switch reading FWD: agree, none")
rt:set(GB_SW, 2)
frames(0.2)
T.equal(get(ADVISORY, 273), 1, "the nose up band, the switch reading AFT: >STAB GREENBAND")
T.equal(get(STATUS, 147), 1, "the STATUS STAB GREENBAND")
rt:set("laminar/B747/fmc/elevator_trim", 6.0)
frames(0.2)
T.equal(get(ADVISORY, 273), 0, "the mid band: not compared")
rt:set("laminar/B747/fmc/elevator_trim", 2.6)
frames(0.2)
T.equal(get(ADVISORY, 273), 0, "the nose down band, the switch reading AFT: agree")
rt:set(GB_SW, 1)
frames(0.2)
T.equal(get(ADVISORY, 273), 1, "the nose down band, the switch reading FWD: >STAB GREENBAND")
rt:set(CFG_FAIL, 1)
frames(0.2)
T.equal(get(ADVISORY, 273), 0, "the card failed too: nothing compared")
rt:set(CFG_FAIL, 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(0.2)
T.equal(get(ADVISORY, 273), 0, "in the air: not compared")
T.equal(get(STATUS, 147), 0, "in the air: no STATUS")
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
frames(0.2)
T.equal(get(ADVISORY, 273), 1, "on the ground again: >STAB GREENBAND")
rt:set(GB_SW, 0)
frames(0.2)
T.equal(get(ADVISORY, 273), 0, "repaired: none")
T.equal(get(STATUS, 147), 0, "repaired: no STATUS")
rt:set("laminar/B747/fmc/elevator_trim", 0)
frames(0.2)

-- an air start: the stabilizer for level flight at the speed (estimate:
-- 3.78 + 154,400 / IAS^2 units, 4.5 to 7.5), not the 7.5 units of before
-- (a 334 kt start pitched up to 13 degrees before the A/P came on)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
for _, c in ipairs({{334, 3.78 + 154400 / 334 ^ 2}, {231, 3.78 + 154400 / 231 ^ 2}, {150, 7.5}}) do
    rt:set("sim/flightmodel/position/indicated_airspeed", c[1])
    rt:callout("flight_start")
    frames(1)
    T.near(units(), c[2], 0.01, "air start at " .. c[1] .. " kt: " .. string.format("%.2f", c[2]) .. " units")
    T.near(get(TRIM), units() / 7.5 - 1, 1e-6, "X-Plane's trim written (" .. c[1] .. " kt)")
end
rt:set("sim/flightmodel/position/indicated_airspeed", 334)
rt:callout("flight_start")
frames(4)
local u = units()
rt:set("sim/flightmodel/position/indicated_airspeed", 250)
frames(1)
T.near(units(), u, 1e-6, "after the start's 3 s the speed no longer sets it")
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)

-- the gear's drag (補正, B747.45.xt.aero_corr.lua): X-Plane's fuselage drag
-- coefficient from the acf's own value, read on the first frame it is
-- there, and the gear's mean extension; laminar/B747/debug/aero_corr_off 1
-- leaves the correction out
local FUSE = "sim/aircraft/bodies/acf_fuse_cd"
local GEAR = "sim/flightmodel2/gear/deploy_ratio"
T.equal(get(FUSE), 0, "no fuselage drag figure yet: nothing written")
for i = 0, 4 do rt:set(GEAR, i, 1) end
rt:set(FUSE, 0.085)
frames(0.1)
local added = 0.0044 / 0.0664
T.near(get(FUSE), 0.085 + added, 1e-6, "gear down: the acf's 0.085 + 0.066")
frames(0.5)
T.near(get(FUSE), 0.085 + added, 1e-6, "the frames after: the same, not added again")
-- (2026-11-11 review) the scripts going (XTLua's aircraft_unload): the
-- acf's own back (a reloaded module reads it, not the corrected one)
rt:callout("aircraft_unload")
T.near(get(FUSE), 0.085, 1e-6, "aircraft_unload: the acf's own back")
frames(0.1)
T.near(get(FUSE), 0.085 + added, 1e-6, "the next frame: corrected again from it")
for i = 0, 1 do rt:set(GEAR, i, 0) end
frames(0.1)
T.near(get(FUSE), 0.085 + 0.6 * added, 1e-6, "three legs of five down: 0.6")
rt:set("laminar/B747/debug/aero_corr_off", 1)
frames(0.1)
T.near(get(FUSE), 0.085, 1e-6, "aero_corr_off 1: the acf's own")
rt:set("laminar/B747/debug/aero_corr_off", 0)
for i = 0, 4 do rt:set(GEAR, i, 0) end
frames(0.1)
T.near(get(FUSE), 0.085, 1e-6, "gear up: the acf's own")
-- (2026-11-07) the cruise above about M.83 by the Mach, the weight and the
-- lift (the dynamic pressure, Pa) (B747.45.aero_corr_model.lua's cd_mach),
-- off with aero_corr_off
local AC = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua")
local Q350 = 0.7 * 23842 * 0.86 ^ 2     -- FL350, M.86: 12,344 Pa
rt:set("sim/flightmodel/misc/machno", 0.86)
rt:set("sim/flightmodel/weight/m_total", 306000)
rt:set("sim/flightmodel/misc/Qstatic", Q350)
frames(0.1)
local cl350 = 306000 * 9.80665 / (Q350 * 541.2)
T.near(cl350, 0.449, 0.001, "FL350, M.86, 306 t: CL 0.449")
T.near(get(FUSE), 0.085 - AC.cd_mach(0.86, 306000, cl350) / AC.CD_PER_FUSE_CD, 1e-6, "M.86, 306 t: the acf's less the excess at its lift")
T.check(get(FUSE) < 0.05, "well under the acf's (" .. get(FUSE) .. ")")
rt:set("laminar/B747/debug/aero_corr_off", 1)
frames(0.1)
T.near(get(FUSE), 0.085, 1e-6, "aero_corr_off 1: the acf's own at M.86 too")
rt:set("laminar/B747/debug/aero_corr_off", 0)
rt:set("sim/flightmodel/misc/machno", 0.80)
frames(0.1)
T.near(get(FUSE), 0.085 - AC.cd_mach(0.80, 306000, cl350) / AC.CD_PER_FUSE_CD, 1e-6, "M.80 (the same lift): the FCOM's part only")
T.near(get(FUSE), 0.085, 0.002, "M.80: about the acf's own")
rt:set("sim/flightmodel/misc/machno", 0.60)
frames(0.1)
T.near(get(FUSE), 0.085, 1e-6, "M.60: the acf's own")
-- light and low (CL 0.29, under the FCOM's cells): the FCOM's wall later
-- (C_KC a unit of CL)
rt:set("sim/flightmodel/misc/machno", 0.86)
rt:set("sim/flightmodel/weight/m_total", 237000)
local Q310 = 0.7 * 28745 * 0.86 ^ 2     -- FL310, M.86
rt:set("sim/flightmodel/misc/Qstatic", Q310)
frames(0.1)
local cl310 = 237000 * 9.80665 / (Q310 * 541.2)
T.near(cl310, 0.29, 0.005, "237 t FL310 M.86: CL " .. string.format("%.3f", cl310) .. ", under the cells' 0.41")
T.near(get(FUSE), 0.085 - AC.cd_mach(0.86, 237000, cl310) / AC.CD_PER_FUSE_CD, 1e-6, "237 t FL310 M.86: the acf's less the excess at its lift")
T.done()
