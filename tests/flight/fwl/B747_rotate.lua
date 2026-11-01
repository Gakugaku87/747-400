-- B747 flight test: a pilot rotating for takeoff as the FCTM describes
-- (FCTM p.95-96: at VR a smooth rotation at about 2.5 degrees a second
-- toward 15 degrees; liftoff about 3 to 5 seconds later, at about 10
-- degrees with flaps 20). Copy into X-Plane's
-- Resources/plugins/FlyWithLua/Scripts/.
--
--   FlyWithLua/B747_rotate/start   from now, the column to a pitch target
--                                  rising RATE_DEG a second from the
--                                  attitude now to TOP_DEG
--   FlyWithLua/B747_rotate/stop    stop, the column left where it is
-- B747/test/rotate_target (float): the pitch target now, degrees.
--
-- The column (sim/cockpit2/controls/yoke_pitch_ratio): the column at the
-- start plus KI of the error integrated, plus KP of the error, plus KD per
-- degree a second of the pitch rate short of the target's rate (2.5 while
-- it rises, then 0), at most RATE of the travel a second (gains:
-- estimates). Version 1 took KD of the pitch rate itself, as
-- B747_fd_follow.lua does for the F/D bar: it held the rotation back, the
-- rate reached 2.5 degrees a second only 3 s after VR and the airplane
-- lifted off at 6 degrees (aero_rotation, 2026-11-02 05:58).

local VERSION = "2"

if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then
    logMsg("B747 rotate: not the 747-400, inactive")
    return
end

local KP, KI, KD = 0.25, 0.10, 0.20
local RATE = 1.5
local RATE_DEG, TOP_DEG = 2.5, 15
dataref("B747RO_theta", "sim/flightmodel/position/theta", "readonly")
dataref("B747RO_q", "sim/flightmodel/position/Q", "readonly")
dataref("B747RO_time", "sim/time/total_running_time_sec", "readonly")
local COLUMN = "sim/cockpit2/controls/yoke_pitch_ratio"
define_shared_DataRef("B747/test/rotate_target", "Float")
dataref("B747RO_target", "B747/test/rotate_target", "writable")

local active, hold, out, last, target = false, 0, 0, nil, 0
function B747RO_start()
    active, last = true, nil
    hold = get(COLUMN)
    out = hold
    target = B747RO_theta
    logMsg(string.format("B747 rotate: from %.1f degrees, column %.2f", target, hold))
end
function B747RO_stop()
    active = false
    logMsg(string.format("B747 rotate: stopped at column %.2f, target %.1f", out, target))
end
function B747RO_frame()
    if not active then return end
    local now = B747RO_time
    local dt = last and math.max(0, math.min(0.1, now - last)) or 0
    last = now
    target = math.min(TOP_DEG, target + RATE_DEG * dt)
    B747RO_target = target
    local err = target - B747RO_theta
    local rate = target < TOP_DEG and RATE_DEG or 0
    hold = math.max(-1, math.min(1, hold + KI * err * dt))
    local want = math.max(-1, math.min(1, hold + KP * err + KD * (rate - B747RO_q)))
    local step = RATE * dt
    out = out + math.max(-step, math.min(step, want - out))
    set(COLUMN, out)
end
create_command("FlyWithLua/B747_rotate/start", "B747 rotate: rotate at 2.5 deg/s toward 15 deg", "B747RO_start()", "", "")
create_command("FlyWithLua/B747_rotate/stop", "B747 rotate: stop", "B747RO_stop()", "", "")
do_every_frame("B747RO_frame()")
B747RO_target = 0
logMsg("B747 rotate v" .. VERSION .. ": ready")
