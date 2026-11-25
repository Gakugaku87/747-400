-- 747-400 takeoff limits for the EFB's takeoff performance, without
-- X-Plane (2026-11-25): four charts of the 747-400F/PW4056 FPPM
-- (_ref/1059530115-74F-FPPM.pdf, D632U002-RZ043, October 29, 2010), the
-- methods of FPPM p.19-20 (1.1.1-1.1.2) and p.22 (1.1.4):
--   Takeoff Climb Limit  FPPM p.29 (1.2.5) flaps 10, p.30 (1.2.6) flaps 20:
--     second segment climb, no obstacles; 3 packs on, anti-ice on or off
--   Tire Speed Limit     FPPM p.33 (1.2.9): 235 mph tires, flaps 10, with
--     the notes for flaps 20 and wind
--   Brake Energy Limit   FPPM p.34 (1.2.10) VMBE, flaps 10 and 20, with the
--     table for slope, wind and brakes deactivated and the shaded area
--     where a normal takeoff without tailwind needs no check
-- The data part is written by docs/overhaul/tools/fppm_takeoff_limits.lua
-- from the PDF's vector drawings (each axis from its ticks and numbers,
-- every curve as drawn); the functions below it are by hand. Between
-- curves linear in altitude (and VMBE in weight and OAT), as the chart is
-- read; along a curve linear between its points.
--
-- Units: kg, deg C, ft (pressure altitude), kt; wind + headwind, - tailwind;
-- slope % + uphill. A result comes as value[, note]: note (a string) when
-- the chart only bounds the value or the point is outside its normal use;
-- nil, reason outside the chart.
--
--   local M = B747_efb_limits_model
--   M.climb_limit(flaps, oat_c, pa_ft)              -> kg [, note]
--   M.climb_oat_limits(flaps, pa_ft)                -> env_oat_c, atl_oat_c
--   M.climb_bleed_adjust_kg(flaps, packs, engine_ai, wing_ai, apu_pack) -> kg
--   M.tire_limit(flaps, oat_c, pa_ft, wind_kt)      -> kg [, note]
--   M.vmbe(weight_kg, oat_c, pa_ft, slope_pct, wind_kt[, brakes_deact]) -> kt [, note]
--   M.vmbe_check_needed(weight_kg, pa_ft)           -> boolean
--   M.vmbe_shaded_max_kg(pa_ft)                     -> kg
--   M.vmbe_weight_per_kt(improved_climb)            -> kg a knot V1 over VMBE
--   M.vmbe_brakes_deactivated_kt(n)                 -> kt to take off VMBE
--
-- Estimates (the charts do not say):
--   - a curve is extended along its end segment where the reading needs
--     it just past its end: the climb charts' higher altitude curve between
--     its own ASSUMED TEMPERATURE LIMIT end and the one interpolated for
--     the altitude (at most 2 C); the tire chart's curves above the chart's
--     top (460 t) when the other curve is inside it; the tire chart's
--     10,000 ft curve below its bottom (280 t) up to 52.75 C at 9,500 ft;
--     the VMBE chart's light weight lines above 210 kt when the heavier one
--     is under it, and its OAT lines right of their end (cold and low).
--   - the tire chart's 10,000 ft curve leaves through the chart's bottom
--     at 50.5 C: taken as that altitude's last OAT.
--   - the climb notes give 0, 1 and 3 packs: 2 packs takes the chart's 3
--     packs basis (no increase).
--   - the VMBE chart's lines stop at one grid line (cold and low airports,
--     heavy airplanes): right of it VMBE is read at it, a lower bound
--     (note); below 240 t the 240 t line, a lower bound (note); above
--     210 kt 210 kt, a lower bound (note).
-- Not estimates: below 0 C the climb charts' 0 C ("0 AND BELOW"); one brake
-- deactivated takes the chart's two brakes value (FPPM p.22 (1.1.4): "For
-- one or two brakes deactivated, reduce VMBE by the amount shown on the
-- brake energy limit chart").

local M = setmetatable({}, {})
B747_efb_limits_model = M

