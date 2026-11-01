-- Run from the repository root with LuaJIT: luajit tests/safety/safety_module_test.lua
-- The sign memos of the safety module (B747.85.xt.safety.lua) as XTLua runs
-- it, with the lighting module (the signs) and the oxygen module: NO
-- SMOKING ON, SEATBELTS ON and PASS SIGNS ON show the selectors manually
-- ON, not the signs lit by AUTO or by the passenger oxygen (FCOM p.502,
-- p.547; ATA33 p.211; LIGHT-02).
local T = dofile("tests/lib/check.lua")("safety_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.85.xt.safety/B747.85.xt.safety.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua")
rt:load("plugins/xtlua/scripts/B747.36.xt.oxygen/B747.36.xt.oxygen.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local MEMO = "laminar/B747/CAS/memo_status"
local NO_SMOKE_SEL, SEAT_BELTS_SEL = "laminar/B747/safety/no_smoking/sel_dial_pos", "laminar/B747/safety/seat_belts/sel_dial_pos"
local NO_SMOKING, SEAT_BELTS = "sim/cockpit2/switches/no_smoking", "sim/cockpit2/switches/fasten_seat_belts"
local OFF, AUTO, ON = 0, 1, 2
local function memos() return get(MEMO, 17), get(MEMO, 27), get(MEMO, 33) end

-- on the ground (gear down), power on, selectors AUTO: the signs on, no memo
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/dc", i, 1) end
for i = 0, 4 do rt:set("sim/flightmodel2/gear/deploy_ratio", i, 1) end
rt:set("sim/cockpit2/pressurization/indicators/cabin_altitude_ft", 0)
rt:set(NO_SMOKE_SEL, AUTO)
rt:set(SEAT_BELTS_SEL, AUTO)
frames(0.5)
T.equal(get(NO_SMOKING), 1, "AUTO, gear down: NO SMOKING signs on")
T.equal(get(SEAT_BELTS), 1, "AUTO, gear down: FASTEN SEAT BELTS signs on")
local ns, ps, sb = memos()
T.check(ns == 0 and ps == 0 and sb == 0, "AUTO: no sign memo (the signs are not manually selected)")

-- the selectors manually ON
rt:set(NO_SMOKE_SEL, ON)
frames(0.2)
ns, ps, sb = memos()
T.check(ns == 1 and ps == 0 and sb == 0, "NO SMOKING ON, SEAT BELTS AUTO: NO SMOKING ON only")
rt:set(SEAT_BELTS_SEL, ON)
frames(0.2)
ns, ps, sb = memos()
T.check(ns == 0 and ps == 1 and sb == 0, "both ON: PASS SIGNS ON, the other two inhibited")
rt:set(NO_SMOKE_SEL, OFF)
frames(0.2)
ns, ps, sb = memos()
T.check(ns == 0 and ps == 0 and sb == 1, "SEAT BELTS ON, NO SMOKING OFF: SEATBELTS ON only")
T.equal(get(NO_SMOKING), 0, "NO SMOKING OFF: the signs off")

-- the passenger oxygen lights the signs with the selectors OFF: no memo
rt:set(SEAT_BELTS_SEL, OFF)
rt:command("laminar/B747/oxygen/pass_oxy_sw_on")
frames(0.2)
T.equal(get(NO_SMOKING), 1, "passenger oxygen: NO SMOKING signs on with the selector OFF")
T.equal(get(SEAT_BELTS), 1, "passenger oxygen: FASTEN SEAT BELTS signs on with the selector OFF")
ns, ps, sb = memos()
T.check(ns == 0 and ps == 0 and sb == 0, "passenger oxygen: no sign memo")

-- (7-3) the doors' mode memos of the E&M's configuration (ATA38_51_52_56
-- p.304): DOORS AUTO (all AUTOMATIC, inhibited from takeoff power to 1
-- minute after landing), DOORS AUTO/MAN (mixed), DOORS MANUAL (all
-- MANUAL, on the ground)
local MODE = "laminar/B747/door/mode"
local GND = "laminar/B747/gear/air_ground/pri_gnd"
local THR = "sim/cockpit2/engine/actuators/throttle_ratio"
local function door_memos() return get(MEMO, 9), get(MEMO, 10), get(MEMO, 11) end
rt:set(GND, 1)
frames(0.2)
local auto, mixed, manual = door_memos()
T.check(get(MODE, 0) == 0 and get(MODE, 11) == 0, "cold and dark: the doors MANUAL")
T.check(auto == 0 and mixed == 0 and manual == 1, "all MANUAL on the ground: DOORS MANUAL")
rt:command("laminar/B747/door/mode_auto_all")
frames(0.2)
auto, mixed, manual = door_memos()
T.check(auto == 1 and mixed == 0 and manual == 0, "all AUTOMATIC: DOORS AUTO")
rt:set(MODE, 4, 0)
frames(0.2)
auto, mixed, manual = door_memos()
T.check(auto == 0 and mixed == 1 and manual == 0, "door L5 MANUAL, the rest AUTOMATIC: DOORS AUTO/MAN")
rt:set(MODE, 4, 1)
rt:set(THR, 0, 0.9)
frames(0.2)
T.equal(get(MEMO, 9), 0, "takeoff power: DOORS AUTO inhibited")
rt:set(GND, 0)
rt:set(THR, 0, 0.5)
frames(0.2)
T.equal(get(MEMO, 9), 0, "in the air: DOORS AUTO inhibited")
rt:set(GND, 1)
rt:set(THR, 0, 0)
frames(59)
T.equal(get(MEMO, 9), 0, "59 s after landing: DOORS AUTO inhibited")
frames(2)
T.equal(get(MEMO, 9), 1, "61 s after landing: DOORS AUTO")
rt:command("laminar/B747/door/mode_manual_all")
rt:set(GND, 0)
frames(0.2)
auto, mixed, manual = door_memos()
T.check(auto == 0 and mixed == 0 and manual == 0, "all MANUAL in the air: no memo (DOORS MANUAL on the ground only)")
rt:set(GND, 1)

T.done()
