-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_pitch_model_test.lua
-- The FCCs' pitch laws, step 3a (6-3: docs/overhaul/notes/ATA-22.md §18):
-- plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua.
-- The capture's start (closing within the 0.05 g level-off and 10 s),
-- ALT's vertical speed, a level-off flown on a simple airplane (the
-- attitude follows the command; the flight path is the attitude less a
-- fixed angle of attack) and on a lagged one (the attitude 2 s behind the
-- command, the flight path 3 s behind the attitude: as X-Plane's 747 at
-- 10,000 ft in s107's first run): no overshoot, within the 0.05 g,
-- settled; V/S established within the limit; V/S 000 holding where it was
-- set; ALT HOLD pushed in a climb: over and back; the old VNAV's laws by
-- its flags; no law (FLCH, nothing engaged or shown, on the ground).
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
T.equal(P.update(s, inp({mode = "VNAV", vnav_law = "FLCH"}), DT), nil, "VNAV with the old speed flag: the old law (step 3b)")
-- no law
T.equal(P.update(s, inp({mode = "FLCH"}), DT), nil, "FLCH: the old law (step 3b)")
T.equal(P.update(s, inp({mode = "VS", vs_sel = 1000, active = false}), DT), nil, "nothing engaged or shown")
T.equal(P.update(s, inp({mode = "VS", vs_sel = 1000, ground = true}), DT), nil, "on the ground")
-- the command starts from the attitude
s = P.new()
local c = P.update(s, inp({mode = "VS", vs_sel = 0, pitch = 4.5, vs = 0}), DT)
T.near(c, 4.5, 0.05, "from the attitude where the law starts")

T.done()
