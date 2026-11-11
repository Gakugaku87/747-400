-- Run from the repository root with LuaJIT: luajit tests/apu/apu_module_test.lua
-- The APU in the electrical module as XTLua runs it (tests/lib/xtlua.lua):
-- the APU selector commands and the BATTERY switch in, X-Plane's APU starter
-- switch, the inlet door, the APU GEN availability, the STATUS page N2 and oil
-- and the EICAS slots out, through the glue (B747.03.xt.apu.lua). The model's
-- behaviour itself is tested in apu_model_test.lua; this checks the wiring.
-- A stand-in for X-Plane's APU spins N1 as the starter switch says.
local T = dofile("tests/lib/check.lua")("apu_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.03.xt.electrical/B747.03.xt.electrical.lua")
-- the fire protection detects the APU fire and commands the shutdown
rt:load("plugins/xtlua/scripts/B747.35.xt.fire/B747.35.xt.fire.lua")
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/operation/prefs/startup_running", 0)
rt:set("sim/flightmodel/weight/m_fuel", 2, 30000)
rt:callout("flight_start")

local function get(name, i) return rt:get(name, i) end
local STARTER = "sim/cockpit2/electrical/APU_starter_switch"
local N1 = "sim/cockpit2/electrical/APU_N1_percent"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local MEMO = "laminar/B747/CAS/memo_status"
local DOOR = "laminar/B747/electrical/apu_inlet_door"
local AVAIL = "laminar/B747/electrical/apu_pwr1_avail"
local SEL = "laminar/B747/electrical/apu/sel_dial_pos"

