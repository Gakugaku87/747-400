-- 747-400 FMC cruise page's step climb without X-Plane (6-1/6-2 step 8b2;
-- docs/overhaul/notes/ATA-34-61-FMC.md §46): the STEP TO altitude by the
-- step size and the weight of the optimum step point.
--
--   local C = B747_crz_model                  -- in XTLua, after dofile
--   local C = dofile(".../B747.68.crz_model.lua")   -- in the tests
--   local ft = C.step_to(crz_ft, opt_ft, "ICAO", C.east(crz_ft_before_takeoff))

local M = setmetatable({}, {})
B747_crz_model = M

M.CEILING = 45000           -- the highest STEP TO (the maximum certified altitude 45,100 ft: FCOM p.1311)

-- ICAO's cruising levels by direction before RVSM, which the FMC's ICAO step
-- size uses (FCOM p.1349: FL280 before takeoff, OPT FL337, STEP TO FL350;
-- FMSPG p.133: FL310, OPT FL311, FL350; FCTM p.4.8: the FMC's steps may not
-- suit RVSM airspace): below FL290 the odd thousands east, the even west;
-- from FL290 every 4,000 ft, FL290 up east and FL310 up west
local function level_east(k)
    if k < 29 then return k % 2 == 1 end
    if (k - 29) % 4 == 0 then return true end
    if (k - 31) % 4 == 0 then return false end
    return nil
end

-- whether a cruise altitude (ft) is an eastbound one: its thousand's level;
-- an even thousand from FL300 (RVSM's levels) west (an estimate)
function M.east(ft)
    local e = level_east(math.floor(ft / 1000 + 0.5))
    if e == nil then return false end
    return e
end

-- the STEP TO altitude (ft) from the cruise altitude, the optimum altitude
-- and the step size ("ICAO" or 0 to 9000 ft): the next level above OPT in
-- the direction (ICAO), or CRZ ALT plus the size's steps, the first above
-- OPT (FCOM p.1349); nil without a step climb (size 0, not above CRZ ALT,
-- above the ceiling)
function M.step_to(crz_ft, opt_ft, size, east)
    local to
    if size == "ICAO" then
        for k = 1, 60 do
            if k * 1000 > opt_ft and level_east(k) == east then to = k * 1000 break end
        end
    else
        size = tonumber(size) or 0
        if size <= 0 then return nil end
        to = crz_ft + size
        while to <= opt_ft do to = to + size end
    end
    if to == nil or to <= crz_ft or to > M.CEILING then return nil end
    return to
end

-- the weight (kg) at which a step from CRZ ALT to STEP TO is best: where the
-- optimum altitude is halfway (FCOM p.1257), by bisection between lo and hi
-- kg with opt(kg) the optimum altitude (ft; lower when heavier)
function M.step_weight(crz_ft, to_ft, opt, lo, hi)
    local mid = (crz_ft + to_ft) / 2
    if opt(hi) >= mid then return hi end
    if opt(lo) < mid then return lo end
    for _ = 1, 40 do
        local m = (lo + hi) / 2
        if opt(m) >= mid then lo = m else hi = m end
    end
    return lo
end

return M
