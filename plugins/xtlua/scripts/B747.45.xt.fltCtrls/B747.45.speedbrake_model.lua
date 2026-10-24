-- 747-400 speedbrakes without X-Plane (4-1 step 3): the auto speedbrake
-- actuator and its relays (extension on landing and for a refused takeoff,
-- retraction when thrust lever 1 or 3 is advanced), SPEEDBRAKE AUTO and
-- >SPEEDBRAKES EXT. The lever's positions are the 3D's and the hydraulics
-- module's controlObject rows'. Logic and sources:
-- docs/overhaul/notes/ATA-27.md §4.2 (FCOM p.951-952, p.958; ATA27
-- p.162-186, p.740).
--
--   local B = B747_speedbrake_model      -- in XTLua, after dofile
--   local B = dofile(".../B747.45.speedbrake_model.lua")   -- in the tests

local M = setmetatable({}, {})
B747_speedbrake_model = M

M.DN, M.ARM, M.DETENT, M.UP = 0, 0.125, 0.53, 1.0
M.ARM_LO = 0.07                 -- the ARM detent and aft of it close S217 (the 3D's detent snaps from here)
M.ABOVE_ARM = 0.15              -- above the arm detent (the MAWEA's microswitch, ATA27 p.740)
-- thrust lever angles from the forward idle stop (the EEC's: X-Plane's
-- throttle ratio times 50 degrees): S1B and S3B close within 6-8 degrees
-- of idle (ATA27 p.176); the speedbrake power level is a resolver angle of
-- 40 degrees (p.740), the resolver reading 34.88 degrees at idle (ATA70_80
-- p.146-151: the CF6; the PW taken as the same, an estimate)
M.TLA_STOP = 50
M.IDLE_TLA = 7
M.POWER_TLA = 40 - 34.88
M.GND_PSI = 1600                -- hydraulic system 1 or 4 for the control relays (p.182)
M.SBEXT_RA_LO, M.SBEXT_RA_HI = 15, 800
-- estimates (no values in the sources)
M.ACTUATOR_S = 2                -- the auto speedbrake actuator moving the lever from DN to UP
M.FAULT_S = 3                   -- SPEEDBRAKE AUTO's conditions held this long before it shows (the actuator retracting after the pilot's DN does not)

function M.inputs()
    return {
        lever = 0,                      -- the speedbrake lever (M.DN .. M.UP)
        tla = {0, 0, 0, 0},             -- thrust lever angles, degrees from idle
        reverse = {false, false, false, false},   -- the reverse lever raised
        hyd_psi = {0, 0},               -- hydraulic systems 1, 4
        pri_gnd = false, alt_gnd = false,   -- the gear's primary and alternate ground sensing
        dc1 = true,                     -- DC bus 1 (AUTO SPD BRK)
        ra = 0,                         -- radio altitude, ft
        landing_flaps = false,          -- the TE flaps at 25 or 30
        actuator_stuck = false,         -- the auto speedbrake actuator does not move
    }
end

function M.new()
    local s = {
        act = 0,                        -- the actuator: 0 retracted .. 1 extended
        driving = 0,                    -- the actuator driving the lever: 1 up, -1 down, 0 not
        fault_t = 0,
    }
    s.out = {
        lever = 0,                      -- the lever after the actuator
        driving = 0,
        extend = false, retract = false,    -- the relays R835, R834
        speedbrake_auto = false,        -- advisory SPEEDBRAKE AUTO (and STATUS)
        speedbrakes_ext = false,        -- caution >SPEEDBRAKES EXT
        armed = false,                  -- memo SPEEDBRAKE ARMED
    }
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    local lever = inp.lever

    -- the relays (ATA27 p.176-184, the p.181 schematic; FCOM p.951). R837
    -- and R838: hydraulic system 1 or 4 above 1600 psi with the PSEU's
    -- primary, alternate ground sensing (simplified: p.182 pairs system 1
    -- with the body gear down and not tilted, system 4 with the wing gear
    -- not tilted)
    local idle = function(n) return inp.reverse[n] or inp.tla[n] <= M.IDLE_TLA end
    local idle13 = idle(1) and idle(3)
    local hyd = inp.hyd_psi[1] > M.GND_PSI or inp.hyd_psi[2] > M.GND_PSI
    local r837, r838 = hyd and inp.pri_gnd, hyd and inp.alt_gnd
    local armed = lever >= M.ARM_LO                 -- S217
    local rev24 = inp.reverse[2] or inp.reverse[4]  -- S861
    -- extension: thrust levers 1 and 3 at idle, armed or reverse lever 2
    -- or 4 raised, both control relays on the ground. Retraction: thrust
    -- lever 1 or 3 advanced, in the air too (the p.181 schematic)
    local extend = inp.dc1 and idle13 and (armed or rev24) and r837 and r838
    local retract = inp.dc1 and not idle13
    out.extend, out.retract = extend, retract

    -- the actuator drives the lever through the no-back brake, which the
    -- pilot can always override; the pilot's DN drives it back to retracted
    -- (p.170). It drives the lever down when it is out, or on the ground with
    -- the spoilers up (FCOM p.951: ground spoilers extended by hand too); a
    -- speedbrake set by hand in flight, or the lever at ARM, has the actuator
    -- retracted and stays
    local step = (M.UP - M.DN) / M.ACTUATOR_S * dt
    local driving = 0
    if not inp.actuator_stuck then
        if extend and not retract then
            if lever < M.UP then lever = math.min(M.UP, lever + step); driving = 1 end
            s.act = math.min(1, s.act + dt / M.ACTUATOR_S)
        elseif retract then
            if lever > M.DN and (s.act > 0 or s.driving == -1 or (r837 and r838 and lever > M.ABOVE_ARM)) then
                lever = math.max(M.DN, lever - step); driving = -1
            end
            s.act = math.max(0, s.act - dt / M.ACTUATOR_S)
        elseif lever < M.ARM_LO then
            s.act = math.max(0, s.act - dt / M.ACTUATOR_S)      -- the pilot's DN
        end
    end
    s.driving = driving
    out.lever, out.driving = lever, driving

    -- SPEEDBRAKE AUTO (ATA27 p.184; FCOM p.952): S217 not armed with the
    -- actuator not retracted; the extend and retract relays together; the
    -- primary and alternate control relays disagreeing
    local fault = (not armed and s.act > 0) or (extend and retract) or (r837 ~= r838)
    if fault then s.fault_t = s.fault_t + dt else s.fault_t = 0 end
    out.speedbrake_auto = s.fault_t >= M.FAULT_S

    -- >SPEEDBRAKES EXT (FCOM p.958; ATA27 p.740): the lever above the arm
    -- detent above 15 ft RA, with the TE flaps at 25 or 30, at or below 800
    -- ft, or more than one thrust lever above the speedbrake power level
    local fwd = 0
    for n = 1, 4 do
        if not inp.reverse[n] and inp.tla[n] > M.POWER_TLA then fwd = fwd + 1 end
    end
    out.speedbrakes_ext = lever > M.ABOVE_ARM and inp.ra > M.SBEXT_RA_LO
        and (inp.landing_flaps or inp.ra <= M.SBEXT_RA_HI or fwd >= 2)
    out.armed = lever >= M.ARM_LO and lever <= M.ABOVE_ARM
    return out
end

return M
