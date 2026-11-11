-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_pitch_model_test.lua
-- The FCCs' pitch laws, steps 3a and 3b (6-3: docs/overhaul/notes/ATA-22.md
-- §18, §19):
-- plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua.
-- The capture's start (closing within the 0.05 g level-off and 10 s),
-- ALT's vertical speed, a level-off flown on a simple airplane (the
-- attitude follows the command; the flight path is the attitude less a
-- fixed angle of attack) and on a lagged one (the attitude 2 s behind the
-- command, the flight path 3 s behind the attitude: as X-Plane's 747 at
-- 10,000 ft in s107's first run): no overshoot, within the 0.05 g,
-- settled; V/S established within the limit; V/S 000 holding where it was
-- set; ALT HOLD pushed in a climb: over and back; the old VNAV's laws by
-- its flags; no law (nothing engaged or shown, on the ground).
-- Step 3b, on the lagged airplane with a speed (the thrust's excess less the
-- climb): the speed protection; FLCH's climb entry (the thrust up 1.2 kt/s
-- in 8 s) within 10 kt and settled, a new speed (250 to 280 kt) without an
-- overshoot over 2 kt (5 kt 1.5 times as slow), within SPD_G, the descent;
-- (2026-11-12) FLCH's and VNAV SPD's near-level path against their way:
-- the user's flight (272 to 340 kt climbing on 1.0 kt/s of excess: no more
-- down for the speed), a light airplane as before, a descent's
-- deceleration not a climb, the driftdown's 300 fpm, the thrust short;
-- the old VNAV's speed flag; T/O: 8 degrees on the ground, the rotation's
-- speed, V2 the window's, V2 + 10 or the rotation's + 10, the target reset
-- after 5 s above it (up to V2 + 25), the window when set higher, a takeoff
-- flown near the target, the PLI, a windshear from the attitude, a
-- takeoff on an attitude loop little damped (as X-Plane's 747 at 170 kt:
-- s109) without a lasting swing; G/A: the
-- window's or the speed then, the cap (MCP + 25 or the speed then), the 15
-- degrees (or 1 below the PLI) blended into the speed from 600 to 1,200
-- fpm, a go-around flown, on the ground too.
-- Step 4b: FLARE flown on a model of X-Plane's 747 at 130, 150 and 170 kt
-- over the ground (0.5 to 3 ft/s, 150 to 1,000 ft past the G/S
-- transmitter), the sink rate held under the deceleration's, NOSE LETDOWN.
local T = dofile("tests/lib/check.lua")("afds_pitch_model")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")

local G_FT = 9.80665 / 0.3048
local DT = 0.1
local function inp(o)
    local i = P.inputs()
    i.active, i.tas, i.alt, i.pitch = true, 250, 9000, 2
    for k, v in pairs(o or {}) do i[k] = v end
    return i
end

-- the capture: 2,000 fpm up to 10,000 ft needs 345 ft to level off at 0.05
-- g and 333 ft for 10 s
T.near(P.level_off_vs(345), 2000, 5, "2,000 fpm levels off in 345 ft at 0.05 g")
T.check(not P.capture(inp({alt = 9200, vs = 2000}), 10000), "800 ft below at 2,000 fpm: not yet")
T.check(P.capture(inp({alt = 9350, vs = 2000}), 10000), "650 ft below: captured (678 ft)")
T.check(not P.capture(inp({alt = 9600, vs = -2000}), 10000), "going away: not")
T.check(P.capture(inp({alt = 9990, vs = 0}), 10000), "within 20 ft: captured")
T.check(not P.capture(inp({alt = 9600, vs = 2000}), nil), "no altitude: not")
T.equal(P.alt_vs(10050, 10000), 300, "ALT 50 ft below: 300 fpm (a tenth of the error a second)")
T.near(P.alt_vs(9000, 10000), -P.level_off_vs(1000), 1e-9, "1,000 ft above: the level-off's, down")

-- the simple airplane: the attitude follows the command, alpha 2 degrees
local function fly(s, i, seconds, cb, tau_t, tau_g)
    local v = i.tas * 1852 / 3600
    local amax, last = 0, i.vs
    local gam = i.pitch - 2
    for _ = 1, math.floor(seconds / DT + 0.5) do
        local c = P.update(s, i, DT)
        if c then
            if tau_t then i.pitch = i.pitch + (c - i.pitch) * DT / tau_t else i.pitch = c end
        end
        if tau_g then gam = gam + ((i.pitch - 2) - gam) * DT / tau_g else gam = i.pitch - 2 end
        i.vs = v * math.sin(math.rad(gam)) / 0.3048 * 60
        i.alt = i.alt + i.vs / 60 * DT
        amax = math.max(amax, math.abs(i.vs - last) / 60 / DT)
        last = i.vs
        if cb then cb(i) end
    end
    return amax / G_FT
end

-- a level-off: V/S 2,000 fpm to 10,000 ft, the capture by `capture`
local s = P.new()
local i = inp({mode = "VS", vs_sel = 2000, alt = 8000})
i.pitch = 2 + math.deg(math.asin(2000 / 60 * 0.3048 / (250 * 1852 / 3600)))
i.vs = 2000
fly(s, i, 5)
T.near(i.vs, 2000, 20, "V/S 2,000: established")
local captured_at
local g = fly(s, i, 120, function(x)
    if x.mode == "VS" and P.capture(x, 10000) then
        x.mode, x.hold_alt = "ALT", 10000
        captured_at = x.alt
    end
end)
T.check(captured_at and captured_at < 9380 and captured_at > 9270, "captured about 678 ft below (at " .. tostring(captured_at) .. ")")
T.check(i.alt < 10010, "no overshoot over 10 ft (" .. i.alt .. ")")
T.near(i.alt, 10000, 5, "level at 10,000 ft")
T.check(g <= 0.055, "within the 0.05 g (" .. g .. ")")
-- the same on the lagged airplane: no overshoot either
s = P.new()
i = inp({mode = "VS", vs_sel = 2000, alt = 8000})
i.pitch = 2 + math.deg(math.asin(2000 / 60 * 0.3048 / (250 * 1852 / 3600)))
i.vs = 2000
local top = i.alt
fly(s, i, 150, function(x)
    if x.mode == "VS" and P.capture(x, 10000) then x.mode, x.hold_alt = "ALT", 10000 end
    top = math.max(top, x.alt)
end, 2, 3)
T.check(top < 10030, "lagged: no overshoot over 30 ft (" .. top .. ")")
T.near(i.alt, 10000, 10, "lagged: level at 10,000 ft")
-- and with the airplane 1.5 times as slow (3 s and 4.5 s)
s = P.new()
i = inp({mode = "VS", vs_sel = 2000, alt = 8000})
i.pitch = 2 + math.deg(math.asin(2000 / 60 * 0.3048 / (250 * 1852 / 3600)))
i.vs = 2000
top = i.alt
fly(s, i, 150, function(x)
    if x.mode == "VS" and P.capture(x, 10000) then x.mode, x.hold_alt = "ALT", 10000 end
    top = math.max(top, x.alt)
end, 3, 4.5)
T.check(top < 10030, "slower: no overshoot over 30 ft (" .. top .. ")")

-- V/S from level to -1,500 fpm: established in 45 s within the limit
s = P.new()
i = inp({mode = "VS", vs_sel = -1500, alt = 10000, vs = 0, pitch = 2})
g = fly(s, i, 45)
T.near(i.vs, -1500, 30, "V/S -1,500 in 45 s")
T.check(g <= 0.055, "within the 0.05 g (" .. g .. ")")

-- V/S 000: the altitude where it was set (ATA22 p.282)
i.vs_sel = 0
local set_at = i.alt
fly(s, i, 120)
T.near(i.alt, set_at, 15, "V/S 000: back to and holding where it was set")
T.near(s.vs0_alt, set_at, 1e-9, "the altitude held is the one at 000")

-- ALT HOLD pushed climbing 2,000 fpm: over and back to the push's altitude
s = P.new()
i = inp({mode = "ALT", hold_alt = 9000, alt = 9000, vs = 2000})
i.pitch = 2 + math.deg(math.asin(2000 / 60 * 0.3048 / (250 * 1852 / 3600)))
local top = i.alt
fly(s, i, 120, function(x) top = math.max(top, x.alt) end)
T.check(top > 9300 and top < 9500, "ALT HOLD in a 2,000 fpm climb: over by the level-off (" .. top .. ")")
T.near(i.alt, 9000, 15, "back to the push's altitude")

