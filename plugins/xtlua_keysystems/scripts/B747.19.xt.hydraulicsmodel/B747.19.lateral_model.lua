-- 747-400 lateral control without X-Plane (4-1 step 4): the aileron
-- programmers, the flight spoilers' share of roll and the spoiler mixers
-- with the speedbrake program. The control wheel angle comes from the
-- controlObject (laminar/B747/cablecontrols/wheel); the hydraulics module
-- (B747.19.xt.hydraulics_override.lua) takes the surfaces' commands through
-- its pressure gates and rates. Logic and sources:
-- docs/overhaul/notes/ATA-27.md §4.1-§4.2 and §15 (ATA27 p.59, p.76, p.88,
-- p.143-150, p.165, p.188-190, p.206-207; FCOM p.947).
--
--   local L = B747_lateral_model          -- in XTLua, after dofile
--   local L = dofile(".../B747.19.lateral_model.lua")   -- in the tests

local M = setmetatable({}, {})
B747_lateral_model = M

-- the captain's control wheel stops at 90 degrees (the first officer's at
-- 100 with its 10 degrees of lost motion: ATA27 p.59, p.143); the aileron
-- trim moves the wheel's neutral 47 degrees at 6 units (ATA27 p.76)
M.WHEEL_MAX = 90
M.TRIM_WHEEL = 47

-- the aileron programmers (ATA27 p.59 figure, read every 5 degrees of wheel;
-- full travel at about 45 degrees, p.88): wheel degrees -> surface degrees
M.WHEEL_PTS  = {0, 5,    10,   15,  20,   25,    30,    35,    40,    45,    47}
M.INNER      = {0, 2.9,  5.65, 8.5, 11.1, 13.45, 15.65, 17.55, 19.0,  20.0,  20.0}
M.OUTER_UP   = {0, 3.8,  7.6,  11.2, 14.3, 17.2, 19.8,  22.05, 23.55, 24.65, 25.0}
M.OUTER_DOWN = {0, 2.15, 4.3,  6.5, 8.6,  10.65, 12.4,  13.7,  14.55, 15.0,  15.0}

-- the flight spoilers: pickup at about 8 to 14 degrees of wheel, then in
-- proportion (ATA27 p.206); spoilers 1-4 and 9-12 to 45 degrees, 5 and 8 to
-- 20, 6 and 7 none (p.207). Pickup at 11 and the maximum at the wheel stop:
-- estimates (the sources give no curve)
M.SPOILER_PICKUP = 11
M.LATERAL_MAX = {45, 45, 45, 45, 20, 0, 0, 20, 45, 45, 45, 45}
M.LEFT_WING = {true, true, true, true, true, true, false, false, false, false, false, false}

