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
T.check(i.vs < -1000, "descending (" .. i.vs .. ")")
-- the reference protected: under the minimum maneuvering speed with the
-- flaps out, 5 kt above it
s = P.new()
i = inp({mode = "FLCH", ias = 180, spd_sel = 160, v_min = 175, flaps_up = false, vs = 0, tas = 200})
P.update(s, i, DT)
T.equal(s.target, 180, "FLCH under the minimum maneuvering speed: 5 kt above it (flaps out)")

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
-- NOSE LETDOWN on the ground after FLARE: from a degree under the attitude
-- (FLARE's last command higher), down a degree a second, the nose held down
-- at -1 under 2 degrees (ATA22 p.332)
local sl = P.new()
local li = P.inputs()
li.active, li.mode, li.tas, li.ias, li.pitch, li.vs, li.gear_alt = true, "FLARE", 140, 140, 5, -90, 0
sl.cmd, sl.law = 6, "FLARE"
P.update(sl, li, DT)
li.mode, li.ground, li.letdown = nil, true, true
local l1 = P.update(sl, li, DT)
T.near(l1, 5 - P.LETDOWN_STEP - P.LETDOWN_RATE * DT, 1e-9, "NOSE LETDOWN: from a degree under the attitude (5), not FLARE's command (6)")
local l2 = P.update(sl, li, 1)
T.near(l1 - l2, P.LETDOWN_RATE, 1e-9, "NOSE LETDOWN: the command down LETDOWN_RATE a second")
li.pitch = 3
for _ = 1, 10 do l2 = P.update(sl, li, 1) end
T.equal(l2, P.LETDOWN_PITCH, "NOSE LETDOWN: down to LETDOWN_PITCH")
local sl2 = P.new()
li.pitch = 4
P.update(sl2, li, DT)
li.pitch = 1.9
T.equal(P.update(sl2, li, DT), P.LETDOWN_PITCH, "under 2 degrees on the ground: the nose held down at once")
li.letdown = false
T.check(P.update(sl, li, DT) == nil, "NOSE LETDOWN's end: no law on the ground")

T.done()