-- the old VNAV's laws by its flags
s = P.new()
T.check(P.update(s, inp({mode = "VNAV", vnav_law = "VS", vnav_vs = -1000}), DT) ~= nil, "VNAV with the old V/S flag: here")
s = P.new()
T.check(P.update(s, inp({mode = "VNAV", vnav_law = "ALT", vnav_alt = 9000}), DT) ~= nil, "VNAV with the old ALT flag: here")
s = P.new()
T.check(P.update(s, inp({mode = "VNAV", vnav_law = "FLCH", ias = 250, spd_sel = 250}), DT) ~= nil,
    "VNAV with the old speed flag: here (step 3b)")
-- no law
T.equal(P.update(s, inp({mode = "FLCH", active = false}), DT), nil, "FLCH, nothing engaged or shown")
T.equal(P.update(s, inp({mode = "VS", vs_sel = 1000, active = false}), DT), nil, "nothing engaged or shown")
T.equal(P.update(s, inp({mode = "VS", vs_sel = 1000, ground = true}), DT), nil, "on the ground")
-- the command starts from the attitude
s = P.new()
local c = P.update(s, inp({mode = "VS", vs_sel = 0, pitch = 4.5, vs = 0}), DT)
T.near(c, 4.5, 0.05, "from the attitude where the law starts")

-- step 3b: the speed protection (FCOM p.675)
T.equal(P.protect(150, inp({v_min = 170, v_max = 0, flaps_up = true})), 170, "under the minimum maneuvering: it")
T.equal(P.protect(150, inp({v_min = 170, v_max = 0, flaps_up = false})), 175, "flaps out: 5 kt above it")
T.equal(P.protect(340, inp({v_min = 0, v_max = 330})), 325, "over the maximum: 5 kt under it")
T.equal(P.protect(250, inp({v_min = 0, v_max = 0})), 250, "no speeds: as set")

-- the lagged airplane with a speed: the attitude 2 s behind the command,
-- the path 3 s behind the attitude less the angle of attack; the speed's
-- rate the thrust's excess (kt a second) less the climb's
local KT = 1852 / 3600
local function fly_spd(s, i, seconds, thrust, tau_t, tau_g, alpha, cb)
    tau_t, tau_g, alpha = tau_t or 2, tau_g or 3, alpha or 2
    local gam = i.gam or (i.pitch - alpha)
    local t, g, last = 0, 0, i.vs
    local r = {vmin = i.ias, vmax = i.ias, pmax = i.pitch}
    for _ = 1, math.floor(seconds / DT + 0.5) do
        local cmd = P.update(s, i, DT)
        if cmd then i.pitch = i.pitch + (cmd - i.pitch) * DT / tau_t end
        gam = gam + ((i.pitch - alpha) - gam) * DT / tau_g
        i.ias = i.ias + (thrust(t) - 9.80665 * math.sin(math.rad(gam)) / KT) * DT
        i.tas = i.ias * (i.tas_ratio or 1.16)
        i.vs = i.tas * KT * math.sin(math.rad(gam)) / 0.3048 * 60
        i.alt = i.alt + i.vs / 60 * DT
        g = math.max(g, math.abs(i.vs - last) / 60 / DT / G_FT)
        last = i.vs
        r.vmin, r.vmax, r.pmax = math.min(r.vmin, i.ias), math.max(r.vmax, i.ias), math.max(r.pmax, i.pitch)
        t = t + DT
        if cb then cb(t, i, cmd) end
    end
    i.gam, r.g = gam, g
    return r
end
local function ramp(a, secs) return function(t) return a * math.min(1, t / secs) end end

