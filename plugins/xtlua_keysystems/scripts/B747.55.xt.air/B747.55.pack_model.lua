-- 747-400 air conditioning packs without X-Plane: the flow control and
-- shutoff valves (FCSOV) of packs 1-3, normal and high flow and the flow
-- schedule, the recirculation fans, the pack temperature controllers A and
-- B, the pack trips and PACK RST, and the EICAS messages of the packs.
-- Logic and sources: docs/overhaul/notes/ATA-21.md §2.1, §4.1, §4.2, §4.7
-- (FCOM 2.10-2.50, ATA21 21-00, 21-20, 21-50, 21-60).
--
--   local P = B747_pack_model             -- in XTLua, after dofile
--   local P = dofile(".../B747.55.pack_model.lua")   -- in the tests
--   local s = P.new()
--   local inp = P.inputs()                -- fill it every frame
--   local out = P.update(s, inp, dt)      -- the same table every frame

local M = setmetatable({}, {})
B747_pack_model = M

M.VALVE_MIN_PSI = 12        -- the FCSOV needs 12 psi to open; a spring closes it (ATA21 p.40-42)
-- flow in the bleed model's unit, one pack at high flow; normal is 2/3 of
-- high (ATA21 p.86)
M.HIGH, M.NORMAL = 1.0, 2 / 3
M.PACK_STEP_S = 15          -- the packs change flow one at a time, 15 s apart (ATA21 p.387, p.389)
M.FAN_STEP_S = 5            -- the recirculation fans 5 s apart
M.PTC_LOST_S = 30           -- PACK n: neither controller controls the pack for 30 s (ATA21 p.102)
M.INIT_S = 3                -- no touchdown in a new flight's first seconds (XTLua's first reads
                            -- are 0; the air/ground can be late)
-- estimates (no value in the sources)
M.VALVE_TRAVEL_S = 3        -- the FCSOV, closed to open

-- the recirculation fans: 1 upper right, 2 upper left, 3 lower left,
-- 4 lower right (ATA21 p.139, p.141); the lower fan that stands in for a
-- failed upper one
M.STANDIN = {[1] = 3, [2] = 4}
-- in cruise, one failed fan sets one pack to high (ATA21 p.141)
M.FAN_PACK = {2, 2, 1, 3}

function M.inputs()
    return {
        selector = {1, 1, 1},           -- PACK 1-3: 0 OFF, 1 NORM, 2 A, 3 B
        duct_psi = {0, 0, 0},           -- the ducts that feed packs 1, 2, 3: left, centre, right
        hi_flow = false,                -- HI FLOW switch
        trim_air = true,                -- TRIM AIR switch
        recirc_upr = true,              -- UPR RECIRC switch
        recirc_lwr = true,              -- LWR RECIRC switch
        pack_rst = false,               -- PACK RST pushed (this frame)
        cargo_fire_arm = false,         -- FWD or AFT cargo fire ARM
        relief_open = false,            -- a positive pressure relief valve open (the pressurization model)
        cruise_clamp = false,           -- the ECS card's cruise clamp (the pressurization model)
        on_ground = true,
        dc = {true, true, true, true},  -- DC bus 1-4
        ac = {true, true, true, true},  -- AC bus 1-4
        any_ac = true,                  -- the fans (their buses are not in the sources)
        overheat = {false, false, false},           -- failure: a pack overheat (trips it)
        fan_failed = {false, false, false, false},  -- failure: a recirculation fan
        ptc_failed = {false, false},                -- failure: PTC A, B
    }
end

function M.new()
    local s = {t = 0, first = true, norm_ptc = 1, was_ground = true,
        valve = {0, 0, 0}, tripped = {false, false, false}, high = {true, true, true},
        want_high = {true, true, true}, forced_high = {false, false, false}, lost_t = {0, 0, 0},
        fan = {false, false, false, false}, want_fan = {false, false, false, false},
        forced_off = {false, false, false, false},
        pack_step_t = M.PACK_STEP_S, fan_step_t = M.FAN_STEP_S}
    s.out = {valve = {0, 0, 0}, flow = {0, 0, 0}, high = {false, false, false},
        operating = {false, false, false}, packs_operating = 0, ptc = {0, 0, 0},
        fan = {false, false, false, false}, sys_fault = false,
        pack_alert = {false, false, false}, control_alert = false}
    return s
end

local function travel(pos, target, seconds, dt)
    local step = dt / seconds
    if pos < target then return math.min(target, pos + step) end
    return math.max(target, pos - step)
end

