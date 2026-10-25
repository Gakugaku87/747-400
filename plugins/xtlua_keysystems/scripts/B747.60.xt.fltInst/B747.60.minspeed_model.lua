-- 747-400 minimum speeds (5-2 step 3b): the stick shaker speed and the stick
-- shaker of the stall warning management computers (ATA27 p.701-702), the
-- FMC's minimum and maximum maneuvering speeds (ATA34_2 p.501), the speed
-- tape's minimum speed and amber bands (FCOM p.969, p.973), AIRSPEED LOW and
-- the amber box (FCOM p.1556, p.1605). Logic and sources:
-- docs/overhaul/notes/ATA-31.md §14 and notes/FCTM.md §1.14.
--
--   local S = B747_minspeed_model             -- in XTLua, after dofile
--   local S = dofile(".../B747.60.minspeed_model.lua")   -- in the tests
--   local s = S.new()
--   local inp = S.inputs()                    -- fill it every frame
--   local out = S.update(s, inp, dt)          -- the same table every frame
--
-- The lift limit is kept as B(M) = n W / (delta M^2) in kg: the load factor
-- times the weight over the pressure ratio and the Mach number squared at
-- the stick shaker or the buffet onset (0.7 p0 S CL / g, so the wing area
-- drops out). Speeds are calibrated airspeeds in kt.

local M = setmetatable({}, {})
B747_minspeed_model = M

local A0 = 661.4786             -- kt, the speed of sound at sea level (ISA)

-- the pressure ratio at a pressure altitude (ISA)
function M.delta(alt_ft)
    if alt_ft < 36089 then return (1 - 6.8755856e-6 * alt_ft) ^ 5.2558797 end
    return 0.22336 * math.exp(-(alt_ft - 36089) / 20806.7)
end

function M.cas_to_mach(cas, d)
    local qc = (1 + 0.2 * (cas / A0) ^ 2) ^ 3.5 - 1
    return math.sqrt(5 * ((qc / d + 1) ^ (2 / 7) - 1))
end

function M.mach_to_cas(mach, d)
    local qc = d * ((1 + 0.2 * mach * mach) ^ 3.5 - 1)
    return A0 * math.sqrt(5 * ((qc + 1) ^ (2 / 7) - 1))
end

-- the tables' weights, 1,000 kg
local W_T = {200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400}
-- the FCTM's stick shaker speeds at 10,000 ft, idle thrust, forward CG, kt
-- (FCTM p.261-262, read from the charts: notes/FCTM.md §1.14); flaps 30
-- with the gear down, the others up
local SHAKER = {
    [0] = {163.5, 172.2, 180.8, 189.2, 197.3, 204.7, 212.3, 219.7, 227.0, 234.0, 240.6},
    [10] = {123.8, 129.8, 135.8, 141.8, 148.4, 153.6, 158.9, 164.1, 169.4, 174.6, 178.8},
    [20] = {118.3, 123.9, 129.6, 135.1, 141.3, 146.3, 151.3, 156.2, 160.9, 166.0, 170.1},
    [30] = {110.7, 115.6, 120.5, 125.4, 130.3, 135.1, 140.1, 145.0, 149.9, 154.8, 159.6},
}
-- and their stall speeds for flaps 20 and 30 (for the flaps 25 estimate)
local STALL = {
    [20] = {113.6, 119.1, 124.7, 130.3, 136.3, 141.2, 146.1, 150.8, 155.7, 160.6, 164.7},
    [30] = {105.2, 109.9, 114.8, 119.6, 124.4, 129.3, 134.2, 138.9, 143.8, 148.5, 153.3},
}
-- VREF25 at sea level (FCOM PI.10.2)
local VREF25 = {132, 139, 146, 152, 158, 164, 170, 176, 181, 187, 192}

-- Flaps 25 (estimate): the stall speed is VREF25 / 1.23 with VREF's 1 kt per
-- 4,000 ft at 10,000 ft (VREF30 so made is the FCTM's flaps 30 stall speed
-- within 1 kt), and the shaker the mean of flaps 20's and 30's ratios to it.
-- Flaps 1 and 5 (estimate): 0.63 and 0.87 of the way from UP's shaker speed
-- to 10's, where the old stall speed table (Laminar's) puts them.
SHAKER[25], SHAKER[1], SHAKER[5] = {}, {}, {}
for i = 1, #W_T do
    local ratio = (SHAKER[20][i] / STALL[20][i] + SHAKER[30][i] / STALL[30][i]) / 2
    SHAKER[25][i] = (VREF25[i] + 2.5) / 1.23 * ratio
    SHAKER[1][i] = SHAKER[0][i] - 0.63 * (SHAKER[0][i] - SHAKER[10][i])
    SHAKER[5][i] = SHAKER[0][i] - 0.87 * (SHAKER[0][i] - SHAKER[10][i])
