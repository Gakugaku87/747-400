-- Run from the repository root with LuaJIT: luajit tests/autopilot/spd_flap_ramp_test.lua
-- (2026-11-26; docs/overhaul/notes/ATA-22.md §73) The speed law's near-level
-- path (B747.70.afds_pitch_model.lua's `way`, §62) against a target moving
-- with the way: the takeoff's acceleration flap by flap (FCOM p.667,
-- p.1255, p.1326: 5 kt under the placard of the flap setting). The FMC's
-- target and the protection's maximum go with the flaps' position here
-- (the PFD's Vmax), up some 3 kt a second from flaps 10 to 5; before, the
-- floor took that rate as the speed to keep in step with, and where the
-- thrust gave less the path went past level: the user's flight (2026-11-25,
-- heavy, the A/P in VNAV SPD after the acceleration height at 3,000 ft
-- AGL) went down. On the lagged airplane (the attitude 2 s behind the
-- command, the path 3 s behind the attitude):
--  - 390 t on the climb thrust (1.2 kt/s of excess in level flight), the
--    acceleration height's step to 225 kt, the flaps on the FCTM's schedule
--    (p.113: 10 at VREF30 + 20, 5 at VREF30 + 40; VREF30 181.5) with the
--    target and the maximum (the protection's, less 5) moving with the
--    flaps: not under near level (before, down to -212 fpm), on to 255 kt;
--  - the same with the target in steps (the lever's): the same;
--  - a descent the other way (the flaps coming out in VNAV SPD's descent,
--    the target falling with them faster than the drag takes the speed):
--    not over near level of descent;
--  - against the way as before: a Mach held in a climb (its IAS target
--    falling) still keeps in step (afds_pitch_model_test.lua's); the speed
--    under the minimum maneuvering speed still takes the path past level
--    (FCOM p.675; afds_pitch_model_test.lua's `short`).
local T = dofile("tests/lib/check.lua")("spd_flap_ramp")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")

local DT, G, KT, FT = 0.05, 9.80665, 1852 / 3600, 0.3048
local function fpm_of(fpm, ias) return math.deg(math.asin(fpm / 60 * FT / (ias * 1.05 * KT))) end

-- a climb (way 1) or a descent (way -1) at the speed `from` on `thr` kt/s
-- of excess (negative: the drag over the thrust), 60 s steady; then `run`
-- (t, i) sets the target and the limits each step for `secs`; the least and
-- the most vertical speed, the speed at the end
local function fly(o)
    local s = P.new()
    local i = P.inputs()
    i.active, i.mode, i.vnav_law, i.way = true, "VNAV", "FLCH", o.way
    i.ias, i.spd_sel, i.mcp_ias, i.alt, i.flaps_up = o.from, o.from, o.from, o.alt or 3000, false
    i.tas = i.ias * 1.05
    i.v_min, i.v_max = 0, o.vmax0 or 0
    local gam = math.deg(math.asin(o.thr * KT / G))
    i.pitch, i.vs = gam + 4, i.tas * KT * math.sin(math.rad(gam)) / FT * 60
    local function step(thr)
        local c = P.update(s, i, DT)
        i.pitch = i.pitch + (c - i.pitch) * DT / 2
        gam = gam + ((i.pitch - 4) - gam) * DT / 3
        i.ias = i.ias + (thr - G * math.sin(math.rad(gam)) / KT) * DT
        i.tas = i.ias * 1.05
        i.vs = i.tas * KT * math.sin(math.rad(gam)) / FT * 60
        i.alt = i.alt + i.vs / 60 * DT
    end
    for _ = 1, math.floor(60 / DT) do step(o.thr) end
    local q = {vs0 = i.vs, lo = 1e9, hi = -1e9}
    local t = 0
    for _ = 1, math.floor(o.secs / DT) do
        o.run(t, i)
        step(o.thr)
        t = t + DT
        q.lo, q.hi = math.min(q.lo, i.vs), math.max(q.hi, i.vs)
    end
    q.ias = i.ias
    return q
end

-- the takeoff's acceleration at 390 t on the climb thrust: at the
-- acceleration height 225 kt (flaps 20's 230 less 5), the flaps on the
-- schedule, the FMC's target and the maximum moving with the flaps over
-- 15 s (20 to 10) and 6 s (10 to 5); the minimum maneuvering speed shown
-- from the first retraction (the minimum speed model's at 390 t: 201.1 at
-- flaps 10, 210.0 at 5)
local function takeoff(ramped)
    local flaps, f_t = 20, nil
    return fly({way = 1, from = 190, thr = 1.2, secs = 200, vmax0 = 230, run = function(t, i)
        if flaps == 20 and i.ias >= 202 then flaps, f_t = 10, t end
        if flaps == 10 and i.ias >= 222 then flaps, f_t = 5, t end
        local placard
        if flaps == 20 then
            placard = 230
        elseif flaps == 10 then
            placard = ramped and 230 + math.min(1, (t - f_t) / 15) * 10 or 240
        else
            placard = ramped and 240 + math.min(1, (t - f_t) / 6) * 20 or 260
        end
        i.spd_sel, i.v_max = placard - 5, ramped and placard or i.v_max
        if not ramped then i.v_max = placard end
        i.v_min = flaps == 10 and 201.1 or (flaps == 5 and 210.0 or 0)
    end})
end
local r = takeoff(true)
T.check(r.vs0 > 1200 and r.vs0 < 1350, ("390 t on the climb thrust: %.0f fpm at 190 kt before the acceleration height"):format(r.vs0))
T.check(r.lo >= 90, ("  the acceleration flap by flap, the target with the flaps' position: not under near level (%.0f fpm at the least; before -212)"):format(r.lo))
T.near(r.ias, 255, 1, "  on to 255 kt (flaps 5's 260 less 5)")
local st = takeoff(false)
T.check(st.lo >= 90 and math.abs(st.lo - r.lo) < 30, ("  the target in steps (the lever's): the same (%.0f fpm)"):format(st.lo))

-- the other way: VNAV SPD's descent at 240 kt where the drag takes 0.4 kt/s
-- in level flight (535 fpm down holding the speed), the target falling 3 kt
-- a second (240 to 210 in 10 s: the flaps coming out, under their
-- placards: the maximum 280 kt): not over near level of descent (before,
-- the ceiling rose with the falling target: up to +986 fpm)
local d = fly({way = -1, from = 240, thr = -0.4, alt = 8000, secs = 120, vmax0 = 280, run = function(t, i)
    i.spd_sel = 240 - math.min(30, 3 * math.max(0, t - 5))
end})
T.check(d.vs0 < -500 and d.vs0 > -570, ("a descent: %.0f fpm before the flaps"):format(d.vs0))
T.check(d.hi <= -90, ("  the flaps coming out, the target falling with them: not over near level of descent (%.0f fpm at the most; before +986)"):format(d.hi))
T.check(d.ias < 225, ("  slowing on the drag (%.1f kt after 2 minutes)"):format(d.ias))

T.done()
