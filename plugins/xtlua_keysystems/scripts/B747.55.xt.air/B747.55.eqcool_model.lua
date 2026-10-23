-- 747-400 equipment cooling without X-Plane: the forward system's supply
-- and exhaust fans and its valves in NORM, STBY and OVRD (on the ground
-- overboard or into the forward cargo by the skin temperature; the flight
-- configuration with an engine running on each side; the closed loop with
-- a failed fan; the override by the cabin's differential pressure), cargo
-- fire ARM, and EQUIP COOLING. Logic and sources: docs/overhaul/notes/
-- ATA-21.md §2.5, §4.6, §4.7 (FCOM p.557-558, p.603-605, p.619, p.908;
-- ATA21 21-58).
--
--   local Q = B747_eqcool_model            -- in XTLua, after dofile
--   local Q = dofile(".../B747.55.eqcool_model.lua")   -- in the tests
--   local s = Q.new()
--   local inp = Q.inputs()                 -- fill it every frame
--   local out = Q.update(s, inp, dt)       -- the same table every frame

local M = setmetatable({}, {})
B747_eqcool_model = M

M.STBY, M.NORM, M.OVRD = 0, 1, 2            -- EQUIP COOLING selector
-- configurations (out.config)
M.OVERBOARD, M.CARGO, M.CLOSED_LOOP, M.OVERRIDE, M.OFF = 1, 2, 3, 4, 0

M.SKIN_C = (45 - 32) * 5 / 9 -- 45°F, 7.2°C: overboard above, into the forward cargo below
                                     -- (FCOM p.605; ATA21 p.512, p.538, p.546)
M.FAN_FAIL_S = 10            -- a fan not turning for 10 s is failed (ATA21 p.524)
M.FAN_RESET_S = 30           -- reset: OVRD for 30 s, then back (ATA21 p.524)
M.OVRD_ALERT_S = 55          -- OVRD without the differential pressure: EQUIP COOLING after 55 s (ATA21 p.594-598)
-- estimates (no value in the sources)
M.OVRD_DP = 1.0              -- the OVRD differential pressure switch, psi
M.OVRD_KG_S = 0.25           -- the air OVRD takes overboard, at 8.8 psi (the cabin model)

function M.inputs()
    return {
        selector = 1,                   -- 0 STBY, 1 NORM, 2 OVRD
        on_ground = true,               -- air/ground
        engine_left = false,            -- engine 1 or 2 running
        engine_right = false,           -- engine 3 or 4 running
        skin_c = 15,                    -- the skin temperature (the outside air)
        cargo_fire_arm = false,         -- FWD or AFT cargo fire ARM (FCOM p.908)
        dp = 0,                         -- cabin differential pressure, psi
        ac = true,                      -- the fans and the motor valves (their buses: estimate)
        bat = true,                     -- main battery bus: the smoke/override valve (ATA21 p.611)
        fan_failed = {false, false},    -- failure: the supply, exhaust fan
        overheat = false,               -- failure: equipment cooling overheat (130°F)
        low_flow = false,               -- failure: low flow
        smoke = false,                  -- failure: smoke in the exhaust air
    }
end

function M.new()
    local s = {fan_t = {0, 0}, fan_fault = false, reset_t = 0, ovrd_t = 0}
    s.out = {config = M.OFF, fans = false, ground_exhaust = false, inboard_exhaust = false,
        inboard_supply = false, bypass = false, smoke_override = false,
        overboard_kg_s = 0, cargo_warm = false, alert = false, state = 0}
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    local ovrd = inp.selector == M.OVRD or inp.cargo_fire_arm

    -- a fan not turning for 10 s faults the system into the closed loop
    -- (no EICAS message); OVRD for 30 s resets it (ATA21 p.524, p.552-556)
    for f = 1, 2 do
        if inp.fan_failed[f] and not ovrd then s.fan_t[f] = s.fan_t[f] + dt else s.fan_t[f] = 0 end
        if s.fan_t[f] >= M.FAN_FAIL_S then s.fan_fault = true end
    end
    if inp.selector == M.OVRD then s.reset_t = s.reset_t + dt else s.reset_t = 0 end
    if s.reset_t >= M.FAN_RESET_S then s.fan_fault = false end

    -- the configuration (FCOM p.557-558, p.603-605; ATA21 p.504-512,
    -- p.546-556, p.580-584): override by the selector or cargo fire ARM;
    -- the flight configuration in the air, with an engine on each side, or
    -- in STBY; on the ground by the skin temperature
    local config
    if ovrd then config = M.OVERRIDE
    elseif not inp.ac then config = M.OFF
    elseif s.fan_fault then config = M.CLOSED_LOOP
    elseif inp.selector == M.STBY or not inp.on_ground or (inp.engine_left and inp.engine_right) then config = M.CARGO
    elseif inp.skin_c > M.SKIN_C then config = M.OVERBOARD
    else config = M.CARGO end
    out.config = config
    out.fans = inp.ac and (config == M.OVERBOARD or config == M.CARGO or config == M.CLOSED_LOOP)
    out.ground_exhaust = config == M.OVERBOARD
    out.inboard_exhaust = config == M.CARGO
    out.inboard_supply = config == M.OVERBOARD or config == M.CARGO
    out.bypass = config == M.CLOSED_LOOP
    out.smoke_override = config == M.OVERRIDE and inp.bat
    out.cargo_warm = config == M.CARGO       -- the forward cargo heat (ATA21 p.254-256)
    -- OVRD draws cabin air overboard through the equipment by the
    -- differential pressure (estimate: in proportion to it)
    if out.smoke_override and inp.dp > 0 then out.overboard_kg_s = M.OVRD_KG_S * math.min(1, inp.dp / 8.8)
    else out.overboard_kg_s = 0 end

    -- EQUIP COOLING: overheat, low flow or smoke in NORM or STBY; in OVRD
    -- the differential pressure too low for 55 s (on the ground: estimate,
    -- no differential) (FCOM p.619; ATA21 p.530, p.548, p.578, p.594-598)
    if config == M.OVERRIDE and inp.dp < M.OVRD_DP then s.ovrd_t = s.ovrd_t + dt else s.ovrd_t = 0 end
    out.alert = s.ovrd_t >= M.OVRD_ALERT_S
        or (config ~= M.OVERRIDE and (inp.overheat or inp.low_flow or inp.smoke))
    out.state = out.fans and 1 or 0
    return out
end

return M
