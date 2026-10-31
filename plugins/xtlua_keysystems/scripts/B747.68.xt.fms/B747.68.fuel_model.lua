-- The FMC's fuel monitoring (6-1/6-2 step 11a; notes/ATA-34-61-FMC.md
-- §90): its fuel quantity (CALC, MANUAL, SENSED), FUEL USED, the
-- totalizer's and the calculated quantities, FUEL DISAGREE and the USE
-- prompts, INSUFFICIENT FUEL. Logic and sources (FCOM p.1273-1274,
-- p.1310, p.1378-1382, p.1432; ATA34_2 p.569):
--  - CALCULATED: the totalizer's before the engine start; from a positive
--    fuel flow, the quantity at the start less FUEL USED; back to the
--    totalizer's during a jettison (and its end) and after all engines
--    are shut down. A crew entry (MANUAL) replaces it and goes down with
--    the flow the same way.
--  - FUEL USED: from the fuel flow (the fuel system's totaliser), each
--    engine's and the total, kept through flight completion, cleared at
--    the engine start.
--  - FUEL DISAGREE - PROG 2 and PROGRESS 2's <USE and USE>: the totalizer
--    and the calculated quantity 4,080 kg (9,000 lb) or more apart. USE
--    TOTALIZER: the FMC uses the totalizer's (SENSED; CALCULATED and FUEL
--    USED blank); USE CALCULATED: the calculated one (TOTALIZER blank).
--  - INSUFFICIENT FUEL: the predicted fuel at the destination under the
--    RESERVES.
-- Estimates: the choice holds (no FUEL DISAGREE again) until the engines
-- are shut down; a deleted MANUAL entry back to the totalizer's; the
-- fuel flow always valid (no SENSED without the crew's choice).
--
--   local M = B747_fuel_model             -- in XTLua, after dofile
--   local s = M.new()
--   M.update(s, inp)                      -- each frame

local M = setmetatable({}, {})
B747_fuel_model = M

M.DISAGREE_KG = 4080                       -- FCOM p.1381 (9,000 lb: p.1378)
M.RUNNING_KG_S = 0.01                      -- a positive fuel flow

function M.new()
    return {
        running = false,    -- an engine's fuel flow positive
        base = nil,         -- the quantity at the start (or the entry), kg
        used0 = nil,        -- the totaliser's at the start: {1..4, total}
        manual = nil,       -- the crew's entry (kg) while not running
        manual_on = false,  -- MANUAL
        use = nil,          -- "TOTALIZER" or "CALCULATED": the crew's choice
        jett = false,
        out = {},
    }
end

local function zero5() return {0, 0, 0, 0, 0} end

-- the crew's FUEL entry (kg) or DELETE (nil): false when not allowed
-- (SENSED: FCOM p.1310; DELETE of no entry)
function M.enter(s, kg, fqis, used)
    if s.use == "TOTALIZER" then return false end
    if kg == nil then
        if not s.manual_on then return false end
        s.manual_on = false
        s.base, s.used0 = fqis, used and {used[1], used[2], used[3], used[4], used[5]} or zero5()
        return true
    end
    s.manual_on = true
    s.base = kg
    s.used0 = used and {used[1], used[2], used[3], used[4], used[5]} or zero5()
    return true
end

-- PROGRESS 2's <USE (TOTALIZER) and USE> (CALCULATED)
function M.choose(s, which)
    if not s.out.disagree then return false end
    s.use = which
    return true
end

-- inp: fqis (kg), used ({1..4, 5 the total}: the fuel system's totaliser,
-- kg), ff ({1..4} kg/s), jett (a jettison on), pred_dest (kg) and reserves
-- (kg) for INSUFFICIENT FUEL
function M.update(s, inp)
    local out = s.out
    local used = inp.used
    local running = false
    for n = 1, 4 do
        if (inp.ff[n] or 0) > M.RUNNING_KG_S then running = true end
    end
    -- the start: FUEL USED from zero, the calculated quantity disconnects
    if running and not s.running then
        if not s.manual_on then s.base = inp.fqis end
        s.used0 = {used[1], used[2], used[3], used[4], used[5]}
    end
    -- all engines shut down: back to the totalizer (FCOM p.1382), the
    -- choice and the entry gone; FUEL USED kept
    if s.running and not running then
        s.manual_on, s.use = false, nil
        s.base = nil
    end
    s.running = running
    -- a jettison: the totalizer's, again from its end
    if inp.jett then
        s.base = inp.fqis
        s.used0 = {used[1], used[2], used[3], used[4], used[5]}
    end
    s.jett = inp.jett and true or false

    local u0 = s.used0 or zero5()
    for n = 1, 5 do out[n] = math.max(0, used[n] - u0[n]) end
    local calc
    if running or s.manual_on then
        calc = (s.base or inp.fqis) - out[5]
    else
        calc = inp.fqis
    end
    out.calc = calc
    out.fqis = inp.fqis
    out.disagree = s.use == nil and running and math.abs(inp.fqis - calc) >= M.DISAGREE_KG
    out.source = s.use == "TOTALIZER" and "SENSED" or (s.manual_on and "MANUAL" or "CALC")
    out.fmc = s.use == "TOTALIZER" and inp.fqis or calc
    -- PROGRESS 2's lines: TOTALIZER blank with a manual entry or after USE
    -- CALCULATED, CALCULATED and FUEL USED blank after USE TOTALIZER
    out.show_totalizer = not s.manual_on and s.use ~= "CALCULATED"
    out.show_calc = s.use ~= "TOTALIZER"
    out.insufficient = inp.pred_dest ~= nil and inp.reserves ~= nil and inp.pred_dest < inp.reserves
    return out
end

return M
