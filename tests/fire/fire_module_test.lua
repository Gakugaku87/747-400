-- Run from the repository root with LuaJIT: luajit tests/fire/fire_module_test.lua
-- The fire module as XTLua runs it (tests/lib/xtlua.lua), with the lighting
-- module for the BTL DISCH lights: X-Plane's engine and APU fires, the
-- failure datarefs, the fire switch and test commands, FUEL CONTROL, the
-- buses and the air/ground relay in; the switches' animation, the bottles,
-- X-Plane's extinguishers and APU fire, the APU shutdown, the lights and
-- the EICAS slots out. The model's behaviour is tested in
-- fire_model_test.lua; this checks the wiring and the names
-- (docs/overhaul/notes/ATA-26.md).
local T = dofile("tests/lib/check.lua")("fire_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.35.xt.fire/B747.35.xt.fire.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local FIRE = "laminar/B747/fire/"
local WARNING = "laminar/B747/CAS/warning_status"
local CAUTION = "laminar/B747/CAS/caution_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"
local LIGHTS = "laminar/B747/annunciators/engine_fires"
local EXT = "sim/cockpit2/engine/actuators/fire_extinguisher_on"
local ANNUN = "laminar/B747/annunciator/brightness_ratio"

-- power (APU battery bus, main hot battery bus), on the ground, engines in RUN
rt:set("laminar/B747/electrical/bus/bat_apu", 1)
rt:set("laminar/B747/electrical/bus/hot_bat_main", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
for i = 0, 3 do rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", i, 1) end
rt:set("sim/flightmodel2/lights/generic_lights_brightness_ratio", 63, 1)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
frames(4)
T.equal(get(FIRE .. "engine01_02A/ext_bottle/psi"), 600, "bottle L A: 600 psi")
T.equal(get(FIRE .. "apu/ext_bottle/psi"), 600, "APU bottle: 600 psi")
for i = 0, 4 do T.equal(get(LIGHTS, i), 0, "no fire: fire light " .. i .. " out") end
T.equal(get(WARNING, 11), 0, "no FIRE ENG 1")
T.equal(get(FIRE .. "apu_shutdown"), 0, "no APU shutdown")
T.near(get(ANNUN, 113), 0, 0.01, "BTL DISCH L A out")

-- the fire switches are locked in: no fire, RUN
rt:command(FIRE .. "engine02/ext_switch_arm")
frames(1)
T.equal(get(FIRE .. "engine02/ext_switch/pos_arm"), 0, "no fire, RUN: fire switch 2 stays in (FCOM p.905)")
rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", 1, 0)
rt:command(FIRE .. "engine02/ext_switch_arm")
frames(1)
T.near(get(FIRE .. "engine02/ext_switch/pos_arm"), 1, 0.01, "FUEL CONTROL 2 CUTOFF: fire switch 2 pulled (FCOM p.916)")
rt:command(FIRE .. "engine02/ext_switch_arm")
frames(1)
T.near(get(FIRE .. "engine02/ext_switch/pos_arm"), 0, 0.01, "fire switch 2 pushed back in")
rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", 1, 1)
rt:command(FIRE .. "engine03/ext_switch_override")
frames(1)
T.near(get(FIRE .. "engine03/ext_switch/pos_arm"), 1, 0.01, "Fire Override 3: fire switch 3 pulled (FCOM p.906)")
rt:command(FIRE .. "engine03/ext_switch_arm")
frames(1)

-- X-Plane's engine 1 fire: FIRE ENG 1, the light; pull, rotate to A:
-- X-Plane's extinguisher for 1.5 s, bottle L A empty, BTL DISCH, >BTL LO
rt:set("sim/flightmodel2/engines/is_on_fire", 0, 1)
frames(0.2)
T.equal(get(WARNING, 11), 1, "X-Plane's engine 1 fire: FIRE ENG 1")
T.equal(get(LIGHTS, 0), 1, "engine 1 fire switch light")
rt:command(FIRE .. "engine01/ext_switch_arm")
frames(1)
T.near(get(FIRE .. "engine01/ext_switch/pos_arm"), 1, 0.01, "fire switch 1 pulled")
rt:command(FIRE .. "engine01/ext_switch_A")
frames(0.2)
T.equal(get(EXT, 0), 1, "rotated to A: X-Plane's engine 1 extinguisher")
T.equal(get(EXT, 1), 0, "engine 2's extinguisher off")
frames(2)
T.equal(get(EXT, 0), 0, "the agent is out")
T.near(get(FIRE .. "engine01/ext_switch/pos_disch"), -1, 0.01, "fire switch 1 rotated to A (counterclockwise)")
T.equal(get(FIRE .. "engine01_02A/ext_bottle/psi"), 0, "bottle L A empty")
T.equal(get(FIRE .. "light/btl_disch", 0), 1, "BTL DISCH L A (the model)")
T.near(get(ANNUN, 113), 0.8, 0.01, "BTL DISCH L A light (annunciator 113)")
T.equal(get(ADVISORY, 47), 1, ">BTL LO L ENG A (ATA26_28 p.78)")
T.equal(get(ADVISORY, 48), 0, "no >BTL LO L ENG B")
T.equal(get(STATUS, 59), 1, "STATUS BTL LOW L ENG A")
rt:set("sim/flightmodel2/engines/is_on_fire", 0, 0)
frames(0.2)
T.equal(get(WARNING, 11), 0, "fire out: FIRE ENG 1 cleared")
T.equal(get(LIGHTS, 0), 0, "fire out: light out")

-- an engine overheat (failure dataref): OVHT ENG 2 NAC
rt:set(FIRE .. "fail/eng_ovht", 1, 1)
frames(0.2)
T.equal(get(CAUTION, 80), 1, "overheat in nacelle 2: OVHT ENG 2 NAC (FCOM p.922)")
T.equal(get(LIGHTS, 1), 0, "overheat: no fire light")
rt:set(FIRE .. "fail/eng_ovht", 1, 0)
-- both fire loops of engine 4 failed: >DET FIRE/OHT 4; STATUS after 20 s
rt:set(FIRE .. "fail/loop_a", 3, 1)
rt:set(FIRE .. "fail/loop_b", 3, 1)
frames(0.2)
T.equal(get(ADVISORY, 62), 1, "both loops failed: >DET FIRE/OHT 4 (FCOM p.921)")
frames(20)
T.equal(get(STATUS, 46), 1, "STATUS ENG 4 FIRE LP A after 20 s")
T.equal(get(STATUS, 47), 1, "STATUS ENG 4 FIRE LP B")
rt:set(FIRE .. "fail/loop_a", 3, 0)
rt:set(FIRE .. "fail/loop_b", 3, 0)
frames(0.2)
T.equal(get(ADVISORY, 62), 0, "loops back: >DET cleared")

-- X-Plane's APU fire: FIRE APU, the APU shutdown, the horn; after 10 s below
-- 95 % on the ground the bottle discharges and puts X-Plane's fire out
rt:set("sim/operation/failures/rel_apu_fire", 6)
rt:set("sim/cockpit2/electrical/APU_N1_percent", 50)
frames(0.2)
T.equal(get(WARNING, 8), 1, "X-Plane's APU fire: FIRE APU")
T.equal(get(LIGHTS, 4), 1, "APU fire light")
T.equal(get(FIRE .. "apu_shutdown"), 1, "APU shutdown for the APU glue")
T.equal(get(FIRE .. "apu_horn"), 1, "on the ground: the APU fire horn")
rt:command(FIRE .. "apu/ext_switch_arm")
frames(0.2)
T.equal(get(FIRE .. "apu/ext_switch/pos_arm"), 1, "APU fire switch pulled (unlocked by the fire)")
T.equal(get(FIRE .. "apu_horn"), 0, "switch out: the horn stops")
frames(10)
T.equal(get("sim/operation/failures/rel_apu_fire"), 0, "10 s: the APU bottle discharged, X-Plane's APU fire out")
frames(2)
T.equal(get(FIRE .. "apu/ext_bottle/psi"), 0, "APU bottle empty")
T.near(get(ANNUN, 117), 0.8, 0.01, "APU BTL DISCH light (annunciator 117)")
T.equal(get(ADVISORY, 44), 1, ">BOTTLE LOW APU (ATA26_28 p.130)")
T.equal(get(STATUS, 63), 1, "STATUS BOTTLE LOW APU")
T.equal(get(WARNING, 8), 0, "fire out: FIRE APU cleared")
T.equal(get(FIRE .. "apu_shutdown"), 1, "the APU fire switch still out: shutdown")
rt:command(FIRE .. "apu/ext_switch_arm")
frames(0.2)
T.equal(get(FIRE .. "apu_shutdown"), 0, "APU fire switch pushed in: no shutdown")

-- FIRE/OVHT TEST held 6 s: TEST IN PROG, then FIRE TEST PASS; every fire
-- light; no FIRE message; released, all clear
local seen = {}
local function watch()
    for _, w in ipairs({{"in_prog", 24}, {"pass", 20}, {"fail", 19}, {"fire_eng", 11}}) do
        if get(WARNING, w[2]) == 1 then seen[w[1]] = true end
    end
    if get(LIGHTS, 2) == 1 and get(LIGHTS, 4) == 1 then seen.lights = true end
end
rt:command(FIRE .. "button/fire_ovht_test", 2)
watch()
T.check(seen.in_prog and not seen.pass, "test 2 s: TEST IN PROG")
T.check(seen.lights, "test: the fire lights")
T.check(not seen.fire_eng, "test: no FIRE ENG message (FCOM p.919)")
seen = {}
rt.commands[FIRE .. "button/fire_ovht_test"].handler(0, 0)
frames(5.5)
watch()
T.check(seen.pass and not seen.in_prog and not seen.fail, "test 5.5 s: FIRE TEST PASS")
rt.commands[FIRE .. "button/fire_ovht_test"].handler(2, 5.5)
frames(0.2)
T.equal(get(WARNING, 20), 0, "released: FIRE TEST PASS cleared")
T.equal(get(LIGHTS, 2), 0, "released: the lights out")
-- with a loop failed: FIRE TEST FAIL
rt:set(FIRE .. "fail/loop_b", 8, 1)
rt.commands[FIRE .. "button/fire_ovht_test"].handler(0, 0)
frames(5.5)
T.equal(get(WARNING, 19), 1, "APU loop B failed: FIRE TEST FAIL")
rt.commands[FIRE .. "button/fire_ovht_test"].handler(2, 5.5)
rt:set(FIRE .. "fail/loop_b", 8, 0)
frames(0.2)
-- no power for the detection: STATUS FIRE/OVHT SYS after 20 s
rt:set("laminar/B747/electrical/bus/bat_apu", 0)
frames(21)
T.equal(get(STATUS, 58), 1, "no APU battery bus: STATUS FIRE/OVHT SYS (ATA26_28 p.34)")
rt:set("laminar/B747/electrical/bus/bat_apu", 1)

-- the AI's cold & dark: full bottles, switches in
rt:set(FIRE .. "init_CD", 1)
frames(0.5)
T.equal(get(FIRE .. "init_CD"), 2, "init_CD done")
T.equal(get(FIRE .. "engine01_02A/ext_bottle/psi"), 600, "init_CD: bottle L A full")
T.near(get(FIRE .. "engine01/ext_switch/pos_arm"), 0, 0.01, "init_CD: fire switch 1 in")

-- every X-Plane dataref the fire module wrote is writable (DataRefs.txt)
local writable = {}
local file = assert(io.open(xtlua.xplane_root .. "/Resources/plugins/DataRefs.txt", "rb"))
for line in file:lines() do
    local name, w = line:match("^(%S+)\t%S+\t(%S+)")
    if name then writable[name] = w == "y" end
end
file:close()
file = assert(io.open("plugins/xtlua/scripts/B747.35.xt.fire/B747.35.xt.fire.lua", "rb"))
local glue = file:read("*a")
file:close()
for name in pairs(rt.written) do
    if name:sub(1, 4) == "sim/" and glue:find('"' .. name .. '"', 1, true) then
        T.check(writable[name], "the fire module writes a read-only X-Plane dataref: " .. name)
    end
end

T.done()