-- FLCH from level at 250 kt, the thrust up 1.2 kt/s in 8 s: within 10 kt,
-- then on the speed; a new speed, 280 kt
s = P.new()
i = inp({mode = "FLCH", ias = 250, spd_sel = 250, vs = 0, tas = 290})
local r = fly_spd(s, i, 120, ramp(1.2, 8))
T.check(r.vmax < 260 and r.vmin > 245, ("FLCH's climb entry within 10 kt (%.1f..%.1f)"):format(r.vmin, r.vmax))
T.near(i.ias, 250, 1, "on the speed after 2 minutes")
T.check(i.vs > 1000, "climbing (" .. i.vs .. ")")
i.spd_sel = 280
r = fly_spd(s, i, 150, function() return 1.2 end)
T.check(r.vmax < 282, ("250 to 280 kt: no overshoot over 2 kt (%.1f)"):format(r.vmax))
T.near(i.ias, 280, 1, "at 280 kt")
T.check(r.g <= P.SPD_G * 1.06, "within SPD_G (" .. r.g .. ")")
-- the same 1.5 times as slow
s = P.new()
i = inp({mode = "FLCH", ias = 250, spd_sel = 250, vs = 0, tas = 290})
fly_spd(s, i, 120, ramp(1.2, 8), 3, 4.5)
i.spd_sel = 280
r = fly_spd(s, i, 150, function() return 1.2 end, 3, 4.5)
T.check(r.vmax < 285, ("slower: no overshoot over 5 kt (%.1f)"):format(r.vmax))
T.near(i.ias, 280, 1, "slower: at 280 kt")
-- FLCH's descent at idle: on the speed, going down
s = P.new()
i = inp({mode = "FLCH", ias = 250, spd_sel = 250, vs = 0, tas = 290})
r = fly_spd(s, i, 120, ramp(-0.8, 5))
T.check(r.vmin > 240 and r.vmax < 255, ("FLCH's descent entry (%.1f..%.1f)"):format(r.vmin, r.vmax))
T.near(i.ias, 250, 1, "descending on the speed")
-- (2026-11-08) a Mach held in FLCH: its IAS target moving 0.33 kt a second
-- (M.84 climbing at 2,800 fpm) down in the climb, up in the descent; the
-- speed on it within 1 kt (the target's rate fed forward). Before, the
-- closing in SPD_TAU_S lagged it by the rate x 15 s, 5 kt: the perf
-- session's phase 2 climbed at M.851-.854 for M.840
local function moving(rate, thrust, way)
    local ms = P.new()
    local mi = inp({mode = "FLCH", way = way, ias = 300, spd_sel = 300, vs = 0, tas = 480, tas_ratio = 1.6, alt = 28000})
    fly_spd(ms, mi, 60, ramp(thrust, 8))
    local sum, n, t0 = 0, 0, nil
    fly_spd(ms, mi, 150, function() return thrust end, nil, nil, nil, function(t, ii)
        ii.spd_sel = 300 + rate * t
        if t > 90 then sum, n = sum + (ii.ias - ii.spd_sel), n + 1 end
    end)
    return sum / n, mi
end
local e1, c1 = moving(-0.33, 1.5)
T.check(math.abs(e1) < 1, ("a Mach held in the climb (the target 0.33 kt/s down): the speed on it (%+.2f kt; before about +5)"):format(e1))
T.check(c1.vs > 1000, "climbing (" .. math.floor(c1.vs) .. " fpm)")
local c1m_vs = c1.vs
local e2, c2 = moving(0.33, -0.8)
local c2m_vs = c2.vs
T.check(math.abs(e2) < 1, ("a Mach held in the descent (the target 0.33 kt/s up): the speed on it (%+.2f kt; before about -5)"):format(e2))
T.check(c2.vs < -500, "descending (" .. math.floor(c2.vs) .. " fpm)")
-- a new speed selected (a step) is no rate: 300 to 280 kt as before
local ss = P.new()
local si = inp({mode = "FLCH", ias = 300, spd_sel = 300, vs = 0, tas = 480, tas_ratio = 1.6, alt = 28000})
fly_spd(ss, si, 60, ramp(1.5, 8))
si.spd_sel = 280
local rs = fly_spd(ss, si, 150, function() return 1.5 end)
T.check(rs.vmin > 278, ("a step to 280 kt: no undershoot over 2 kt (%.1f)"):format(rs.vmin))
T.near(si.ias, 280, 1, "at 280 kt")
T.check(i.vs < -1000, "descending (" .. i.vs .. ")")
-- the reference protected: under the minimum maneuvering speed with the
-- flaps out, 5 kt above it
s = P.new()
i = inp({mode = "FLCH", ias = 180, spd_sel = 160, v_min = 175, flaps_up = false, vs = 0, tas = 200})
P.update(s, i, DT)
T.equal(s.target, 180, "FLCH under the minimum maneuvering speed: 5 kt above it (flaps out)")

-- (2026-11-12; notes/ATA-22.md §62) FLCH's and VNAV SPD's near-level path
-- against their way (`way`). The user's flight: 347.5 t in VNAV SPD and
-- THR REF through 10,000 ft, the FMC's target in one step from 272 kt (the
-- minimum maneuvering speed's) to the ECON climb's 340 kt; the climb
-- thrust's excess, about 2,100 fpm at 340 kt, gives 1.0 kt/s in level
-- flight (0.93 to 1.07 in the record), the law asked for 1.5; the airplane
-- went down some 300 ft in 35 s, -839 fpm in the record's 30 s samples.
-- A step of the target after 90 s at a thrust (a steady climb or descent),
-- on the lagged airplane: the vertical speed's extremes from the step on,
-- the altitude lost and gained, when the speed came within a knot
local function spd_step(o)
    local ss = P.new()
    local mode = o.mode or "VNAV"
    local si = inp({mode = mode, vnav_law = mode == "VNAV" and "FLCH" or nil, way = o.way, way_fpm = o.way_fpm,
        ias = o.from, spd_sel = o.from, vs = 0, tas = o.from * 1.16, alt = 10000, v_min = o.v_min or 0, v_max = o.v_max or 0})
    local thrust = function() return o.thrust end
    fly_spd(ss, si, 90, thrust, o.tau_t, o.tau_g)
    si.spd_sel = o.to
    local q = {vs0 = si.vs, lo = si.vs, hi = si.vs, top = si.alt, bot = si.alt, lost = 0, gained = 0}
    local rr = fly_spd(ss, si, o.secs or 180, thrust, o.tau_t, o.tau_g, nil, function(t, x)
        q.lo, q.hi = math.min(q.lo, x.vs), math.max(q.hi, x.vs)
        q.top, q.bot = math.max(q.top, x.alt), math.min(q.bot, x.alt)
        q.lost, q.gained = math.max(q.lost, q.top - x.alt), math.max(q.gained, x.alt - q.bot)
        if not q.t and math.abs(x.ias - o.to) <= 1 then q.t = t end
    end)
    q.vmin, q.vmax, q.g, q.ias, q.vs = rr.vmin, rr.vmax, rr.g, si.ias, si.vs
    return q
end
-- without a way, the law as it was: down for the acceleration
local b = spd_step({from = 272, to = 340, thrust = 1.0, way = 0})
T.check(b.lo < -800 and b.lo > -1100, ("272 to 340 kt climbing on 1.0 kt/s, no way (as before): down to %.0f fpm"):format(b.lo))
T.check(b.lost > 300 and b.lost < 700, ("  and %.0f ft lost (the flight: some 300 ft, -839 fpm)"):format(b.lost))
-- VNAV SPD's climb: not under near level, no altitude lost, the speed
-- captured as before
local a = spd_step({from = 272, to = 340, thrust = 1.0, way = 1})
T.check(a.vs0 > 1500, ("VNAV SPD's climb before the step: %.0f fpm"):format(a.vs0))
T.check(a.lo >= P.SPD_LEVEL_FPM - 5, ("  272 to 340 kt: not under near level (%.0f fpm at the least)"):format(a.lo))
T.check(a.lost < 1, ("  no altitude lost (%.1f ft)"):format(a.lost))
T.check(a.t and a.t < 100 and a.t - b.t < 30, ("  within a knot of 340 kt after %.0f s (%.0f s going down for it)"):format(a.t or -1, b.t or -1))
T.check(a.vmax < 342, ("  no overshoot over 2 kt (%.1f)"):format(a.vmax))
T.near(a.ias, 340, 1, "  at 340 kt")
T.check(a.vs > 1500, ("  climbing again (%.0f fpm)"):format(a.vs))
T.check(a.g <= P.SPD_G * 1.06, "  within SPD_G (" .. a.g .. ")")
-- the record's thrust, 0.93 to 1.07 kt/s; FLCH the same
for _, thr in ipairs({0.93, 1.07}) do
    local c = spd_step({from = 272, to = 340, thrust = thr, way = 1})
    T.check(c.lo >= P.SPD_LEVEL_FPM - 5 and c.lost < 1 and c.t and c.t < 100 and c.vmax < 342,
        ("  on %.2f kt/s: %.0f fpm at the least, %.1f ft lost, %.0f s, %.1f kt at the most"):format(thr, c.lo, c.lost, c.t or -1, c.vmax))
end
local f = spd_step({from = 272, to = 340, thrust = 1.0, way = 1, mode = "FLCH"})
T.check(f.lo >= P.SPD_LEVEL_FPM - 5 and f.lost < 1, ("  FLCH to an MCP altitude above: the same (%.0f fpm, %.1f ft)"):format(f.lo, f.lost))
-- the airplane 1.5 times as slow: still no descent
local sl = spd_step({from = 272, to = 340, thrust = 1.0, way = 1, tau_t = 3, tau_g = 4.5})
T.check(sl.lo >= 0 and sl.lost < 1, ("  1.5 times as slow: no descent (%.0f fpm at the least, %.1f ft lost)"):format(sl.lo, sl.lost))
T.check(sl.vmax < 345 and sl.t and sl.t < 100, ("  and 340 kt within 5 kt after %.0f s (%.1f)"):format(sl.t or -1, sl.vmax))
-- a light airplane (238 t: about 2 kt/s in level flight, more than the law
-- asks for): the path stays over near level, the way changes nothing
local l0 = spd_step({from = 272, to = 340, thrust = 2.0, way = 0})
local l1 = spd_step({from = 272, to = 340, thrust = 2.0, way = 1})
T.check(l1.lo > 500, ("light, 2.0 kt/s: climbing through the acceleration (%.0f fpm at the least)"):format(l1.lo))
T.check(l1.lo == l0.lo and l1.t == l0.t and l1.vmax == l0.vmax and l1.ias == l0.ias,
    ("  as without a way (%.0f fpm, %.0f s, %.2f kt at the most)"):format(l0.lo, l0.t or -1, l0.vmax))
-- the old test's 250 to 280 kt on 1.2 kt/s, FLCH up: not under near level
-- now (-384 fpm without a way), the speed as before
local n0 = spd_step({from = 250, to = 280, thrust = 1.2, way = 0, mode = "FLCH", secs = 150})
local n1 = spd_step({from = 250, to = 280, thrust = 1.2, way = 1, mode = "FLCH", secs = 150})
T.check(n1.lo >= P.SPD_LEVEL_FPM - 5 and n1.lost < 1, ("250 to 280 kt on 1.2 kt/s: %.0f fpm at the least (%.0f without a way)"):format(n1.lo, n0.lo))
T.check(n1.vmax < 282 and n1.t and n1.t < n0.t + 10, ("  no overshoot over 2 kt (%.1f), 280 kt after %.0f s (%.0f)"):format(n1.vmax, n1.t or -1, n0.t or -1))
-- a descent at idle (1.2 kt/s lost in level flight), 300 to 250 kt: not
-- turned into a climb (without a way: up to +500 fpm), the speed captured
local d0 = spd_step({from = 300, to = 250, thrust = -1.2, way = 0, mode = "FLCH"})
local d1 = spd_step({from = 300, to = 250, thrust = -1.2, way = -1, mode = "FLCH"})
T.check(d0.hi > 300 and d0.gained > 100, ("FLCH's descent, 300 to 250 kt, no way (as before): up to %+.0f fpm, %.0f ft gained"):format(d0.hi, d0.gained))
T.check(d1.vs0 < -2000, ("FLCH's descent before the step: %.0f fpm"):format(d1.vs0))
T.check(d1.hi <= -P.SPD_LEVEL_FPM + 5, ("  300 to 250 kt: not over near level (%.0f fpm at the most)"):format(d1.hi))
T.check(d1.gained < 1, ("  no altitude gained (%.1f ft)"):format(d1.gained))
T.check(d1.t and d1.t < 70 and d1.t - d0.t < 20, ("  within a knot of 250 kt after %.0f s (%.0f s climbing for it)"):format(d1.t or -1, d0.t or -1))
T.check(d1.vmin > 248, ("  no undershoot over 2 kt (%.1f)"):format(d1.vmin))
T.check(d1.vs < -1500, ("  descending again (%.0f fpm)"):format(d1.vs))
local ds = spd_step({from = 300, to = 250, thrust = -1.2, way = -1, mode = "FLCH", tau_t = 3, tau_g = 4.5})
T.check(ds.hi <= 0 and ds.gained < 1, ("  1.5 times as slow: no climb (%.0f fpm at the most)"):format(ds.hi))
-- the driftdown (FCOM p.1268): its rate of descent decreases to a minimum
-- of 300 fpm slowing to the E/O speed (`way_fpm`)
local dd = spd_step({from = 300, to = 270, thrust = -0.8, way = -1, way_fpm = 300})
T.check(dd.hi <= -295, ("the driftdown's 300 fpm, 300 to 270 kt: %.0f fpm at the most"):format(dd.hi))
T.near(dd.ias, 270, 1, "  at 270 kt")
-- the thrust short of level flight in a climb (1.0 kt/s of excess to 0.4
-- short in 5 s): the speed first (FCOM p.675, p.646; ATA22 p.338): its fall
-- stopped going down as before, then gained back slowly, SPD_LEVEL_FPM of
-- path more than holds it; under the minimum maneuvering speed back to it
-- at the law's own rate
local function short(way, v_min)
    local ss = P.new()
    local si = inp({mode = "FLCH", way = way, ias = 300, spd_sel = 300, vs = 0, tas = 348, alt = 20000, v_min = v_min or 0})
    fly_spd(ss, si, 90, function() return 1.0 end)
    local lo, back = si.ias, nil
    fly_spd(ss, si, 240, function(t) return 1.0 - 1.4 * math.min(1, t / 5) end, nil, nil, nil, function(t, x)
        lo = math.min(lo, x.ias)
        if v_min and not back and t > 20 and x.ias >= v_min - 0.5 then back = t end
    end)
    return lo, si, ss, back
end
local lo0, c0 = short(0)
local lo1, c1, s1 = short(1)
T.check(lo1 > lo0 - 1, ("the thrust short in a climb: the speed's fall stopped as before (%.1f kt at the least, %.1f without a way)"):format(lo1, lo0))
T.check(c1.vs < -600, ("  going down for it (%.0f fpm; %.0f without a way)"):format(c1.vs, c0.vs))
T.check(c1.ias > lo1 + 8 and c1.ias <= 300.5, ("  and the speed gained back slowly (%.1f kt after 4 minutes, %.1f without a way)"):format(c1.ias, c0.ias))
T.check(c1.vs > c0.vs - 2 * P.SPD_LEVEL_FPM, ("  no more than near level's share of path for it (%.0f fpm against %.0f)"):format(c1.vs, c0.vs))
local lo2, c2, _, back = short(1, 296)
T.check(back and back < 60, ("  under the minimum maneuvering speed (296 kt): back to it in %.0f s"):format(back or -1))
T.check(c2.ias > 299, ("  and on to the target (%.1f kt)"):format(c2.ias))
-- a Mach held with the way as without it: the speed on the moving target
local e3, c3 = moving(-0.33, 1.5, 1)
T.check(math.abs(e3 - e1) < 1e-9 and c3.vs == c1m_vs, ("a Mach held in the climb with its way: as without (%+.2f kt, %d fpm)"):format(e3, math.floor(c3.vs)))
local e4, c4 = moving(0.33, -0.8, -1)
T.check(math.abs(e4 - e2) < 1e-9 and c4.vs == c2m_vs, ("  and in the descent (%+.2f kt, %d fpm)"):format(e4, math.floor(c4.vs)))
-- T/O does not take the way (its own blend from the attitude: ATA22 p.344):
-- in the air, level and 20 kt under V2 + 10, down for the speed with it
local function to_slow(way)
    local ts = P.new()
    local ti = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150, way = way})
    P.update(ts, ti, DT)
    ti.ground, ti.pitch = false, 8
    local cmd
    for _ = 1, 20 do cmd = P.update(ts, ti, DT) end
    return cmd, ts.target
