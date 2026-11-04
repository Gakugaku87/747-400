-- 747-400 takeoff configuration warning (the MAWEA's configuration warning
-- card) without X-Plane: >CONFIG FLAPS, >CONFIG GEAR CTR, >CONFIG PARK BRK,
-- >CONFIG SPOILERS (its takeoff part) and >CONFIG STAB.
-- Sources: FCOM p.1557 (15.20.11), p.1603-1604 (15.30); ATA27 p.729-730;
-- ATA31 p.180, p.188-194; docs/overhaul/notes/ATA-31-warning.md §4.5.
--
--   local W = B747_tocw_model              -- in XTLua, after dofile
--   local W = dofile(".../B747.45.tocw_model.lua")   -- in the tests
--   local s, inp = W.new(), W.inputs()
--   local out = W.update(s, inp, dt)       -- the same table every frame
--
-- The warning is armed on the ground below V1 with three or more FUEL
-- CONTROL switches in RUN and engine 2 or 3 at takeoff thrust: its N1
-- indication above 66.5 (P&W), 66.7 (RR) or 75.0 (GE) (ATA27 p.730). Without
-- a V1 the takeoff inhibit starts at 5 degrees of pitch instead (ATA31
-- p.180, p.188). A message goes at once when the configuration is put
-- right, and 10 s after the takeoff thrust goes (ATA27 p.730).

local M = setmetatable({}, {})
B747_tocw_model = M

M.N1_TO = {[0] = 66.5, [1] = 75.0, [2] = 66.7}   -- the engine type: 0 P&W, 1 GE, 2 RR
M.HOLD_S = 10
M.PITCH_DEG = 5
M.V1_NONE = 999      -- the FMC's V1 when none is selected (B744.fms.pages.takeoff.lua)
M.MESSAGES = {"flaps", "gear_ctr", "park_brk", "spoilers", "stab"}

function M.inputs()
    return {
        on_ground = true,            -- the PSEU
        ias_kt = 0,
        v1_kt = 999,                 -- 999 (or 0): no V1 from the FMC
        pitch_deg = 0,
        fuel_run = 0,                -- FUEL CONTROL switches in RUN
        n1 = {0, 0, 0, 0},           -- the N1 indications of engines 1-4
        reverse = false,             -- a reverser out: no takeoff thrust (estimate)
        engine_type = 0,
        -- the configuration
        flaps_to = true,             -- the flaps in a takeoff position
        body_unlocked = false,       -- a body gear steering actuator not locked
        park_brake = false,          -- the parking brake lever set
        speedbrake_not_down = false, -- the speedbrake lever not DOWN
        stab_in_band = true,         -- the stabilizer in the greenband
    }
end

function M.new()
    local s = {hold = {}, out = {armed = false, takeoff_thrust = false}}
    for _, k in ipairs(M.MESSAGES) do s.hold[k] = nil; s.out[k] = false end
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    local thr = M.N1_TO[inp.engine_type] or M.N1_TO[0]
    local takeoff_thrust = (inp.n1[2] > thr or inp.n1[3] > thr) and not inp.reverse
    -- below V1; without a V1 until the rotation (5 degrees of pitch)
    local before_v1
    if inp.v1_kt > 0 and inp.v1_kt < M.V1_NONE then before_v1 = inp.ias_kt < inp.v1_kt
    else before_v1 = inp.pitch_deg <= M.PITCH_DEG end
    local can_arm = inp.on_ground and before_v1 and inp.fuel_run >= 3
    local armed = can_arm and takeoff_thrust
    local wrong = {
        flaps = not inp.flaps_to,
        gear_ctr = inp.body_unlocked,
        park_brk = inp.park_brake,
        spoilers = inp.speedbrake_not_down,
        stab = not inp.stab_in_band,
    }
    for _, k in ipairs(M.MESSAGES) do
        if not wrong[k] or not can_arm then
            s.hold[k] = nil                      -- put right, airborne, at V1 or the switches
        elseif armed then
            s.hold[k] = 0
        elseif s.hold[k] ~= nil then
            s.hold[k] = s.hold[k] + dt           -- the takeoff thrust gone: 10 s more
            if s.hold[k] >= M.HOLD_S then s.hold[k] = nil end
        end
        out[k] = s.hold[k] ~= nil
    end
    out.armed, out.takeoff_thrust = armed, takeoff_thrust
    return out
end

return M
