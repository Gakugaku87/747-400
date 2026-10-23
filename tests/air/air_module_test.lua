-- Run from the repository root with LuaJIT: luajit tests/air/air_module_test.lua
-- The air conditioning module as XTLua runs it (tests/lib/xtlua.lua), with
-- the pack and pressurization models through their glue (B747.55.xt.packs.lua,
-- B747.55.xt.press.lua): the PACK selectors, the bleed air, the CABIN
-- ALTITUDE panel, the FMC's route and the buses in; the pack valves and
-- count, X-Plane's cabin (override_pressurization), ducts and bleed loss,
-- the outflow valve gauges, the landing altitude, the EICAS slots and the
-- ECS data block out. The models' behaviour is tested in pack_model_test.lua
-- and press_model_test.lua; this checks the wiring and the names
-- (docs/overhaul/notes/ATA-21.md §6).
local T = dofile("tests/lib/check.lua")("air_module")
local xtlua = dofile("tests/lib/xtlua.lua")

-- made-up airports for the FMC's route (the module reads X-Plane's list)
B747_AIR_APTMETA = {"tests/air/data/aptmeta_test.dat"}

local rt = xtlua.new()
local air = rt:load("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.xt.air.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local AIR = "laminar/B747/air/"
local SW = "laminar/B747/button_switch/position"
local PACK = "laminar/B747/air/pack_ctrl/sel_dial_pos"
local MEMO = "laminar/B747/CAS/memo_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"

-- power, on the ground at sea level, APU air, three packs NORM
frames(0.5)
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/electrical/bus/any_ac", 1)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/hot_bat_apu", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("laminar/B747/gear/air_ground/alt_gnd", 1)
rt:set("sim/weather/aircraft/barometer_current_pas", 101325)
rt:set("sim/flightmodel2/position/pressure_altitude", 0)
rt:set("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot", 29.92)
rt:set(AIR .. "landing_alt/button_pos", 1)
rt:set(SW, 38, 1)           -- UPR, LWR RECIRC
rt:set(SW, 39, 1)
for i = 75, 81 do rt:set(SW, i, 1) end
for i = 0, 2 do rt:set(PACK, i, 1) end
rt:set("laminar/B747/electrical/apu/sel_dial_pos", 1)
rt:set("sim/cockpit2/electrical/APU_N1_percent", 100)
frames(10)

-- the packs
for i = 0, 2 do T.equal(get(AIR .. "pack/valve_pos", i), 1, "APU air: pack " .. (i + 1) .. " valve open") end
T.equal(get(AIR .. "packs_operating"), 3, "three packs operating (the EEC reads it)")
T.equal(get(AIR .. "pack/high_flow", 0), 1, "on the ground: high flow")
T.equal(get(AIR .. "pack/ptc", 0), 1, "NORM: controller A")
T.check(get(AIR .. "duct_pressure_C") > 28 and get(AIR .. "duct_pressure_C") < 34, "APU and three packs at high flow: about 30 psi (FCOM p.895)")
T.equal(get(AIR .. "recirc_fan", 0), 1, "ground: upper fans on")
T.equal(get(AIR .. "recirc_fan", 2), 0, "ground: lower fans off")

-- X-Plane's cabin, ducts and bleed loss while its pressurization is taken over
T.equal(get("sim/operation/override/override_pressurization"), 1, "X-Plane's pressurization taken over")
T.check(math.abs(get("sim/cockpit/pressure/cabin_altitude_actual_ft")) < 100, "X-Plane's cabin altitude at the field")
T.check(get("sim/cockpit/pressure/cabin_pressure_differential_psi") >= 0 and get("sim/cockpit/pressure/cabin_pressure_differential_psi") < 0.05,
    "X-Plane's ΔP: a few hundredths of a psi")
T.equal(get("sim/cockpit/pressure/outflow_valve"), 1, "X-Plane's outflow valve: open")
T.equal(get(AIR .. "outflow_valve_left/pos"), 1, "the left gauge: +1, open")
T.equal(get(AIR .. "outflow_valve_right/pos"), 1, "the right gauge: +1, open")
T.near(get("sim/cockpit2/bleedair/indicators/bleed_available_center"), get(AIR .. "duct_pressure_C") / 27.5, 0.01,
    "X-Plane's centre duct: the pressure over 27.5 psi")
T.near(get("sim/cockpit2/bleedair/indicators/APU_loss_from_bleed_air_ratio"), 45, 0.5, "APU bleed loss: 15 per pack of flow, three packs")
T.equal(get("sim/cockpit2/bleedair/indicators/engine_loss_from_bleed_air_ratio", 0), 0, "engines not running: no engine bleed loss")

-- pack memos (FCOM p.622)
for i = 18, 25 do T.equal(get(MEMO, i), 0, "three packs on: no pack memo " .. i) end
rt:set(PACK, 0, 0)
frames(0.5)
T.equal(get(MEMO, 18), 1, "PACK 1 OFF")
rt:set(PACK, 1, 0)
frames(0.5)
T.check(get(MEMO, 21) == 1 and get(MEMO, 18) == 0 and get(MEMO, 19) == 0, "PACKS 1 + 2 OFF, not PACK 1 OFF, PACK 2 OFF")
rt:set(PACK, 2, 0)
frames(0.5)
T.check(get(MEMO, 25) == 1 and get(MEMO, 21) == 0, "PACKS OFF")
frames(4)
T.equal(get(AIR .. "packs_operating"), 0, "packs off: none operating")
for i = 0, 2 do rt:set(PACK, i, 1) end
rt:set(SW, 41, 1)
frames(4)
T.equal(get(MEMO, 24), 1, "HI FLOW: PACKS HIGH FLOW")
rt:set(SW, 41, 0)
rt:set(SW, 84, 1)
frames(4)
T.equal(get(AIR .. "pack/valve_pos", 2), 0, "FWD cargo fire ARM: pack 3 off (FCOM p.908)")
rt:set(SW, 84, 0)
frames(4)

-- equipment cooling: NORM runs the fans (laminar/B747/air/equip_cooling/state);
-- OVRD on the ground: no differential pressure, EQUIP COOLING after 55 s
-- (FCOM p.558, p.619; ATA21 p.594-598)
rt:set(AIR .. "equip_cooling/sel_dial_pos", 1)
frames(1)
T.equal(get(AIR .. "equip_cooling/state"), 1, "EQUIP COOLING NORM: fans running")
rt:set(AIR .. "equip_cooling/sel_dial_pos", 2)
frames(54)
T.equal(get(AIR .. "equip_cooling/state"), 0, "EQUIP COOLING OVRD: fans off")
T.equal(get("laminar/B747/CAS/caution_status", 27), 0, "OVRD on the ground 54 s: no EQUIP COOLING yet")
frames(2)
T.equal(get("laminar/B747/CAS/caution_status", 27), 1, "OVRD on the ground 56 s: EQUIP COOLING")
rt:set(AIR .. "equip_cooling/sel_dial_pos", 1)
frames(1)
T.equal(get("laminar/B747/CAS/caution_status", 27), 0, "NORM again: no EQUIP COOLING")

-- the landing altitude: no FMC route, 2,000 AUTO and LANDING ALT; the FMC's
-- departure field (FCOM p.608, p.1400)
T.equal(get(AIR .. "landing_altitude"), 2000, "no FMC route: 2,000 ft")
T.equal(get(ADVISORY, 240), 1, "no FMC route: LANDING ALT")
T.equal(get(AIR .. "pressurization/EICAS1_display_status"), 1, "LANDING ALT: the ECS data block (ATA21 p.451)")
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("laminar/B747/fms/data", '{"fltno":"","fltdep":"ZZZA","fltdst":"ZZB","crzalt":"FL370"}')
frames(0.5)
T.equal(get(AIR .. "landing_altitude"), 135, "FMC route on the ground: the departure field's elevation")
T.equal(get(ADVISORY, 240), 0, "FMC landing altitude: no LANDING ALT")
T.equal(get(AIR .. "pressurization/EICAS1_display_status"), 0, "nothing to show: no ECS data block")
rt:set("sim/flightmodel/position/latitude", 37.0)       -- past half way (and the destination's
rt:set("sim/flightmodel/position/longitude", 141.5)     -- 3-letter ident with a leading space)
frames(0.2)
T.equal(get(AIR .. "landing_altitude"), 1234, "past half way: the destination's elevation")

-- MAN: from the AUTO value in 50 ft steps; the knob's dataref is moved back
-- by whole turns away from its ends (FCOM p.573)
rt:set(AIR .. "landing_alt/button_pos", 0)
frames(0.2)
T.equal(get(AIR .. "landing_altitude"), 1250, "MAN: from the AUTO value, on a 50 ft step")
T.equal(get(ADVISORY, 240), 1, "MAN: LANDING ALT")
local rheo = get(AIR .. "land_alt_sel/rheostat")
T.check(rheo >= 720 and rheo <= 4280, "the knob's dataref away from its ends: " .. rheo)
rt:set(AIR .. "land_alt_sel/rheostat", rheo + 3)
frames(0.2)
T.equal(get(AIR .. "landing_altitude"), 1400, "MAN: three knob steps, 150 ft")
rt:set(AIR .. "land_alt_sel/rheostat", 4290)
frames(0.2)
T.equal(get(AIR .. "land_alt_sel/rheostat"), 4290 - 1800, "the knob's dataref back by five turns near its end")
rt:set(AIR .. "landing_alt/button_pos", 1)
frames(0.2)

-- MAN L: OUTFLOW VLV L and its STATUS, the data block; both CPCs lost:
-- CABIN ALT AUTO; the air/ground relays disagree: CPCS AIR/GND
rt:set(SW, 34, 1)
frames(0.5)
T.equal(get(ADVISORY, 249), 1, "MAN L: OUTFLOW VLV L")
T.equal(get(STATUS, 31), 1, "MAN L: STATUS OUTFLOW VLV L")
T.equal(get(AIR .. "press/valve_man", 0), 1, "MAN L: the left valve in MAN")
T.equal(get(AIR .. "pressurization/EICAS1_display_status"), 1, "OUTFLOW VLV: the ECS data block")
rt:set(SW, 34, 0)
rt:set("laminar/B747/electrical/bus/dc", 0, 0)
rt:set("laminar/B747/electrical/bus/dc", 1, 0)
frames(3)
T.equal(get("laminar/B747/CAS/caution_status", 10), 1, "both CPCs without power: CABIN ALT AUTO")
T.equal(get(AIR .. "press/cpc"), 0, "both CPCs without power: none in control")
T.check(get(STATUS, 29) == 1 and get(STATUS, 30) == 1, "STATUS CABIN ALT AUTO A and B")
rt:set("laminar/B747/electrical/bus/dc", 0, 1)
rt:set("laminar/B747/electrical/bus/dc", 1, 1)
frames(0.5)
T.equal(get("laminar/B747/CAS/caution_status", 10), 0, "power back: no CABIN ALT AUTO")
rt:set("laminar/B747/gear/air_ground/alt_gnd", 0)
frames(0.2)
T.equal(get(STATUS, 35), 1, "primary and alternate air/ground disagree: STATUS CPCS AIR/GND")
rt:set("laminar/B747/gear/air_ground/alt_gnd", 1)

-- the EEC's pack count follows the valves (AIR-16): the APU's air back
-- after its valve's DC bus came back
rt:set(PACK, 1, 2)          -- PACK 2 at A: still one pack
frames(10)
T.equal(get(AIR .. "packs_operating"), 3, "PACK 2 at A: three packs, not the selectors' sum")

-- the models' output tables shared between the glue files stay the models'
-- own: XTLua's namespace copies a bare table, whose numbers then stop
-- (the equipment cooling read the cabin's ΔP from such a copy)
T.equal(air.ns.B747_pack_out.packs_operating, 3, "B747_pack_out follows the pack model")
T.equal(air.ns.B747_press_out.ldg_ft, get(AIR .. "landing_altitude"), "B747_press_out follows the pressurization model")

T.done()