end
local tc, tt = to_slow(1)
T.check(tt == 170 and tc < 7.5 and tc == to_slow(0), ("T/O with a way: as without, down for the speed (%.2f from 8)"):format(tc))

-- T/O: 8 degrees on the ground; the rotation (pitch over 2 degrees) at 150
-- kt, V2 160 in the window: V2 + 10
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 100, pitch = 0, vs = 0, alt = 0, tas = 100})
T.equal(P.update(s, i, DT), 8, "T/O on the ground: 8 degrees (FCOM p.666)")
i.ias = 150; i.pitch = 2.5
P.update(s, i, DT)
T.equal(s.vrot, 150, "the rotation's speed: pitch over 2 degrees")
T.equal(s.v2, 160, "V2 the window's (FCOM p.664)")
i.ground, i.ias, i.pitch, i.gam = false, 165, 9, 1
c = P.update(s, i, DT)
T.near(c, 9, 0.5, "lift-off: from the attitude")
T.equal(s.target, 170, "V2 + 10 (the rotation's + 10: 160)")
-- the rotation late (165 kt): its + 10
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 165, pitch = 3, vs = 0, alt = 0, tas = 165})
P.update(s, i, DT)
i.ground = false
P.update(s, i, DT)
T.equal(s.target, 175, "rotated at 165 kt: 175")
-- 5 s above the target: the speed then (up to V2 + 25)
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150})
P.update(s, i, DT)
i.ground, i.ias = false, 178
for _ = 1, math.floor(4.9 / DT) do P.update(s, i, DT) end
T.equal(s.target, 170, "4.9 s above: still V2 + 10")
for _ = 1, math.floor(0.2 / DT + 0.5) do P.update(s, i, DT) end
T.equal(s.target, 178, "5 s above: the speed then")
i.ias = 192
for _ = 1, math.floor(5.2 / DT) do P.update(s, i, DT) end
T.equal(s.target, 185, "and at most V2 + 25")
i.mcp_ias = 200
P.update(s, i, DT)
T.equal(s.target, 200, "the window set higher: the window's")
-- a takeoff flown: lift-off at 165 kt, the thrust's excess 2.4 kt/s
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150})
P.update(s, i, DT)
i.ground, i.ias, i.pitch, i.gam, i.tas_ratio = false, 165, 9, 1, 1.02
r = fly_spd(s, i, 60, function() return 2.4 end, 2, 3, 7)
T.check(r.vmax < 178, ("a takeoff: within V2 + 18 (%.1f)"):format(r.vmax))
T.check(math.abs(i.ias - s.target) < 1.5, ("on the target after a minute (%.1f, %.1f)"):format(i.ias, s.target))
T.check(r.pmax < 20, "the pitch under 20 degrees (" .. r.pmax .. ")")
-- the same on an attitude loop little damped (natural 0.55 rad/s, damping
-- 0.3: X-Plane's A/P at 170 kt swung the pitch 3.6 degrees every 12 s
-- with the full gain): within a degree after 30 s
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 121, pitch = 3, vs = 0, alt = 0, tas = 121})
P.update(s, i, DT)
i.ground, i.ias, i.pitch = false, 141, 5.7
do
    local gam, q, lo, hi = 0, 0, 99, -99
    for n = 1, math.floor(60 / DT) do
        local cmd = P.update(s, i, DT) or i.pitch
        q = q + (0.55 * 0.55 * (cmd - i.pitch) - 2 * 0.3 * 0.55 * q) * DT
        i.pitch = i.pitch + q * DT
        gam = gam + ((i.pitch - 5) - gam) * DT / 3
        i.ias = i.ias + (2.6 - 9.80665 * math.sin(math.rad(gam)) / KT) * DT
        i.tas = i.ias * 1.02
        i.vs = i.tas * KT * math.sin(math.rad(gam)) / 0.3048 * 60
        if n * DT > 30 then lo, hi = math.min(lo, i.pitch), math.max(hi, i.pitch) end
    end
    T.check(hi - lo < 2, ("an attitude loop little damped: the pitch within a degree after 30 s (%.1f..%.1f)"):format(lo, hi))
    T.check(math.abs(i.ias - s.target) < 2, ("and on the target (%.1f, %.1f)"):format(i.ias, s.target))
end
-- the PLI: not over it
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150})
P.update(s, i, DT)
i.ground, i.ias, i.pitch, i.pli = false, 140, 10, 2
for _ = 1, 20 do c = P.update(s, i, DT) end
i.ias = 200
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c <= 12 + 1e-9, "T/O: not over the PLI (" .. c .. ")")
-- a windshear: from the attitude (15 degrees) below 600 fpm; 10 kt slow
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 160, pitch = 3, vs = 0, alt = 0, tas = 160})
P.update(s, i, DT)
i.ground, i.pitch, i.vs, i.windshear = false, 10, 200, true
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c > 11, "T/O in a windshear, 10 kt slow: up toward 15 degrees (" .. c .. ")")
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 160, pitch = 3, vs = 0, alt = 0, tas = 160})
P.update(s, i, DT)
i.ground, i.pitch, i.vs = false, 10, 200
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c < 10, "without: down for the speed (" .. c .. ")")