-- the speedbrake program (ATA27 p.165 figure, lever degrees: ARM about 3,
-- the flight detent 37, UP 80), with the lever's positions (DN, ARM, flight
-- detent, UP: 0, 0.125, 0.53, 1 as the 3D's)
M.LEVER_POS = {0, 0.125, 0.53, 1.0}
M.LEVER_DEG = {0, 3,     37,   80}
-- spoilers 3, 4, 9, 10 and 5, 8 from about 6 degrees of lever; 6 and 7 at
-- 20 degrees from 28 (the ground spoiler control valve's U1 port), 5 to 8 at
-- 45 from 49 (U1 and U2: p.188-190); 1, 2, 11, 12 from 43 to 74
M.G34_DEG  = {6.3, 7,   8,   9,   11,   12.5, 15,   17.5, 20.5, 22.5, 25,   27.5, 29,   32.5, 34,   35.5, 37}
M.G34      = {0,   2.8, 6.2, 9.0, 13.9, 16.9, 21.4, 25.4, 29.3, 31.9, 34.2, 37.0, 38.4, 41.5, 42.6, 43.7, 45}
M.G58_DEG  = {6.3, 7,   8,   9,   11,  12.5, 15,  17.5, 20.5, 22.5, 25,   27.5, 29,   32.5, 35}
M.G58      = {0,   1.1, 2.4, 3.8, 6.1, 7.7,  9.9, 11.9, 14.0, 15.2, 16.5, 17.7, 18.2, 19.5, 20}
M.G1212_DEG = {42.8, 45,  47.5, 51,  52.5, 55,   57.5, 60.5, 62.5, 65,   67.5, 69,   71,   72.5, 73.5, 74.2}
M.G1212     = {0,    1.6, 3.5,  6.6, 8.0,  10.7, 13.4, 17.1, 19.7, 23.9, 28.3, 31.2, 36.0, 40.4, 43.6, 45}
M.U1_DEG, M.U2_DEG = 28.2, 49
M.GROUP = {"g1212", "g1212", "g34", "g34", "g58", "g67", "g67", "g58", "g34", "g34", "g1212", "g1212"}

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi end
    return x
end

-- piecewise linear in (xs, ys), held at the ends
local function interp(xs, ys, x)
    if x <= xs[1] then return ys[1] end
    for i = 2, #xs do
        if x <= xs[i] then
            return ys[i - 1] + (ys[i] - ys[i - 1]) * (x - xs[i - 1]) / (xs[i] - xs[i - 1])
        end
    end
    return ys[#ys]
end
M.interp = interp

-- an inboard aileron for a wheel angle that moves it trailing edge down
-- when positive (degrees, trailing edge down positive)
function M.inner(wheel)
    if wheel >= 0 then return interp(M.WHEEL_PTS, M.INNER, wheel) end
    return -interp(M.WHEEL_PTS, M.INNER, -wheel)
end

-- an outboard aileron, up 25 and down 15
function M.outer(wheel)
    if wheel >= 0 then return interp(M.WHEEL_PTS, M.OUTER_DOWN, wheel) end
    return -interp(M.WHEEL_PTS, M.OUTER_UP, -wheel)
end

-- the speedbrake lever's angle from its position
function M.lever_deg(lever)
    return interp(M.LEVER_POS, M.LEVER_DEG, lever)
end

-- the speedbrake program for one group at a lever angle
function M.program(group, deg)
    if group == "g34" then return interp(M.G34_DEG, M.G34, deg) end
    if group == "g58" then
        if deg >= M.U2_DEG then return 45 end
        return interp(M.G58_DEG, M.G58, deg)
    end
    if group == "g67" then
        if deg >= M.U2_DEG then return 45 end
        if deg >= M.U1_DEG then return 20 end
        return 0
    end
    return interp(M.G1212_DEG, M.G1212, deg)
end

-- the flight spoilers' roll command on the wing going up, as a share of
-- their maximum (0 to 1) for the wheel's angle
function M.lateral_share(wheel)
    return clamp((math.abs(wheel) - M.SPOILER_PICKUP) / (M.WHEEL_MAX - M.SPOILER_PICKUP), 0, 1)
end

-- the twelve spoilers' commands (degrees) for the wheel (right wing down
-- positive) and the speedbrake lever: the mixers raise the spoilers of the
-- wing going up and lower those of the other from their speedbrake
-- positions (FCOM p.947, ATA27 p.150), between 0 and the panel's travel:
-- 45, or 20 for 5 and 8 until the ground spoiler valve extends their ratio
-- changers (U2, p.144, p.188)
function M.spoilers(wheel, lever, out)
    out = out or {}
    local deg = M.lever_deg(lever)
    local share = M.lateral_share(wheel)
    for n = 1, 12 do
        local sb = M.program(M.GROUP[n], deg)
        -- roll right (wheel positive) raises the right wing's spoilers
        local up = (wheel > 0) ~= M.LEFT_WING[n]
        local lat = share * M.LATERAL_MAX[n]
        if not up then lat = -lat end
        local max = 45
        if n == 5 or n == 8 then
            if deg < M.U2_DEG then max = 20 end
        elseif n == 6 or n == 7 then
            max = sb
        end
        out[n] = clamp(sb + lat, 0, max)
    end
    return out
end

return M
