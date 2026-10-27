-- The FCCs' pitch laws (6-3 steps 3a and 3b; the plan and sources in
-- docs/overhaul/notes/ATA-22.md §10, §18 and §19): the pitch command, the
-- attitude the A/P flies and the F/Ds show, of V/S, ALT (the hold and the
-- MCP altitude's capture), the speed laws (FLCH, T/O, G/A) and the old
-- VNAV's laws, out of the pitch mode the AFDS model (B747.70.afds_model.lua)
-- has.
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
--  - FLCH SPD, the old VNAV's speed (step 3b; ATA22 p.344): the speed
--    through the elevator, to the MCP's (the old VNAV's), within the speed
--    protection (FCOM p.675: the minimum maneuvering speed, 5 kt above it
--    with the flaps out, and the maximum less 5 kt).
--  - T/O (FCOM p.664, p.666): 8 degrees on the ground; in the air the
--    speed, the higher of V2 + 10 and the rotation's speed + 10 (pitch
--    over 2 degrees), the speed then once above it 5 s (up to V2 + 25),
--    the MCP's when set higher; V2 the IAS/MACH window's (FCOM's note);
--    not over the PLI. In a windshear as G/A (ATA22 p.344).
--  - G/A (FCOM p.664, p.674; ATA22 p.344): the higher of the MCP's and the
--    speed then, the speed then once above it 5 s (up to MCP + 25, or the
--    start's speed when it was more); from 600 to 1,200 fpm of climb
--    from the attitude (15 degrees, or 1 below the PLI) to the speed.
--  - VNAV: the old VNAV's laws by its flags (until the FMC's step 9).
--  - G/S, FLARE: not here (the old law until steps 3c and 4).
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
-- The speed laws (step 3b) ask for the acceleration that closes the speed
-- error in SPD_TAU_S (at most SPD_ACCEL): the flight path that would make
-- the difference from the acceleration now, against the path flown LEAD_S
-- ahead (as above), K_PATH again (less below SPD_K_KT); FLCH and VNAV
-- within SPD_G, T/O and G/A at most TOGA_RATE. Estimates too, tuned on the
-- lagged airplane with a speed (the thrust's excess less the climb):
-- undamped without the lead (250 to 280 kt overshot 18 kt); within SPD_G =
-- 0.05 a FLCH climb's entry overshot 14 kt (0.1: 9 kt); T/O and G/A slower
-- than TOGA_RATE overshot more and raised the target. In X-Plane at 170 kt
-- (s109) the A/P's attitude loop, less damped there, and the full K_PATH
-- swung the pitch 3.6 degrees every 12 s; on an attitude loop as damped
-- (zeta 0.3) 0.17 left 0.6 degrees.
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
-- the speed laws (step 3b, estimates): the speed error closed over
-- SPD_TAU_S, at most SPD_ACCEL kt a second; FLCH's and VNAV's normal
-- acceleration within SPD_G; the speed protection's margin (FCOM p.675:
-- the FMC's 5 kt)
M.SPD_TAU_S = 15
M.SPD_ACCEL = 1.5
M.SPD_G = 0.1
M.SPD_MARGIN = 5
-- the speed laws' K_PATH times the IAS over SPD_K_KT, from SPD_K_MIN to all
-- of it (150 kt: 0.15, 170 kt: 0.17, 250 kt up: 0.25; estimate)
M.SPD_K_KT = 250
M.SPD_K_MIN = 0.6
-- T/O (FCOM p.664, p.666): the ground's 8 degrees, the rotation over
-- ROT_DEG, V2 + TO_ADD up to V2 + TO_MAX_ADD; above the target ABOVE_S
M.TO_PITCH = 8
M.ROT_DEG = 2
M.TO_ADD = 10
M.TO_MAX_ADD = 25
M.ABOVE_S = 5
-- G/A (FCOM p.664, p.674): up to MCP + GA_MAX_ADD; the attitude ATT_DEG or
-- ATT_PLI below the PLI ("slightly": estimate), blended into the speed from
-- BLEND_LO to BLEND_HI fpm of climb (ATA22 p.344), the attitude at K_ATT of
-- its error a second (estimate); TO/GA's command at most TOGA_RATE degrees
-- a second (estimate)
M.GA_MAX_ADD = 25
M.ATT_DEG = 15
M.ATT_PLI = 1
M.BLEND_LO = 600
M.BLEND_HI = 1200
M.K_ATT = 0.5
M.TOGA_RATE = 3

local G = 9.80665
local FT = 0.3048
local KT = 1852 / 3600
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function a_ft() return M.G_LIMIT * G / FT end   -- the limit, ft/s/s
-- the flight path (degrees) of a vertical speed (fpm) at v (m/s)
local function path(fpm, v) return math.deg(math.asin(clamp(fpm * FT / 60 / v, -1, 1))) end

function M.new()
    return {cmd = nil, vs0_alt = nil, law = nil, target = nil, cap_vs = nil,
        last_ias = nil, ias_rate = 0, above = 0, mode = nil,
        v2 = nil, vrot = nil, to_target = nil, ga_target = nil, ga_cap = nil}
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
        -- the speed laws (step 3b)
        ias = 0,            -- the indicated airspeed, kt
        spd_sel = 0,        -- FLCH's and the old VNAV's speed, kt
        mcp_ias = 0,        -- the IAS/MACH window (T/O's V2, G/A's), kt
        v_min = 0,          -- the minimum maneuvering speed (0: none)
        v_max = 0,          -- the maximum speed (0: none)
        pli = nil,          -- the PLI, degrees above the pitch (nil: none)
        flaps_up = true,
        windshear = false,
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

-- the speed protected (FCOM p.675): from the minimum maneuvering speed (5
-- kt above it with the flaps out) to the maximum less 5 kt
function M.protect(v, inp)
    if inp.v_max > 0 then v = math.min(v, inp.v_max - M.SPD_MARGIN) end
    if inp.v_min > 0 then v = math.max(v, inp.v_min + (inp.flaps_up and 0 or M.SPD_MARGIN)) end
    return v
end

-- T/O's and G/A's speed: once above it ABOVE_S, the speed then up to the
-- cap; the IAS/MACH window when set higher
local function ratchet(s, inp, target, cap, dt)
    if inp.mcp_ias > target then target = inp.mcp_ias end
    if inp.ias > target then s.above = s.above + dt else s.above = 0 end
    if s.above >= M.ABOVE_S then
        target = math.max(target, math.min(inp.ias, cap))
        s.above = 0
    end
    return target
end

-- the law of the mode: "VS" with its vertical speed, "ALT" with its
-- altitude, "SPD" with its speed (and whether it blends from the
-- attitude), "TOGND" (8 degrees), or nil (not here)
local function law_of(s, inp, dt)
    local mode = inp.mode
    if mode ~= s.mode then
        s.mode, s.above = mode, 0
        if mode ~= "TO" then s.vrot, s.v2, s.to_target = nil, nil, nil end
        if mode == "GA" then
            s.ga_target = math.max(inp.mcp_ias, inp.ias)
            s.ga_cap = math.max(inp.mcp_ias + M.GA_MAX_ADD, inp.ias)
        end
    end
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
    if mode == "VNAV" and inp.vnav_law == "FLCH" then return "SPD", M.protect(inp.spd_sel, inp) end
    if mode == "FLCH" then return "SPD", M.protect(inp.spd_sel, inp) end
    if mode == "TO" then
        if inp.ground then
            -- the rotation's speed; V2 the IAS/MACH window's
            if s.vrot == nil and inp.pitch > M.ROT_DEG then s.vrot = inp.ias end
            s.v2 = inp.mcp_ias
            return "TOGND", M.TO_PITCH
        end
        if s.to_target == nil then
            local v2 = s.v2 or inp.mcp_ias
            s.v2 = v2
            s.to_target = math.max(v2 + M.TO_ADD, (s.vrot or 0) + M.TO_ADD)
        end
        s.to_target = ratchet(s, inp, s.to_target, s.v2 + M.TO_MAX_ADD, dt)
        return "SPD", M.protect(s.to_target, inp), inp.windshear
    end
    if mode == "GA" then
        s.ga_target = ratchet(s, inp, s.ga_target or inp.mcp_ias, s.ga_cap or inp.mcp_ias + M.GA_MAX_ADD, dt)
        return "SPD", M.protect(s.ga_target, inp), true
    end
    return nil
end

-- the command (degrees of pitch), or nil without a law here
function M.update(s, inp, dt)
    dt = dt or 0
    local law, target, blend
    if inp.active and (not inp.ground or inp.mode == "TO" or inp.mode == "GA") then
        law, target, blend = law_of(s, inp, dt)
    end
    if law == nil then
        s.cmd, s.law, s.target, s.cap_vs, s.last_vs, s.vs_rate = nil, nil, nil, nil, nil, 0
        s.last_ias, s.ias_rate, s.mode = nil, 0, inp.active and inp.mode or nil
        if not (inp.active and inp.mode == "VS") then s.vs0_alt = nil end
        return nil
    end
    -- the inertial vertical acceleration (fpm a second) and the speed's
    -- (kt a second), filtered
    local k = math.min(1, dt / M.ACCEL_S)
    if s.last_vs and dt > 0 then s.vs_rate = (s.vs_rate or 0) + ((inp.vs - s.last_vs) / dt - (s.vs_rate or 0)) * k end
    if s.last_ias and dt > 0 then s.ias_rate = s.ias_rate + ((inp.ias - s.last_ias) / dt - s.ias_rate) * k end
    s.last_vs, s.last_ias = inp.vs, inp.ias
    if law == "TOGND" then
        -- T/O on the ground: the F/D's 8 degrees (FCOM p.666)
        s.cmd, s.law, s.target = target, law, target
        return s.cmd
    end
    if s.cmd == nil or s.law == "TOGND" then s.cmd = inp.pitch end
    local v = math.max(inp.tas, 100) * KT
    local lim = math.deg(M.G_LIMIT * G / v)
    local rate
    if law == "SPD" then
        -- the acceleration that closes the error in SPD_TAU_S, the flight
        -- path of the difference
        local want = clamp((target - inp.ias) / M.SPD_TAU_S, -M.SPD_ACCEL, M.SPD_ACCEL)
        local lead = path(inp.vs + (s.vs_rate or 0) * M.LEAD_S, v) - path(inp.vs, v)
        local k = M.K_PATH * clamp(inp.ias / M.SPD_K_KT, M.SPD_K_MIN, 1)
        rate = k * (math.deg((s.ias_rate - want) * KT / G) - lead)
        local toga = inp.mode == "TO" or inp.mode == "GA"
        if blend then
            -- from the attitude to the speed between 600 and 1,200 fpm
            local att = M.ATT_DEG
            if inp.pli then att = math.min(att, inp.pitch + inp.pli - M.ATT_PLI) end
            local w = clamp((inp.vs - M.BLEND_LO) / (M.BLEND_HI - M.BLEND_LO), 0, 1)
            rate = (1 - w) * M.K_ATT * (att - s.cmd) + w * rate
        end
        lim = toga and M.TOGA_RATE or math.deg(M.SPD_G * G / v)
        s.cap_vs = nil
    else
        local want = target
        if law == "ALT" then
            -- a new altitude: closing on it, no more than the vertical speed
            -- now until the level-off asks for less; the altitude
            -- ANTICIPATE_S ahead
            if s.law ~= "ALT" or s.target ~= target then
                local closing = (target - inp.alt) * inp.vs > 0
                s.cap_vs = closing and math.abs(inp.vs) or nil
            end
            want = M.alt_vs(target, inp.alt + inp.vs / 60 * M.ANTICIPATE_S)
            if s.cap_vs then
                if math.abs(want) < s.cap_vs then s.cap_vs = nil else want = want > 0 and s.cap_vs or -s.cap_vs end
            end
        end
        local flown = inp.vs + (s.vs_rate or 0) * M.LEAD_S
        rate = M.K_PATH * (path(want, v) - path(flown, v))
    end
    s.law, s.target = law, target
    s.cmd = clamp(s.cmd + clamp(rate, -lim, lim) * dt, M.PITCH_MIN, M.PITCH_MAX)
    -- T/O and G/A not over the PLI (FCOM p.664)
    if (inp.mode == "TO" or inp.mode == "GA") and inp.pli then
        s.cmd = math.min(s.cmd, inp.pitch + inp.pli)
    end
    return s.cmd
end

return M