-- G/A: the window's or the speed then, the cap
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 145, pitch = 2.5, vs = -800, alt = 300, tas = 150})
P.update(s, i, DT)
T.equal(s.target, 150, "G/A at 145 kt: the window's 150")
T.equal(s.ga_cap, 175, "up to MCP + 25")
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 180, pitch = 2.5, vs = -800, alt = 300, tas = 180})
P.update(s, i, DT)
T.equal(s.target, 180, "at 180 kt: the speed then")
T.equal(s.ga_cap, 180, "over MCP + 25: that speed kept (FCOM p.664)")
-- the attitude below 600 fpm: up to 15 degrees at most 3 degrees a second
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 2.5, vs = -800, alt = 300, tas = 150})
local prev = 2.5
local fastest = 0
for _ = 1, 150 do
    c = P.update(s, i, DT)
    fastest = math.max(fastest, (c - prev) / DT)
    prev = c
end
T.near(c, 15, 0.1, "G/A below 600 fpm: 15 degrees (FCOM p.674)")
T.check(fastest <= P.TOGA_RATE + 1e-9, "at most 3 degrees a second (" .. fastest .. ")")
-- or 1 below the PLI
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 8, vs = -800, alt = 300, tas = 150, pli = 4})
for _ = 1, 100 do c = P.update(s, i, DT) end
T.near(c, 11, 0.1, "the PLI 4 degrees above: 1 below it")
-- blended: above 1,200 fpm the speed only, under 600 the attitude only
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 12, vs = 1500, alt = 600, tas = 150})
P.update(s, i, DT)
i.ias = 140
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c < 12, "1,500 fpm, 10 kt slow: down for the speed (" .. c .. ")")
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 12, vs = 300, alt = 600, tas = 150})
P.update(s, i, DT)
i.ias = 140
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c > 12, "300 fpm, 10 kt slow: up for the attitude (" .. c .. ")")
-- a go-around flown: 150 kt, -3 degrees, the thrust's excess up to 3 kt/s
-- in 6 s
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 2.5, vs = -800, alt = 300, tas = 153, gam = -3, tas_ratio = 1.02})
r = fly_spd(s, i, 60, ramp(3, 6), 2, 3, 5.5)
T.check(r.vmin > 148, ("the go-around: no slower than 2 kt under (%.1f)"):format(r.vmin))
T.check(r.pmax < 17, "the pitch under 17 degrees (" .. r.pmax .. ")")
T.check(i.vs > 1200, "climbing over 1,200 fpm (" .. i.vs .. ")")
T.check(math.abs(i.ias - s.target) < 1.5 and s.target <= 175, ("on the target (%.1f, %.1f)"):format(i.ias, s.target))
-- on the ground too (a touch and go: FCOM p.673)
s = P.new()
T.check(P.update(s, inp({mode = "GA", ground = true, mcp_ias = 150, ias = 140, pitch = 1, vs = 0, tas = 140}), DT) ~= nil,
    "G/A on the ground: here")

-- G/S (step 3c; ATA22 p.346, p.292): G/S DEV ALT from the radio altitude
-- on a 3 degree glide slope, the capture by the distance and its rate, the
-- law on the lagged airplane down an ILS (the beam 3 degrees from a
-- transmitter, the radio altitude the height above it, 140 kt over the
-- ground)
local TAN3 = math.tan(math.rad(3))
local function gs_dots(h, x, angle)
    return (math.deg(math.atan(h / x)) - (angle or 3)) / P.GS_DOT_DEG
end
local function gs_inp(o)
    local g = inp({mode = "ALT", tas = 145, gs = 140, gs_valid = true, vs = 0, pitch = 4})
    for k, v in pairs(o or {}) do g[k] = v end
    return g
end
-- 1,500 ft up, 0.35 degree above the beam: 28,621 ft out, 175 ft above
T.near(P.gs_dev_alt(gs_inp({ra = 1500, gs_dots = 0.35 / P.GS_DOT_DEG})), 1500 / TAN3 * math.tan(math.rad(0.35)), 1e-6,
    "G/S DEV ALT: 0.35 degree above at 1,500 ft is " .. math.floor(1500 / TAN3 * math.tan(math.rad(0.35)) + 0.5) .. " ft")
