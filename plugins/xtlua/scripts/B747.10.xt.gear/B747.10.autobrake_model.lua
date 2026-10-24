-- 747-400 autobrakes without X-Plane (4-2 step 3): the selector and its
-- latch, the landing arm, application and disarm, the deceleration it holds,
-- RTO, and the memo and AUTOBRAKES. Logic and sources:
-- docs/overhaul/notes/ATA-32.md §4.8 (FCOM p.1502-1503, p.1515-1516,
-- p.1521-1522; ATA29_32 32-42 autobrake p.498-563).
--
--   local A = B747_autobrake_model           -- in XTLua, after dofile
--   local A = dofile(".../B747.10.autobrake_model.lua")   -- in the tests
--   local s = A.new()
--   local inp = A.inputs()               -- fill it every frame
--   local out = A.update(s, inp, dt)     -- out.dial may move the selector

local M = setmetatable({}, {})
B747_autobrake_model = M

-- the selector (gear/autobrakes/sel_dial_pos): 0 RTO, 1 OFF, 2 DISARM,
-- 3-6 = 1-4, 7 MAX AUTO
M.RTO, M.OFF, M.DISARM, M.MAX = 0, 1, 2, 7
M.DECEL = {[3] = 4.0, [4] = 5.0, [5] = 6.0, [6] = 7.5, [7] = 11.0}   -- ft/s² (ATA29_32 p.503 figure)
M.MAX_PSI = {[0] = 3000, [3] = 1300, [4] = 1500, [5] = 1750, [6] = 2050, [7] = 3000}
M.FULL_PSI = 3000           -- X-Plane's brake ratio 1 (the brake model: full at 3000 psi)
M.SPINUP_KT, M.SPINUP_S = 60, 3     -- the wheels spun up (p.520-521)
M.RTO_KT = 85                       -- p.527, FCOM p.1515
M.PEDAL_DISARM = 750 / 3000         -- the metered pressure switch, 750 psi (p.522)
M.RTO_PEDAL = 12 / 17               -- the pedals 12 of 17 degrees disable RTO (p.528)
M.SHORT_FT_S2 = 1                   -- the control pressure low and the decel short by 1 ft/s² (p.523)
-- estimates (no values in the sources): the thrust levers retarded and
-- advanced; the wheels' speed taken as the IRS groundspeed on the ground; the
-- pressure let go through the orifice after a disarm (p.512); the control
-- loop on the IRS deceleration, tuned on the custom acf (X-Plane's brake
-- ratio per ft/s² error)
M.IDLE, M.ADVANCED = 0.05, 0.1
M.BLEED_S = 2
M.KP, M.KI = 0.02, 0.12
M.DECEL_TAU = 0.5

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

function M.inputs()
    return {
        dial = M.OFF,
        air = false,                -- the PSEU's primary and alternate air mode
        gnd = true,                 -- primary or alternate ground mode
        gnd_both = true,            -- primary and alternate ground mode
        levers = {0, 0, 0, 0},      -- the thrust levers (0 idle .. 1)
        irs = true,                 -- the captain's IRS valid
        gs_kt = 0,                  -- its groundspeed
        pedal = {0, 0},             -- the pilots' pedals (the metered pressure, 0..1 of 3000 psi)
        speedbrake = 0,             -- the speedbrake lever (0 DN .. 1 UP)
        normal = true,              -- the normal brakes: system 4 the brake source
        antiskid_fault = false,     -- the normal antiskid failed or off
        fail = false,               -- the autobrake failed
    }
end

function M.new()
    local s = {armed = false, applying = false, spin_t = 0, spun = false, idle_gnd = false, sb_up = false,
        integ = 0, cmd = 0, decel = 0, last_gs = nil, rto_latched = false, rto_off = false}
    s.out = {dial = M.OFF, cmd = 0, armed = false, memo = nil, autobrakes = false, decel = 0}
    return s
end

local function reset(s)
    s.armed, s.applying, s.spin_t, s.spun, s.idle_gnd, s.sb_up = false, false, 0, false, false, false
    s.integ, s.rto_latched, s.rto_off = 0, false, false
end