end
M.SHAKER_10K = SHAKER

-- the trailing edge flap angles of the detents
M.DETENTS = {0, 1, 5, 10, 20, 25, 30}
-- the buffet onset at the long range cruise Mach: the FCOM's maximum
-- operating altitudes for 1.25-1.50 g at LRC (PI.11.1, with PI.11.2's
-- Mach) all give n W / (delta M^2) = 2.608e6 kg within 1 % at M 0.86
M.BUFFET_MACH, M.BUFFET_B = 0.86, 2.608e6
-- above it, the high speed buffet: down to 0.8 of that at M 0.92 (estimate:
-- the maximum maneuvering band then shows only near the 1.3 g ceiling, "at
-- high altitude at relatively high gross weights", FCOM p.969)
M.HSB_MACH, M.HSB_RATIO = 0.92, 0.80

-- each detent's B as a straight line in Mach, fitted to its shaker speeds at
-- 10,000 ft (the chart's speeds come back within 0.6 kt, flaps 30 within
-- 1 kt); the line outside the chart's Mach (other weights and altitudes) is
-- an estimate
local D10 = M.delta(10000)
local LINES = {}                -- [deg] = {a, b, highest chart Mach}: B = a + b M
for _, deg in ipairs(M.DETENTS) do
    local n, sx, sy, sxx, sxy, top = #W_T, 0, 0, 0, 0, 0
    for i, w in ipairs(W_T) do
        local m = M.cas_to_mach(SHAKER[deg][i], D10)
        local b = w * 1000 / (D10 * m * m)
        sx, sy, sxx, sxy = sx + m, sy + b, sxx + m * m, sxy + m * b
        top = math.max(top, m)
    end
    local slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    LINES[deg] = {(sy - slope * sx) / n, slope, top}
end

-- one detent's B at a Mach; flaps up, from the chart's highest Mach straight
-- to the buffet onset at M 0.86, then the high speed buffet (estimate)
local function detent_b(deg, m)
    local l = LINES[deg]
    if deg == 0 and m > l[3] then
        if m <= M.BUFFET_MACH then
            local b3 = l[1] + l[2] * l[3]
            return b3 + (M.BUFFET_B - b3) * (m - l[3]) / (M.BUFFET_MACH - l[3])
        end
        local x = (m - M.BUFFET_MACH) / (M.HSB_MACH - M.BUFFET_MACH)
        return M.BUFFET_B * math.max(0.05, 1 - (1 - M.HSB_RATIO) * x * x)
    end
    return math.max(0.2 * l[1], l[1] + l[2] * m)
end

-- B at a trailing edge flap angle (between the detents by the angle: estimate)
function M.boundary(flap_deg, m)
    local d = M.DETENTS
    if flap_deg <= d[1] then return detent_b(d[1], m) end
    for i = 2, #d do
        if flap_deg <= d[i] then
            local f = (flap_deg - d[i - 1]) / (d[i] - d[i - 1])
            local lo, hi = detent_b(d[i - 1], m), detent_b(d[i], m)
            return lo + (hi - lo) * f
        end
    end
    return detent_b(d[#d], m)
end

-- flaps up, the Mach where M^2 B(M) is largest: the most lift at any speed
-- (above it the high speed buffet takes it away)
M.PEAK_MACH = M.BUFFET_MACH
do
    local best = M.BUFFET_MACH ^ 2 * M.boundary(0, M.BUFFET_MACH)
    for m = M.BUFFET_MACH, 0.98, 0.001 do
        local v = m * m * M.boundary(0, m)
        if v > best then M.PEAK_MACH, best = m, v end
    end
end

-- the Mach on the low speed side where the lift limit is reached: M^2 B(M)
-- equals req (n W / delta); at most the peak's Mach (flaps up) or the buffet
-- onset Mach
local function low_mach(req, flap_deg)
    local lo, hi = 0.05, flap_deg <= 0 and M.PEAK_MACH or M.BUFFET_MACH
    if hi * hi * M.boundary(flap_deg, hi) <= req then return hi end
    if lo * lo * M.boundary(flap_deg, lo) >= req then return lo end
    for _ = 1, 22 do
        local mid = 0.5 * (lo + hi)
        if mid * mid * M.boundary(flap_deg, mid) < req then lo = mid else hi = mid end
    end
    return 0.5 * (lo + hi)
end
M.low_mach = low_mach

-- flaps up: the Mach above the peak where M^2 B(M) falls to req; the peak's
-- Mach when req is above the peak (no such margin at any speed: the two
-- bands meet); nil when it stays above req up to M 0.98
local function high_mach(req)
    local lo = M.PEAK_MACH
    if lo * lo * M.boundary(0, lo) <= req then return lo end
    local hi = 0.98
    if hi * hi * M.boundary(0, hi) > req then return nil end
    for _ = 1, 22 do
        local mid = 0.5 * (lo + hi)
        if mid * mid * M.boundary(0, mid) > req then lo = mid else hi = mid end
    end
    return 0.5 * (lo + hi)
end
M.high_mach = high_mach

function M.inputs()
    return {
        weight_kg = 0,
        alt_ft = 0,             -- pressure altitude
        mach = 0,               -- the captain's air data
        cas = 0,                -- kt
        nz = 1,                 -- the normal load factor
        flap_deg = 0,           -- the trailing edge flap angle
        vref30 = 0,             -- kt
        vmax = 0,               -- kt, the maximum speed (Vmo/Mmo, gear, flaps)
        ra_ft = 0,
        air = false,            -- the PSEU's air mode
        air_data = true,        -- mach and cas valid
        show_mins = false,      -- the minimum maneuvering speed band shown (the speed tape model)
    }
end

function M.new()
    return {
        nz_disp = 1,            -- the load factor for the displayed speed
        nz_trip = 1,            -- the load factor for the stick shaker
        shaker = false,
        out = {
            vss = 0,            -- the minimum speed: stick shaker or low speed buffet
            vmin_man = 0,       -- the minimum maneuvering speed
            vmax_man = 0,       -- the maximum maneuvering speed (vmax when not shown)
            show_vmax_man = false,
            shaker = false,
            airspeed_low = false,   -- AIRSPEED LOW and the amber box
        },
    }
end

function M.update(s, inp, dt)
    local out = s.out
    local d = M.delta(inp.alt_ft)
    local w = inp.weight_kg
    -- the load factor: the speed tape's smoothed over about 3 s (this A/P
    -- swings about 0.1 g holding altitude), the shaker's over 0.2 s
    -- (estimate)
    local nz = math.max(0.5, math.min(2.5, inp.nz))
    s.nz_disp = s.nz_disp + (nz - s.nz_disp) * math.min(1, dt / 3.0)
    s.nz_trip = s.nz_trip + (nz - s.nz_trip) * math.min(1, dt / 0.2)

    -- the minimum speed: the stick shaker or low speed buffet for the load
    -- factor (FCOM p.973); the SWMC computes the shaker speed (ATA27 p.702)
    out.vss = M.mach_to_cas(low_mach(s.nz_disp * w / d, inp.flap_deg), d)
    -- the minimum maneuvering speed (FCOM p.973): 1.3 g to the stick shaker
    -- with flaps down; flaps up below 20,200 ft that or VREF+80 (VREF30:
    -- FCOM PI.10.3), whichever is less; above, 1.3 g to low speed buffet
    local vmm = M.mach_to_cas(low_mach(1.3 * w / d, inp.flap_deg), d)
    local flaps_up = inp.flap_deg < 0.5
    if flaps_up and inp.alt_ft < 20200 then vmm = math.min(vmm, inp.vref30 + 80) end
    out.vmin_man = vmm
    -- the maximum maneuvering speed: 1.3 g to high speed buffet, shown when
    -- below the maximum speed (FCOM p.969)
    local mh = flaps_up and high_mach(1.3 * w / d) or nil
    local vmx = mh and M.mach_to_cas(mh, d) or nil
    out.show_vmax_man = vmx ~= nil and vmx < inp.vmax
    out.vmax_man = out.show_vmax_man and vmx or inp.vmax

    -- the stick shaker: the lift needed is above the limit at the present
    -- Mach (the SWMC compares the angle of attack with its limit: ATA27
    -- p.701); 2 % hysteresis (estimate). Without valid air data none
    local m = math.max(0.05, inp.mach)
    local need = s.nz_trip * w / d
    local limit = m * m * M.boundary(inp.flap_deg, m)
    if not inp.air or not inp.air_data then
        s.shaker = false
    elseif s.shaker then
        s.shaker = need > limit * 0.98
    else
        s.shaker = need > limit
    end
    out.shaker = s.shaker

    -- AIRSPEED LOW and the amber box: below the minimum maneuvering speed
    -- (FCOM p.1556, p.1605); only with its band shown (from the first flap
    -- retraction after takeoff) and above 100 ft RA (estimate)
    out.airspeed_low = inp.air and inp.air_data and inp.show_mins and inp.ra_ft > 100 and inp.cas < vmm
    return out
end

return M
