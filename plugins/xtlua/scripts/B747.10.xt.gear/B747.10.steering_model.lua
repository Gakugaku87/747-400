-- 747-400 nose wheel and body gear steering without X-Plane (4-2 step 4):
-- the tillers and the rudder pedals on the nose wheels, system 1's gear down
-- pressure, the body gear steering's arming and its command, the trucks'
-- locks, >BODY GEAR STRG and the STATUS messages. Logic and sources:
-- docs/overhaul/notes/ATA-32.md §4.9 (FCOM p.1513, p.1521; ATA29_32 32-50
-- steering p.565-633; FCTM p.78).
--
--   local S = B747_steering_model          -- in XTLua, after dofile
--   local S = dofile(".../B747.10.steering_model.lua")   -- in the tests
--   local s = S.new()
--   local inp = S.inputs()               -- fill it every frame
--   local out = S.update(s, inp, dt)     -- the same table every frame
--
-- Angles in degrees, positive right (X-Plane's tire_steer_*_deg); the body
-- gear in the order left, right.

local M = setmetatable({}, {})
B747_steering_model = M

M.TILLER_DEG = 70           -- the tillers: 70 degrees either way (FCOM p.1513)
M.PEDAL_DEG = 7             -- the rudder pedals: 7 degrees (FCOM p.1513, ATA29_32 p.570)
M.TILLER_DEADBAND = 0.01    -- a tiller off its spring centre overrides the pedals (p.578)
M.BODY_START_DEG = 20       -- the body gear steers above 20 degrees of nose wheel (p.604, p.606)
M.BODY_MAX_DEG = 13         -- the trucks' 13 degrees at about 70 (p.604)
M.ARM_KT, M.DISARM_KT = 15, 20      -- the wing gear wheels' speed (p.622)
M.IRU_KT = 40                       -- either IRU's groundspeed (p.622)
M.GND_S = 10                        -- both air/ground systems in ground mode (p.622)
-- estimates (no values in the sources): the pressure steering needs (the
-- gear actuators' 1000 psi); the nose wheels' and the trucks' rates; the
-- trucks' angle in proportion from 20 to 70 degrees of nose wheel (p.608:
-- "in proportion"); the nose wheels and the trucks staying where they are
-- without pressure (the metering valve shut; the bypass valve only opens to
-- towing loads: p.596-598); the trucks centred when disarmed with pressure;
-- the time a truck may be unlocked without a command before >BODY GEAR STRG
-- (its centring after a turn)
M.POWER_PSI = 1000
M.NOSE_RATE = 20            -- degrees per second
M.BODY_RATE = 5
M.LOCKED_DEG = 0.1          -- a truck within this of centre: its actuators retracted and locked
M.UNLOCKED_S = 5
-- not the aircraft: with no tiller, the pedals as the tiller at taxi speeds
-- (70 degrees up to 10 kt, down to the pedals' 7 at 30 kt; FCTM p.78: the
-- tiller at low taxi speeds), for users without a tiller axis
M.PT_FULL_KT, M.PT_PEDAL_KT = 10, 30

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
local function toward(x, target, step)
    if x < target then return math.min(x + step, target) end
    return math.max(x - step, target)
end

function M.inputs()
    return {
        tiller = 0,                 -- the tillers (-1 .. 1, + right)
        tiller_avail = false,       -- a tiller axis present
        pedal = 0,                  -- the rudder pedals (-1 .. 1, + right; the rudder trim moves them)
        pedal_tiller = false,       -- not the aircraft: the pedals as the tiller without a tiller axis
        down_psi = 3000,            -- system 1's gear down pressure (0 unless the lever is DN)
        ng_compressed = true,       -- the PSEU: the nose gear compressed 8 in (pedal steering engaged)
        gnd_both = true,            -- the primary and the alternate air/ground systems in ground mode
        air = false,                -- either in air mode
        wheel_kt = 0,               -- the wing gear wheels' speed
        iru_kt = 0,                 -- the IRUs' groundspeed
        -- failures (no X-Plane equivalents)
        fail_pedal = false,         -- a pedal steering interconnect actuator
        fail_body = false,          -- a body gear steering actuator unlocked
    }
end

function M.new()
    local s = {nose = 0, body = {0, 0}, gnd_t = 0, armed = false, unlocked_t = 0}
    s.out = {nose = 0, body = {0, 0}, armed = false, commanded = false, unlocked = false,
        body_gear_strg = false, pedal_steering = false}
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    local power = inp.down_psi >= M.POWER_PSI

    -- the nose wheels: centred by the cams with the strut extended; on the
    -- ground the tillers, else the pedals (engaged with the nose gear
    -- compressed: p.570, p.574, p.578); held without pressure
    local target = s.nose
    if not inp.ng_compressed then
        target = 0
    elseif power then
        if math.abs(inp.tiller) > M.TILLER_DEADBAND then
            target = clamp(inp.tiller, -1, 1) * M.TILLER_DEG
        elseif inp.pedal_tiller and not inp.tiller_avail then
            local f = clamp((M.PT_PEDAL_KT - inp.iru_kt) / (M.PT_PEDAL_KT - M.PT_FULL_KT), 0, 1)
            target = clamp(inp.pedal, -1, 1) * (M.PEDAL_DEG + (M.TILLER_DEG - M.PEDAL_DEG) * f)
        else
            target = clamp(inp.pedal, -1, 1) * M.PEDAL_DEG
        end
    end
    s.nose = toward(s.nose, target, M.NOSE_RATE * dt)

    -- the body gear: armed (R7500, R7501) on the ground for 10 s under 15 kt
    -- of wheel speed and 40 kt of IRU groundspeed; disarmed over 20 kt or
    -- 40 kt or in air mode (p.622). Above 20 degrees of nose wheel the arming
    -- switch opens the modules' solenoid valves and the trucks steer the
    -- other way, 13 degrees at 70 (p.604, p.606, p.622-624)
    if inp.gnd_both then s.gnd_t = s.gnd_t + dt else s.gnd_t = 0 end
    if s.armed then
        if inp.wheel_kt > M.DISARM_KT or inp.iru_kt > M.IRU_KT or inp.air then s.armed = false end
    elseif s.gnd_t >= M.GND_S and inp.wheel_kt < M.ARM_KT and inp.iru_kt < M.IRU_KT and not inp.air then
        s.armed = true
    end
    local commanded = s.armed and power and math.abs(s.nose) > M.BODY_START_DEG
    local body_target = nil
    if commanded then
        local a = math.min(M.BODY_MAX_DEG,
            (math.abs(s.nose) - M.BODY_START_DEG) * M.BODY_MAX_DEG / (M.TILLER_DEG - M.BODY_START_DEG))
        body_target = s.nose > 0 and -a or a
    elseif power then
        body_target = 0
    end
    if body_target then
        for i = 1, 2 do s.body[i] = toward(s.body[i], body_target, M.BODY_RATE * dt) end
    end

    -- the trucks' lock switches (CONFIG GEAR CTR, the gear lever's lock);
    -- >BODY GEAR STRG and BODY GR STRG SYS with a truck unlocked without a
    -- command (p.626, p.630); PEDAL STEERING with an interconnect actuator
    -- failed (p.580, p.600)
    local unlocked = inp.fail_body or math.abs(s.body[1]) > M.LOCKED_DEG or math.abs(s.body[2]) > M.LOCKED_DEG
    if unlocked and not commanded then s.unlocked_t = s.unlocked_t + dt else s.unlocked_t = 0 end

    out.nose = s.nose
    out.body[1], out.body[2] = s.body[1], s.body[2]
    out.armed, out.commanded, out.unlocked = s.armed, commanded, unlocked
    out.body_gear_strg = s.unlocked_t >= M.UNLOCKED_S
    out.pedal_steering = inp.fail_pedal
    return out
end

return M
