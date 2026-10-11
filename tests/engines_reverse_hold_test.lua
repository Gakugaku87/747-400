-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Drive the production all-engine reverse-hold command handler, the reverse
-- monitor and the auto-stow timers frame by frame. Datarefs and XTLua timers
-- are mocks; this does not model the engines or the reverser doors.
local ENGINES = "plugins/xtlua/scripts/B747.40.xt.engines/B747.40.xt.engines.lua"
local FRAME = 0.05
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end

local file = assert(io.open(ENGINES))
local source = file:read("*a")
file:close()
local function slice(first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last-1)
end
-- The reverse-hold state, the reverse command handlers with their auto-stow
-- timer callbacks, and the per-frame reverse monitor, in one chunk so they
-- share the script locals as they do in the aircraft.
local reverse_source =
    slice("local B747_hold_rev_on_engine", "--local B747_igniter_status").."\n"..
    slice("local callEngineReverse={}", "function B747_engine_TOGA_power_CMDhandler").."\n"..
    slice("function B747_engines_monitor_reverse()", "function aircraft_load()")

-- One aircraft with its own namespace, clock and timers. As in XTLua, a timer
-- belongs to its callback: scheduling the same callback again replaces the
-- pending one.
local function new_aircraft(ias)
    local aircraft = {frame=0, now=0, timers={}}
    local env = setmetatable({
        print=function() end,
        simDR_engine_throttle_jet_all=0.0,
        simDR_prop_mode={[0]=1, 1, 1, 1},
        simDR_ind_airspeed_kts_pilot=ias,
        B747DR_reverser_lockout=0
    }, {__index=_G})
    env.run_after_time = function(callback, delay)
        aircraft.timers[callback] = aircraft.now + delay
    end
    env.is_timer_scheduled = function(callback)
        return aircraft.timers[callback] ~= nil
    end
    env.stop_timer = function(callback)
        aircraft.timers[callback] = nil
    end
    setfenv(assert(loadstring(reverse_source, "@"..ENGINES)), env)()
    aircraft.env = env
    return aircraft
end

-- One frame: the command handler (when the command is active), then the
-- reverse monitor from after_physics, then any timer that has come due.
local function frame(aircraft, phase, duration)
    aircraft.frame = aircraft.frame + 1
    aircraft.now = aircraft.frame*FRAME
    local env = aircraft.env
    if phase then env.B747_thrust_rev_hold_max_all_CMDhandler(phase, duration) end
    env.B747_engines_monitor_reverse()
    local due = {}
    for callback, time in pairs(aircraft.timers) do
        if time <= aircraft.now + 1e-9 then due[#due+1] = callback end
    end
    for _, callback in ipairs(due) do
        -- A callback fired earlier in this frame may have stopped or moved it.
        local time = aircraft.timers[callback]
        if time and time <= aircraft.now + 1e-9 then
            aircraft.timers[callback] = nil
            callback()
        end
    end
end
local function frames_for(seconds)
    return math.floor(seconds/FRAME + 0.5)
end
local function run(aircraft, seconds)
    for _=1,frames_for(seconds) do frame(aircraft) end
end
-- Press the reverse-hold command and keep it held until the frame before the
-- release, so the levers can be checked while it is still held.
local function press(aircraft, seconds)
    frame(aircraft, 0, 0)
    for k=1,frames_for(seconds)-1 do frame(aircraft, 1, k*FRAME) end
end
local function release(aircraft, seconds)
    frame(aircraft, 2, seconds)
end
local function lever(aircraft)
    return aircraft.env.simDR_engine_throttle_jet_all
end

-- Held for 3 s while still fast: releasing it brings the levers back to
-- reverse idle at once instead of leaving full reverse on until the stow
-- timers run below 65 KIAS. No timer stows them while the aircraft is still
-- fast; the stow still waits for 65 KIAS.
local aircraft = new_aircraft(120)
press(aircraft, 3.0)
equal(lever(aircraft), -1, "long hold: full reverse while the command is held")
release(aircraft, 3.0)
equal(lever(aircraft), -0.01, "long hold: release returns to reverse idle")
run(aircraft, 9.0)
equal(lever(aircraft), -0.01, "long hold: reverse idle kept while still above 65 KIAS")
aircraft.env.simDR_ind_airspeed_kts_pilot = 60
run(aircraft, 4.9)
equal(lever(aircraft), -0.01, "long hold: reverse idle while slowing below 65 KIAS")
run(aircraft, 3.0)
equal(lever(aircraft), -0.01, "long hold: reverse idle until the stow timer")
run(aircraft, 0.2)
equal(lever(aircraft), 0.0, "long hold: reversers stow 8 s after 65 KIAS")

-- A tap shorter than 0.5 s still latches full reverse, and the monitor still
-- brings it to reverse idle 5 s and stows it 8 s after 65 KIAS.
aircraft = new_aircraft(120)
press(aircraft, 0.2)
release(aircraft, 0.2)
equal(lever(aircraft), -1, "tap: release keeps full reverse latched")
run(aircraft, 2.0)
equal(lever(aircraft), -1, "tap: latch holds with the command released")
aircraft.env.simDR_ind_airspeed_kts_pilot = 60
run(aircraft, 4.9)
equal(lever(aircraft), -1, "tap: full reverse until 5 s after 65 KIAS")
run(aircraft, 0.2)
equal(lever(aircraft), -0.01, "tap: reverse idle 5 s after 65 KIAS")
run(aircraft, 3.1)
equal(lever(aircraft), 0.0, "tap: reversers stow 8 s after 65 KIAS")

-- Held for 10 s below 65 KIAS: every held frame restarts the stow timers, so
-- full reverse stays on while held; release goes to reverse idle at once and
-- the timers still stow the reversers 8 s later.
aircraft = new_aircraft(60)
press(aircraft, 10.0)
equal(lever(aircraft), -1, "slow hold: full reverse for as long as the command is held")
release(aircraft, 10.0)
equal(lever(aircraft), -0.01, "slow hold: release returns to reverse idle")
run(aircraft, 5.1)
equal(lever(aircraft), -0.01, "slow hold: reverse idle after the hold timer")
run(aircraft, 3.1)
equal(lever(aircraft), 0.0, "slow hold: reversers stow 8 s after release")

-- A hold that never deployed the reversers (lockout in the air) leaves the
-- levers alone on release, even after an earlier long hold on the ground.
aircraft = new_aircraft(120)
press(aircraft, 2.0)
release(aircraft, 2.0)
aircraft.env.simDR_ind_airspeed_kts_pilot = 60
run(aircraft, 8.2)
equal(lever(aircraft), 0.0, "no deploy: earlier ground hold has stowed")
aircraft.env.B747DR_reverser_lockout = 1
aircraft.env.simDR_ind_airspeed_kts_pilot = 140
press(aircraft, 2.0)
equal(lever(aircraft), 0.0, "no deploy: the lockout keeps the reversers stowed")
release(aircraft, 2.0)
equal(lever(aircraft), 0.0, "no deploy: release leaves forward idle")
run(aircraft, 9.0)
equal(lever(aircraft), 0.0, "no deploy: no stow timer moves the levers afterwards")

print("Engine reverse-hold tests passed: "..checks)
