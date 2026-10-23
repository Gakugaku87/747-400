-- Run from the repository root with LuaJIT: luajit tests/oxygen/oxygen_module_test.lua
-- The oxygen module as XTLua runs it (tests/lib/xtlua.lua), with the
-- lighting module for the cabin signs: the cabin altitude, the switch and
-- mask commands, the forward cargo temperature, the DC buses and X-Plane's
-- failure in; the cylinder pressures, the passenger and therapeutic
-- oxygen, the EICAS slots, the signs and X-Plane's oxygen out. The model's
-- behaviour is tested in oxygen_model_test.lua; this checks the wiring and
-- the names (docs/overhaul/notes/ATA-35.md).
local T = dofile("tests/lib/check.lua")("oxygen_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.36.xt.oxygen/B747.36.xt.oxygen.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")

local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
local function get(name, i) return rt:get(name, i) end
local OXY = "laminar/B747/oxygen/"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"
local MEMO = "laminar/B747/CAS/memo_status"
local CABIN = "sim/cockpit2/pressurization/indicators/cabin_altitude_ft"
local FELT = "sim/cockpit2/oxygen/indicators/pilot_felt_altitude_ft"
local NO_SMOKING, SEAT_BELTS = "sim/cockpit2/switches/no_smoking", "sim/cockpit2/switches/fasten_seat_belts"

-- power, cruise cabin at 6,000 ft, cylinders at 70°F, sign selectors OFF
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/dc", i, 1) end
rt:set(CABIN, 6000)
rt:set("laminar/B747/air/temp/cargo", 0, 21.1)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
rt:set("laminar/B747/safety/no_smoking/sel_dial_pos", 0)
rt:set("laminar/B747/safety/seat_belts/sel_dial_pos", 0)
frames(1)
T.equal(get(OXY .. "crew_press_psi"), 1850, "STATUS page: crew 1850 psi (FCOM p.455)")
T.equal(get(OXY .. "pass_press_psi"), 1850, "STATUS page: passenger 1850 psi")
T.equal(get("sim/operation/override/override_oxygen_system"), 1, "X-Plane's oxygen system taken over")
T.near(get(FELT), 6000, 1, "no mask: X-Plane's pilot feels the cabin altitude")
T.equal(get("sim/cockpit2/oxygen/indicators/o2_bottle_pressure_psi"), 1850, "X-Plane's crew cylinder: 1850 psi")
T.equal(get(OXY .. "pass_oxy_on"), 0, "passenger oxygen off")
T.equal(get(ADVISORY, 256), 0, "no PASS OXYGEN ON")
T.equal(get(ADVISORY, 53), 0, "no >CREW OXY LOW")
T.equal(get(MEMO, 36), 0, "no THERAP OXYGEN ON")
T.equal(get(NO_SMOKING), 0, "selectors OFF: NO SMOKING off")
T.equal(get(SEAT_BELTS), 0, "selectors OFF: FASTEN SEAT BELTS off")