-- BEGIN GENERATED DATA (docs/overhaul/tools/fppm_takeoff_limits.lua from
-- _ref/1059530115-74F-FPPM.pdf's vector drawings; do not edit by hand)

-- Takeoff Climb Limit, FPPM p.29 (1.2.5) flaps 10, p.30 (1.2.6) flaps 20:
-- 3 packs on, anti-ice on or off. A curve an airport pressure altitude
-- (alt, 1000 ft): {OAT C, weight 1000 kg, ...} with the OAT rising from
-- the chart's 0 C ("0 AND BELOW"); its last point is on the ASSUMED
-- TEMPERATURE LIMIT line. env: the OAT where the curve crosses the
-- ENVIRONMENTAL LIMIT line. notes: the kg to add for the bleed
-- configurations under the chart.
M.CLIMB = {
    [10] = {                                     -- FPPM p.29 (1.2.5)
        alt = {-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
        curve = {
            -- -2000 ft
            {0,462.5, 18.96,462.5, 39.26,461.7, 41.74,450.5, 47.3,423.5, 52.85,395.1, 58.42,369,
             63.97,340.7, 69.52,313.1, 75.06,287.5},
            -- -1000 ft
            {0,455.3, 16.98,455.2, 31.98,454.6, 37.28,454.9, 39.76,444.4, 45.31,418.8, 50.87,391.6,
             56.43,366.6, 67.54,312, 73.08,287},
            -- 0 ft
            {0,455.3, 15,455.2, 30,454.7, 33.3,454.6, 37.78,437.1, 43.33,413.3, 48.89,387.5,
             54.45,363.3, 60,336.6, 65.56,310.3, 71.1,285.5},
            -- 1000 ft
            {0,446, 13.02,445.9, 31.32,445.4, 35.8,429, 41.35,406.7, 46.91,383.5, 52.47,359.6,
             58.02,333.7, 63.58,308.3, 69.12,283.8},
            -- 2000 ft
            {0,436.4, 11.04,436.4, 26.04,435.8, 29.34,435.8, 33.82,421, 44.93,379.7, 50.49,355.8,
             56.04,330.7, 61.6,306.2, 67.14,282},
            -- 3000 ft
            {0,426.6, 9.06,426.5, 24.06,426, 27.35,426, 31.83,412.1, 37.39,393.3, 42.95,374.8,
             48.51,351.4, 54.06,327, 65.16,279.8},
            -- 4000 ft
            {0,416.6, 7.08,416.5, 25.37,416, 29.85,402.9, 35.41,386.2, 40.97,368.7, 46.53,346.7,
             52.08,323, 63.17,277.3},
            -- 5000 ft
            {0,406.2, 5.1,406.2, 23.39,405.6, 27.87,394, 33.43,379.5, 38.99,362.4, 44.55,342, 50.1,319,
             61.19,274.8},
            -- 6000 ft
            {0,399.4, 3.12,399.3, 18.11,398.8, 19.81,398.7, 25.89,385.4, 31.45,372.2, 37.01,355.2,
             42.57,335.9, 48.12,314.8, 53.68,293, 59.21,271.8},
            -- 7000 ft
            {0,389.9, 16.13,389.4, 17.41,389.5, 23.91,376.8, 29.47,363.7, 35.03,347.5, 40.59,329.8,
             46.14,310.1, 51.7,289.2, 57.23,268.6},
            -- 8000 ft
            {0,380.5, 15,380, 21.93,367.5, 27.49,354.5, 33.05,339.6, 38.61,323, 44.16,304.9,
             49.72,284.6, 55.25,264.7},
            -- 9000 ft
            {0,370.7, 12.59,370.3, 19.95,356.8, 25.51,344.7, 31.07,330.9, 36.63,315.5, 42.18,298.6,
             47.74,279.8, 53.27,260.2},
            -- 10000 ft
            {0,360.2, 10.19,359.8, 17.97,346.4, 23.53,335.5, 29.08,322.5, 34.65,308.2, 40.2,292.3,
             45.75,275, 51.29,255.7},
        },
        env = {54.4, 54.4, 54.4, 52.4, 50.4, 48.5, 46.5, 44.5, 42.5, 40.5, 38.5, 36.6, 34.6},
        notes = {packs_off = 4200, one_pack = 3000, apu_one_pack = 3800},
    },
    [20] = {                                     -- FPPM p.30 (1.2.6)
        alt = {-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
        curve = {
            -- -2000 ft
            {0,445.9, 18.96,445.8, 37.47,445.1, 39.28,444.9, 41.74,433.8, 52.85,381.1, 58.41,355.2,
             63.95,328, 69.52,301.3, 75.06,276.2},
            -- -1000 ft
            {0,438.9, 15,438.9, 30,438.1, 37.29,438, 39.76,427.6, 50.87,378.2, 56.43,352.7,
             67.53,300.3, 73.08,275.7},
            -- 0 ft
            {0,438.1, 15,438, 32.19,437.4, 33.33,437.3, 37.78,420.7, 48.89,374.9, 59.99,324,
             65.55,298.8, 71.1,274.4},
            -- 1000 ft
            {0,429.1, 13.14,429, 30.21,428.5, 31.35,428.3, 35.8,412.8, 46.91,370.7, 52.47,345.7,
             58.01,321.1, 69.12,272.9},
            -- 2000 ft
            {0,419.6, 11.04,419.6, 28.23,419.1, 29.36,419, 34.15,403.9, 39.37,386.1, 44.93,366.2,
             50.49,341.9, 56.03,318.2, 67.14,271.3},
            -- 3000 ft
            {0,410.2, 9.06,410.1, 27.38,409.5, 31.83,396.7, 37.39,379.9, 42.95,360.6, 48.51,337.8,
             54.27,313.7, 59.61,291.8, 65.16,269.4},
            -- 4000 ft
            {0,400.6, 7.08,400.6, 25.37,400, 29.85,388.2, 35.41,373.3, 40.97,354.4, 46.53,333.2,
             52.07,310.7, 57.63,288.7, 63.17,267.2},
            -- 5000 ft
            {0,390.9, 5.1,390.9, 23.39,390.4, 27.87,380.2, 33.43,365.9, 38.99,348, 44.55,328.4,
             50.31,306, 55.65,285.6, 61.19,264.6},
            -- 6000 ft
            {0,384.8, 8.14,384.6, 18.11,384.3, 19.81,384.2, 25.89,372.1, 31.45,357.8, 37.01,341.2,
             42.57,322.8, 48.11,302.7, 53.67,281.9, 59.21,261.5},
            -- 7000 ft
            {0,376.2, 16.13,375.8, 17.41,375.9, 23.91,362.6, 29.47,349, 35.03,333.9, 40.59,316.8,
             46.13,298.1, 51.69,278.3, 57.23,258.2},
            -- 8000 ft
            {0,366.7, 15,366.1, 21.93,352.7, 27.49,340.2, 33.05,326.3, 38.61,310.4, 44.15,293,
             49.71,273.8, 55.25,254.3},
            -- 9000 ft
            {0,356.2, 12.6,355.7, 19.95,342.4, 25.51,331, 26.43,328.8, 31.07,317.9, 36.63,303.3,
             42.17,287, 47.73,269.1, 53.27,250.2},
            -- 10000 ft
            {0,345.7, 10.19,345.3, 17.97,332.5, 23.53,322.1, 29.09,309.8, 34.65,296.3, 40.19,281.1,
             45.74,264.3, 51.29,246.1},
        },
        env = {54.4, 54.4, 54.4, 52.4, 50.4, 48.5, 46.5, 44.5, 42.5, 40.5, 38.5, 36.6, 34.6},
        notes = {packs_off = 4500, one_pack = 3000, apu_one_pack = 4100},
    },
}

-- Tire Speed Limit, FPPM p.33 (1.2.9): 235 mph tires, flaps 10. A curve an
-- airport pressure altitude: {OAT C, tire limit weight 1000 kg, ...}, OAT
-- rising; the curves leave the chart at its top (top, 1000 kg) and end
-- at the right at the highest OAT drawn. notes: kg to add for flaps 20,
-- kg a knot headwind (added) and tailwind (taken off).
M.TIRE = {
    alt = {-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
    curve = {
        -- -2000 ft
        {44.5,460, 60,435, 70,420.5},
        -- -1000 ft
        {34,460, 40,451, 60,420, 70,405.5},
        -- 0 ft
        {22.5,460, 34,446, 66,396.5, 67,387, 70,382.5},
        -- 1000 ft
        {10.5,460, 31,433, 56,396, 57,386.5, 70,367},
        -- 2000 ft
        {-1,460, 10,445, 29,421, 46,396, 47,386.5, 60,367, 68,356},
        -- 3000 ft
        {-12,460, 0,442.9, 10,429, 20,416.5, 27.5,407.5, 36,396, 36.5,387, 50,366.5, 66,345.5},
        -- 4000 ft
        {-23,460, -10,441, 0,427, 10,413.5, 25,396, 26,386.5, 40,366, 64,335},
        -- 5000 ft
        {-33.5,460, -20,439, 0,411.5, 12.5,396, 13,387, 23,375, 30,365, 62,325},
        -- 6000 ft
        {-43,460, -20,423.5, 1,396, 2,387, 30,352, 60.5,315},
        -- 7000 ft
        {-50,455, -30,422.5, -11,396, -9,387, 7,365, 20,350.5, 59,305},
        -- 8000 ft
        {-50,438.5, -40,422.5, -22,396, -21,387, -3.5,364.5, 20,337.9, 57.5,295},
        -- 9000 ft
        {-50,422.5, -40,407, -32.5,396, -32,387, -14.9,362.9, 10,336, 55,286},
        -- 10000 ft
        {-50,406.5, -43,397, -42,386.5, -30,368.2, -20,355.5, -10,344.2, 10,323.2, 50.5,280},
    },
    oat_min = -50, oat_max = 70, bottom = 280, top = 460,
    notes = {flaps20 = 19000, head = 2200, tail = 3900},
}

-- Brake Energy Limit VMBE, FPPM p.34 (1.2.10), flaps 10 and 20. shaded:
-- the shaded area (no check for a normal takeoff without tailwind),
-- {brake release weight 1000 kg, pressure altitude 1000 ft, ...}. The
-- right part has no scale across: ref counts its grid columns from its
-- left edge. oat_line: an OAT's line (upper right), {pressure altitude
-- 1000 ft, ref, ...} with the altitude rising; wt_line: a brake release
-- weight's line (lower right), {ref, VMBE KIAS, ...} with ref rising.
-- ref_max: the grid line where the lines stop; vmin, vmax: the VMBE
-- scale. notes: kt a 1 % slope up (added) and down (taken off); kt for
-- head_per kt headwind (added) and tail_per kt tailwind (taken off); kt
-- for two brakes deactivated; kg of brake release weight (normal) and of
-- climb weight improvement (improved climb) a knot V1 exceeds VMBE.
M.VMBE = {
    shaded =
        {300,-2, 379.2,-2, 364.6,1, 347.4,4.6, 329.1,8.2, 320.8,10, 300,10},
    oat = {-50, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50, 60},
    oat_line = {
        -- -50 C
        {7.81,6.999, 10,6.017},
        -- -40 C
        {6.6,7.002, 8,6.373, 10,5.518},
        -- -30 C
        {5.48,7.002, 6,6.759, 8,5.883, 10,5.045},
        -- -20 C
        {4.35,7.005, 6,6.252, 7,5.82, 9,4.99, 10,4.59},
        -- -10 C
        {3.2,7.005, 6,5.776, 8,4.946, 10,4.156},
        -- 0 C
        {2.11,7.002, 4,6.167, 6,5.308, 8,4.503, 10,3.742},
        -- 10 C
        {1,6.999, 3,6.118, 6,4.878, 8,4.1, 10,3.353},
        -- 20 C
        {-0.08,6.999, 1,6.526, 3,5.677, 6,4.467, 9,3.394, 10,3.049},
        -- 30 C
        {-1.11,6.994, 0,6.499, 1,6.075, 2,5.669, 3,5.289, 6,4.178, 8,3.465, 10,2.776},
        -- 40 C
        {-2,6.986, -1,6.578, 1,5.787, 4,4.651, 7,3.567, 10,2.535},
        -- 50 C
        {-2,6.759, 0,5.951, 3,4.802, 6,3.704, 8,3.003, 10,2.327},
        -- 60 C
        {-2,6.556, -1,6.149, 1,5.362, 2,4.977, 4,4.23, 7,3.154, 10,2.135},
    },
    wt = {240, 260, 280, 300, 320, 340, 360, 380, 400},
    wt_line = {
        -- 240 t
        {1.801,187.3, 3,202.3, 3.599,210},
        -- 260 t
        {1.801,178.4, 3.2,194.8, 4.467,210},
        -- 280 t
        {1.801,170.7, 3.701,191.7, 5.327,210},
        -- 300 t
        {1.801,164, 3.301,179.7, 6.162,209.9},
        -- 320 t
        {1.801,157.9, 6.999,210},
        -- 340 t
        {1.801,152.6, 4.399,177.4, 6.999,202},
        -- 360 t
        {1.801,147.8, 3.098,159.8, 4.599,173.4, 6.999,194.9},
        -- 380 t
        {1.801,143.3, 3.098,154.9, 4.599,168, 5.699,177.6, 6.999,188.6},
        -- 400 t
        {1.897,140, 3.098,150.4, 4.399,161.5, 5.499,170.7, 7,183},
    },
    ref_max = 6.999, vmin = 140, vmax = 210,
    notes = {up = 4, down = 8, head = 3, head_per = 10, tail = 29, tail_per = 10, brakes2 = 24,
        per_kt = 1500, per_kt_ic = 500},
}
-- END GENERATED DATA

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
-- y at x on a flat list {x1, y1, x2, y2, ...} with x rising; the end
-- segments' lines beyond the ends
local function at(c, x)
    local n = #c
    local i = 1
    if x >= c[n - 1] then
        i = n - 3
    else
        while i < n - 3 and c[i + 2] < x do i = i + 2 end
    end
    local x0, y0, x1, y1 = c[i], c[i + 1], c[i + 2], c[i + 3]
    if x1 == x0 then return y1 end
    return y0 + (x - x0) / (x1 - x0) * (y1 - y0)
end

-- the segment of a rising list holding v (inside it): index, fraction
local function bracket(list, v)
    local n = #list
    for i = 1, n - 2 do
        if v <= list[i + 1] then return i, (v - list[i]) / (list[i + 1] - list[i]) end
    end
    return n - 1, (v - list[n - 1]) / (list[n] - list[n - 1])
end

local function last_x(c) return c[#c - 1] end

local function is_num(v) return type(v) == "number" and v == v end

local EPS = 1e-9

------------------------------------------------------------------------
-- Takeoff Climb Limit (FPPM p.29 (1.2.5), p.30 (1.2.6))
------------------------------------------------------------------------
-- The chart at the airport's pressure altitude: the two altitude curves
-- around it and the fraction between them, or nil, reason
local function climb_curves(flaps, pa_ft)
    local ch = M.CLIMB[flaps]
    if not ch then return nil, "climb limit: flaps 10 or 20 only" end
    if not is_num(pa_ft) then return nil, "climb limit: no pressure altitude" end
    local a = pa_ft / 1000
    if a < ch.alt[1] - EPS or a > ch.alt[#ch.alt] + EPS then
        return nil, "climb limit: pressure altitude outside the chart (-2,000 to 10,000 ft)"
    end
    local i, f = bracket(ch.alt, a)
    return ch, i, f
end

-- The OATs that bound the chart at the airport's pressure altitude: the
-- ENVIRONMENTAL LIMIT (the highest airport OAT) and the ASSUMED
-- TEMPERATURE LIMIT (the curves' ends).
function M.climb_oat_limits(flaps, pa_ft)
    local ch, i, f = climb_curves(flaps, pa_ft)
    if not ch then return nil, i end
    local env = ch.env[i] + f * (ch.env[i + 1] - ch.env[i])
    local a1, a2 = last_x(ch.curve[i]), last_x(ch.curve[i + 1])
    return env, a1 + f * (a2 - a1)
end

-- Climb limit brake release weight (kg) for 3 packs on, anti-ice on or
-- off (the charts' basis; add M.climb_bleed_adjust_kg for others): up from
-- the OAT to the pressure altitude, read left (FPPM p.19 (1.1.1)). Below
-- 0 C the 0 C value ("0 AND BELOW"). Right of the ENVIRONMENTAL LIMIT
-- (an assumed temperature only) the weight with a note; right of the
-- ASSUMED TEMPERATURE LIMIT nil.
function M.climb_limit(flaps, oat_c, pa_ft)
    local ch, i, f = climb_curves(flaps, pa_ft)
    if not ch then return nil, i end
    if not is_num(oat_c) then return nil, "climb limit: no OAT" end
    local t = oat_c > 0 and oat_c or 0
    local env, atl = M.climb_oat_limits(flaps, pa_ft)
    if t > atl + EPS then return nil, "climb limit: OAT right of the assumed temperature limit" end
    local c1, c2 = ch.curve[i], ch.curve[i + 1]
    local w1 = at(c1, t)
    local w = w1 + f * (at(c2, t) - w1)
    if t > env + EPS then
        return w * 1000, "right of the environmental limit: for an assumed temperature only"
    end
    return w * 1000
end

-- The notes under the climb charts (FPPM p.29, p.30), kg to add to the
-- climb limit weight: packs = the packs on engine bleed (0, 1, 2 or 3;
-- 2 an estimate: no increase, the 3 packs basis); apu_pack = engine bleed
-- off and the APU supplying 1 pack (packs then unused). engine_ai and
-- wing_ai change nothing: the charts are "based on engine bleed for 3
-- packs on and anti-ice on or off".
function M.climb_bleed_adjust_kg(flaps, packs, engine_ai, wing_ai, apu_pack)
    local ch = M.CLIMB[flaps]
    if not ch then return nil, "climb limit: flaps 10 or 20 only" end
    local n = ch.notes
    if apu_pack then return n.apu_one_pack end
    if packs == 0 then return n.packs_off end
    if packs == 1 then return n.one_pack end
    if packs == 2 or packs == 3 then return 0 end
    return nil, "climb limit: packs 0 to 3"
end

------------------------------------------------------------------------
-- Tire Speed Limit (FPPM p.33 (1.2.9))
------------------------------------------------------------------------
-- Tire speed limit brake release weight (kg), 235 mph tires: up from the
-- OAT to the pressure altitude, read left the flaps 10 weight (FPPM p.19,
-- p.20 (1.1.1-1.1.2)), then the notes: flaps 20 more, per knot of
-- headwind more, per knot of tailwind less. Above the chart's top (460 t
-- before the notes) the top with a note: the limit is at least that.
-- nil left of the chart (-50 C), right of a curve's end, under its bottom.
function M.tire_limit(flaps, oat_c, pa_ft, wind_kt)
    if flaps ~= 10 and flaps ~= 20 then return nil, "tire limit: flaps 10 or 20 only" end
    if not is_num(oat_c) or not is_num(pa_ft) then return nil, "tire limit: no OAT or pressure altitude" end
    wind_kt = is_num(wind_kt) and wind_kt or 0
    local tr = M.TIRE
    local a = pa_ft / 1000
    if a < tr.alt[1] - EPS or a > tr.alt[#tr.alt] + EPS then
        return nil, "tire limit: pressure altitude outside the chart (-2,000 to 10,000 ft)"
    end
    if oat_c < tr.oat_min - EPS then return nil, "tire limit: OAT left of the chart (-50 C)" end
    local i, f = bracket(tr.alt, a)
    local c1, c2 = tr.curve[i], tr.curve[i + 1]
    local tmax = last_x(c1) + f * (last_x(c2) - last_x(c1))
    if oat_c > tmax + EPS then return nil, "tire limit: OAT right of the curves' ends" end
    local w1 = at(c1, oat_c)
    local w = w1 + f * (at(c2, oat_c) - w1)
    local note
    if w > tr.top then
        w, note = tr.top, "above the chart: the tire speed limit is at least this"
    elseif w < tr.bottom - EPS then
        return nil, "tire limit: under the chart (280,000 kg)"
    end
    local kg = w * 1000
    if flaps == 20 then kg = kg + tr.notes.flaps20 end
    if wind_kt > 0 then
        kg = kg + tr.notes.head * wind_kt
    else
        kg = kg + tr.notes.tail * wind_kt
    end
    return kg, note
end

------------------------------------------------------------------------
-- Brake Energy Limit VMBE (FPPM p.34 (1.2.10))
------------------------------------------------------------------------
-- The heaviest brake release weight (kg) inside the shaded area at the
-- pressure altitude, or nil outside the chart's altitudes.
function M.vmbe_shaded_max_kg(pa_ft)
    if not is_num(pa_ft) then return nil end
    local a = pa_ft / 1000
    local s = M.VMBE.shaded
    local best
    for k = 1, #s - 1, 2 do
        local x1, y1 = s[k], s[k + 1]
        local x2, y2 = s[k + 2] or s[1], s[k + 3] or s[2]
        if y1 ~= y2 and (y1 - a) * (y2 - a) <= 0 then
            local x = x1 + (a - y1) / (y2 - y1) * (x2 - x1)
            if not best or x > best then best = x end
        end
    end
    return best and best * 1000
end

-- false inside the shaded area (a normal takeoff without tailwind needs
-- no VMBE check: FPPM p.20 (1.1.2)), true outside it or outside the
-- chart's altitudes. Always check with a tailwind or improved climb.
function M.vmbe_check_needed(weight_kg, pa_ft)
    local m = M.vmbe_shaded_max_kg(pa_ft)
    if not m or not is_num(weight_kg) then return true end
    return weight_kg > m + EPS
end

-- The kt to take off VMBE for n brakes deactivated: the chart's value for
-- two brakes, also for one (FPPM p.22 (1.1.4)); nil for more than two.
function M.vmbe_brakes_deactivated_kt(n)
    n = n or 0
    if n == 0 then return 0 end
    if n == 1 or n == 2 then return M.VMBE.notes.brakes2 end
    return nil, "VMBE: one or two brakes deactivated only"
end

-- The weight (kg) to take off for each knot V1 exceeds VMBE: the brake
-- release weight for a normal takeoff, the climb weight improvement for an
-- improved climb takeoff (FPPM p.34's notes); then V1, VR, V2 again for
-- the lower weight.
function M.vmbe_weight_per_kt(improved_climb)
    local n = M.VMBE.notes
    return improved_climb and n.per_kt_ic or n.per_kt
end

-- The right part's reference (grid column) at the pressure altitude (1000
-- ft) and the OAT, linear between the OAT lines
local function vmbe_ref(a, oat_c)
    local v = M.VMBE
    local j, g = bracket(v.oat, oat_c)
    local r1 = at(v.oat_line[j], a)
    return r1 + g * (at(v.oat_line[j + 1], a) - r1)
end

-- VMBE (KIAS): right at the pressure altitude to the OAT, down to the
-- brake release weight, read right (FPPM p.20 (1.1.2)); then the table:
-- slope, wind and, with brakes_deactivated (1 or 2), the brakes. A
-- lower bound with a note right of the chart's lines (cold and low),
-- under 240 t and above 210 kt (before the table's adjustments).
function M.vmbe(weight_kg, oat_c, pa_ft, slope_pct, wind_kt, brakes_deactivated)
    local v = M.VMBE
    if not is_num(weight_kg) or not is_num(oat_c) or not is_num(pa_ft) then
        return nil, "VMBE: no weight, OAT or pressure altitude"
    end
    slope_pct = is_num(slope_pct) and slope_pct or 0
    wind_kt = is_num(wind_kt) and wind_kt or 0
    local brakes, why = M.vmbe_brakes_deactivated_kt(brakes_deactivated)
    if not brakes then return nil, why end
    local t, a = weight_kg / 1000, pa_ft / 1000
    if a < -2 - EPS or a > 10 + EPS then return nil, "VMBE: pressure altitude outside the chart (-2,000 to 10,000 ft)" end
    if oat_c < v.oat[1] - EPS or oat_c > v.oat[#v.oat] + EPS then return nil, "VMBE: OAT outside the chart (-50 to 60 C)" end
    if t > v.wt[#v.wt] + EPS then return nil, "VMBE: brake release weight above the chart (400,000 kg)" end
    local note
    local ref = vmbe_ref(a, oat_c)
    if ref > v.ref_max then
        ref, note = v.ref_max, "right of the chart's lines: VMBE at least this"
    end
    if t < v.wt[1] then
        t, note = v.wt[1], "under the chart's lightest weight: VMBE at least this"
    end
    local k, h = bracket(v.wt, t)
    local s1 = at(v.wt_line[k], ref)
    local kt = s1 + h * (at(v.wt_line[k + 1], ref) - s1)
    if kt > v.vmax then kt, note = v.vmax, "above the chart (210 kt): VMBE at least this" end
    local n = v.notes
    if slope_pct > 0 then kt = kt + n.up * slope_pct else kt = kt + n.down * slope_pct end
    if wind_kt > 0 then
        kt = kt + n.head / n.head_per * wind_kt
    else
        kt = kt + n.tail / n.tail_per * wind_kt
    end
    return kt - brakes, note
end

return M