T.near(P.beam_vs(gs_inp()), -140 * 1852 / 0.3048 / 60 * TAN3, 1e-6, "the beam's vertical speed at 140 kt: 743 fpm down")
-- level below the beam, closing at the beam's 743 fpm: 12.4 ft/s needs 48
-- ft to turn onto it at 0.05 g, and the lead
local close = (140 * 6076.12 / 3600 * TAN3) ^ 2 / (2 * 0.05 * G_FT) + 140 * 6076.12 / 3600 * TAN3 * P.GS_LEAD_S
local function dots_at(d, ra) return math.deg(math.atan(d * TAN3 / ra)) / P.GS_DOT_DEG end
T.check(not P.gs_capture(gs_inp({ra = 1500, gs_dots = dots_at(-(close + 30), 1500)})), "level, " .. math.floor(close + 30) .. " ft below: not yet")
T.check(P.gs_capture(gs_inp({ra = 1500, gs_dots = dots_at(-(close - 10), 1500)})), "level, " .. math.floor(close - 10) .. " ft below: captured")
T.check(not P.gs_capture(gs_inp({ra = 1500, vs = -1500, gs_dots = dots_at(-(close - 10), 1500)})), "below and going down faster than the beam: not")
T.check(P.gs_capture(gs_inp({ra = 1500, vs = -1500, gs_dots = dots_at(close - 10, 1500)})), "above, going down faster: captured")
T.check(P.gs_capture(gs_inp({ra = 1500, vs = -743, gs_dots = P.GS_BAND / P.GS_DOT_DEG * 0.9})), "on the beam's path within the band: captured")
T.check(not P.gs_capture(gs_inp({ra = 1500, gs_valid = false, gs_dots = 0})), "no signal: not")
-- at the end of the scale (X-Plane's 2.5 dots) the distance is unknown:
-- climbing 1,500 fpm toward it (the closing would capture 750 ft away), not
-- until inside the scale
T.check(not P.gs_capture(gs_inp({ra = 2000, vs = 1500, gs_dots = -2.5})), "2.5 dots below, climbing fast: not (the scale's end)")
T.check(P.gs_capture(gs_inp({ra = 2000, vs = 1500, gs_dots = -2.4})), "2.4 dots below, climbing fast: captured")

-- an ILS flown: from x ft out, h ft above the transmitter, the beam at
-- `angle`; the capture by `gs_capture` from `mode`; the signal lost
-- between `lost` seconds; the deviation from the beam's centre (ft) each
-- step to cb
local function ils(o)
    local sp = P.new()
    local x, h = o.x, o.h
    local g = gs_inp({mode = o.mode or "ALT", hold_alt = o.mode == nil and h or nil, vs_sel = o.vs_sel or 0, vs = o.vs or 0, alt = h, ra = h})
    local v = 145 * 1852 / 3600
    g.pitch = 4 + math.deg(math.asin(g.vs / 60 * 0.3048 / v))
    local gam = g.pitch - 4
    local t, r = 0, {cap = nil, dmin = 1e9, dmax = -1e9}
    local angle = o.angle or 3
    while t < o.seconds do
        local c = P.update(sp, g, DT)
        if c then g.pitch = g.pitch + (c - g.pitch) * DT / 2 end
        gam = gam + ((g.pitch - 4) - gam) * DT / 3
        g.vs = v * math.sin(math.rad(gam)) / 0.3048 * 60
        h = h + g.vs / 60 * DT
        x = x - 140 * 6076.12 / 3600 * DT
        g.alt, g.ra = h, h
        local lost = o.lost and t >= o.lost[1] and t < o.lost[2]
        g.gs_valid = not lost
        g.gs_dots = lost and 0 or gs_dots(h, x, angle)
        if g.mode ~= "GS" and P.gs_capture(g) then g.mode, r.cap = "GS", t end
        local d = h - x * math.tan(math.rad(angle))
        if r.cap then
            r.dmin, r.dmax = math.min(r.dmin, d), math.max(r.dmax, d)
            if o.cb then o.cb(t - r.cap, d, g) end
        end
        t = t + DT
    end
    r.d, r.vs = h - x * math.tan(math.rad(angle)), g.vs
    return r
end
-- from below, level at 1,500 ft 9 NM out (the beam 2,865 ft there)
local settled = 0
local r = ils({x = 9 * 6076.12, h = 1500, seconds = 200, cb = function(t, d) if t > 40 then settled = math.max(settled, math.abs(d)) end end})
T.check(r.cap ~= nil, "from below: captured (" .. tostring(r.cap) .. " s)")
T.check(r.dmax < 10, ("from below: through the beam no more than 10 ft (%.1f)"):format(r.dmax))
T.check(settled < 8, ("on the beam within 8 ft from 40 s after the capture (%.1f)"):format(settled))
T.near(r.vs, -743, 20, "down the beam at its 743 fpm")
-- from above: V/S 1,500 down from 3,500 ft 9 NM out
settled = 0
r = ils({x = 9 * 6076.12, h = 3500, mode = "VS", vs_sel = -1500, vs = -1500, seconds = 200, cb = function(t, d) if t > 40 then settled = math.max(settled, math.abs(d)) end end})
T.check(r.cap ~= nil, "from above: captured (" .. tostring(r.cap) .. " s)")
T.check(r.dmin > -12, ("from above: under the beam no more than 12 ft (%.1f)"):format(r.dmin))
T.check(settled < 5, ("from above: on the beam within 5 ft from 40 s (%.1f)"):format(settled))
-- a 3.2 degree glide slope (the law assumes 3): on it all the same
settled = 0
r = ils({x = 9 * 6076.12, h = 1500, angle = 3.2, seconds = 200, cb = function(t, d) if t > 60 then settled = math.max(settled, math.abs(d)) end end})
T.check(settled < 5, ("a 3.2 degree beam: within 5 ft from 60 s (%.1f)"):format(settled))
-- the signal lost for 20 s on the beam (50 s after the capture): the path
-- held (ATA22 p.346)
local during = 0
r = ils({x = 9 * 6076.12, h = 1500, seconds = 180, lost = {150, 170}, cb = function(t, d, g)
    if not g.gs_valid then during = math.max(during, math.abs(d)) end
end})
T.check(during < 15, ("the signal lost 20 s: still within 15 ft of the beam (%.1f)"):format(during))
-- no G/S law off the mode, and none on the ground
T.check(P.update(P.new(), gs_inp({mode = "GS", ground = true, ra = 0, gs_dots = 0}), DT) == nil, "G/S on the ground: not here")

-- step 4b: FLARE on a model of X-Plane's 747 (fitted to s114's first run:
-- the attitude second order, 1.4 rad/s, damping 0.35, 0.4 s late; the path
-- 0.45 s behind the attitude; the main gear 35 ft behind the radio
-- altimeter's arm), from the AFDS model's flare height on the 3 degree
-- path, no wind; the gear's path without a flare on the runway 90 ft before
-- the transmitter: about 1.5 ft/s 450 ft past it (ATA22 p.294, p.346)
local AF = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua")
local function flare(gs_kt)
    local dt, ft = 0.02, 0.3048
    local s, i = P.new(), P.inputs()
    local vf = gs_kt * 1852 / 3600 / ft
    local gam, alpha0, off = -3, 6.3, 0.24
    local h = AF.flare_height(vf * math.sin(math.rad(3)))
    local x = -90 - h / math.tan(math.rad(3))
    local th, thd, hist, t, thmax, hd = alpha0 + gam, 0, {}, 0, 0, 0
    i.active, i.mode, i.tas, i.ias = true, "FLARE", gs_kt, gs_kt
    s.cmd, s.law, s.last_vs = th + off, "GS", vf * math.sin(math.rad(gam)) * 60
    while h > 0 and t < 30 do
        i.pitch, i.vs, i.gear_alt = th, vf * math.sin(math.rad(gam)) * 60, h
        hist[#hist + 1] = P.update(s, i, dt)
        local cmd = hist[math.max(#hist - 20, 1)] - off
        thd = thd + (1.96 * (cmd - th) - 2 * 0.35 * 1.4 * thd) * dt
        th = th + thd * dt
        gam = gam + ((th - alpha0) - gam) * dt / 0.45
        hd = vf * math.sin(math.rad(gam)) - 35 * math.rad(thd)
        h, x, t = h + hd * dt, x + vf * dt, t + dt
        thmax = math.max(thmax, th)
    end
    return {sink = -hd, x = x, thmax = thmax}
end
for _, gs in ipairs({130, 150, 170}) do
    local r = flare(gs)
    T.check(r.sink > 0.5 and r.sink < 3, ("FLARE at %d kt over the ground: the touchdown 0.5 to 3 ft/s (%.1f)"):format(gs, r.sink))
    T.check(r.x > 150 and r.x < 1000, ("FLARE at %d kt: 150 to 1,000 ft past the transmitter (%.0f)"):format(gs, r.x))
    T.check(r.thmax < 8, ("FLARE at %d kt: the pitch under 8 degrees (%.1f)"):format(gs, r.thmax))
end
-- the sink rate under the deceleration's: held (no command to sink faster)
local sf = P.new()
local fi = P.inputs()
fi.active, fi.mode, fi.tas, fi.ias, fi.pitch, fi.vs, fi.gear_alt = true, "FLARE", 140, 140, 3, -480, 50
local c0 = P.update(sf, fi, DT)
local c1 = P.update(sf, fi, DT)
T.near(c1, c0, 0.01, "FLARE at 50 ft sinking 8 ft/s (under the deceleration's 12): the sink held")
-- under 5 ft of gear altitude FLARE's command is not raised, sinking
-- faster than the profile too
local sh = P.new()
local hi = P.inputs()
hi.active, hi.mode, hi.tas, hi.ias, hi.pitch, hi.vs, hi.gear_alt = true, "FLARE", 150, 150, 6, -480, 8
local h1 = P.update(sh, hi, DT)
local h2 = P.update(sh, hi, DT)
T.check(h2 > h1, "FLARE at 8 ft sinking 8 ft/s: the command up")
hi.gear_alt = 4
local h3 = P.update(sh, hi, DT)
T.check(h3 <= h2, "under 5 ft: the command not raised")
-- under 5 ft not sinking any more (the ground effect's float, s116): the
-- command down at K_FLOAT a second of the path error to TD_SINK's, more
-- than K_FLARE's; sinking at TD_SINK or more, no more than K_FLARE's.
-- FLARE begins at 50 ft at 2.5 degrees (its landing attitude 4.5), then
-- the float at 1.5 ft with the nose at 6.5
local function floated(vs)
    local sf2, fl = P.new(), P.inputs()
    fl.active, fl.mode, fl.tas, fl.ias, fl.pitch, fl.vs, fl.gear_alt = true, "FLARE", 150, 150, 2.5, -780, 50
    P.update(sf2, fl, DT)
    fl.pitch, fl.vs, fl.gear_alt = 6.5, vs, 1.5
    -- the command where the flare had raised it, the vertical speed's
    -- filter started again (no jump from the 50 ft step)
    sf2.cmd, sf2.last_vs, sf2.vs_rate = 6.5, nil, 0
    return sf2, fl
end
local function settle(vs, steps)
    local sf2, fl = floated(vs)
    local c, last = nil, nil
    for _ = 1, steps do last = c; c = P.update(sf2, fl, DT) end
    return (c - last) / DT, c
end
local v150 = 150 * 1852 / 3600
local want = -(math.deg(math.atan((P.TD_SINK * 0.3048) / v150)))
T.near(settle(0, 20), P.K_FLOAT * want, 0.05, ("level at 1.5 ft: down at K_FLOAT (%.2f a second)"):format(P.K_FLOAT * want))
T.check(settle(-150, 20) > P.K_FLOAT * want, "sinking 2.5 ft/s at 1.5 ft: not the float's rate")
-- the landing attitude (FCTM p.222-223): a float takes the nose down to
-- FLARE_FLOOR over FLARE's first attitude and no further (s114 2026-11-02
-- touched down at 0.0 degree after a 3 ft float)
local _, c_end = settle(0, 100)
T.near(c_end, 2.5 + P.FLARE_FLOOR, 1e-9, "a float for 10 s: down to the landing attitude, 4.5, and no further")
local up_s, up_i = floated(1500)
up_i.gear_alt = 12
local up_c
for _ = 1, 100 do up_c = P.update(up_s, up_i, DT) end
T.near(up_c, 2.5 + P.FLARE_FLOOR, 1e-9, "climbing at 12 ft (LF6's 14.6 ft float): no lower than the landing attitude either")
-- under it, rising to it is not limited: FLARE begins at 2.5 and the
-- first command is not the landing attitude's
local sr, ri = P.new(), P.inputs()
ri.active, ri.mode, ri.tas, ri.ias, ri.pitch, ri.vs, ri.gear_alt = true, "FLARE", 150, 150, 2.5, -780, 50
local r1 = P.update(sr, ri, DT)
T.check(r1 < 2.5 + 0.5, ("FLARE's first command near the attitude, not the landing attitude (%.2f)"):format(r1))
-- under the landing attitude and asked down (sinking less than the
-- profile): held where it is, not lowered
ri.vs, ri.gear_alt = -60, 30
local r2 = P.update(sr, ri, DT)
local r3 = P.update(sr, ri, DT)
T.check(r3 >= r2 - 1e-9 and r2 >= r1 - 1e-9, "under the landing attitude: not lowered")
-- under FLARE_HOLD_FT the command no more than HOLD_LEAD over the attitude
-- (the nose stops coming up: in X-Plane it went on 0.9 degree past 5 ft on
-- the A/P's lag and the 747 floated 6 ft at 1.14 g, s114 2026-11-02), not
-- under the landing attitude
local sc, ci = P.new(), P.inputs()
ci.active, ci.mode, ci.tas, ci.ias, ci.pitch, ci.vs, ci.gear_alt = true, "FLARE", 150, 150, 2.0, -780, 50
P.update(sc, ci, DT)
sc.cmd, sc.last_vs, sc.vs_rate = 6.0, nil, 0
ci.pitch, ci.vs, ci.gear_alt = 5.0, -300, 4
local cc = P.update(sc, ci, DT)
T.near(cc, 5.0 + P.HOLD_LEAD, 1e-9, ("4 ft, the command a degree over the attitude: down to it + HOLD_LEAD (%.2f)"):format(cc))
ci.pitch = 3.0
sc.cmd = 6.0
cc = P.update(sc, ci, DT)
T.near(cc, 2.0 + P.FLARE_FLOOR, 1e-9, "the attitude under the landing attitude: the landing attitude, 4.0")
ci.gear_alt, ci.pitch = 8, 5.0
sc.cmd = 6.0
cc = P.update(sc, ci, DT)
T.check(cc > 5.0 + P.HOLD_LEAD + 0.5, ("8 ft: not limited (%.2f)"):format(cc))
-- NOSE LETDOWN on the ground after FLARE: from the attitude (FLARE's last
-- command higher), down a degree a second to the pitch-down command of -1
-- that holds the nose gear down (ATA22 p.294, p.332); no step at the
-- touchdown, no jump under 2 degrees (2026-11-04: the main gear lifted off
-- and the nose gear came down 3 to 4 degrees a second: s114, s117)
local sl = P.new()
local li = P.inputs()
li.active, li.mode, li.tas, li.ias, li.pitch, li.vs, li.gear_alt = true, "FLARE", 140, 140, 5, -90, 0
sl.cmd, sl.law = 6, "FLARE"
P.update(sl, li, DT)
li.mode, li.ground, li.letdown = nil, true, true
local l1 = P.update(sl, li, DT)
T.near(l1, 5 - P.LETDOWN_RATE * DT, 1e-9, "NOSE LETDOWN: from the attitude (5), not FLARE's command (6), no step")
local l2 = P.update(sl, li, 1)
T.near(l1 - l2, P.LETDOWN_RATE, 1e-9, "NOSE LETDOWN: the command down LETDOWN_RATE a second")
li.pitch = 3
for _ = 1, 10 do l2 = P.update(sl, li, 1) end
T.equal(l2, P.LETDOWN_PITCH, "NOSE LETDOWN: down to LETDOWN_PITCH")
local sl2 = P.new()
li.pitch = 4
P.update(sl2, li, DT)
li.pitch = 1.9
local l3 = P.update(sl2, li, DT)
T.near(l3, 4 - 2 * P.LETDOWN_RATE * DT, 1e-9, ("under 2 degrees: the command on down at LETDOWN_RATE, no jump to LETDOWN_PITCH (%.3f)"):format(l3))
li.pitch = 0.5
for _ = 1, 6 do l3 = P.update(sl2, li, 1) end
T.equal(l3, P.LETDOWN_PITCH, "under 2 degrees: then held at LETDOWN_PITCH")
local sl3 = P.new()
sl3.cmd, sl3.law = 4.4, "FLARE"
li.pitch = 4.3
T.near(P.update(sl3, li, DT), 4.3 - P.LETDOWN_RATE * DT, 1e-9, "FLARE's command HOLD_LEAD over the attitude: from the attitude")
-- off the runway again (a skip): the command held, on down once the gear
-- is back on it (FCTM p.222-223: hold or re-establish a normal landing
-- attitude; 2026-11-04: lowered on in the air, the nose gear met the
-- runway at 4 degrees a second, s114, s117)
local sl4 = P.new()
sl4.cmd, sl4.law = 5.5, "FLARE"
li.pitch, li.ground, li.letdown = 5.5, true, true
local b1 = P.update(sl4, li, 0.4)
T.near(b1, 5.5 - 0.4 * P.LETDOWN_RATE, 1e-9, "on the runway: down LETDOWN_RATE a second")
li.ground = false
local b2 = P.update(sl4, li, 1)
T.near(b2, b1, 1e-9, ("skipped off the runway: the command held (%.2f)"):format(b2))
li.ground = true
local b3 = P.update(sl4, li, 0.5)
T.near(b3, b1 - 0.5 * P.LETDOWN_RATE, 1e-9, "back on the runway: on down")
li.letdown = false
T.check(P.update(sl, li, DT) == nil, "NOSE LETDOWN's end: no law on the ground")

-- (the FMC's step 9h3b) an engine failure in T/O (ATA22 p.264; FCOM
-- p.666): the speed then within V2 and V2 + 10, on the ground the
-- lift-off's, the window's when set higher, no ratchet; the blend from
-- the attitude to the speed between 0 and 600 fpm; in G/A up to MCP + 10
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150})
P.update(s, i, DT)
i.ground, i.ias, i.pitch = false, 178, 9
for _ = 1, math.floor(5.2 / DT) do P.update(s, i, DT) end
T.equal(s.target, 178, "all engines: 5 s above, the speed then (V2 + 18)")
i.eo = true
P.update(s, i, DT)
T.equal(s.target, 170, "an engine failure at 178 kt: V2 + 10 at most")
i.ias = 192
for _ = 1, math.floor(6 / DT) do P.update(s, i, DT) end
T.equal(s.target, 170, "no ratchet with the engine out")
i.mcp_ias = 180
P.update(s, i, DT)
T.equal(s.target, 180, "the window set higher: the window's")
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150})
P.update(s, i, DT)
i.ground, i.ias, i.pitch, i.eo = false, 165, 9, true
P.update(s, i, DT)
T.equal(s.target, 165, "a failure at 165 kt (between V2 and V2 + 10): 165")
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150})
P.update(s, i, DT)
i.ground, i.ias, i.pitch, i.eo = false, 156, 9, true
P.update(s, i, DT)
T.equal(s.target, 160, "a failure at 156 kt (under V2): V2")
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 140, pitch = 3, vs = 0, alt = 0, tas = 140, eo = true})
P.update(s, i, DT)
i.ground, i.ias, i.pitch = false, 163, 9
P.update(s, i, DT)
T.equal(s.target, 163, "failed on the ground: the lift-off's 163 kt (FCOM p.666)")
-- the blend with an engine out: at 700 fpm the speed only
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 12, vs = 700, alt = 600, tas = 150})
P.update(s, i, DT)
i.ias = 140
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c > 12, "all engines, 700 fpm, 10 kt slow: up, mostly the attitude (" .. c .. ")")
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 150, pitch = 12, vs = 700, alt = 600, tas = 150, eo = true})
P.update(s, i, DT)
i.ias = 140
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c < 12, "an engine out, 700 fpm, 10 kt slow: down for the speed (the blend 0 to 600 fpm: ATA22 p.264) (" .. c .. ")")
-- G/A: up to MCP + 10 with an engine out
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 145, pitch = 2.5, vs = -800, alt = 300, tas = 150, eo = true})
P.update(s, i, DT)
T.equal(s.ga_cap, 160, "G/A with an engine out: up to MCP + 10 (ATA22 p.298)")
s = P.new()
i = inp({mode = "GA", mcp_ias = 150, ias = 145, pitch = 2.5, vs = -800, alt = 300, tas = 150})
P.update(s, i, DT)
T.equal(s.ga_cap, 175, "all engines: MCP + 25")
i.eo = true
P.update(s, i, DT)
T.equal(s.ga_cap, 160, "an engine failing in G/A: MCP + 10")

