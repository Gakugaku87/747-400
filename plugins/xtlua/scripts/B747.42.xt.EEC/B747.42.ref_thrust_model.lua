-- 747-400 FMC reference thrust limit without X-Plane (6-1/6-2 step 9g3;
-- docs/overhaul/notes/ATA-34-61-FMC.md §75): the limit for the FMC's thrust
-- limit mode (B747.68.thrlim_model.lua's; ATA34_2 p.642: for the CDU, the
-- EICAS and the A/T) from the FCOM PI tables the EEC holds (B747.42.
-- eec_model.lua), with the bleed adjustments as the EEC's maximum:
--   TO the takeoff rating (the go-around table's, as the EEC's full-forward
--   rating); TO 1 and TO 2 its thrust less the derate (the operator's %:
--   FCOM p.1272); D- the rating at the assumed temperature (SEL) when above
--   the TAT (ATA34_2 p.651), at most 25 % less thrust than the (derated)
--   rating (FCOM p.1273, p.1314);
--   CLB the maximum climb table; CLB 1 and CLB 2 10 and 20 % less thrust to
--   10,000 ft, then linearly back to CLB's at 30,000 and 35,000 ft (the
--   109: P&W and RR; the 405 and 570, GE: both at 15,000 ft) (FCOM p.1273);
--   GA the go-around table;
--   CRZ the maximum climb table (estimate: the FCOM has no maximum cruise
--   table);
--   CON the maximum continuous table at the airspeed (step 9h1: PI.13.1-
--   13.2, PI.23.1-23.3; one engine inoperative, also with all engines:
--   estimate).
-- P&W in EPR, a thrust's EPR from the EPR model (B747.42.epr_model.lua);
-- GE in N1, a thrust's as N1 x the thrust ratio to the 1/3 (estimate).
--
--   local R = B747_ref_thrust_model
--   local v, red = R.reference(inp)     -- the limit, the takeoff's thrust reduction (%)

local M = setmetatable({}, {})
B747_ref_thrust_model = M

-- the assumed temperature's most (FCOM p.1273); the climb derates' thrust
-- (FCOM p.1273) and the altitudes they wash out between
M.SEL_MAX = 0.25
M.CLB_DERATE = {0.10, 0.20}
M.CLB_FULL, M.CLB_GONE = 10000, {PW = {30000, 35000}, GE = {15000, 15000}}

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi end
    return x
end

-- the value for a fraction x less thrust, and the thrust ratio of b to a
local function less(ge, v, x, mach)
    if x <= 0 then return v end
    if ge then return v * (1 - x) ^ (1 / 3) end
    local P = B747_epr_model
    return P.epr((1 - x) * P.thrust(v, 1, mach), 1, mach)
end
local function ratio(ge, a, b, mach)
    if ge then return (b / a) ^ 3 end
    local P = B747_epr_model
    local fa = P.thrust(a, 1, mach)
    if fa <= 0 then return 1 end
    return P.thrust(b, 1, mach) / fa
end

-- the climb derate's share left at an altitude (1 to 10,000 ft, 0 at its top)
function M.washout(alt, top)
    return clamp((top - alt) / (top - M.CLB_FULL), 0, 1)
end

-- inp: type ("PW" or "GE"), mode (the FMC's: "TO", "D-TO 1", "CLB 2", ...),
-- to_pct (the takeoff derate, %), sel (the assumed temperature, °C, or
-- nil), alt (pressure altitude, ft), tat (°C), mach, kias, packs_on, wai,
-- nai (this engine's). Returns the limit and the takeoff's thrust reduction
-- (%: 0 in other modes)
function M.reference(inp)
    local E = B747_eec_model
    local ge = inp.type == "GE"
    local tables = E.TABLE[inp.type] or E.TABLE.PW
    local mode = inp.mode or "TO"
    local d = mode:sub(1, 2) == "D-"
    local base = d and mode:sub(3) or mode
    local mach = inp.mach or 0
    local gaAlt = math.min(inp.alt, tables.ga.alt[#tables.ga.alt])
    if base:sub(1, 2) == "TO" or mode == "" then
        local full = E.rating(tables.ga, inp, inp.tat, gaAlt, inp.nai)
        local x = (inp.to_pct or 0) / 100
        local derated = less(ge, full, x, mach)
        local v = derated
        if d and inp.sel and inp.sel > inp.tat then
            local hot = less(ge, E.rating(tables.ga, inp, inp.sel, gaAlt, inp.nai), x, mach)
            v = math.max(hot, less(ge, derated, M.SEL_MAX, mach))
        end
        return v, 100 * (1 - ratio(ge, full, v, mach))
    end
    if base == "GA" then return E.rating(tables.ga, inp, inp.tat, gaAlt, inp.nai), 0 end
    if base == "CON" then return E.rating_mct(tables.mct, inp, inp.tat, inp.alt, inp.kias or 0, inp.nai), 0 end
    local v = E.rating(tables.clb, inp, inp.tat, inp.alt, inp.nai)
    local n = base:sub(1, 3) == "CLB" and tonumber(base:sub(5)) or nil
    if n and M.CLB_DERATE[n] then
        local top = (M.CLB_GONE[inp.type] or M.CLB_GONE.PW)[n]
        v = less(ge, v, M.CLB_DERATE[n] * M.washout(inp.alt, top), mach)
    end
    return v, 0
end

return M
