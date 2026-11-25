-- The RB211-524G/H's thrust and the EPR the EICAS shows, by difference from
-- the PW4056's (2026-11-25, the user's 「RRも作り直そう」: GAP_ANALYSIS.md §8,
-- notes/ATA-70-80.md §40). No source gives the RB211's thrust at its EPR.
-- The PW4056's EPR model (B747.42.epr_model.lua: fitted to the FPPM and the
-- FCOM, ENG-1) gives the thrust; the RB211's differs from it by
--  - the rating: takeoff 56,870 lbf (-524G) and 59,450 lbf (-524H, H2)
--    against the PW4056's 56,750 lbf (TCDS_RB211 p.10, TCDS_PW4000 p.1;
--    ICAO_EEDB 1RR009, 1RR011, 1PW041: 253.0, 264.4 and 252.4 kN) up to
--    M .30, the maximum continuous 47,230 against 47,970 lbf (the same
--    pages) from M .45, linear between (estimate: the takeoff's at the
--    takeoff's and the go-around's speeds, the continuous's in the climb
--    and the cruise);
--  - the low Mach's fall with the speed: as the GE's (B747.42.ge_n1_model.
--    lua, notes/ATA-70-80.md §39) the P&W's fall 1 - F/F0 at its takeoff
--    EPR times sqrt((1 + B) / (1 + 4.7)), the bypass ratios 4.3 and 4.2
--    (ICAO_EEDB): 0.964 and 0.955 (a little more thrust), whole to M .29,
--    none from .438 (estimate).
-- The EEC (B747.42.eec_model.lua and its glue) runs on the PW4056's scale:
-- the PW4056's EPR of the RB211's thrust over that multiplier (M.pw_epr),
-- its ratings and commands the P&W's. The EICAS shows the RB211's own EPR:
-- the fan's and the turbine's exhaust pressures together over the inlet's
-- (RR_JET p.147), another number for the same thrust. M.display turns the
-- PW4056's scale into it by an excess x over 1: x_RR = A x / (1 + B x), none
-- below it (no net thrust at the same NPR 1 either way):
--  - to M .30, on the EPRs themselves (x = EPR - 1): the RB211's takeoff EPR
--    table (TOGA_epr_RR, B747.42.xt.EEC.tbls.lua: the upstream's, its source
--    not given, laid out as an FCOM's and flat to 30 C at sea level as
--    TCDS_RB211 p.15's ISA+15) against the FPPM's (TABLE.PW.to) at 10 C from
--    -2,000 to 6,000 ft, where both are flat rated: 9 points within 0.006
--    (rms 0.003). The EEC holds the takeoff EPR through the roll, the
--    RB211's as the P&W's, so the relation stays as it stands there and in
--    the go-around (estimate);
--  - from M .72, on the NPRs (x = EPR (1 + 0.2 M^2)^3.5 - 1): PMDG's long
--    range cruise RR-RB211 table (PMDG_CRZ p.34-35, FL300-370, 200-400 t,
--    M .727-.856: PMDG-derived, no real-aircraft source; PMDG's GE table is
--    the FCOM's CF6 table, p.364, to the digit) at the thrust the FMC's drag
--    polar (B747.68.perf_db.lua, fitted to the FCOM PW4056's long range
--    cruise) asks there: 147 points within 0.014 (rms 0.005);
--  - the two blended linearly between (estimate). (The first version took
--    the NPRs' A and B linear from M 0 to .72: the takeoff reference shown
--    rose from 1.71 to 1.75 by 80 kt, s427 2026-11-25)
--   local R = B747_rr_model
--   local v = R.variant("RB211-524H2")          -- "G" or "H"
--   local e = R.epr(thrust_kn, delta, mach, v)  -- the EPR shown
--   local p = R.pw_epr(thrust_kn, delta, mach, v) -- the EEC's (the P&W's scale)
-- B747_epr_model (B747.42.epr_model.lua) is loaded first (the P&W's glue in
-- the aircraft, the tests themselves)
local M = setmetatable({}, {})
B747_rr_model = M
local P = setmetatable({}, {__index = function(_, k) return B747_epr_model[k] end})

M.PW_TO, M.PW_MCT, M.PW_BPR = 56750, 47970, 4.7
M.VARIANT = {
    G = {to = 56870, mct = 47230, bpr = 4.3},   -- RB211-524G (1RR009)
    H = {to = 59450, mct = 47230, bpr = 4.2},   -- RB211-524H, H2 (1RR011)
}
M.MACH_TO, M.MACH_MCT = 0.30, 0.45              -- the takeoff's ratio to, the continuous's from
M.LOW_END, M.LOW_NONE = 0.29, 0.438             -- the bypass ratio's fall: whole to, none from
M.PW_TO_EPR = 1.51                              -- the P&W's takeoff EPR (the fall's)
M.SCALE0 = {2.7114, 1.8411}                    -- A, B on EPR - 1 (standing, the takeoff tables)
M.SCALE_CRZ = {3.1104, 1.1206}                  -- A, B on NPR - 1 (PMDG's cruise table)
M.BLEND = {0.30, 0.72}                          -- Mach: the first's to, the second's from

local function ram(mach) return (1 + 0.2 * mach * mach) ^ 3.5 end

-- "G" or "H" from the simconfig's engine (RB211-524G..., RB211-524H, H2, H8T)
function M.variant(engines)
    if engines and string.match(engines, "524H") then return "H" end
    return "G"
end

-- the bypass ratio's factor on the P&W's thrust at a Mach (1 at M 0 and from
-- M.LOW_NONE)
local function low_factor(v, mach)
    if mach <= 0 or mach >= M.LOW_NONE then return 1 end
    local s = math.sqrt((1 + M.VARIANT[v].bpr) / (1 + M.PW_BPR))
    local function g(m)
        local l = P.thrust(M.PW_TO_EPR, 1, m) / P.thrust(M.PW_TO_EPR, 1, 0)
        return (1 - s * (1 - l)) / l
    end
    if mach <= M.LOW_END then return g(mach) end
    return 1 + (g(M.LOW_END) - 1) * (M.LOW_NONE - mach) / (M.LOW_NONE - M.LOW_END)
end

-- the RB211's thrust over the PW4056's at the same setting (the P&W's scale)
function M.multiplier(v, mach)
    local t = M.VARIANT[v] or M.VARIANT.G
    local m = math.max(0, mach or 0)
    local r_to, r_mct = t.to / M.PW_TO, t.mct / M.PW_MCT
    local w = math.max(0, math.min(1, (m - M.MACH_TO) / (M.MACH_MCT - M.MACH_TO)))
    return (r_to + (r_mct - r_to) * w) * low_factor(v or "G", m)
end

-- x_RR = A x / (1 + B x) and back
local function sat(x, ab) return ab[1] * x / (1 + ab[2] * x) end
local function sat_back(y, ab)
    local d = ab[1] - ab[2] * y
    if d <= 1e-6 then d = 1e-6 end
    return y / d
end
-- the standing relation on the EPRs (to M.BLEND[1]); the cruise's on the NPRs
local function shown0(e)
    local x = e - 1
    if x <= 0 then return e end
    return 1 + sat(x, M.SCALE0)
end
local function shown_crz(e, mach)
    local r = ram(mach)
    local x = e * r - 1
    if x <= 0 then return e end
    return (1 + sat(x, M.SCALE_CRZ)) / r
end

-- the EPR shown for an EPR on the PW4056's scale at a Mach
function M.display(epr_pw, mach)
    local m = math.max(0, mach or 0)
    local lo, hi = M.BLEND[1], M.BLEND[2]
    if m <= lo then return shown0(epr_pw) end
    if m >= hi then return shown_crz(epr_pw, m) end
    local w = (m - lo) / (hi - lo)
    return shown0(epr_pw) * (1 - w) + shown_crz(epr_pw, m) * w
end

-- the other way: the PW4056's scale's EPR for an EPR shown (the RB211's
-- takeoff table into the EEC's scale; the blend's by halving, M.display
-- rising with the EPR)
function M.pw_of_display(epr_rr, mach)
    local m = math.max(0, mach or 0)
    if m <= M.BLEND[1] then
        local y = epr_rr - 1
        if y <= 0 then return epr_rr end
        return 1 + sat_back(y, M.SCALE0)
    end
    if m >= M.BLEND[2] then
        local r = ram(m)
        local y = epr_rr * r - 1
        if y <= 0 then return epr_rr end
        return (1 + sat_back(y, M.SCALE_CRZ)) / r
    end
    local lo, hi = 0.2, 3.0
    for _ = 1, 60 do
        local mid = (lo + hi) / 2
        if M.display(mid, m) < epr_rr then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
end

-- the PW4056's scale's EPR of the RB211's net thrust (kN) at the ambient
-- pressure ratio and the Mach: the EEC's controlled value
function M.pw_epr(thrust_kn, delta, mach, v)
    return P.epr(thrust_kn / M.multiplier(v, mach), delta, mach)
end

-- the EPR shown for the RB211's net thrust (kN)
function M.epr(thrust_kn, delta, mach, v)
    return M.display(M.pw_epr(thrust_kn, delta, mach, v), mach)
end

-- the RB211's net thrust (kN) at an EPR on the PW4056's scale
function M.thrust(epr_pw, delta, mach, v)
    return P.thrust(epr_pw, delta, mach) * M.multiplier(v, mach)
end

return M
