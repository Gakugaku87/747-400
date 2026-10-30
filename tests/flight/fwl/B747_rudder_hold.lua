-- B747 flight test: a pilot holding the heading with the rudder pedals, for
-- the VMCG test (PROGRESS.md 5f, notes/AERO.md 3.11; FCOM p.236 (PI.10.10)
-- gives VMCG, the speed below which the rudder alone cannot hold the
-- direction after an outboard engine fails at maximum takeoff thrust).
-- Copy into X-Plane's Resources/plugins/FlyWithLua/Scripts/.
--
--   FlyWithLua/B747_rudder_hold/start   from DELAY s on, hold the heading
--                                       at the command with the pedals
--   FlyWithLua/B747_rudder_hold/stop    stop, pedals back to neutral
-- B747/test/rudder_hold_sat (float): seconds the pedals have been full
-- since the start (the rudder could not do more).
--
-- The pedals (sim/cockpit2/controls/yoke_heading_ratio) go to KP per degree
-- off the heading less KD per degree a second of yaw rate, at most full.
-- Gains and the delay: estimates (a quick pilot), not from the sources.

local VERSION = "1"

if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then
    logMsg("B747 rudder hold: not the 747-400, inactive")
    return
end

local KP, KD = 0.35, 0.35
local DELAY = 1.0
dataref("B747RH_psi", "sim/flightmodel/position/psi", "readonly")
dataref("B747RH_r", "sim/flightmodel/position/R", "readonly")
dataref("B747RH_time", "sim/time/total_running_time_sec", "readonly")
-- the pedals read and written with get() and set() while holding only
-- (docs/overhaul/TESTING.md)
local PEDAL = "sim/cockpit2/controls/yoke_heading_ratio"
define_shared_DataRef("B747/test/rudder_hold_sat", "Float")
dataref("B747RH_sat", "B747/test/rudder_hold_sat", "writable")

local active, target, t0, last = false, 0, 0, nil
function B747RH_start()
    active, target, t0, last = true, B747RH_psi, B747RH_time, nil
    B747RH_sat = 0
    logMsg(string.format("B747 rudder hold: holding %.1f deg after %.1f s", target, DELAY))
end
function B747RH_stop()
    if active then set(PEDAL, 0) end
    active = false
    logMsg(string.format("B747 rudder hold: stopped, %.1f s at full pedal", B747RH_sat))
end
function B747RH_frame()
    if not active then return end
    local now = B747RH_time
    local dt = last and math.max(0, math.min(0.1, now - last)) or 0
    last = now
    if now - t0 < DELAY then return end
    local err = target - B747RH_psi
    if err > 180 then err = err - 360 elseif err < -180 then err = err + 360 end
    local cmd = KP * err - KD * B747RH_r
    if cmd >= 1 or cmd <= -1 then B747RH_sat = B747RH_sat + dt end
    set(PEDAL, math.max(-1, math.min(1, cmd)))
end
create_command("FlyWithLua/B747_rudder_hold/start", "B747 rudder hold: hold the heading with the pedals", "B747RH_start()", "", "")
create_command("FlyWithLua/B747_rudder_hold/stop", "B747 rudder hold: stop", "B747RH_stop()", "", "")
do_every_frame("B747RH_frame()")
B747RH_sat = 0
logMsg("B747 rudder hold v" .. VERSION .. ": ready")
