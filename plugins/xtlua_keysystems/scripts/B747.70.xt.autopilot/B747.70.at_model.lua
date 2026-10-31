-- 747-400 A/T (the FMC's thrust management) without X-Plane (6-4, the
-- FMC's step 9f1; docs/overhaul/notes/ATA-34-61-FMC.md §58): its engage
-- logic and AUTOTHROT DISC, its modes, how they are selected and change;
-- from step 9f2 (§60) its control laws and servo (`servo`: the levers'
-- command the EEC puts them at while excited).
--  - Engage (ATA34_2 p.644): the A/T ARM switch on and the interlocks met
--    (`inp.ok`: the engines, the EECs' ALTN, the switch's own fail); a
--    mode engages it (FCOM p.641-642, p.656; ATA34_2 p.647, p.660-674):
--    VNAV or FLCH engaging (or the ARM switch put on while they are), a
--    TO/GA push (on the ground under 50 kt with the flaps out and the TO
--    limit: TO; in the air with the flaps out or G/S, not the TO limit:
--    G/A; after takeoff on the TO limit: THR REF), the SPD switch (above
--    400 ft, not the TO limit, not in VNAV, FLCH, T/O or G/A), the THR
--    switch (above 400 ft, not the TO or GA limit, not in VNAV or FLCH).
--    No TO/GA push by 50 kt on the ground: none until 400 ft (FCOM p.656).
--  - Disengaged by the ARM switch off, the interlocks lost, a disconnect
--    switch, the reversers. AUTOTHROT DISC latches when it was engaged
--    (not for the reversers on the ground); the next engage or a
--    disconnect push resets it (FCOM p.657, p.677; ATA34_2 p.644).
--  - The modes (the FMA's numbers: HOLD 1, IDLE 2, SPD 3, THR 4, THR REF
--    5): TO's THR REF, HOLD from 65 kt until VNAV engages or another mode
--    is selected (FCOM p.667; ATA34_2 p.654); VNAV's the FMC's (SPD when
--    levelled: FCOM p.645), its IDLE HOLD once the levers reach the aft
--    stop (ATA34_2 p.666), its THR (the early and the cruise descent) HOLD
--    at the FMC's V/S (FMSPG p.3.5-5: step 9d2a); FLCH's THR, G/A's THR
--    then THR REF at a second push (step 9f2; ATA34_2 p.674); from VNAV or
--    FLCH into ALT, V/S or G/S, SPD (ATA34_2 p.654; from T/O or G/A not:
--    FCOM p.673); the flare retard's IDLE
--    (ATA34_2 p.648) through the rollout until the reversers.
-- Pure: the airplane's state and the switches' pushes in, the A/T out.
--   local A = B747_at_model                     -- in XTLua, after dofile
--   local A = dofile(".../B747.70.at_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_at_model = M

M.HOLD, M.IDLE, M.SPD, M.THR, M.THR_REF = 1, 2, 3, 4, 5
-- TO's HOLD (FCOM p.667), TO/GA's last speed on the ground (ATA34_2
-- p.660), the SPD and THR switches' height (FCOM p.641-642); a stop again
-- on the ground ends the no-TO inhibit (estimate)
M.TO_HOLD_KT = 65
M.TO_ARM_KT = 50
M.MIN_RA = 400
M.STOP_KT = 30
-- the servo (step 9f2; ATA34_2 p.472, p.648): the laws' lever rates
-- integrated to its command, at most 10 degrees a second, the flare
-- retard's 5 (the 3D lever's 50 degrees of travel: 0.2 and 0.1 of it a
-- second, estimate); FLCH's override at 8 degrees off the command
M.SERVO_RATE, M.FLARE_RATE = 0.2, 0.1
M.OVERRIDE = 0.16
-- (the FMC's step 9h4b) SPD's and THR's levers forward slower within this
-- of the reference thrust (EPR, % N1), to none at it (estimates)
M.REF_NEAR_EPR, M.REF_NEAR_N1 = 0.05, 2.5
-- the laws' gains (estimates: the sources give none). SPD: the lever's
-- rate a kt of the speed's error and a kt/s of its acceleration, less when
-- reducing (FCTM p.43: up fast, down slowly); THR: a fpm of the V/S
-- error; THR REF and the thrust limit: an EPR's (PW, RR) or a % N1's (GE)
-- error of the levers' command (the EEC's TRA: no spool lag). In X-Plane
-- the engines' thrust lags the levers some 7 s near idle: 0.006 and 0.05
-- had SPD's levers swing idle to 0.3 every 30 s at 250 kt (s01, 9f2's
-- first run; a lagged loop's simulation the same), 0.002 and 0.06 settle
M.K_SPD, M.K_ACC, M.SPD_DOWN = 0.002, 0.06, 0.5
M.K_VS = 1.2e-5
M.K_EPR, M.K_N1 = 0.33, 0.003
-- FLCH's V/S: the altitude change in 125 s (ATA34_2 p.670); G/A's 2,000
-- fpm (p.674); the speed protection's margin (FCOM p.675)
M.FLCH_S, M.GA_VS = 125, 2000
M.LIMIT_MARGIN = 5
-- (the FMC's step 9d2) VNAV's THR (the early and the cruise descent): the
-- levers to the FMC's V/S on the energy's rate at the target speed (the V/S
-- the speed would give held at its target, in the target's IAS or Mach: the
-- elevator trades speed for height, s146's +1,500 fpm slowing 12 kt to the
-- descent's speed was the energy's -100 to -800; on the TAS's change alone a
-- held IAS's falling TAS left the V/S 260 fpm shallower and no HOLD; ATA34_2
-- p.647's FMC reference thrust in steady flight: estimate), at half FLCH's
-- K_VS (the engines' lag alone in that loop; a simulation of s146's
-- engines, 2 s and 4 to 7 s behind: within 100 fpm in 25 s, FLCH's gain
-- swinging). HOLD with the inertial V/S and the energy's rate within
-- VS_REACHED of the FMC's and the speed within SPD_REACHED of its target
-- for REACH_S (FMSPG p.3.5-5: THR HOLD on reaching the 1,250 fpm; the
-- bands and the time: estimates). In X-Plane: the VSI passing the rate 50
-- kt slow held a thrust that flew level at the target speed (s144); the
-- inertial V/S passing it as the pitch levelled a dive held the cruise's
-- thrust (s145); on the V/S at a quarter of K_VS the levers went on to the
-- aft stop as the airplane climbed slowing down, then -2,600 fpm at idle
-- (s146)
M.VS_REACHED, M.SPD_REACHED, M.REACH_S = 100, 5, 5
M.K_VS_VNAV = 6e-6
-- the energy's rate at the target speed (target_vs): ft/min of V^2 d(ln
-- X)/dt / g with the TAS in m/s
M.EVS_K = 60 / 9.80665 / 0.3048

function M.new()
    return {engaged = false, mode = nil, disc = false,
        to = false,         -- TO: "thr" from the push on the ground, "hold"
                            -- from 65 kt, "air" pushed after takeoff
        no_to = false,      -- no push by 50 kt: no engage until 400 ft
        idle_hold = false,  -- VNAV's or the retard's IDLE at the aft stop
        thr_hold = false,   -- VNAV's THR at its V/S, the aft stop, the hand
        reach_t = 0,        -- VNAV's THR: the seconds at its V/S
        vnav_dd = false,    -- the FMC's driftdown the update before (its step 9h4b)
        lx = nil, lx_mach = nil, lx_rate = 0,  -- target_vs: ln of the target's measure, its rate
        vnav_phase = nil,   -- the FMC's phase the update before
        ga = false,         -- G/A's THR (the first push) on
        retard = false,     -- the flare retard's IDLE
        servo = false, cmd = 0,  -- the servo excited, its lever command
        pitch = nil, arm = nil}
end

-- VNAV's mode: the FMC's, SPD levelled; IDLE's and THR's HOLDs latched
-- until the FMC asks another (step 9d2a: levelled too; before, IDLE's
-- latch stayed through a level-off, HOLD at once when the descent went on)
local function vnav_mode(s, inp)
    -- a new FMC phase: THR first again (the early descent after a cruise
    -- descent: FCOM p.1260)
    if inp.vnav_phase ~= s.vnav_phase then s.thr_hold = false end
    s.vnav_phase = inp.vnav_phase
    -- (the FMC's step 9h4b) the driftdown's start: THR again (FCOM p.1268:
    -- the A/T advances the engines to CON, from a cruise descent's HOLD too)
    if inp.vnav_dd and not s.vnav_dd then s.thr_hold = false end
    s.vnav_dd = inp.vnav_dd and true or false
    local at = inp.vnav_level and M.SPD or inp.vnav_at
    if at ~= M.IDLE then s.idle_hold = false end
    if at ~= M.THR then s.thr_hold = false end
    if at == M.IDLE then
        if inp.lever_idle then s.idle_hold = true end
        return s.idle_hold and M.HOLD or M.IDLE
    end
    if at == M.THR then return s.thr_hold and M.HOLD or M.THR end
    if at and at >= M.HOLD and at <= M.THR_REF then return at end
    return M.SPD
end

-- the mode the pitch mode asks for when the A/T engages with it (FLCH's
-- THR: step 9f2)
local function pitch_mode(s, inp)
    if inp.pitch == "VNAV" then return vnav_mode(s, inp) end
    if inp.pitch == "FLCH" then return M.THR end
    return M.SPD
end

local function engage(s, mode)
    s.engaged, s.mode, s.disc = true, mode, false
    s.ga, s.retard = false, false
end

local function disengage(s, latch)
    if s.engaged and latch then s.disc = true end
    s.engaged, s.mode, s.to, s.idle_hold, s.thr_hold = false, nil, false, false, false
    s.ga, s.retard = false, false
end

-- inp: arm, ok, ground, cas, ra, flaps_up, reverse, limit_to, limit_ga,
-- pitch (the AFDS's: "TO", "GA", "VNAV", "FLCH", "VS", "ALT", "GS",
-- "FLARE" or nil), retard, vnav_at (the FMC's A/T mode), vnav_level,
-- vnav_phase (the FMC's: step 9d2a), vnav_dd (the FMC's driftdown: its step
-- 9h4b), lever_idle (the levers at the aft stop); the pushes since the last
-- update: toga, spd, thr, disc (true when pushed)
function M.update(s, inp)
    local was = s.pitch
    -- the no-TO inhibit: no push by 50 kt on the ground (FCOM p.656)
    if inp.ground then
        if not s.engaged and inp.cas >= M.TO_ARM_KT then s.no_to = true end
        if inp.cas < M.STOP_KT then s.no_to = false end
    elseif inp.ra > M.MIN_RA then
        s.no_to = false
    end
    local can = inp.arm and inp.ok and not s.no_to
    -- the ARM switch, the interlocks, the reversers
    if s.engaged and not inp.arm then disengage(s, true) end
    if s.engaged and not inp.ok then disengage(s, true) end
    if s.engaged and inp.reverse then disengage(s, not inp.ground) end
    if inp.arm and s.arm == false and not s.engaged and can
        and (inp.pitch == "VNAV" or inp.pitch == "FLCH") then
        engage(s, pitch_mode(s, inp))
    end
    s.arm = inp.arm and true or false
    -- a disconnect push: off with AUTOTHROT DISC, else its reset
    if inp.disc then
        if s.engaged then disengage(s, true) else s.disc = false end
    end
    -- TO/GA
    if inp.toga and can then
        if inp.ground then
            if inp.cas < M.TO_ARM_KT and not inp.flaps_up and inp.limit_to then
                engage(s, M.THR_REF)
                s.to = "thr"
            end
        elseif inp.limit_to then
            -- after takeoff on the TO limit: THR REF (its derate off: 9g)
            engage(s, M.THR_REF)
            s.to = "air"
        elseif not inp.flaps_up or inp.pitch == "GS" then
            -- G/A: THR at 2,000 fpm, a second push THR REF (ATA34_2 p.674)
            if s.engaged and s.ga then
                engage(s, M.THR_REF)
            else
                engage(s, M.THR)
                s.ga = true
            end
            s.to = false
        end
    end
    -- the pitch modes engaging
    if inp.pitch ~= was then
        if (inp.pitch == "VNAV" or inp.pitch == "FLCH") and can then
            s.to = false
            engage(s, pitch_mode(s, inp))
        elseif s.engaged and (was == "VNAV" or was == "FLCH")
            and (inp.pitch == "ALT" or inp.pitch == "VS" or inp.pitch == "GS") then
            engage(s, M.SPD)
        end
    end
    s.pitch = inp.pitch
    -- the MCP's SPD and THR switches
    local air = not inp.ground and inp.ra > M.MIN_RA
    local p = inp.pitch
    if inp.spd and can and air and not inp.limit_to
        and p ~= "VNAV" and p ~= "FLCH" and p ~= "TO" and p ~= "GA" then
        s.to = false
        engage(s, M.SPD)
    end
    if inp.thr and can and air and not inp.limit_to and not inp.limit_ga
        and p ~= "VNAV" and p ~= "FLCH" then
        s.to = false
        engage(s, M.THR_REF)
    end
    -- the engaged modes as they go on
    if s.engaged then
        if inp.retard then
            s.mode, s.retard = M.IDLE, true
        elseif s.to then
            if s.to == "thr" and inp.cas > M.TO_HOLD_KT then s.mode, s.to = M.HOLD, "hold" end
        elseif p == "VNAV" then
            s.mode = vnav_mode(s, inp)
        end
    end
    return s
end

local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

-- (step 9d2) the energy's rate at the target speed for VNAV's THR (evs,
-- fpm): the inertial V/S ivs and the energy the speed's change gives, the
-- change taken in the target's own measure x, the IAS (kt) or the Mach (mach
-- true): a held IAS's TAS falls going down, so on the TAS's change the V/S
-- came 260 fpm shallower than the energy's rate at a held 294 kt (s146) and
-- HOLD never came. ln x's rate through a second's filter, kept a frame when
-- the measure changes; tas in m/s; each frame before servo
function M.target_vs(s, ivs, tas, x, mach, dt)
    if x > (mach and 0.05 or 30) then
        local lx = math.log(x)
        if s.lx and s.lx_mach == mach and dt > 0 then
            s.lx_rate = s.lx_rate + ((lx - s.lx) / dt - s.lx_rate) * math.min(1, dt)
        end
        s.lx, s.lx_mach = lx, mach
    end
    return ivs + M.EVS_K * tas * tas * s.lx_rate
end

-- the speed law's lever rate to a speed: the error and the acceleration,
-- less when reducing
local function speed_rate(inp, tgt)
    local r = M.K_SPD * (tgt - inp.ias) - M.K_ACC * inp.accel
    if r < 0 then r = r * M.SPD_DOWN end
    return r
end

-- the servo (step 9f2; ATA34_2 p.646-648): each frame after update, the
-- engaged mode's law as a lever rate, integrated to the command within the
-- servo's rate; excited unless HOLD or off (the command then follows the
-- levers). inp (beside update's): dt; ias, accel (kt/s), target (the speed
-- laws' kt), v_max and v_min (the maximum and the minimum maneuvering
-- speeds); vs (fpm), alt, mcp_alt, vnav_vs (the FMC's V/S for VNAV's THR:
-- step 9d2), ivs (the inertial V/S for it; vs without), evs (the energy's
-- rate at the target speed for it, fpm: the inertial V/S and the speed's
-- change in the target's IAS or Mach; ivs without); thrust and
-- thrust_ref (EPR or % N1, n1 true for N1), thrust_max (the EEC's
-- full-forward rating: the most the levers give, nil not known; the FMC's
-- step 9h4b); lever (the levers' mean)
function M.servo(s, inp)
    local mode = s.engaged and s.mode or nil
    if mode ~= M.THR then s.reach_t = 0 end
    if mode == nil or mode == M.HOLD then
        s.servo, s.cmd = false, inp.lever
        return s
    end
    if not s.servo then s.servo, s.cmd = true, inp.lever end
    local k_thr = inp.n1 and M.K_N1 or M.K_EPR
    -- (the FMC's step 9h4b) the reference within the EEC's full-forward
    -- rating (above 25,000 ft the maximum climb, under CON's reference: the
    -- levers past 35° give no more). SPD's and THR's levers forward slower
    -- within REF_NEAR of it, to none there, so they stop where the thrust
    -- does (s157's driftdown had wound them to the forward stop at CON's
    -- reference: eight minutes back through the band); over it back at the
    -- limit's rate (none without a reference)
    local ref = inp.thrust_ref
    if inp.thrust_max and inp.thrust_max < ref then ref = inp.thrust_max end
    local over = inp.thrust - ref
    local limit = -k_thr * over   -- the thrust limit's rate
    local cap = math.huge
    if over > 0 then
        cap = limit
    elseif ref > 0 then
        cap = -over * M.SERVO_RATE / (inp.n1 and M.REF_NEAR_N1 or M.REF_NEAR_EPR)
    end
    local vmax = inp.v_max - M.LIMIT_MARGIN
    local rate
    if mode == M.IDLE then
        rate = -(s.retard and M.FLARE_RATE or M.SERVO_RATE)
    elseif mode == M.THR_REF then
        -- the reference thrust, the limit speed (ATA34_2 p.672)
        rate = math.min(limit, speed_rate(inp, vmax))
    elseif mode == M.SPD then
        local tgt = clamp(inp.target, inp.v_min + M.LIMIT_MARGIN, vmax)
        rate = math.min(speed_rate(inp, tgt), cap)
    else
        -- THR: FLCH's V/S to the MCP altitude in 125 s, G/A's 2,000 fpm,
        -- VNAV's the FMC's (step 9d2a: the early and the cruise descent);
        -- climbing not less thrust (ATA34_2 p.646)
        local vnav = s.pitch == "VNAV"
        local want = s.ga and M.GA_VS or (vnav and (inp.vnav_vs or 0)) or (inp.mcp_alt - inp.alt) / M.FLCH_S * 60
        local vs = (vnav and inp.ivs) or inp.vs
        local ev = (vnav and inp.evs) or vs
        rate = (vnav and M.K_VS_VNAV or M.K_VS) * (want - ev)
        if want > 0 and rate < 0 then rate = 0 end
        rate = math.min(rate, cap)
        -- VNAV's descent at its V/S and the energy's at the target speed
        -- for REACH_S (FMSPG p.3.5-5)
        local at_rate = vnav and want < 0 and math.abs(vs - want) <= M.VS_REACHED
            and math.abs(ev - want) <= M.VS_REACHED
            and math.abs(inp.ias - inp.target) <= M.SPD_REACHED
        s.reach_t = at_rate and s.reach_t + inp.dt or 0
        -- (the FMC's step 9h4b) not in the driftdown: its rate held, at
        -- least 300 fpm with CON the most (FCOM p.1268)
        local reached = s.reach_t >= M.REACH_S and not inp.vnav_dd
        -- the descent at the aft stop, or the hand 8 degrees off: HOLD
        -- (p.648, p.670); VNAV's at its V/S too, latched
        if not s.ga and ((want < 0 and s.cmd <= 0 and rate < 0)
            or math.abs(inp.lever - s.cmd) > M.OVERRIDE or reached) then
            s.mode, s.servo, s.cmd, s.reach_t = M.HOLD, false, inp.lever, 0
            if vnav then s.thr_hold = true end
            return s
        end
    end
    s.cmd = clamp(s.cmd + clamp(rate, -M.SERVO_RATE, M.SERVO_RATE) * inp.dt, 0, 1)
    return s
end

-- the FMA's number: the mode engaged, else blank
function M.fma(s)
    return s.engaged and s.mode or 0
end

return M