function M.update(s, inp, dt)
    s.t = s.t + dt
    local out = s.out
    local fire = inp.cargo_fire_arm

    -- pack temperature controllers: A on DC bus 3 and AC bus 3, B on bus 4
    -- (ATA21 p.84). NORM uses A and B on alternate flights and changes at
    -- touchdown; a failed controller hands over to the other; TRIM AIR off
    -- keeps A (FCOM p.556, p.560, p.588; ATA21 p.81)
    if inp.on_ground and not s.was_ground and s.t > M.INIT_S then s.norm_ptc = 3 - s.norm_ptc end
    s.was_ground = inp.on_ground
    local ptc_ok = {inp.dc[3] and inp.ac[3] and not inp.ptc_failed[1],
        inp.dc[4] and inp.ac[4] and not inp.ptc_failed[2]}

    local operating = 0
    for p = 1, 3 do
        local sel = inp.selector[p]
        -- trips latch until PACK RST with the overheat gone, or the selector
        -- OFF (FCOM p.560; ATA21 p.78, p.82, p.94)
        if inp.overheat[p] and sel ~= 0 then s.tripped[p] = true end
        if s.tripped[p] and (sel == 0 or (inp.pack_rst and not inp.overheat[p])) then s.tripped[p] = false end
        -- the valve: open with the selector not OFF and 12 psi; closed by a
        -- trip, by cargo fire ARM (pack 3) and by an open relief valve
        -- (pack 2) (ATA21 p.42, p.86, p.94; FCOM p.609, p.908)
        local cmd = sel ~= 0 and not s.tripped[p] and not (p == 3 and fire) and not (p == 2 and inp.relief_open)
        local target = (cmd and inp.duct_psi[p] >= M.VALVE_MIN_PSI) and 1 or 0
        if s.first then s.valve[p] = target else s.valve[p] = travel(s.valve[p], target, M.VALVE_TRAVEL_S, dt) end
        out.valve[p] = s.valve[p]
        out.operating[p] = s.valve[p] >= 0.5
        if out.operating[p] then operating = operating + 1 end

        local want = (sel == 2 and 1) or (sel == 3 and 2) or s.norm_ptc
        if not inp.trim_air then want = 1 end
        if ptc_ok[want] then out.ptc[p] = want
        elseif ptc_ok[3 - want] then out.ptc[p] = 3 - want
        else out.ptc[p] = 0 end
        if out.ptc[p] == 0 and sel ~= 0 then s.lost_t[p] = s.lost_t[p] + dt else s.lost_t[p] = 0 end
    end
    out.packs_operating = operating

    -- failed fans
    local failed, upper_failed = 0, 0
    for f = 1, 4 do
        if inp.fan_failed[f] then
            failed = failed + 1
            if f <= 2 then upper_failed = upper_failed + 1 end
        end
    end

    -- the flow each pack should have: high on the ground, in climb and in
    -- descent, with fewer than three packs, a failed fan, HI FLOW, a relief
    -- valve open (packs 1 and 3) or cargo fire ARM (packs 1 and 2); normal
    -- in the cruise clamp (FCOM p.558, p.588, p.609; ATA21 p.86, p.90,
    -- p.94, p.138-141, p.386-387)
    local forced = inp.hi_flow or operating < 3 or failed >= 2 or fire or inp.relief_open
    for p = 1, 3 do
        local f_high = forced
        if failed == 1 then
            for f = 1, 4 do if inp.fan_failed[f] and M.FAN_PACK[f] == p then f_high = true end end
        end
        s.forced_high[p] = f_high
        s.want_high[p] = f_high or not inp.cruise_clamp
    end

    -- the fans: the upper pair on the ground, in climb and in descent, all
    -- four in the cruise clamp; a failed upper fan brings in the lower one
    -- below it; all four with a pack off; none with cargo fire ARM; HI FLOW
    -- with three packs high stops two (the lower pair: estimate) (ATA21
    -- p.23, p.134, p.138-141, p.386-389; FCOM p.556)
    local four = inp.cruise_clamp or operating < 3
    if inp.hi_flow and operating == 3 then four = false end
    for f = 1, 4 do
        local on = f <= 2 or four or upper_failed >= 2
        for u = 1, 2 do
            if inp.fan_failed[u] and M.STANDIN[u] == f then on = true end
        end
        local switch = (f <= 2 and inp.recirc_upr) or (f >= 3 and inp.recirc_lwr)
        s.forced_off[f] = not switch or fire or inp.fan_failed[f] or not inp.any_ac
        s.want_fan[f] = on and not s.forced_off[f]
    end

    -- the schedule's changes go one at a time: packs 15 s apart, fans 5 s
    -- apart (ATA21 p.387, p.389); a pack set high for another reason, a fan
    -- switched off, failed or unpowered, and a pack that cannot run follow
    -- at once (estimate: the sources stagger only the schedule)
    s.pack_step_t = s.pack_step_t + dt
    for p = 1, 3 do
        if s.first or not out.operating[p] or (s.forced_high[p] and not s.high[p]) then s.high[p] = s.want_high[p]
        elseif s.high[p] ~= s.want_high[p] and s.pack_step_t >= M.PACK_STEP_S then
            s.high[p] = s.want_high[p]
            s.pack_step_t = 0
        end
    end
    s.fan_step_t = s.fan_step_t + dt
    for f = 1, 4 do
        if s.first or (s.forced_off[f] and s.fan[f]) then
            s.fan[f] = s.want_fan[f]
        elseif s.fan[f] ~= s.want_fan[f] and s.fan_step_t >= M.FAN_STEP_S then
            s.fan[f] = s.want_fan[f]
            s.fan_step_t = 0
        end
        out.fan[f] = s.fan[f]
    end

    out.sys_fault = false
    for p = 1, 3 do
        out.high[p] = s.high[p] and out.operating[p]
        out.flow[p] = s.valve[p] * (s.high[p] and M.HIGH or M.NORMAL)
        -- PACK n: a trip, pack 2 shut by the relief valve, or no controller
        -- for 30 s (FCOM p.620; ATA21 p.102); SYS FAULT: a trip (FCOM p.560)
        out.pack_alert[p] = s.tripped[p] or (p == 2 and inp.relief_open and inp.selector[2] ~= 0)
            or s.lost_t[p] >= M.PTC_LOST_S
        if s.tripped[p] then out.sys_fault = true end
    end
    -- PACK CONTROL: no automatic temperature control of any pack (FCOM p.620;
    -- estimate: neither controller for every pack)
    out.control_alert = s.lost_t[1] >= M.PTC_LOST_S and s.lost_t[2] >= M.PTC_LOST_S and s.lost_t[3] >= M.PTC_LOST_S

    s.first = false
    return out
end

return M
