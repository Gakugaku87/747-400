-- 747-400 wheel brakes without X-Plane (4-2 step 2): the pressure of the
-- brake source the hydraulic model chooses (system 4, then 1, then 2, then
-- the accumulator), the parking brake lever and its valve, the antiskid's
-- power and failures, and the messages. Logic and sources:
-- docs/overhaul/notes/ATA-32.md §2.4, §4.6, §4.7 (FCOM 14.20.3-6
-- p.1513-1516, p.1521-1522; ATA29_32 32-41, 32-42).
--
--   local B = B747_brake_model             -- in XTLua, after dofile
--   local B = dofile(".../B747.10.brake_model.lua")   -- in the tests
--   local s = B.new()
--   local inp = B.inputs()               -- fill it every frame
--   local out = B.update(s, inp, dt)     -- the same table every frame

local M = setmetatable({}, {})
B747_brake_model = M

M.NORMAL = 4                -- brake source 4: the normal brakes (the hydraulic model)
M.LEVER_SET = 0.9           -- the parking brake lever set
M.PEDAL_RELEASE = 0.9       -- both pedals pushed this far release the lever (FCOM p.1516)
M.VALVE_DISAGREE_S = 2      -- the valve not open 2 s after the lever's release (ATA29_32 p.420)
-- estimates (no values in the sources): the brakes' torque in proportion to
-- the pressure, full at the systems' 3000 psi; the valve's motor travel (it
-- has to open within 2 s)
M.FULL_PSI = 3000
M.VALVE_S = 1

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
local function toward(x, target, step)
    if x < target then return math.min(target, x + step) end
    if x > target then return math.max(target, x - step) end
    return x
end

function M.inputs()
    return {
        pedal = {0, 0},             -- the pilots' brake pedals, left and right (0..1)
        lever = 0,                  -- the parking brake lever (0..1)
        source = 4, psi = 3000,     -- the brake source (0 accumulator, 1, 2, 4) and its pressure
        bat_bus = true,             -- 28V DC battery bus: the parking brake valve's motor (ATA29_32 p.416-421)
        dc = {true, true, true, true},  -- the antiskid wheel cards (DC 1-4) and the BSCU's BITE cards (DC 4, 2)
        air = false,                -- the PSEU in air mode
        chocked = false,            -- wheel chocks (ground handling, not the 747's brakes)
        -- failures (no X-Plane equivalents)
        fail_antiskid = {false, false},     -- the normal and the alternate antiskid
        fail_limiter = false,               -- the torque limiters (two or more wheels on a truck)
        fail_valve = false,                 -- the parking brake valve does not move
    }
end

function M.new()
    local s = {valve = 0, trapped = nil, disagree_t = 0}
    s.out = {
        brake = {0, 0},             -- X-Plane's left and right brake (0..1)
        park = 0,                   -- X-Plane's parking brake: the trapped pressure's hold, or the chocks
        valve = 0,                  -- the parking brake valve, 0 open .. 1 closed
        release_lever = false,      -- both pedals pushed with the lever set: the lever goes off
        park_brake_set = false, antiskid = false, antiskid_off = false, brake_limiter = false,
        abs = true,                 -- X-Plane's antiskid
    }
    return s
end

-- a flight start: the valve where the lever is, holding the source's pressure
function M.set_to(s, inp)
    local set = inp.lever > M.LEVER_SET
    s.valve = set and 1 or 0
    s.trapped = set and inp.psi or nil
    s.disagree_t = 0
end

function M.update(s, inp, dt)
    local out = s.out
    local set = inp.lever > M.LEVER_SET
    -- the valve follows the lever while its motor has power; it traps the
    -- brakes' pressure as it closes and keeps it while closed (no thermal
    -- relief or leak: estimate). The accumulator keeps the parking brake;
    -- it cannot stop the airplane (FCOM p.1516)
    if inp.bat_bus and not inp.fail_valve then s.valve = toward(s.valve, set and 1 or 0, dt / M.VALVE_S) end
    if s.valve >= 1 then
        if s.trapped == nil then s.trapped = inp.psi end
    else
        s.trapped = nil
    end
    local avail = clamp(inp.psi / M.FULL_PSI, 0, 1)
    for i = 1, 2 do out.brake[i] = clamp(inp.pedal[i], 0, 1) * avail end
    out.park = s.trapped and clamp(s.trapped / M.FULL_PSI, 0, 1) or 0
    if inp.chocked then out.park = 1 end
    out.valve = s.valve
    out.release_lever = set and inp.pedal[1] >= M.PEDAL_RELEASE and inp.pedal[2] >= M.PEDAL_RELEASE
    -- PARK BRAKE SET: the lever set and the valve closed (ATA29_32 p.420)
    out.park_brake_set = set and s.valve >= 1

    -- the valve not open 2 s after the lever's release, or closed in air
    -- mode: BRAKE LIMITER and ANTISKID OFF (p.420, p.421 figure)
    if s.valve > 0 and (not set or inp.air) then s.disagree_t = s.disagree_t + dt else s.disagree_t = 0 end
    local valve_fault = s.disagree_t >= M.VALVE_DISAGREE_S
    -- the antiskid: the normal antiskid with the normal brakes, the alternate
    -- (pairs of wheels) with systems 1 and 2 and the accumulator (FCOM
    -- p.1514); ANTISKID OFF with all the wheel cards' power or the BSCU's
    -- lost (p.456-459, p.480, p.561)
    local cards = inp.dc[1] or inp.dc[2] or inp.dc[3] or inp.dc[4]
    local bscu = inp.dc[4] or inp.dc[2]
    out.antiskid_off = not cards or not bscu or valve_fault
    local active = (inp.source == M.NORMAL) and 1 or 2
    out.antiskid = inp.fail_antiskid[active] and not out.antiskid_off
    out.brake_limiter = inp.fail_limiter or valve_fault or not bscu
    out.abs = not out.antiskid_off and not inp.fail_antiskid[active]
    return out
end

return M