-- PASS OXYGEN ON (a press shorter than a frame): actuated, PASS OXYGEN ON,
-- the signs on whatever the selectors (FCOM p.437, p.502, p.547)
rt:command(OXY .. "pass_oxy_sw_on")
frames(0.1)
T.equal(get(OXY .. "pass_oxy_sw_pos"), 0, "PASS OXYGEN: back to NORM")
T.equal(get(OXY .. "pass_oxy_on"), 1, "PASS OXYGEN ON pressed: actuated")
T.equal(get(ADVISORY, 256), 1, "PASS OXYGEN ON (advisory)")
T.equal(get(MEMO, 36), 0, "manual passenger ON: no THERAP OXYGEN ON")
T.equal(get(NO_SMOKING), 1, "passenger oxygen on: NO SMOKING on with the selector OFF")
T.equal(get(SEAT_BELTS), 1, "passenger oxygen on: FASTEN SEAT BELTS on with the selector OFF")
T.equal(get(STATUS, 39), 0, "STATUS PASS OXYGEN ON: not at once")
frames(60)
T.equal(get(STATUS, 39), 1, "STATUS PASS OXYGEN ON after 60 s (ATA30_32_35_36 p.376)")
T.check(get(OXY .. "pass_press_psi") < 1850, "actuated: the passenger cylinders in use (estimate)")
-- RESET held below 12,000 ft
rt:command(OXY .. "pass_oxy_sw_reset", 0.2)
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 0, "RESET at 6,000 ft: passenger oxygen off")
T.equal(get(ADVISORY, 256), 0, "RESET: PASS OXYGEN ON cleared")
T.equal(get(STATUS, 39), 0, "RESET: STATUS cleared")
T.equal(get(NO_SMOKING), 0, "RESET: NO SMOKING off again")
-- a press whose end XTLua does not pass (seen with X-Plane's Web API): the
-- switch springs back to NORM all the same
rt.commands[OXY .. "pass_oxy_sw_on"].handler(0, 0)
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 1, "ON without its end: actuated")
T.equal(get(OXY .. "pass_oxy_sw_pos"), 1, "ON without its end: held a moment")
frames(0.4)
T.equal(get(OXY .. "pass_oxy_sw_pos"), 0, "ON without its end: back to NORM after 0.3 s")
rt.commands[OXY .. "pass_oxy_sw_reset"].handler(0, 0)
frames(0.5)
T.equal(get(OXY .. "pass_oxy_on"), 0, "RESET without its end: off")
T.equal(get(OXY .. "pass_oxy_sw_pos"), 0, "RESET without its end: back to NORM")

-- the cabin climbs past 14,000 ft: passenger and therapeutic oxygen
rt:set(CABIN, 15000)
frames(0.2)
T.equal(get(OXY .. "pass_oxy_on"), 1, "15,000 ft: passenger oxygen actuated")
T.equal(get(OXY .. "therap_oxy_on"), 1, "15,000 ft: therapeutic oxygen too (FCOM p.513)")
T.equal(get(MEMO, 36), 1, "THERAP OXYGEN ON (memo)")
rt:command(OXY .. "pass_oxy_sw_reset")
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 1, "RESET at 15,000 ft: no reset (FCOM p.456)")
rt:set(CABIN, 11000)
rt:command(OXY .. "pass_oxy_sw_reset")
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 0, "RESET at 11,000 ft: passenger oxygen off")
T.equal(get(OXY .. "therap_oxy_on"), 1, "the therapeutic oxygen stays (its own switch)")
rt:command(OXY .. "therap_oxy_sw_dn")
frames(0.1)
T.equal(get(OXY .. "therap_oxy_sw_pos"), 0, "THERAPEUTIC: RESET springs back to NORM")
T.equal(get(OXY .. "therap_oxy_on"), 0, "THERAPEUTIC RESET at 11,000 ft: off")
T.equal(get(MEMO, 36), 0, "THERAP OXYGEN ON cleared")
-- the therapeutic switch to ON and back
rt:command(OXY .. "therap_oxy_sw_up")
frames(0.1)
T.equal(get(OXY .. "therap_oxy_sw_pos"), 1, "THERAPEUTIC up: ON (stays)")
T.equal(get(MEMO, 36), 1, "THERAPEUTIC ON: THERAP OXYGEN ON")
T.equal(get(OXY .. "pass_oxy_on"), 0, "THERAPEUTIC ON: no passenger masks")
rt:command(OXY .. "therap_oxy_sw_dn")
frames(0.1)
T.equal(get(OXY .. "therap_oxy_sw_pos"), 0, "THERAPEUTIC down: NORM")
T.equal(get(MEMO, 36), 1, "THERAPEUTIC NORM: still on")
rt:command(OXY .. "therap_oxy_sw_dn", 0.2)
frames(0.1)
T.equal(get(MEMO, 36), 0, "THERAPEUTIC RESET: off")