-- X-Plane's APU: up to 100 % in 50 s on START, held on ON, down in 20 s on OFF.
-- (2026-11-09) the fuel model's APU fuel valve: open in 4 s while X-Plane's
-- APU starts or runs (the fuel glue's demand), closed otherwise; held
-- closed for a failed valve (valve_stuck)
local VALVE = "laminar/B747/fuel/main2_tank/apu_vlv_pos"
local valve_stuck = false
local function xplane(dt)
    local n1, starter = get(N1), get(STARTER)
    if starter == 2 then n1 = math.min(100, n1 + 2 * dt)
    elseif starter == 1 and n1 >= 90 then n1 = 100
    elseif starter == 0 then n1 = math.max(0, n1 - 5 * dt) end
    rt:set(N1, n1)
    rt:set("sim/cockpit2/electrical/APU_running", (n1 >= 90) and 1 or 0)
    if not valve_stuck then
        local v = get(VALVE)
        v = (starter >= 1) and math.min(1, v + dt / 4) or math.max(0, v - dt / 4)
        rt:set(VALVE, v)
    end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        rt:frame(1 / 30)
        xplane(1 / 30)
    end
end

-- BATTERY ON; the selector to ON: the door opens, the APU waits
frames(0.1)
rt:set("laminar/B747/button_switch/position", 13, 1)
frames(1)
rt:command("laminar/B747/electrical/apu/sel_dial_up", 0.1)
T.equal(get(SEL), 1, "ON: selector at ON")
frames(5)
local door = get(DOOR)
T.check(door > 0.3 and door < 0.6, "ON: the inlet door opening (about 12 s, estimate): " .. door)
T.equal(get(STARTER), 0, "ON: X-Plane's starter off")
frames(10)
T.equal(get(DOOR), 1, "ON: inlet door open")
T.equal(get(ADVISORY, 13), 0, "ON: no APU advisory while it waits (APU-04)")
T.equal(get(ADVISORY, 14), 0, "ON: no APU DOOR (APU-03)")

-- START, released back to ON at once: the start is latched (APU-13)
rt:command("laminar/B747/electrical/apu/sel_dial_up", 0.1)
T.equal(get(SEL), 1, "START: the selector springs back to ON")
frames(1)
T.equal(get(STARTER), 2, "START: X-Plane's APU starting (door already open)")
frames(60)
T.equal(get(STARTER), 1, "running: X-Plane's APU held on")
T.equal(get(MEMO, 1), 1, "running: APU RUNNING memo")
T.equal(get(AVAIL), 1, "running: APU GEN 1 available to its switch")
T.equal(get("laminar/B747/electrical/light/apu_avail", 0), 1, "running: AVAIL light (electrical model)")
T.near(get("laminar/B747/apu/n2"), 92.6, 0.1, "running: STATUS N2 (estimate)")
T.check(get("laminar/B747/apu/oil") < 1, "running: STATUS oil below 1.00 while running (estimate)")

-- APU GEN 1 on, then the selector OFF: the cooldown drops the generator
rt:set("laminar/B747/apu_pwr_1/switch_mode", 1)
frames(1)
T.equal(get("laminar/B747/electrical/breaker/apb", 0), 1, "APU GEN 1: APB 1 closed")
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(1)
T.equal(get(AVAIL), 0, "OFF: generator unavailable in the unloaded cooldown (estimate)")
T.equal(get("laminar/B747/electrical/breaker/apb", 0), 0, "OFF: APB 1 opens")
T.equal(get(MEMO, 1), 0, "OFF: no APU RUNNING")
T.equal(get(STARTER), 1, "OFF: still running in the cooldown")
frames(61)
T.equal(get(STARTER), 0, "OFF: X-Plane's APU shut down after 60 s")
frames(30)
T.equal(get(DOOR), 0, "OFF: inlet door closed after the run-down")
T.equal(get(ADVISORY, 13), 0, "OFF: no APU advisory")

-- the quick start's X-Plane command (sim/electrical/APU_start) turns the
-- selector OFF to START with two sel_dial_up; the mock logs the commands a
-- module runs instead of running them, so the test runs them as X-Plane would
local before = #rt.command_log
rt:command("sim/electrical/APU_start", 0)
local ups = 0
for i = before + 1, #rt.command_log do
    local c = rt.command_log[i]
    if c.name == "laminar/B747/electrical/apu/sel_dial_up" and c.phase == "once" then ups = ups + 1 end
end
T.equal(ups, 2, "APU_start command: the selector turned twice (OFF to START)")
for _ = 1, ups do rt:command("laminar/B747/electrical/apu/sel_dial_up", 0) end
frames(80)
T.equal(get(STARTER), 1, "APU_start command: running")
T.equal(get(SEL), 1, "APU_start command: selector at ON")

-- X-Plane's APU fire, detected by the fire protection (B747.35.xt.fire.lua):
-- shut down at once, the APU advisory
rt:set("sim/operation/failures/rel_apu_fire", 6)
frames(0.2)
T.equal(get(STARTER), 0, "fire: X-Plane's APU shut down")
T.equal(get(ADVISORY, 13), 1, "fire: APU advisory")
rt:set("sim/operation/failures/rel_apu_fire", 0)
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(0.2)
T.equal(get(ADVISORY, 13), 0, "fire: selector OFF clears the APU advisory")

-- (2026-11-04) the failures (laminar/B747/apu/fail/*; notes/ATA-49.md §11):
-- the APU running again, a limit exceeded stops it with APU; the bleed duct
-- leak stops it and keeps it from starting again
for _ = 1, 2 do rt:command("laminar/B747/electrical/apu/sel_dial_up", 0) end
frames(80)
T.equal(get(STARTER), 1, "failures: the APU running again")
rt:set("laminar/B747/apu/fail/limit", 1)
frames(0.2)
T.equal(get(STARTER), 0, "a limit exceeded: X-Plane's APU shut down")
T.equal(get(ADVISORY, 13), 1, "a limit exceeded: APU advisory")
rt:set("laminar/B747/apu/fail/limit", 0)
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(30)
rt:set("laminar/B747/apu/fail/duct_leak", 1)
for _ = 1, 2 do rt:command("laminar/B747/electrical/apu/sel_dial_up", 0) end
frames(20)
T.equal(get(STARTER), 0, "the bleed duct leak: no start (FCOM p.613)")
T.equal(get(ADVISORY, 13), 1, "the bleed duct leak, selector ON: APU advisory")
rt:set("laminar/B747/apu/fail/duct_leak", 0)
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(1)
T.equal(get(ADVISORY, 13), 0, "the leak repaired, selector OFF: no APU advisory")
-- the inlet door jammed closed (notes/ATA-49.md §12): no start, APU DOOR
rt:set("laminar/B747/apu/fail/door", 1)
for _ = 1, 2 do rt:command("laminar/B747/electrical/apu/sel_dial_up", 0) end
frames(25)
T.equal(get(STARTER), 0, "the inlet door jammed: no start")
T.equal(get(ADVISORY, 14), 1, "the inlet door jammed: APU DOOR")
rt:set("laminar/B747/apu/fail/door", 0)
frames(14)
T.equal(get(ADVISORY, 14), 0, "freed: no APU DOOR")
frames(80)
T.equal(get(STARTER), 1, "freed: the APU started")
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(100)
-- (2026-11-09's audit) the APU fuel valve stuck closed (the fuel model's
-- failed valve; here the stand-in held): the start begins, no fuel past
-- the valve's travel and a margin (6 s, an estimate): shut down with the
-- APU advisory. Before, the APU ran on main tank 2's fuel alone
valve_stuck = true
rt:set(VALVE, 0)
for _ = 1, 2 do rt:command("laminar/B747/electrical/apu/sel_dial_up", 0) end
frames(14)
T.equal(get(STARTER), 2, "the APU fuel valve stuck closed: the start begins (the door open)")
frames(7)
T.equal(get(STARTER), 0, "no fuel past its travel and 2 s: X-Plane's APU shut down")
T.equal(get(ADVISORY, 13), 1, "and the APU advisory")
valve_stuck = false
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(30)

-- (2026-11-11 review) X-Plane paused for 30 s during a start with the valve
-- a quarter open: its clock (sim/time/total_running_time_sec), its APU and
-- the fuel model's valve stand still while XTLua's frames go on; the APU
-- carries on with the start after it. Before, the valve's wait counted
-- XTLua's frames: shut down for want of fuel 6 s into the pause
rt:set(VALVE, 0)
frames(60)
for _ = 1, 2 do rt:command("laminar/B747/electrical/apu/sel_dial_up", 0) end
local t = 0
while get(STARTER) ~= 2 and t < 30 do frames(0.1) t = t + 0.1 end
frames(1)
T.check(get(STARTER) == 2 and get(VALVE) > 0.2 and get(VALVE) < 0.5,
    string.format("starting, the valve %.2f open: X-Plane paused here", get(VALVE)))
for _ = 1, 30 * 30 do
    rt.time = rt.time - 1 / 30     -- X-Plane's clock held: the frame sets it back where it was
    rt:frame(1 / 30)
end
T.check(get(STARTER) == 2 and get(ADVISORY, 13) == 0, "30 s paused: still starting, no APU advisory")
frames(60)
T.check(get(STARTER) == 1 and get(ADVISORY, 13) == 0, "after the pause: running")
rt:command("laminar/B747/electrical/apu/sel_dial_dn", 0.1)
frames(100)

-- (2026-11-04; APU-09) the starter's power from the electrical model (FCOM
-- p.895-896): the APU battery run down, a P&W start does not begin; a GE's
-- runs on the APU start TR while utility bus 4 is powered
local real = nil
for _, m in ipairs(rt.modules or {}) do if m.ns and m.ns.B747_elec_last_out then real = m end end
if real then
    local fake = {battery = {main = {ah = 30}, apu = {ah = 0}}, util = {true, true, true, false}}
    real.ns.B747_elec_last_out = function() return fake end
    rt:set("laminar/B747/engines/type", 0)
    frames(30)
    rt:command("laminar/B747/electrical/apu/sel_dial_up", 0.1)
    rt:command("laminar/B747/electrical/apu/sel_dial_up", 0.1)
    frames(20)
    T.equal(get(STARTER), 0, "P&W, the APU battery run down: no start (FCOM p.896: both batteries)")
    rt:set("laminar/B747/engines/type", 1)
    fake.util[4] = true
    frames(2)
    T.equal(get(STARTER), 2, "GE, utility bus 4 powered: the start on the APU start TR (FCOM p.895)")
else
    T.check(false, "the electrical module's namespace for the stub")
end

T.done()
