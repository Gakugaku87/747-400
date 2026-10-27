-- The FCCs' pitch laws (6-3 step 3a; the plan and sources in
-- docs/overhaul/notes/ATA-22.md §10 and §18): the pitch command, the
-- attitude the A/P flies and the F/Ds show, of V/S, ALT (the hold and the
-- MCP altitude's capture) and the old VNAV's V/S and altitude laws, out of
-- the pitch mode the AFDS model (B747.70.afds_model.lua) has.
--  - V/S: the MCP's vertical speed against the IRUs' inertial one (ATA22
--    p.344); 000 holds the altitude where it was set (ATA22 p.282, p.338:
--    the FMA stays V/S).
--  - ALT: the altitude the AFDS model holds (the push's, or the MCP
--    altitude from its capture: ATA22 p.346), its error made a vertical
--    speed, at most the one that levels off at the capture's 0.05 g
--    (ATA22 p.286), the altitude taken ANTICIPATE_S ahead; closing on it,
--    never more than when the law started until the level-off asks for
--    less. The capture starts (`capture`, the AFDS model's input: before,
--    the old window) when the airplane, closing on the MCP altitude, is no
--    farther than that level-off and CAPTURE_LAG_S of its vertical speed.
--  - VNAV: the old VNAV's laws by its flags (until the FMC's step 9): its
--    V/S and its altitude here, its speed on the old law (step 3b).
--  - FLCH, T/O, G/A, G/S, FLARE: not here (the old law until steps 3b, 3c
--    and 4).
-- A vertical speed asks for its flight path; the command moves at
-- K_PATH times the flight path's error a second, the path flown taken
-- LEAD_S ahead on the inertial vertical acceleration (damping: ATA22
-- p.346), at most the G_LIMIT's, from the attitude where the law starts
-- (the pitch attitude integrator synchronized: ATA22 p.332). The numbers
-- are estimates (the sources give the inputs, not the gains), tuned on a
-- lagged airplane that flies as X-Plane's 747 did in s107's first run
-- (the attitude 2 s behind the command, the path 3 s behind the
-- attitude): there the level-offs had overshot 200 ft; tuned for the path
-- 1.5 times as slow too (s107's second run had overshot 74 ft).
-- Pure: the airplane's state in, the command out.
--   local P = B747_afds_pitch_model                       -- in XTLua, after dofile
--   local P = dofile(".../B747.70.afds_pitch_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_afds_pitch_model = M

-- the command's rate: K_PATH degrees a second for each degree of flight
-- path error, the normal acceleration within G_LIMIT (the capture's 0.05
-- g, ATA22 p.286, for all: estimate)
M.K_PATH = 0.25
M.G_LIMIT = 0.05
-- ALT: the altitude error's vertical speed, K_ALT of the error a second
-- (estimate), at most the capture's level-off
M.K_ALT = 0.1
-- the capture starts this much earlier than the level-off needs (the
-- command's and the airplane's lag: estimate), or within CAPTURE_NEAR ft
M.CAPTURE_LAG_S = 10
M.CAPTURE_NEAR = 20
-- the command's limits (estimate)
M.PITCH_MIN = -10
M.PITCH_MAX = 20
-- damping (ATA22 p.346: the inertial vertical speed for damping): the
-- flight path taken LEAD_S ahead on the inertial vertical acceleration
-- (filtered over ACCEL_S), ALT's altitude ANTICIPATE_S ahead on the
-- vertical speed (estimates)
M.LEAD_S = 3.5
M.ACCEL_S = 1
M.ANTICIPATE_S = 8

local G = 9.80665
local FT = 0.3048
local KT = 1852 / 3600
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function a_ft() return M.G_LIMIT * G / FT end   -- the limit, ft/s/s
-- the flight path (degrees) of a vertical speed (fpm) at v (m/s)
local function path(fpm, v) return math.deg(math.asin(clamp(fpm * FT / 60 / v, -1, 1))) end

function M.new()
    return {cmd = nil, vs0_alt = nil, law = nil, target = nil, cap_vs = nil}
end

function M.inputs()
    return {
        mode = nil,         -- the AFDS model's pitch mode
        vnav_law = nil,     -- the old VNAV's law by its flags: "VS", "ALT", "FLCH"
        active = false,     -- an A/P engaged or a F/D shown
        ground = false,
        pitch = 0,          -- the pitch attitude, degrees
        vs = 0,             -- the inertial vertical speed, fpm
        tas = 0,            -- kt
        alt = 0,            -- the barometric altitude, ft
        vs_sel = 0,         -- the MCP's vertical speed, fpm
        hold_alt = nil,     -- ALT's altitude (the AFDS model's)
        vnav_vs = 0,        -- the old VNAV's vertical speed
        vnav_alt = 0,       -- and altitude
    }
end

-- the vertical speed (fpm) that levels off from dh ft at the limit
function M.level_off_vs(dh)
    return math.sqrt(2 * a_ft() * math.abs(dh)) * 60
end

-- the MCP altitude's capture (ATA22 p.286): closing on it no farther than
-- the level-off at G_LIMIT and CAPTURE_LAG_S of the vertical speed, or
-- within CAPTURE_NEAR
function M.capture(inp, target)
    if target == nil then return false end
    local dh = target - inp.alt
    if math.abs(dh) <= M.CAPTURE_NEAR then return true end
    local vs = inp.vs / 60
    if dh * vs <= 0 then return false end
    return math.abs(dh) <= vs * vs / (2 * a_ft()) + math.abs(vs) * M.CAPTURE_LAG_S
end

-- ALT's vertical speed (fpm) to the altitude: K_ALT of the error, at most
-- the level-off's
function M.alt_vs(target, alt)
    local dh = target - alt
    local v = math.min(M.K_ALT * math.abs(dh) * 60, M.level_off_vs(dh))
    return dh >= 0 and v or -v
end

-- the law of the mode: "VS" with its vertical speed, "ALT" with its
-- altitude, or nil (not here)
local function law_of(s, inp)
    local mode = inp.mode
    if mode == "VS" then
        if inp.vs_sel ~= 0 then s.vs0_alt = nil; return "VS", inp.vs_sel end
        -- 000: the altitude where it was set (ATA22 p.282)
        if s.vs0_alt == nil then s.vs0_alt = inp.alt end
        return "ALT", s.vs0_alt
    end
    s.vs0_alt = nil
    if mode == "ALT" and inp.hold_alt then return "ALT", inp.hold_alt end
    if mode == "VNAV" and inp.vnav_law == "VS" then return "VS", inp.vnav_vs end
    if mode == "VNAV" and inp.vnav_law == "ALT" then return "ALT", inp.vnav_alt end
    return nil
end

-- the command (degrees of pitch), or nil without a law here
function M.update(s, inp, dt)
    dt = dt or 0
    local law, target
    if inp.active and not inp.ground then law, target = law_of(s, inp) end
    if law == nil then
        s.cmd, s.law, s.target, s.cap_vs, s.last_vs, s.vs_rate = nil, nil, nil, nil, nil, 0
        if not (inp.active and inp.mode == "VS") then s.vs0_alt = nil end
        return nil
    end
    if s.cmd == nil then s.cmd = inp.pitch end
    -- the inertial vertical acceleration (fpm a second), filtered
    if s.last_vs and dt > 0 then
        s.vs_rate = (s.vs_rate or 0) + ((inp.vs - s.last_vs) / dt - (s.vs_rate or 0)) * math.min(1, dt / M.ACCEL_S)
    end
    s.last_vs = inp.vs
    local want = target
    if law == "ALT" then
        -- a new altitude: closing on it, no more than the vertical speed now
        -- until the level-off asks for less; the altitude ANTICIPATE_S ahead
        if s.law ~= "ALT" or s.target ~= target then
            local closing = (target - inp.alt) * inp.vs > 0
            s.cap_vs = closing and math.abs(inp.vs) or nil
        end
        want = M.alt_vs(target, inp.alt + inp.vs / 60 * M.ANTICIPATE_S)
        if s.cap_vs then
            if math.abs(want) < s.cap_vs then s.cap_vs = nil else want = want > 0 and s.cap_vs or -s.cap_vs end
        end
    end
    s.law, s.target = law, target
    local v = math.max(inp.tas, 100) * KT
    local lim = math.deg(M.G_LIMIT * G / v)
    local flown = inp.vs + (s.vs_rate or 0) * M.LEAD_S
    local rate = clamp(M.K_PATH * (path(want, v) - path(flown, v)), -lim, lim)
    s.cmd = clamp(s.cmd + rate * dt, M.PITCH_MIN, M.PITCH_MAX)
    return s.cmd
end

return M
