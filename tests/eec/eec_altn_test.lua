-- Run from the repository root with LuaJIT: luajit tests/eec/eec_altn_test.lua
-- (2026-11-20, GAP_ANALYSIS.md N19-ENG-05; notes/ATA-70-80.md §25) The
-- PW4000 EEC's alternate mode is its N1 mode (PW_PPM p.196-198, p.204-205):
-- the N1 command from the thrust lever angle and Tt2 only, not limited at
-- the maximum EPR (the redline's at the forward stop, the overspeed
-- protection holding it); the automatic reversion's lockup keeps the
-- thrust (delta N1 held, p.197-198), manual selection removes it at about
-- 100 rpm a second, back to the EPR mode with the switch once the fault is
-- gone (p.198); the ALTN light of an automatic reversion through the N2 >
-- 50 % contact (p.199). The FCOM's crew-visible rules (p.877, p.900): at
-- least the normal mode's thrust at the same lever, the maximum reached
-- before full forward, LIM PROT as the thrust approaches the maximum. The
-- GE and the RR keep their alternate modes. Before, the P&W's ALTN kept
-- controlling EPR (the corner point's line): every N1-mode check here
-- fails on that code.
local T = dofile("tests/lib/check.lua")("eec_altn")
local root = "plugins/xtlua/scripts/B747.42.xt.EEC/"
local P = dofile(root .. "B747.42.epr_model.lua")
local E = dofile(root .. "B747.42.eec_model.lua")
local A = E.PW_ALTN
local DT = 0.1
local function sqrt_theta(tat) return math.sqrt((tat + 273.15) / 288.15) end

-- the schedule: corrected N1 by lever angle, times the square root of Tt2
-- (PW_PPM p.196: TRA biased by Tt2)
T.near(E.pw_altn_n1(2, 15), 20, 1e-9, "the flat idle: the idle end, n1c 20 (estimate)")
T.near(E.pw_altn_n1(0, 15), 20, 1e-9, "under the flat idle: the idle end")
T.near(E.pw_altn_n1(44, 15), 105.6, 1e-9, "44 degrees (TRA about 78, p.197): the highest full-forward rating's n1c and a little more")
T.near(E.pw_altn_n1(50, 15), 118, 1e-9, "the forward stop: 118, beyond the N1 red line 111.4 at 15 degrees C (p.197: the redline)")
T.near(E.pw_altn_n1(30, -30), 99 * sqrt_theta(-30), 1e-9, "TAT -30: the corrected N1 times sqrt(theta)")
T.check(E.pw_altn_n1(30, 35) > E.pw_altn_n1(30, 15), "warmer: more N1 (Tt2 bias)")
do
    local up = true
    for t = 2, 49 do up = up and E.pw_altn_n1(t + 1, 15) >= E.pw_altn_n1(t, 15) end
    T.check(up, "the schedule never falls as the lever goes forward")
    -- steep from idle, flatter above (the shape of p.197, p.205)
    T.check(E.pw_altn_n1(10, 15) - E.pw_altn_n1(2, 15) > 2 * (E.pw_altn_n1(44, 15) - E.pw_altn_n1(10, 15)) / 4,
        "the first 8 degrees climb faster than the rest to 44")
end

-- FCOM p.877: the alternate mode gives at least the normal mode's thrust at
-- the same lever, and the maximum before full forward. The normal mode's
-- EPR command through the EPR model's corrected N1 (the shown N1 from 70 %),
-- over the envelope: 0-43,000 ft, ISA-25 to +35, the speeds flown (on the
-- ground standing to 10,000 ft; above 25,000 ft M.70 and up), packs on or
-- off, anti-ice off or engine and wing
local function mach_of(kias, alt)
    local p0, a0 = 101325, 661.4788
    local p = p0 * (1 - 6.87559e-6 * alt) ^ 5.25588
    if alt > 36089 then p = 22632 * math.exp(-(alt - 36089) / 20806) end
    local qc = p0 * ((1 + 0.2 * (kias / a0) ^ 2) ^ 3.5 - 1)
    return math.sqrt(5 * ((qc / p + 1) ^ (2 / 7) - 1))
end
do
    local worst, where, cases = math.huge, "", 0
    local top_ok, top_where = true, ""
    for alt = 0, 43000, 2000 do
        local isa = math.max(15 - 1.98 * alt / 1000, -56.5)
        for _, dev in ipairs({-25, -5, 15, 35}) do
            for _, kias in ipairs({0, 150, 200, 250, 300, 350}) do
                local m = kias > 0 and mach_of(kias, alt) or 0
                local flown = m <= 0.86 and (alt <= 10000 or (kias >= 220 and (alt <= 25000 or m >= 0.70)))
                if flown then
                    local tat = (isa + dev + 273.15) * (1 + 0.2 * m * m) - 273.15
                    for _, packs in ipairs({3, 0}) do
                        for _, ai in ipairs({false, true}) do
                            local s, i = E.new(), E.inputs()
                            i.type, i.alt, i.tat, i.kias, i.air = "PW", alt, tat, kias, kias > 0
                            i.packs_on, i.wai = packs, ai
                            i.nai = {ai, ai, ai, ai}
                            local idle = P.idle_command(m)
                            i.idle = {idle, idle, idle, idle}
                            for tla = 12, 48, 2 do
                                i.lever = {tla / 50, tla / 50, tla / 50, tla / 50}
                                local o = E.update(s, i, DT)
                                local c = P.n1c(o.command[1], m)
                                if c >= 70 then
                                    cases = cases + 1
                                    local margin = E.pw_altn_n1(tla, tat) / sqrt_theta(tat) - c
                                    if margin < worst then
                                        worst = margin
                                        where = string.format("%d deg, %d ft, ISA%+d, %d kt", tla, alt, dev, kias)
                                    end
                                end
                                if tla == 48 and P.n1c(o.max[1], m) > E.pw_altn_n1(44, tat) / sqrt_theta(tat) then
                                    top_ok, top_where = false, string.format("%d ft, ISA%+d, %d kt", alt, dev, kias)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    T.check(cases > 3000, "the envelope's cases: " .. cases)
    T.check(worst >= 0, string.format("ALTN at least the normal mode's N1 at the same lever (FCOM p.877): the least margin %.2f at %s", worst, where))
    T.check(top_ok, "every full-forward rating reached by 44 degrees, before full forward (FCOM p.877) " .. top_where)
end
-- a sea level takeoff (15 degrees C, standing): the rating's n1c 100.7
-- (EPR 1.51) comes at about 32 degrees, the crew setting the alternate
-- mode's takeoff EPR (PI.15.6) with the lever
do
    local t = 2
    while E.pw_altn_n1(t, 15) < P.n1(1.51, 0, 15) do t = t + 0.1 end
    T.check(t > 28 and t < 36, string.format("sea level takeoff EPR 1.51 at %.1f degrees", t))
end

-- the cruise of the failure tests: P&W at 31,000 ft, TAT -25, the levers at
-- 25 degrees, N1 80 % (the EPR mode's), N2 95 %
local function cruise()
    local st, i = E.new(), E.inputs()
    i.type, i.alt, i.tat, i.kias, i.air = "PW", 31000, -25, 280, true
    i.idle = {0.6, 0.6, 0.6, 0.6}
    i.lever = {0.5, 0.5, 0.5, 0.5}
    i.n1, i.n2, i.actual = {80, 80, 80, 80}, {95, 95, 95, 95}, {1.30, 1.30, 1.30, 1.30}
    return st, i
end

-- manual selection (the EEC MODE switch at ALTN) from the EPR mode: the N1
-- mode at once, the command from the N1 now, ramped at 100 rpm a second
-- (2.78 % N1) to the schedule (p.198; FCOM p.877: the thrust increases)
do
    local st, i = cruise()
    local o = E.update(st, i, DT)
    T.check(not o.n1_mode[2], "the EPR mode before")
    st.throttle[2], st.ref[2] = 0.7, 1.3        -- the EPR loop's state
    i.altn[2] = true
    o = E.update(st, i, DT)
    T.check(o.n1_mode[2] and o.altn[2] and not o.n1_mode[1], "ALTN 2: engine 2 in the N1 mode (ENG 2 EEC MODE)")
    T.near(o.command[2], 80 + A.ramp * DT, 1e-9, "the command: the N1 now plus one step of the ramp")
    T.check(st.throttle[2] == nil and st.ref[2] == nil, "the thrust control starts again (EPR to N1)")
    T.check(o.at_disconnect and o.at_inhibit, "the A/T disconnects and cannot be used (FCOM p.877)")
    T.check(o.altn_light[2], "the ALTN light")
    local sched = E.pw_altn_n1(25, -25)
    local t = DT
    while o.command[2] < sched - 1e-9 and t < 30 do
        o = E.update(st, i, DT)
        t = t + DT
    end
    T.near(t, DT * math.ceil((sched - 80) / (A.ramp * DT) - 1e-9), DT + 1e-9,
        string.format("the schedule's %.1f %% reached at 100 rpm a second (%.1f s)", sched, t))
    o = E.update(st, i, DT)
    T.near(o.command[2], sched, 1e-9, "then the schedule: the lever sets N1")
    T.check(o.command[2] > 80, "more N1 than the EPR mode at the same lever")
    i.lever[2] = 0.7
    o = E.update(st, i, DT)
    T.near(o.command[2], E.pw_altn_n1(35, -25), 1e-9, "the lever forward: the schedule's N1 at 35 degrees")
    i.tat = -15
    o = E.update(st, i, DT)
    T.near(o.command[2], E.pw_altn_n1(35, -15), 1e-9, "warmer: biased by Tt2 only (no altitude, Mach or bleed)")
    i.alt, i.kias = 20000, 300
    o = E.update(st, i, DT)
    T.near(o.command[2], E.pw_altn_n1(35, -15), 1e-9, "lower and faster: the same N1 (the levers to be adjusted, FCOM p.877)")
    -- LIM PROT (FCOM p.900, 109: the thrust approaching the maximum): the EPR
    -- measured within 0.01 of the maximum
    T.check(not o.lim_prot[2], "no LIM PROT with the EPR well under the maximum")
    i.actual[2] = o.max[2] - 0.005
    o = E.update(st, i, DT)
    T.check(o.lim_prot[2] and not o.lim_prot[1], ">ENG 2 LIM PROT: the EPR near the maximum in the N1 mode")
    i.actual[1] = o.max[1] - 0.005
    o = E.update(st, i, DT)
    T.check(not o.lim_prot[1], "no LIM PROT in the EPR mode")
    -- back to NORM, no fault: the EPR mode (p.198)
    i.altn[2], i.lever[2] = false, i.lever[1]
    o = E.update(st, i, DT)
    T.check(not o.n1_mode[2] and not o.altn[2] and not o.at_inhibit, "NORM: the EPR mode, the A/T usable again")
    T.near(o.command[2], o.command[1], 1e-9, "the EPR command again")
    T.check(st.n1_delta[2] == nil, "no delta kept")
end

-- the automatic reversion (the EEC cannot control EPR): the lockup keeps the
-- thrust (delta N1 held, p.197-198), the thrust following the lever; the
-- ALTN light through the N2 > 50 % contact (p.199); latched until the
-- switch is used once the fault is gone (p.198)
do
    local st, i = cruise()
    E.update(st, i, DT)
    i.fail_altn[2] = true
    local o = E.update(st, i, DT)
    local sched = E.pw_altn_n1(25, -25)
    T.check(o.n1_mode[2] and o.altn[2], "reverted: the N1 mode (ENG 2 EEC MODE)")
    T.near(o.command[2], 80, 1e-9, "the lockup: the N1 command is the N1 at the reversion (the thrust does not change)")
    T.near(st.n1_delta[2], sched - 80, 1e-9, "delta N1: the schedule's N1 less the N1 at the reversion")
    T.check(o.at_disconnect and o.at_inhibit and o.altn_light[2], "the A/T disconnects, the ALTN light")
    for _ = 1, 300 do o = E.update(st, i, DT) end
    T.near(o.command[2], 80, 1e-9, "30 s on: delta still held (no ramp without the switch)")
    i.lever[2] = 0.6
    o = E.update(st, i, DT)
    T.near(o.command[2], E.pw_altn_n1(30, -25) - (sched - 80), 1e-9, "the lever forward 5 degrees: the thrust follows (the schedule less delta)")
    i.lever[2] = 0
    o = E.update(st, i, DT)
    T.near(o.command[2], E.pw_altn_n1(0, -25), 1e-9, "the lever at idle: the idle end (not under it)")
    i.lever[2] = 0.5
    -- the fault gone, the switch at NORM: still the N1 mode (latched)
    i.fail_altn[2] = false
    o = E.update(st, i, DT)
    T.check(o.n1_mode[2] and o.altn[2] and o.at_inhibit, "the fault gone: kept in the N1 mode until the switch is used (p.198)")
    T.near(o.command[2], 80, 1e-9, "and its lockup")
    -- the switch at ALTN: the lockup removed, delta ramped out
    i.altn[2] = true
    o = E.update(st, i, DT)
    T.near(o.command[2], 80 + A.ramp * DT, 1e-9, "ALTN selected: delta ramped out at 100 rpm a second")
    for _ = 1, 200 do o = E.update(st, i, DT) end
    T.near(o.command[2], sched, 1e-9, "the schedule's N1 after the ramp")
    -- NORM: the EPR mode again
    i.altn[2] = false
    o = E.update(st, i, DT)
    T.check(not o.n1_mode[2] and not o.altn[2] and not o.altn_light[2], "then NORM: the EPR mode")
end
-- the switch back at NORM while the fault is still there: the lockup again
-- at the N1 then
do
    local st, i = cruise()
    i.fail_altn[2], i.altn[2] = true, true
    E.update(st, i, DT)
    for _ = 1, 100 do E.update(st, i, DT) end   -- the ramp done: on the schedule
    local sched = E.pw_altn_n1(25, -25)
    i.n1[2] = sched
    i.altn[2] = false
    local o = E.update(st, i, DT)
    T.check(o.n1_mode[2], "NORM with the fault still there: the N1 mode")
    T.near(o.command[2], sched, 1e-9, "the lockup at the N1 then (no change of thrust)")
    T.near(st.n1_delta[2], 0, 1e-9, "delta 0")
end
-- an automatic reversion of an engine not running: no delta, the ALTN light
-- off under 50 % N2 (p.199)
do
    local st, i = cruise()
    i.n1[3], i.n2[3] = 10, 20
    i.fail_altn[3] = true
    local o = E.update(st, i, DT)
    T.check(o.altn[3] and not o.altn_light[3], "under 50 % N2: the N1 mode, no ALTN light (PW_PPM p.199)")
    T.near(st.n1_delta[3], 0, 1e-9, "no delta taken from an engine not running")
    T.near(o.command[3], E.pw_altn_n1(25, -25), 1e-9, "the schedule's N1")
    i.n2[3] = 60
    o = E.update(st, i, DT)
    T.check(o.altn_light[3], "over 50 % N2: the ALTN light")
end

-- the overspeed protection in the N1 mode: the N1 limit 111.4 less the
-- margin caps the target, the N2 limit's loop in N1 (as the GE's), RPM LIM
-- while a limit holds the engine (FCOM p.901: P&W on N1 or N2)
do
    local st, i = E.new(), E.inputs()
    i.type, i.alt, i.tat = "PW", 0, 15
    i.idle = {1.0, 1.0, 1.0, 1.0}
    i.lever = {1, 1, 1, 1}
    i.altn = {true, true, true, true}
    i.n1, i.n2, i.actual = {100, 100, 100, 100}, {99, 99, 99, 99}, {1.505, 1.505, 1.505, 1.505}
    local o = E.update(st, i, DT)
    for _ = 1, 100 do o = E.update(st, i, DT) end
    T.near(o.command[1], 118, 1e-9, "full forward at 15 degrees C: the schedule's 118 % N1 (beyond the red line)")
    T.near(o.target[1], E.REDLINE.PW.n1 - E.RPM_MARGIN, 1e-9, "the target held at the EEC's N1 limit less the margin (PW_PPM p.204)")
    T.check(not o.rpm_lim[1], "no RPM LIM while the engine is short of the limit")
    T.check(o.lim_prot[1], ">ENG 1 LIM PROT at the maximum EPR")
    i.n1[1] = 110.9
    o = E.update(st, i, DT)
    T.check(o.rpm_lim[1], ">ENG 1 RPM LIM: the N1 limit holds the engine")
    i.n1[2], i.n2[2] = 105, 103.5 + 1
    o = E.update(st, i, DT)
    T.near(o.target[2], 105 - E.RPM_GAIN.PWN1 * 1, 1e-9, "N2 past its limit less the margin: the N1 allowed less (the gain in N1)")
    T.check(o.rpm_lim[2], ">ENG 2 RPM LIM on N2")
end

-- the thrust control on the shown N1 (key PWN1) on a stand-in engine (the
-- shown N1 = 25 + 85 x the throttle through 1.2 s and 0.4 s lags), its slope
-- given (as the glue's from the EPR model): to the target without much
-- overshoot
do
    local s = E.new()
    local th, a, n1 = 0.4, 0.4, 25 + 85 * 0.4
    local target, peak, t_in = 90, 0, nil
    for k = 1, math.floor(30 / DT) do
        th = E.thrust_control(s, "PWN1", 1, target, n1, th, E.pw_altn_n1(0, 15), DT, 85, 0.66, false)
        a = a + (th - a) * DT / 1.2
        n1 = n1 + (25 + 85 * a - n1) * DT / 0.4
        peak = math.max(peak, n1)
        if not t_in and math.abs(n1 - target) < 1 then t_in = k * DT end
    end
    T.check(t_in and t_in < 15, string.format("the N1 loop (the GE's law): within 1 of 90 %% in %.1f s", t_in or -1))
    T.check(peak < target + 2, string.format("its peak %.1f", peak))
    T.near(n1, target, 0.3, "settled")
    T.equal(E.thrust_control(s, "PWN1", 1, E.pw_altn_n1(1, 15), n1, th, E.pw_altn_n1(0, 15), DT), 0,
        "the lever at its flat idle: throttle 0")
end

-- the GE and the RR keep their alternate modes (ATA70_80 p.205-207 for the
-- CF6; the RR without sources): no N1 mode, the command as before
do
    local st, i = E.new(), E.inputs()
    i.type, i.alt, i.tat, i.kias = "GE", 0, -10, 150
    i.idle = {25, 25, 25, 25}
    i.lever = {1, 1, 1, 1}
    i.altn = {true, false, false, false}
    i.n2 = {95, 95, 95, 95}
    local o = E.update(st, i, DT)
    T.check(not o.n1_mode[1] and o.altn[1], "GE ALTN: not the P&W's N1 mode")
    T.near(o.command[1], 107.3, 1e-9, "GE ALTN: the corner point N1 as before")
    st, i = E.new(), E.inputs()
    i.type, i.rr, i.alt, i.tat = "PW", true, 0, 15
    i.idle = {0.95, 0.95, 0.95, 0.95}
    i.lever = {1, 1, 1, 1}
    i.altn = {true, false, false, false}
    o = E.update(st, i, DT)
    T.check(not o.n1_mode[1] and o.altn[1], "RR ALTN: not the N1 mode")
    T.near(o.command[1], 1.51, 1e-9, "RR ALTN: the corner point EPR at full forward as before")
    T.check(o.lim_prot[1], "RR LIM PROT on the command as before")
    i.altn[1], i.fail_altn[1] = false, true
    o = E.update(st, i, DT)
    i.fail_altn[1] = false
    o = E.update(st, i, DT)
    T.check(not o.altn[1], "RR: the fault gone, the normal mode at once as before (no latch)")
end

T.done()