-- the crew masks and X-Plane's hypoxia
rt:set(CABIN, 30000)
frames(0.1)
T.near(get(FELT), 30000, 1, "30,000 ft without masks: X-Plane's pilot feels 30,000 ft")
rt:command(OXY .. "crew_masks_toggle")
frames(0.1)
T.equal(get(OXY .. "crew_mask_on"), 1, "crew masks on")
T.near(get(FELT), 10000, 1, "on the crew masks: 10,000 ft (estimate)")
T.equal(get("sim/cockpit2/oxygen/actuators/o2_valve_on"), 1, "X-Plane's crew oxygen valve open")
rt:command(OXY .. "crew_masks_toggle")
frames(0.1)
T.equal(get(OXY .. "crew_mask_on"), 0, "crew masks stowed")
T.near(get(FELT), 30000, 1, "masks stowed: the cabin altitude again")
rt:set(CABIN, 6000)

-- the cylinders' temperature (the forward cargo compartment)
rt:set("laminar/B747/air/temp/cargo", 0, 0)
frames(0.1)
T.check(get(OXY .. "crew_press_psi") > 1700 and get(OXY .. "crew_press_psi") < 1730, "forward cargo 0°C: crew about 1716 psi")
rt:set("laminar/B747/air/temp/cargo", 0, 21.1)

-- >CREW OXY LOW: the crew masks on for hours (estimate: the use)
rt:command(OXY .. "crew_masks_toggle")
local hours = 0
while get(ADVISORY, 53) == 0 and hours < 12 do
    frames(600, 10)
    hours = hours + 1 / 6
end
T.check(get(OXY .. "crew_press_psi") <= 500, ">CREW OXY LOW at or below 500 psi (ATA30_32_35_36 p.340): " .. get(OXY .. "crew_press_psi"))
T.check(hours > 5 and hours < 8, "the crew cylinder lasts about 6 h on the masks (estimate): " .. hours)
rt:command(OXY .. "crew_masks_toggle")

-- X-Plane's passenger oxygen failure; no DC for the switch
rt:set("sim/operation/failures/rel_pass_o2_on", 6)
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 1, "X-Plane's failure: passenger oxygen actuated")
rt:command(OXY .. "pass_oxy_sw_reset")
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 1, "failure: RESET does not hold it off")
rt:set("sim/operation/failures/rel_pass_o2_on", 0)
rt:command(OXY .. "pass_oxy_sw_reset")
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 0, "failure gone: RESET")
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/dc", i, 0) end
rt:command(OXY .. "pass_oxy_sw_on")
frames(0.1)
T.equal(get(OXY .. "pass_oxy_on"), 0, "no DC: PASS OXYGEN ON does nothing (estimate)")

-- a new flight: full cylinders, switches NORM, masks stowed
rt:callout("flight_start")
frames(0.1)
T.equal(get(OXY .. "crew_press_psi"), 1850, "new flight: crew cylinder full")
T.equal(get(OXY .. "crew_mask_on"), 0, "new flight: masks stowed")

-- every X-Plane dataref the oxygen module wrote is writable (DataRefs.txt;
-- the lighting module's own writes are not checked here)
local writable = {}
local file = assert(io.open(xtlua.xplane_root .. "/Resources/plugins/DataRefs.txt", "rb"))
for line in file:lines() do
    local name, w = line:match("^(%S+)\t%S+\t(%S+)")
    if name then writable[name] = w == "y" end
end
file:close()
file = assert(io.open("plugins/xtlua/scripts/B747.36.xt.oxygen/B747.36.xt.oxygen.lua", "rb"))
local glue = file:read("*a")
file:close()
for name in pairs(rt.written) do
    if name:sub(1, 4) == "sim/" and glue:find('"' .. name .. '"', 1, true) then
        T.check(writable[name], "the oxygen module writes a read-only X-Plane dataref: " .. name)
    end
end

T.done()