function M.update(s, inp, dt)
    local out = s.out
    local dial = inp.dial
    -- the IRS deceleration, ft/s² (from its groundspeed)
    if s.last_gs and dt > 0 then
        local a = (s.last_gs - inp.gs_kt) * 1.68781 / dt
        s.decel = s.decel + (a - s.decel) * math.min(1, dt / M.DECEL_TAU)
    end
    s.last_gs = inp.gs_kt
    local idle, advanced = true, false
    for i = 1, 4 do
        if inp.levers[i] > M.IDLE then idle = false end
        if inp.levers[i] > M.ADVANCED then advanced = true end
    end
    local pedal = math.max(inp.pedal[1], inp.pedal[2])
    local fault = inp.fail or inp.antiskid_fault or not inp.irs
    local target = 0                    -- the pressure asked for, as X-Plane's ratio
    local disabled = false

    if dial >= 3 then
        -- the latch holds the selector only with its conditions; else the
        -- spring takes it to DISARM (p.502, p.519). After arming, losing
        -- system 4 does not trip it (p.518)
        if not s.armed then
            if (inp.air or idle) and inp.irs and pedal < M.PEDAL_DISARM and not inp.fail
                    and not inp.antiskid_fault and inp.normal then
                reset(s)
                s.armed = true
            else
                dial = M.DISARM
            end
        end
        if s.armed then
            -- disarm (p.522-523; FCOM p.1515-1516): the pedals, a thrust lever
            -- advanced on the ground after it was at idle, the speedbrakes
            -- stowed after their deployment on the ground, a fault, the normal
            -- pressure lost while applying with the decel short
            if inp.gnd and idle then s.idle_gnd = true end
            if inp.gnd and inp.speedbrake > 0.5 then s.sb_up = true end
            local disarm = pedal >= M.PEDAL_DISARM or fault
                or (s.idle_gnd and advanced)
                or (s.sb_up and inp.speedbrake < 0.1)
                or (s.applying and not inp.normal and s.decel < M.DECEL[dial] - M.SHORT_FT_S2)
            if disarm then
                dial = M.DISARM
                s.armed = false
            end
        end
        if s.armed then
            -- application (p.520-521): idle, ground, the wheels spun up (60 kt
            -- for 3 s, latched); then to the stop or a disarm (FCOM p.1515)
            if inp.gnd and inp.gs_kt > M.SPINUP_KT then s.spin_t = s.spin_t + dt elseif not s.spun then s.spin_t = 0 end
            if s.spin_t >= M.SPINUP_S then s.spun = true end
            if idle and inp.gnd and s.spun then s.applying = true end
            disabled = not inp.normal
            if s.applying and inp.gnd and idle and inp.normal then
                local err = M.DECEL[dial] - s.decel
                local top = M.MAX_PSI[dial] / M.FULL_PSI
                s.integ = clamp(s.integ + M.KI * err * dt, 0, top)
                target = clamp(s.integ + M.KP * err, 0, top)
            else
                s.integ = 0
            end
        end
    elseif dial == M.RTO then
        -- RTO: armed on the ground (both air/ground systems), trips to OFF in
        -- air mode (p.502, p.525, p.528); latched above 85 kt (p.527);
        -- maximum pressure with the levers retarded, until the pedals, a lever,
        -- a fault or the speedbrakes stowed disable it (p.528)
        if inp.air then
            dial = M.OFF
            reset(s)
        else
            s.armed = inp.gnd_both and not fault
            if inp.gs_kt > M.RTO_KT then s.rto_latched = true end
            if s.applying then
                if inp.speedbrake > 0.5 then s.sb_up = true end
                if pedal >= M.RTO_PEDAL or advanced or fault or (s.sb_up and inp.speedbrake < 0.1) then s.rto_off = true end
            end
            if s.armed and s.rto_latched and idle and pedal < M.RTO_PEDAL and not s.rto_off then s.applying = true end
            if s.applying and not s.rto_off then target = 1 end
        end
    else
        reset(s)
    end

    -- the pressure: up at once, let go through the orifice (p.512)
    if target >= s.cmd then s.cmd = target else s.cmd = math.max(target, s.cmd - dt / M.BLEED_S) end
    out.dial, out.cmd, out.armed, out.decel = dial, s.cmd, s.armed, s.decel
    -- the memo with the level armed (p.530-531); AUTOBRAKES at DISARM or
    -- armed but disabled (p.511, p.530)
    out.memo = (s.armed and (dial >= 3 or dial == M.RTO)) and dial or nil
    out.autobrakes = dial == M.DISARM or (s.armed and disabled)
    return out
end

return M
