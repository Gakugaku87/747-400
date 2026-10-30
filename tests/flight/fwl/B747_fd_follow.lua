-- B747 flight test: a pilot flying the flight director's pitch bar by
-- hand, for the takeoff before the A/P goes in (FCOM p.79 (L.10.3): the
-- A/P not engaged below 250 ft after takeoff; FCTM p.95-96: the rotation
-- to the F/D's pitch). Copy into X-Plane's
-- Resources/plugins/FlyWithLua/Scripts/.
--
--   FlyWithLua/B747_fd_follow/start   from now, the column to the F/D's
--                                     pitch (laminar/B747/autopilot/
--                                     flight_director_pitch_deg)
--   FlyWithLua/B747_fd_follow/stop    stop, the column left where it is
--                                     (the scenario sets it after)
-- B747/test/fd_follow_err (float): the pitch error now, degrees.
--
-- The column (sim/cockpit2/controls/yoke_pitch_ratio) is the column at the
-- start plus KI of the error integrated, plus KP of the error, less KD per
-- degree a second of pitch rate, at most RATE of the travel a second.
-- Gains: estimates (a steady pilot), not from the sources.

local VERSION = "2"

if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then
    logMsg("B747 F/D follow: not the 747-400, inactive")
    return
end

local KP, KI, KD = 0.10, 0.03, 0.20
local RATE = 0.5
dataref("B747FF_theta", "sim/flightmodel/position/theta", "readonly")
dataref("B747FF_q", "sim/flightmodel/position/Q", "readonly")
dataref("B747FF_fd", "laminar/B747/autopilot/flight_director_pitch_deg", "readonly")
dataref("B747FF_time", "sim/time/total_running_time_sec", "readonly")
-- the column read and written with get() and set() while flying only
-- (docs/overhaul/TESTING.md)
local COLUMN = "sim/cockpit2/controls/yoke_pitch_ratio"
define_shared_DataRef("B747/test/fd_follow_err", "Float")
dataref("B747FF_err", "B747/test/fd_follow_err", "writable")

local active, hold, out, last = false, 0, 0, nil
function B747FF_start()
    active, last = true, nil
    hold = get(COLUMN)
    out = hold
    logMsg(string.format("B747 F/D follow: flying the bar from column %.2f", hold))
end
function B747FF_stop()
    active = false
    logMsg(string.format("B747 F/D follow: stopped at column %.2f", out))
end
function B747FF_frame()
    if not active then return end
    local now = B747FF_time
    local dt = last and math.max(0, math.min(0.1, now - last)) or 0
    last = now
    local err = B747FF_fd - B747FF_theta
    B747FF_err = err
    hold = math.max(-1, math.min(1, hold + KI * err * dt))
    local want = math.max(-1, math.min(1, hold + KP * err - KD * B747FF_q))
    local step = RATE * dt
    out = out + math.max(-step, math.min(step, want - out))
    set(COLUMN, out)
end
create_command("FlyWithLua/B747_fd_follow/start", "B747 F/D follow: fly the F/D pitch bar with the column", "B747FF_start()", "", "")
create_command("FlyWithLua/B747_fd_follow/stop", "B747 F/D follow: stop", "B747FF_stop()", "", "")
do_every_frame("B747FF_frame()")
B747FF_err = 0
logMsg("B747 F/D follow v" .. VERSION .. ": ready")
