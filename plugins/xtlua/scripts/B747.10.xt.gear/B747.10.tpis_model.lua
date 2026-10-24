-- 747-400 tire pressure indicating system (TPIS) without X-Plane (4-2 step
-- 5): >TIRE PRESSURE from the 18 tires' pressures. Logic and sources:
-- docs/overhaul/notes/ATA-32.md §4.11 (FCOM p.1508, p.1522; ATA29_32 p.371,
-- p.374-377).
--
--   local P = B747_tpis_model              -- in XTLua, after dofile
--   local P = dofile(".../B747.10.tpis_model.lua")   -- in the tests
--   local inp = P.inputs()               -- fill it every frame
--   local out = P.update(inp)
--
-- Tires 1-18 as numbered on ATA29_32 p.371: 1-4 left wing gear (1 front
-- outboard, 2 front inboard, 3 rear outboard, 4 rear inboard), 5-8 left
-- body, 9-12 right body, 13-16 right wing, 17-18 the nose gear (left, right).

local M = setmetatable({}, {})
B747_tpis_model = M

M.TIRES, M.MAIN = 18, 16
M.LOW_PSI = 100             -- below 100 psi (ATA29_32 p.376)
M.SPREAD = 0.18             -- a main gear tire 18 % off the main gear tires' average
M.AXLE = 0.25               -- the two tires of an axle differing by more than 25 % of the lower
M.NOSE_PAIR = 0.12          -- the nose tires differing by more than 12 %
-- the axles: the pairs of tires (p.371)
M.AXLES = {{1, 2}, {3, 4}, {5, 6}, {7, 8}, {9, 10}, {11, 12}, {13, 14}, {15, 16}}
M.NOSE = {17, 18}

local function eighteen(v)
    local t = {}
    for i = 1, M.TIRES do t[i] = v end
    return t
end

function M.inputs()
    return {
        psi = eighteen(200),        -- the tires' pressures
        fail = eighteen(false),     -- a channel failed: not in the average, not compared
        takeoff = false,            -- on the ground at takeoff thrust (estimate: inhibited)
    }
end

local out = {tire_pressure = false, abnormal = eighteen(false)}

local function pair_off(a, b, ratio, inp)
    if inp.fail[a] or inp.fail[b] then return false end
    local lo, hi = math.min(inp.psi[a], inp.psi[b]), math.max(inp.psi[a], inp.psi[b])
    return hi - lo > ratio * lo
end

function M.update(inp)
    -- the main gear tires' average, without the failed channels
    local sum, n = 0, 0
    for i = 1, M.MAIN do
        if not inp.fail[i] then sum, n = sum + inp.psi[i], n + 1 end
    end
    local avg = n > 0 and sum / n or 0
    local any = false
    for i = 1, M.TIRES do
        local bad = false
        if not inp.fail[i] then
            bad = inp.psi[i] < M.LOW_PSI
            if i <= M.MAIN and n > 0 and math.abs(inp.psi[i] - avg) > M.SPREAD * avg then bad = true end
        end
        out.abnormal[i] = bad
    end
    for _, a in ipairs(M.AXLES) do
        if pair_off(a[1], a[2], M.AXLE, inp) then out.abnormal[a[1]], out.abnormal[a[2]] = true, true end
    end
    if pair_off(M.NOSE[1], M.NOSE[2], M.NOSE_PAIR, inp) then out.abnormal[17], out.abnormal[18] = true, true end
    for i = 1, M.TIRES do if out.abnormal[i] then any = true end end
    out.tire_pressure = any and not inp.takeoff
    return out
end

return M
