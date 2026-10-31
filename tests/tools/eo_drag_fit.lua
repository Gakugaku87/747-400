-- Run from the repository root with LuaJIT:
--   luajit tests/tools/eo_drag_fit.lua
-- The engine-out drag (6-1/6-2 step 9h2, docs/overhaul/notes/
-- ATA-34-61-FMC.md §78): the inoperative engines' windmilling and trim drag
-- as a drag coefficient's increment DCD, so that the cruise model's fuel
-- flow (B747.68.perf_db.lua: the polar's drag plus DCD q S over the
-- operating engines, thrust_ff) matches the FCOM's engine-out Long Range
-- Cruise Control tables' fuel flow per engine (PI.13.4, 14.4, 23.5, 24.3)
-- on the mean; searched in steps of 0.00001. Prints each table's DCD and
-- the fuel flow ratio's spread: the model alone, made for all engines,
-- runs about 5-9 % high at 10,000 ft and up to 10 % low near the ceilings
-- with engines out, so perf_db anchors the engine-out fuel flow and thrust
-- setting to the tables (eo_cruise_ff, eo_level_setting).
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

-- the model's fuel flow over the table's at every cell, with a DCD
local function ratios(t, n, dcd)
    local e = t.EO[n]
    local out = {}
    for _, w in ipairs(e.LRC_W) do
        for _, a in ipairs(e.LRC_ALT) do
            local c = e.LRC[w][a]
            if c then
                local kg, ft, m = w * 1000 * t.wf, a * 1000, c[2]
                local d = P.drag(t, kg, ft, m) + 0.7 * P.atmos(ft) * m * m * P.S * dcd
                out[#out + 1] = P.thrust_ff(t, d / (4 - n), ft, m, 0) / (c[4] * t.wf)
            end
        end
    end
    return out
end

local function stats(r)
    local s, s2, lo, hi = 0, 0, math.huge, -math.huge
    for _, v in ipairs(r) do
        s, s2 = s + v, s2 + v * v
        lo, hi = math.min(lo, v), math.max(hi, v)
    end
    local mean = s / #r
    return mean, math.sqrt(math.max(0, s2 / #r - mean * mean)), lo, hi
end

for _, ty in ipairs({0, 1}) do
    local t = P.tables(ty)
    for n = 1, 2 do
        local best, bd = math.huge, 0
        for i = 0, 400 do
            local mean = stats(ratios(t, n, i * 0.00001))
            if math.abs(mean - 1) < best then best, bd = math.abs(mean - 1), i * 0.00001 end
        end
        local mean, sd, lo, hi = stats(ratios(t, n, bd))
        local m0 = stats(ratios(t, n, 0))
        print(string.format("%s, %d engine(s) inoperative: DCD %.5f (perf_db %.5f); fuel flow model/table mean %.3f sd %.3f, %.3f to %.3f (without DCD mean %.3f)",
            ty == 0 and "PW" or "GE", n, bd, t.EO[n].DCD, mean, sd, lo, hi, m0))
    end
end
