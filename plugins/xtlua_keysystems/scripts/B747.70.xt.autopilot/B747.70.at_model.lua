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
--    G/A; after takeoff on the TO limit: THR REF), the SPD switch (from
--    400 ft after takeoff until landing, not the TO limit, not in VNAV,
--    FLCH, T/O or G/A), the THR switch (the same heights: THR REF on
--    CLB, CLB 1, CLB 2, CRZ or CON in ALT or V/S, on GA in G/S or FLARE
--    or in ALT or V/S with the landing flaps, FCOM p.642; its thrust
--    limit function the FMC's, B747.68.thrlim_model.lua).
--    No TO/GA push by 50 kt on the ground: none until 400 ft (FCOM p.656).
--  - Disengaged by the ARM switch off, the interlocks lost, a disconnect
--    switch, the reversers. AUTOTHROT DISC latches when it was engaged
--    (not for the reversers on the ground); the next engage or a
--    disconnect push resets it (FCOM p.657, p.677; ATA34_2 p.644).
--  - The modes (the FMA's numbers: HOLD 1, IDLE 2, SPD 3, THR 4, THR REF
--    5): TO's THR REF, HOLD from 65 kt until VNAV engages or another mode
--    is selected (FCOM p.667; ATA34_2 p.654); VNAV's the FMC's (SPD when
--    levelled: FCOM p.645), its IDLE HOLD once the levers reach the aft
--    stop (ATA34_2 p.666), its THR (the early descent; the driftdown, no
--    HOLD: the FMC's step 9h4b; the cruise descent's SPD since 9h4c) HOLD
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
-- reducing within SPD_DOWN_KT of the target (FCTM p.43: in gusts up fast,
-- down slowly), full from its far end (FCTM p.139: 340 to 250 kt level in
-- about 90 s, at idle nearly all the way); THR: a fpm of the V/S error;
-- THR REF and the thrust limit: an EPR's (PW, RR) or a % N1's (GE) error
-- of the levers' command (the EEC's TRA: no spool lag). In X-Plane the
-- engines' thrust lags the levers some 7 s near idle: 0.006 and 0.05 had
-- SPD's levers swing idle to 0.3 every 30 s at 250 kt (s01, 9f2's first
-- run; a lagged loop's simulation the same), 0.002 and 0.06 settled but
-- took the speed down too slowly (2026-11-03: the levers held for 18 s
-- while the flaps took the speed off, s112's balloon at the G/S capture;
-- 220 to 216 kt in 20 s, s43; a simulation 137 s for FCTM p.139's 90 s);
-- 0.004 and 0.06 with the full rate far from the target took 340 to 250
-- kt in 97 s (s220) but swung the levers every 20 s at flaps 20 and 170
-- kt, settling in some 100 s (s112, at_hold_f20: 46 to 106 kN): there a
-- lever's tenth changes the acceleration some 0.6 kt/s and the loop was
-- too strong for the engines' lag. 0.003 and 0.045, the acceleration
-- over 0.5 s (the glue's), settle in 40 s (2026-11-04; K_ACC / K_SPD,
-- the approach's 15 s, kept)
M.K_SPD, M.K_ACC, M.SPD_DOWN = 0.003, 0.045, 0.5
M.SPD_DOWN_KT = {5, 15}
-- (2026-11-13; the 2026-11-12 review AT-3, AT-4, B5) SPD with the flaps up.
-- (AT-4) K_SPD and K_ACC were tuned at 270 t, low, with the flaps out, where
-- a unit of lever gives some 6 kt/s of IAS (G); at 307 t and FL370 it gives
-- 0.83, and the loop's damping, (K_ACC / 2) sqrt(G / K_SPD), fell from 1.0
-- to 0.4 (s262: +3.0, -1.0, +0.85 kt over 280 s after a +21 kt target).
-- With the flaps up the gains are times G_TGT / G (from 1 to G_SCALE_MAX):
-- G estimated as G_C delta (IAS/TAS) (1 - G_MACH M) / (the weight, t),
-- fitted within 20 % to the EEC's and the engines' models (the review's) at
-- 12 points from 238 t at 10,000 ft to 397 t at FL310 and FL410; G_TGT the
-- loop's G aimed at by the pressure ratio, less up high where X-Plane's
-- engines answer slower (2.9 and 1.3 s at 11,000 ft, 3.2 and 1.8 at FL250,
-- 5.8 and 2.1 at FL390: the EEC's open-loop test, notes/ATA-70-80.md §14;
-- on G alone the acceleration's loop swung the levers every 22 s at
-- FL370). (AT-3) SPD_DOWN_UP: with the flaps up the reduction near the
-- target is cut less (FCTM p.43's up fast, down slowly is the approach's;
-- the cruise's gusts are the speed complement's, GUST_TAU). Estimates: the
-- sources give no gains. On the review's models: a +10 kt step within 0.5
-- kt over (before up to +4.1), s262's swing +0.34 kt (+2.42), a 10 kt shear
-- in the cruise back within 1 kt in 42 to 57 s (164 to 168 s before), the
-- levers' travel the same or less
M.G_C, M.G_MACH, M.G_SCALE_MAX = 3630, 0.488, 8
M.G_TGT = {{0.66, 5.0}, {0.37, 4.2}, {0.194, 2.7}}
M.SPD_DOWN_UP = 0.75
M.K_VS = 1.2e-5
-- G/A's THR on the energy's rate (evs, as VNAV's: the speed's change
-- counts) and faster (estimate: on the V/S at K_VS the levers took 37 s
-- from the approach's thrust to 2,000 fpm and the speed fell 14 kt; at
-- 5e-5 the V/S went past to 3,300 fpm and back to 200 with the engines'
-- lag: aero_go_around, 2026-11-02, notes/AERO.md §3.15)
M.K_VS_GA = 3e-5
-- (2026-11-11 review) THR REF on the levers' command: the levers set the
-- reference thrust within some 12 s of TO/GA (FCOM p.667: the A/T advances
-- them to the reference thrust limit; FCTM p.93: set by 80 kt). The command
-- has no spool lag, the servo's 0.2 a second limits the travel. Before, 0.33
-- and 0.003 (a time constant of 5.7 s, P&W, and 4.1 s, GE): HOLD at 65 kt
-- froze them short, EPR 0.016 to 0.028 under the TO reference to 400 ft
-- (s142, 2026-11-10 and 11, 270 to 340 t)
M.K_EPR, M.K_N1 = 1.0, 0.009
-- FLCH's V/S: the altitude change in 125 s (ATA34_2 p.670); G/A's 2,000
-- fpm (p.674); the speed protection's margin (FCOM p.675: the FMC's five
-- knots against the maximum speeds' overshoots and the flaps extended
-- minimum speed's undershoot)
M.FLCH_S, M.GA_VS = 125, 2000
M.LIMIT_MARGIN = 5
-- (2026-11-10) the clean airplane in the air's gusts (estimates: the
-- sources give no filter; notes/ATA-34-61-FMC.md §162). SPD's speed law
-- flies the speed complemented by the inertial acceleration: the TAS
-- through GUST_TAU s with the acceleration along the air path (the IRU's
-- flight path acceleration, ATA34_2 p.280) added at once, back in IAS by
-- the IAS/TAS ratio, and that speed's rate. In still air that is the IAS
-- itself (the airplane's acceleration is the airspeed's); a change of the
-- air, a gust or a shear, comes in over GUST_TAU. FCOM p.214 (SP.16.14):
-- the levers busier with the wind's, the temperature's and the pressure's
-- changes; FCTM p.301: the A/T more aggressive near VMO/MMO, so back to
-- the IAS within GUST_FADE_KT of the maximum speed's limit (v_max less
-- LIMIT_MARGIN) and of the minimum maneuvering speed. Flaps extended the
-- IAS as before (FCTM p.43: the approach's gust protection). A Sperry
-- cruise Mach hold (US4641268, 1983) keeps the short gusts off the
-- throttles by an isolation filter: the same aim. On the KSEA-KLAX
-- record's gusts (2026-11-09, FL390, X-Plane's real weather, 1.3 kt) a
-- model of the airplane had the levers travel 0.33 of their range a
-- minute and the speed 0.9 kt over its target on the IAS (X-Plane: +0.7
-- kt); complemented over 20 s 0.05 and +0.1 kt, the speed's spread the
-- same (0.7 kt), a +5 kt target the same, a 10 kt shear over 30 s 4 kt
-- slow (2.5 before). The IAS/TAS ratio over GUST_RATIO_S: in the record
-- the ratio's quick changes went against the gusts' (the IAS a little
-- behind the TAS), which would bring a share of each gust back in
M.GUST_TAU, M.GUST_FADE_KT, M.GUST_RATIO_S = 20, 10, 2
-- (2026-11-07) FLCH's climb: the V/S the thrust is to make is the energy's
-- rate at the target speed (evs, as VNAV's THR and G/A: the inertial V/S
-- and the energy the speed gains, which the elevator turns into climb)
-- while the speed is at or over its target, from none of it FLCH_EVS_KT
-- under the target (there the acceleration is the speed law's own, to the
-- speed: the thrust to the limit as before); descents on the V/S alone (to
-- the aft stop and HOLD, p.670). On the inertial V/S alone the levers went
-- on while the V/S lagged the pitch-up at the speed law's 0.1 g: at 270 t
-- and 10,000 ft a 5,000 ft FLCH climb from 250 kt set 122 kN an engine
-- for a 2,350 fpm rate, the speed went to 262 kt and the V/S to 4,150 fpm
-- (s108, 2026-11-07); a model of that run (tests/autopilot/
-- flch_entry_test.lua) stops the thrust under 100 kN and the speed within
-- 10 kt, the V/S settling on the rate. The sources give the V/S (ATA34_2
-- p.646, p.670), not its measure: an estimate (notes/ATA-34-61-FMC.md §152).
-- (2026-11-13, B5) Descents on it too while the speed is at or under its
-- target (the servo's THR)
M.FLCH_EVS_KT = 5
-- (the FMC's step 9d2) VNAV's THR (the early descent, the driftdown): the
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
        air = false,        -- above 400 ft since the takeoff, until the landing
        idle_hold = false,  -- VNAV's or the retard's IDLE at the aft stop
        thr_hold = false,   -- VNAV's THR at its V/S, the aft stop, the hand
        reach_t = 0,        -- VNAV's THR: the seconds at its V/S
        vnav_dd = false,    -- the FMC's driftdown the update before (its step 9h4b)
        lx = nil, lx_mach = nil, lx_rate = 0,  -- target_vs: ln of the target's measure, its rate
        vnav_phase = nil,   -- the FMC's phase the update before
        ga = false,         -- G/A's THR (the first push) on
        retard = false,     -- the flare retard's IDLE
        servo = false, cmd = 0,  -- the servo excited, its lever command
        gust_v = nil, gust_i = 0, gust_a = 0, gust_r = 0,  -- servo: the complemented TAS, its IAS and rate, IAS/TAS
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

-- inp: arm, ok, ground, cas, ra, flaps_up, flaps_landing (the handle at 25
-- or 30), reverse, limit_to, limit_ga, limit_ref (CLB, CLB 1, CLB 2, CRZ or
-- CON; nil: neither TO nor GA), pitch (the AFDS's: "TO", "GA", "VNAV",
-- "FLCH", "VS", "ALT", "GS",
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
    if s.pitch ~= "FLCH" then s.flch_vs, s.flch_mcp = nil, nil end
    -- the MCP's SPD and THR switches: from 400 ft after takeoff until the
    -- landing (FCOM p.641-642; 2026-11-05 review 3: before, above 400 ft
    -- radio altitude only, so dead below it on the approach)
    if inp.ground then
        s.air = false
    elseif inp.ra > M.MIN_RA then
        s.air = true
    end
    local air = s.air
    local p = inp.pitch
    if inp.spd and can and air and not inp.limit_to
        and p ~= "VNAV" and p ~= "FLCH" and p ~= "TO" and p ~= "GA" then
        s.to = false
        engage(s, M.SPD)
    end
    -- the THR switch's A/T mode function (FCOM p.642): THR REF on CLB, CLB
    -- 1, CLB 2, CRZ or CON in ALT or V/S; on GA in G/S or FLARE, or in ALT
    -- or V/S with the landing flaps. Elsewhere (VNAV, FLCH, T/O, G/A) its
    -- thrust limit function only, the FMC's. (2026-11-05 review 4: before,
    -- THR REF in any pitch mode but VNAV and FLCH, G/S too, and never on GA)
    if inp.thr and can and air then
        local ref_limit = inp.limit_ref
        if ref_limit == nil then ref_limit = not inp.limit_to and not inp.limit_ga end
        local alt_vs = p == "ALT" or p == "VS"
        if (ref_limit and alt_vs) or (inp.limit_ga
            and (p == "GS" or p == "FLARE" or (alt_vs and inp.flaps_landing))) then
            s.to = false
            engage(s, M.THR_REF)
        end
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

-- (B5) the ISA's pressure ratio at a pressure altitude (ft)
local function delta_of(alt)
    if alt <= 36089 then return (1 - 6.8756e-6 * alt) ^ 5.2559 end
    return 0.22336 * math.exp(-(alt - 36089) / 20806)
end
-- (B5) the loop's G aimed at, by the pressure ratio (G_TGT)
function M.g_target(alt)
    local d, tg = delta_of(alt), M.G_TGT
    if d >= tg[1][1] then return tg[1][2] end
    for i = 2, #tg do
        if d >= tg[i][1] then
            local f = (d - tg[i][1]) / (tg[i - 1][1] - tg[i][1])
            return tg[i][2] + f * (tg[i - 1][2] - tg[i][2])
        end
    end
    return tg[#tg][2] * math.sqrt(d / tg[#tg][1])
end
-- (B5) G, the acceleration a unit of lever gives (kt/s of IAS), estimated
-- from the servo's inputs (weight kg, mach, tas kt, ias, alt); nil without
function M.lever_accel(inp)
    if not (inp.weight and inp.weight > 0 and inp.tas and inp.tas > 50 and inp.mach and inp.alt) then return nil end
    return M.G_C * delta_of(inp.alt) * (inp.ias / inp.tas) * (1 - M.G_MACH * inp.mach) / (inp.weight / 1000)
end

-- the speed law's lever rate to a speed: the error and the acceleration,
-- less when reducing near the target; k the gains' scale and flaps_up
-- SPD_DOWN_UP's (B5)
local function speed_rate(ias, accel, tgt, k, flaps_up)
    local e = tgt - ias
    local r = (k or 1) * (M.K_SPD * e - M.K_ACC * accel)
    if r < 0 then
        local b = M.SPD_DOWN_KT
        local x = clamp((-e - b[1]) / (b[2] - b[1]), 0, 1)
        local down = flaps_up and M.SPD_DOWN_UP or M.SPD_DOWN
        r = r * (down + (1 - down) * x)
    end
    return r
end

-- (2026-11-10) the inertial acceleration along the air path (kt/s of TAS)
-- for gust_speed: the acceleration (m/s/s) on the velocity less the wind
-- (m/s), any one frame of axes (the glue's X-Plane OpenGL ones); 0 under 1
-- m/s of air. On the ground speed's rate alone a turn in a wind reads the
-- wind's swing (some 1 kt/s at 15 degrees of bank in 90 kt)
function M.path_accel(ax, ay, az, vx, vy, vz, wx, wy, wz)
    local x, y, z = vx - wx, vy - wy, vz - wz
    local v = math.sqrt(x * x + y * y + z * z)
    if v < 1 then return 0 end
    return (ax * x + ay * y + az * z) / v * 3600 / 1852
end

-- (2026-11-10) SPD's speed and its rate in the air's gusts (GUST_TAU):
-- with the flaps up, inp.tas (kt) and inp.accel_in (the inertial
-- acceleration along the air path, kt/s of TAS) the TAS complemented by
-- that acceleration, in IAS by the IAS/TAS ratio, its rate through the
-- glue's half second; within GUST_FADE_KT of the speed limits back to the
-- IAS. Each frame (it runs on in every mode); else the IAS and inp.accel
-- (2026-11-11 review) none under the time acceleration (`inp.time_accel`):
-- the acceleration is per X-Plane's second, the frames' dt real time (XTLua's
-- SIM_PERIOD), and the complement fell short of the TAS's change (at 4 x in
-- a 2,000 fpm descent at a constant IAS about 9 kt IAS: the A/T's SPD that
-- slow)
local function gust_speed(s, inp)
    if inp.time_accel or not (inp.flaps_up and inp.accel_in and inp.tas and inp.tas > 50 and inp.ias > 30 and inp.dt > 0) then
        s.gust_v = nil
        return inp.ias, inp.accel
    end
    if not s.gust_v then
        s.gust_v, s.gust_i, s.gust_a, s.gust_r = inp.tas, inp.ias, inp.accel, inp.ias / inp.tas
        return inp.ias, inp.accel
    end
    -- the acceleration's step, then the TAS's share of what is left
    s.gust_v = s.gust_v + inp.accel_in * inp.dt
    s.gust_v = s.gust_v + (inp.tas - s.gust_v) * math.min(1, inp.dt / M.GUST_TAU)
    s.gust_r = s.gust_r + (inp.ias / inp.tas - s.gust_r) * math.min(1, inp.dt / M.GUST_RATIO_S)
    local ias = s.gust_v * s.gust_r
    s.gust_a = s.gust_a + ((ias - s.gust_i) / inp.dt - s.gust_a) * math.min(1, inp.dt / 0.5)
    s.gust_i = ias
    local w = clamp(math.min(inp.v_max - M.LIMIT_MARGIN - inp.ias, inp.ias - (inp.v_min or 0))
        / M.GUST_FADE_KT, 0, 1)
    return inp.ias + w * (ias - inp.ias), inp.accel + w * (s.gust_a - inp.accel)
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
-- step 9h4b); lever (the levers' mean); tas (kt) and accel_in (the inertial
-- acceleration along the air path, kt/s of TAS) for SPD in the gusts
-- (GUST_TAU; none: the IAS)
function M.servo(s, inp)
    local gias, gacc = gust_speed(s, inp)
    -- (B5) the lever's acceleration G and SPD's gains' scale, flaps up
    local g_lev = inp.flaps_up and M.lever_accel(inp) or nil
    local k = g_lev and clamp(M.g_target(inp.alt) / g_lev, 1, M.G_SCALE_MAX) or 1
    -- (B5, AT-3) the inertial V/S's rate (m/s/s), over a second
    if s.ff_vs and inp.ivs and inp.dt > 0 then
        s.ff_acc = (s.ff_acc or 0) + (((inp.ivs - s.ff_vs) * 0.3048 / 60) / inp.dt - (s.ff_acc or 0)) * math.min(1, inp.dt)
    end
    s.ff_vs = inp.ivs
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
    -- limit's rate. Without a reference (0 or less: the EEC's bug not set)
    -- no limit: THR REF holds the levers, SPD and THR are not capped
    -- (estimate; 2026-11-05 review 4: before, the whole thrust was over the
    -- reference and every mode took the levers back to the aft stop)
    local ref = inp.thrust_ref or 0
    if inp.thrust_max and inp.thrust_max < ref then ref = inp.thrust_max end
    local limit, cap = 0, math.huge   -- the thrust limit's rate
    if ref > 0 then
        local over = inp.thrust - ref
        limit = -k_thr * over
        if over > 0 then
            cap = limit
        else
            cap = -over * M.SERVO_RATE / (inp.n1 and M.REF_NEAR_N1 or M.REF_NEAR_EPR)
        end
    end
    local vmax = inp.v_max - M.LIMIT_MARGIN
    local rate
    if mode == M.IDLE then
        rate = -(s.retard and M.FLARE_RATE or M.SERVO_RATE)
    elseif mode == M.THR_REF then
        -- the reference thrust, the limit speed (ATA34_2 p.672)
        rate = math.min(limit, speed_rate(inp.ias, inp.accel, vmax, k, inp.flaps_up))
    elseif mode == M.SPD then
        -- the floor the minimum maneuvering speed, with the margin only
        -- with the flaps extended (FCOM p.675), as the pitch laws'
        -- (afds_pitch_model.lua). 2026-11-06: with it flaps up too, the
        -- A/T held M.858 for the MCP's M.85 at 307 t and FL370
        -- (PERF_SIMBRIEF phase 1)
        local tgt = clamp(inp.target, inp.v_min + (inp.flaps_up and 0 or M.LIMIT_MARGIN), vmax)
        rate = speed_rate(gias, gacc, tgt, k, inp.flaps_up)
        -- (B5, AT-3) the thrust follows the path's change: a vertical speed
        -- dh at the same speed needs W dh / V more thrust (the energy's), its
        -- lever by G (flaps up; estimate: the sources give no law). Before,
        -- at an altitude capture from THR REF's climb the levers came back
        -- only once the speed rose: 8 to 11 kt over the target at every
        -- weight (s139: +10.1 kt at FL170; the KSEA-KLAX T/C M.883 for
        -- .859); on the review's models now 0.6 to 4.5 kt
        if g_lev and s.ff_acc and inp.tas and inp.tas > 50 then
            local v = inp.tas * 0.514444
            rate = rate + 9.80665 * s.ff_acc / v / 0.514444 / (g_lev * inp.tas / inp.ias)
        end
        rate = math.min(rate, cap)
    else
        -- THR: FLCH's V/S to the MCP altitude in 125 s, G/A's 2,000 fpm,
        -- VNAV's the FMC's (step 9d2a: the early descent; 9h4b: the driftdown);
        -- climbing not less thrust (ATA34_2 p.646), but G/A controls to its
        -- V/S (p.675: above it, less)
        local vnav = s.pitch == "VNAV"
        -- FLCH's: the V/S that completes the altitude change in 125 s from
        -- where it began, held to its end (ATA34_2 p.670); a new MCP
        -- altitude from where the airplane is then. Before, the change left
        -- each frame: an approach that never ended (s07's 400 ft took 440 s
        -- to the capture)
        if not (vnav or s.ga) and (s.flch_vs == nil or s.flch_mcp ~= inp.mcp_alt) then
            s.flch_mcp, s.flch_vs = inp.mcp_alt, (inp.mcp_alt - inp.alt) / M.FLCH_S * 60
        end
        local want = s.ga and M.GA_VS or (vnav and (inp.vnav_vs or 0)) or s.flch_vs
        local vs = (vnav and inp.ivs) or inp.vs
        local ev
        if vnav or s.ga then
            ev = inp.evs or vs
        elseif want > 0 and inp.evs and inp.target then
            -- FLCH's climb (2026-11-07): the energy's rate while the speed
            -- is at or over its target, the V/S under it
            local w = clamp((inp.ias - inp.target) / M.FLCH_EVS_KT + 1, 0, 1)
            ev = vs + w * (inp.evs - vs)
        elseif want < 0 and inp.evs and inp.target then
            -- (2026-11-13; the review AT-6, B5) FLCH's descent: the energy's
            -- rate too, while the speed is at or under its target, from none
            -- of it FLCH_EVS_KT over it (as the climb's: the elevator turns
            -- the speed's change into the path; estimate). On the V/S alone a
            -- light airplane's small descent swung: 210 t, 180 kt, 1,000 ft
            -- down, -744 to -201 fpm with a 52 s period for -480 (now -561 to
            -- -479). A large descent still goes to the aft stop and HOLD
            local w = clamp((inp.target - inp.ias) / M.FLCH_EVS_KT + 1, 0, 1)
            ev = vs + w * (inp.evs - vs)
        else
            ev = vs
        end
        rate = (vnav and M.K_VS_VNAV or s.ga and M.K_VS_GA or M.K_VS) * (want - ev)
        if want > 0 and rate < 0 and not s.ga then rate = 0 end
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
        -- (p.648, p.670); VNAV's at its V/S too, latched. (2026-11-12
        -- review AT-7) The hand's HOLD in FLCH only: ATA34_2 p.648's Pilot
        -- Override Logic is FL CH's; in the other modes the levers go back
        -- to the servo's position when let go, the mode unchanged (before,
        -- VNAV's THR too: a stopped engine's lever closed in a driftdown put
        -- the A/T in HOLD for good)
        local hand = not vnav and math.abs(inp.lever - s.cmd) > M.OVERRIDE
        if not s.ga and ((want < 0 and s.cmd <= 0 and rate < 0) or hand or reached) then
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
