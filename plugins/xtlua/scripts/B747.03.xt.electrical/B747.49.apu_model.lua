-- 747-400 APU control without X-Plane: the selector sequence (inlet door,
-- start, run, cooldown, shutdown), the automatic shutdowns and their fault,
-- and what the rest of the aircraft sees (starter command for X-Plane's APU,
-- generator ready, EICAS messages, the STATUS page values). X-Plane's APU
-- model still spins the APU (N1, EGT); this decides when it may.
-- Logic and sources: docs/overhaul/notes/ATA-49.md §3-§4 (FCOM 7.14
-- p.867-869, 7.30 p.895-897, 7.40 p.902). There is no APU maintenance manual;
-- values the FCOM does not give are marked estimate.
--
--   local A = B747_apu_model              -- in XTLua, after dofile
--   local A = dofile(".../B747.49.apu_model.lua")   -- in the tests
--   local s = A.new()
--   local inp = A.inputs()                -- fill it every frame
--   local out = A.update(s, inp, dt)      -- the same table every frame

local M = setmetatable({}, {})
B747_apu_model = M

M.RUN_N1 = 95                   -- APU RUNNING, generator ready (FCOM p.897, p.902)
M.COOLDOWN_S = 60               -- unloaded cooldown after OFF (FCOM p.897)
-- estimates (FCOM gives no values)
M.DOOR_TRAVEL_S = 12            -- inlet door, closed to open
M.DOOR_ALERT_S = 20             -- APU DOOR after the door disagrees this long
M.DOOR_CLOSE_N1 = 10            -- the door closes once the APU has run down
M.START_LIMIT_S = 120           -- a start that has not reached RUN_N1 by then is shut down
M.OFF_HIGH_S = 10               -- APU advisory: selector OFF and still above RUN_N1 this long
M.N2_PER_N1 = 0.926             -- FCOM p.868 shows N1 100.0 with N2 92.6
M.OIL_STOPPED, M.OIL_RUNNING, M.OIL_LAG_S = 1.00, 0.92, 30
-- states
M.OFF, M.STARTING, M.RUNNING, M.COOLDOWN, M.STOPPING = 0, 1, 2, 3, 4

function M.inputs()
    return {
        selector = 0,              -- 0 OFF, 1 ON, 2 START
        start_pushed = false,      -- the selector was turned to START (one frame is enough)
        battery = true,            -- BATTERY switch ON (FCOM p.897: OFF stops the APU)
        n1 = 0,                    -- X-Plane's APU N1, %
        running = false,           -- X-Plane's APU running
        fire = false,              -- APU fire detected (X-Plane failure)
        fuel = true,               -- fuel in main tank 2
    }
end

function M.new()
    local s = {state = M.OFF, start_latch = false, fault = false, door = 0, cooldown_t = 0,
        start_t = 0, door_disagree_t = 0, door_cmd = false, off_high_t = 0,
        oil = M.OIL_STOPPED, first = true}
    s.out = {state = M.OFF, starter = 0, door = 0, door_cmd = false, gen_ready = false,
        fault = false, adv_apu = false, adv_door = false, memo_running = false,
        n2 = 0, oil = M.OIL_STOPPED, cooldown = false}
    return s
end

local function step(x, target, rate, dt)
    if x < target then return math.min(target, x + rate * dt) end
    return math.max(target, x - rate * dt)
end