-- (2026-11-07) the ALT law's K_PATH by the lift coefficient (the dynamic
-- pressure and the weight): PATH_K_LO of it up to PATH_CL_LO, all of it
-- from PATH_CL_HI, between in proportion (the light, high cruise's altitude
-- hold swing: notes/ATA-22.md §53; before, (290 / IAS) ^ 3.5 above 290
-- KIAS, §44); the V/S law all of it (2026-11-03: the high-speed VNAV
-- descent, s206)
local function at_cl(cl, w)
    w = w or 250000
    return {q = w * 9.80665 / (cl * P.WING_AREA), weight = w}
end
local LO, HI, KLO = P.PATH_CL_LO, P.PATH_CL_HI, P.PATH_K_LO
T.check(KLO > 0.5 and KLO < 1 and LO < HI, "the schedule's shape")
T.near(P.path_gain(at_cl(1.2)), 1, 1e-12, "path gain 1 on the approach (CL 1.2)")
T.near(P.path_gain(at_cl(HI)), 1, 1e-12, "path gain 1 from PATH_CL_HI")
T.near(P.path_gain(at_cl(LO)), KLO, 1e-12, "PATH_K_LO at PATH_CL_LO")
T.near(P.path_gain(at_cl(LO / 2)), KLO, 1e-12, "the same floor below it")
T.near(P.path_gain(at_cl((LO + HI) / 2)), (1 + KLO) / 2, 1e-12, "halfway between: halfway")
T.near(P.path_gain(at_cl(LO / 2, 400000)), KLO, 1e-12, "the same CL at another weight: the same")
T.near(P.path_gain(nil), 1, 1e-12, "no inputs: 1")
T.near(P.path_gain({ias = 334}), 1, 1e-12, "no q and weight: 1")
T.near(P.path_gain({q = 0, weight = 250000}), 1, 1e-12, "q 0 (the load): 1")
-- the perf kit's points (2026-11-06, raw/crz_*.csv), the sweeps and s215
-- (2026-11-07, §53): the gain X-Plane held at each, not the one that decayed
-- slowly
local function at(q, w_t) return {q = q, weight = w_t * 1000} end
local g238_370 = P.path_gain(at(10987, 237.7))    -- 238 t FL370 M.85: CL 0.415 (0.7 held, 0.8 slow)
local g238_350 = P.path_gain(at(12083, 237.6))    -- 238 t FL350 M.85: CL 0.378 (93 fpm rms with all of it)
local g238_390 = P.path_gain(at(9992, 237.7))     -- 238 t FL390 M.85: CL 0.457 (47)
local g306_350 = P.path_gain(at(11993, 306.9))    -- 306 t FL350 M.85: CL 0.491 (0.75 held, 0.85 slow)
local g306_310 = P.path_gain(at(13217, 306.6))    -- 306 t FL310 M.81: CL 0.445 (0.8 held, 0.9 slow)
local g306_370 = P.path_gain(at(11168, 306.8))    -- 306 t FL370 M.85: CL 0.527 (all of it: 1.5 fpm rms)
local g353_310 = P.path_gain(at(14605, 354.0))    -- 353 t FL310 M.85: CL 0.465 (0.72 before: 3)
local g215 = P.path_gain(at(16549, 270.0))        -- s215, FL250 334 kt 270 t: CL 0.313 (0.7 held, 0.8 slow; 0.61 before)
local g10k = P.path_gain(at(10130, 300.0))        -- 10,000 ft 250 kt 300 t: CL 0.569 (all of it held)
T.check(g238_350 >= 0.65 and g238_350 <= 0.72, "238 t FL350: about 0.7 (" .. g238_350 .. ")")
T.check(g238_370 >= 0.65 and g238_370 <= 0.72, "238 t FL370: about 0.7 (" .. g238_370 .. ")")
T.check(g238_390 >= 0.65 and g238_390 <= 0.75, "238 t FL390: about 0.7 (" .. g238_390 .. ")")
T.check(g306_310 >= 0.65 and g306_310 <= 0.8, "306 t FL310: 0.7 to 0.8 (" .. g306_310 .. ")")
T.check(g306_350 >= 0.72 and g306_350 <= 0.8, "306 t FL350: 0.72 to 0.8 (" .. g306_350 .. ")")
T.check(g306_370 >= 0.8 and g306_370 <= 0.9, "306 t FL370: 0.8 to 0.9 (" .. g306_370 .. ")")
T.check(g215 >= 0.65 and g215 <= 0.72, "FL250 334 kt at 270 t: about 0.7 (" .. g215 .. ")")
T.check(g353_310 >= 0.65 and g353_310 <= 0.8, "353 t FL310: 0.7 to 0.8 (" .. g353_310 .. ")")
T.check(g10k >= 0.9, "10,000 ft, 250 kt, 300 t: nearly all of it (" .. g10k .. ")")
T.check(g238_350 <= g238_370 and g238_370 <= g306_350 and g306_350 <= g306_370, "the lighter for its q, the less")
-- ALT's first command rate (20 ft below: 120 fpm, under the 0.05 g limit)
-- at the floor that share; V/S's (100 fpm) the same at both
local function first_rate(o)
    local st = P.new()
    local x = inp(o)
    P.update(st, x, DT)
    local c0 = st.cmd
    P.update(st, x, DT)
    return (st.cmd - c0) / DT