function M.update(s, inp, dt)
    local out = s.out
    local on = inp.selector >= 1
    local turning = inp.n1 > M.DOOR_CLOSE_N1

    -- the selector: OFF clears a fault and the start; START latches the start
    -- (FCOM p.867: OFF resets the auto shutdown fault logic; the bleed duct
    -- leak shutdown, which cannot be reset, has no source here yet)
    if not on then
        s.fault, s.start_latch = false, false
    elseif inp.start_pushed or inp.selector == 2 then
        if not s.fault and s.state ~= M.RUNNING then s.start_latch = true end
    end

    -- a flight that starts with the APU running, or a start X-Plane made
    if s.state == M.OFF and on and inp.running and inp.n1 >= M.RUN_N1 and inp.battery then
        s.state, s.door = M.RUNNING, 1
    end

    -- automatic shutdowns (FCOM p.897: a fire or a limit stops the APU at once)
    local shutdown = false
    if s.state == M.STARTING or s.state == M.RUNNING or s.state == M.COOLDOWN then
        if inp.fire or not inp.fuel then shutdown = true end
        if s.state == M.STARTING and s.start_t >= M.START_LIMIT_S then shutdown = true end
        if shutdown then
            s.fault = on                            -- the APU advisory waits for selector OFF
            s.start_latch = false
            s.state = M.STOPPING
        end
    end
    -- BATTERY OFF stops it at once (FCOM p.897), without a fault
    if not inp.battery and s.state ~= M.OFF and s.state ~= M.STOPPING then
        s.state, s.start_latch = M.STOPPING, false
    end

    -- the sequence (FCOM p.896-897)
    if s.state == M.OFF then
        if on and s.start_latch and s.door >= 1 and inp.battery then
            s.state, s.start_t, s.start_latch = M.STARTING, 0, false
        end
    elseif s.state == M.STARTING then
        s.start_t = s.start_t + dt
        if not on then
            s.state = M.STOPPING
        elseif inp.n1 >= M.RUN_N1 then
            s.state = M.RUNNING
        end
    elseif s.state == M.RUNNING then
        s.start_latch = false
        if not on then s.state, s.cooldown_t = M.COOLDOWN, 0 end
    elseif s.state == M.COOLDOWN then
        s.cooldown_t = s.cooldown_t + dt
        if on then
            s.state = M.RUNNING                     -- back ON during the cooldown: it keeps running
        elseif s.cooldown_t >= M.COOLDOWN_S then
            s.state = M.STOPPING
        end
    elseif s.state == M.STOPPING then
        if not turning then s.state = M.OFF end
    end

    -- the inlet door: open with the selector on (the door needs battery
    -- power: estimate) and while the APU turns; closed once it has run down
    local door_cmd = (on and inp.battery and not s.fault) or turning
    if inp.battery then s.door = step(s.door, door_cmd and 1 or 0, 1 / M.DOOR_TRAVEL_S, dt) end
    local at_cmd = (door_cmd and s.door >= 1) or (not door_cmd and s.door <= 0)
    if at_cmd or door_cmd ~= s.door_cmd then
        s.door_disagree_t = 0                       -- in place, or a new command starts the travel
    else
        s.door_disagree_t = s.door_disagree_t + dt
    end
    s.door_cmd = door_cmd
    if not on and inp.n1 > M.RUN_N1 and s.state ~= M.COOLDOWN then
        s.off_high_t = s.off_high_t + dt
    else
        s.off_high_t = 0
    end

    -- X-Plane's APU: 2 starts it, 1 keeps it running, 0 shuts it down
    if s.state == M.STARTING then out.starter = 2
    elseif s.state == M.RUNNING or s.state == M.COOLDOWN then out.starter = 1
    else out.starter = 0 end

    -- oil in circulation while it runs (estimate; no consumption, RF or LO)
    local oil_target = (inp.n1 > M.DOOR_CLOSE_N1) and M.OIL_RUNNING or M.OIL_STOPPED
    if s.first then s.oil = oil_target
    else s.oil = s.oil + (oil_target - s.oil) * math.min(1, dt / M.OIL_LAG_S) end
    s.first = false

    out.state = s.state
    out.door, out.door_cmd = s.door, door_cmd
    -- the generators and bleed only while it runs with the selector ON; the
    -- cooldown is unloaded (FCOM p.897; the generators too: estimate)
    out.gen_ready = s.state == M.RUNNING and on and inp.n1 >= M.RUN_N1
    out.cooldown = s.state == M.COOLDOWN
    out.fault = s.fault
    -- EICAS (FCOM p.902): APU after an automatic shutdown with the selector
    -- ON, or with the selector OFF and N1 above 95 % (estimate: not during
    -- the normal cooldown, and only after OFF_HIGH_S, past the run-down);
    -- APU DOOR when the door is not where it was commanded; APU RUNNING with
    -- the selector ON above 95 %
    out.adv_apu = (on and s.fault) or s.off_high_t >= M.OFF_HIGH_S
    out.adv_door = s.door_disagree_t >= M.DOOR_ALERT_S
    out.memo_running = on and inp.n1 > M.RUN_N1
    out.n2 = inp.n1 * M.N2_PER_N1
    out.oil = s.oil
    return out
end

return M