end
local HI, LO = at_cl(HI), at_cl(LO / 2)
local function alt_rate(c)
    return first_rate({mode = "ALT", hold_alt = 9020, alt = 9000, vs = 0, ias = 290, tas = 470, pitch = 2, q = c.q, weight = c.weight})
end
local function vs_rate(c)
    return first_rate({mode = "VS", vs_sel = 100, vs = 0, ias = 290, tas = 470, pitch = 2, q = c.q, weight = c.weight})
end
local ahi, alo = alt_rate(HI), alt_rate(LO)
T.check(ahi > 0, "ALT 20 ft below: the command rises (" .. ahi .. ")")
T.near(alo / ahi, KLO, 0.02, "ALT at the floor: the rate that share (" .. alo .. " / " .. ahi .. ")")
local rhi, rlo = vs_rate(HI), vs_rate(LO)
T.check(rhi > 0, "V/S up: the command rises (" .. rhi .. ")")
T.near(rlo / rhi, 1, 0.02, "V/S at the floor: the full rate (the VNAV descent's path, s206: " .. rlo .. " / " .. rhi .. ")")
local function vnav_rate(c)
    return first_rate({mode = "VNAV", vnav_law = "VS", vnav_vs = -100, vs = 0, ias = 290, tas = 470, pitch = 2, q = c.q, weight = c.weight})
end
T.near(vnav_rate(LO) / vnav_rate(HI), 1, 0.02, "the old VNAV's path (V/S) at the floor: the full rate")
-- VNAV PTH level at the cruise altitude and VNAV ALT: the ALT law (the
-- glue's vnav_law "ALT"), the share as ALT HOLD (the line flights' bob was
-- in the cruise's VNAV PTH)
local function vnav_alt_rate(c)
    return first_rate({mode = "VNAV", vnav_law = "ALT", vnav_alt = 9020, alt = 9000, vs = 0, ias = 290, tas = 470, pitch = 2, q = c.q, weight = c.weight})
end
T.near(vnav_alt_rate(LO) / vnav_alt_rate(HI), KLO, 0.02, "VNAV level (ALT law) at the floor: the share as ALT HOLD")
-- the speed laws keep theirs (steady at 340 kt in the line flights)
local function flch_rate(c)
    local st = P.new()
    local x = inp({mode = "FLCH", ias = 300, spd_sel = 280, vs = 0, tas = 470, pitch = 2, q = c.q, weight = c.weight})
    P.update(st, x, DT)
    local c0 = st.cmd
    P.update(st, x, DT)
    return (st.cmd - c0) / DT
end
T.near(flch_rate(LO), flch_rate(HI), 0.05, "FLCH: the same rate at both")
T.done()
