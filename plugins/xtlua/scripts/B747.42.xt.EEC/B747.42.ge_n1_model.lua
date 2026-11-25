-- The N1 the EICAS shows for the CF6-80C2B1F in the air (ENG-33,
-- 2026-11-10, notes/ATA-70-80.md §17 and §18), without X-Plane: from an engine's
-- net thrust, the ambient pressure ratio, the Mach and the static
-- temperature ratio. The EEC and the A/T hold this N1, so it decides the
-- thrust at every N1 setting (the max climb N1 of the FCOM's tables, the
-- climb rate). Since 2026-11-25 (the 2026-11-23 review's ENG-4) on the
-- takeoff too: before, X-Plane's N1 times the upstream's takeoff factor
-- (B747.42.xt.EEC.GE.lua's N1_display_GE).
--   local G = B747_ge_n1_model
--   local n1 = G.n1(thrust_n, delta, mach, theta)
--
-- The form: the corrected N1 (N1 / sqrt(theta), theta the static
-- temperature's ratio: the same as the total's in a Mach term) = n0(M) +
-- k(M) x^(q0 + q1 M), x the corrected net thrust F / delta in 10,000 lbf;
-- rising with the thrust everywhere. n0 is the upstream's zero-thrust N1
-- (20.96 + 36.93 M, kept: the idle has no FCOM figure); k is cubic in the
-- Mach; k and q fitted to the FCOM's CF6-80C2B1F %N1 (747-400F,
-- PI.20.31-20.34 p.359-362) at the thrust the same flight needs on the
-- custom acf: the PW4056 FCOM's EPR at that weight and speed (PI.10.38-10.40
-- p.264-266) through the EPR model (B747.42.epr_model.lua, fitted to this
-- acf's thrust). The points (71): level flight at 290 KIAS / .84 from sea
-- level to 40,000 ft, holding at 10,000 ft, the terminal area at 5,000 ft
-- with the flaps up, and the climbs at max climb thrust (PI.20.33's climb
-- rates added as the climb's power and its acceleration along the 290 KIAS /
-- .84 schedule, m (g V/S / TAS + dTAS/dh V/S); the max climb %N1 of PI.20.31
-- at the climb's TAT), with the rated 57,160 lbf standing at sea level at
-- the go-around table's 103.8 % (estimate). rms 1.0 %, at most 2.4 (the
-- upstream's cubic with the real Mach: rms 3.8, the high climbs +7 to +10).
-- The first fit left the acceleration out: 6-7 kN an engine too little at
-- 30,000 ft, and the GE climbed 15 % slow there in X-Plane (s282
-- 2026-11-10; the PW4056 at its Max Climb EPR climbs at the FCOM's rate,
-- aero_climb_maxclb 2026-11-09, needing 75 kN an engine). The extended flaps are
-- not fitted (flaps 1 and 5 and the final approach agree, rms 0.6-1.7 % N1).
-- At flaps 10 and 20 this N1 shows 8 to 10 % under the CF6 table: those two
-- rows ask about 40 % more drag than the PW4056's, and the CF6's flaps 20
-- (gear down, level) more than its own flaps 25 and 30 (gear down, 3 deg),
-- the opposite of more flap. With the same wing, flaps and gear and the other
-- rows agreeing, hardly an airframe difference; why the table has them is
-- unknown (notes/ATA-70-80.md §19). Above
-- M_MAX (the points end at .84) the Mach terms of k and q are held.
-- Estimates: the form, n0, the anchor, M_MAX, the low Mach's (M.LOW)
local M = setmetatable({}, {})
B747_ge_n1_model = M

M.N0 = {20.96, 36.93}                   -- corrected N1 at zero net thrust: + M x
M.K = {27.6178, 17.3244, -56.2495, 32.6853}  -- k: + M x, + M^2 x, + M^3 x
M.Q = {0.63, -0.02}                     -- the power: + M x
M.M_MAX = 0.86
M.LBF = 4.4482216                       -- N a lbf

-- (2026-11-25, after ENG-4: the user's 「寄せて」, notes/ATA-70-80.md §39) The
-- low Mach. Between the static anchor and the lowest fitted points (the
-- terminal area at 5,000 ft, M .36-.40, and the climbs from .438) the cubic
-- had no figure at high power, and at the takeoff N1 it gave about 5 % less
-- thrust than the P&W at its takeoff EPR (X-Plane, RJAA 15 C, 160 kt: 199
-- against 208 kN an engine), the takeoff run's 80 to 150 kt 1.3 s longer.
-- No GE source has the takeoff's or the go-around's thrust (the FPPM is
-- the PW4056's). So the P&W's fall with the speed is taken, the EPR model's
-- at its takeoff EPR 1.51 (B747.42.epr_model.lua: the FPPM's static shape
-- and its one engine go-around gradient at M .29, ENG-1), told apart by the
-- bypass ratio: the fall 1 - F/F0 times sqrt((1 + 5.1) / (1 + 4.7)) = 1.034
-- (ICAO_EEDB 1GE023 and 1PW041; at low Mach the fall is the ram drag over
-- the specific thrust, and the specific thrust of one core's energy goes
-- as 1 / sqrt(1 + B): the pressure ratios 30.1 and 29.3 alike). The rated
-- thrusts are 254.3 and 252.4 kN (the same sheets). dq, added to the
-- cubic's power q, puts the takeoff N1's (the anchor's 103.8 % corrected)
-- thrust there at M .1, .2 and .29 (within 0.4 % between); k is kept, so
-- the N1 at 10,000 lbf corrected stays the cubic's (the FCOM's final
-- approach rows, M .21-.25 at 12,000-16,000 lbf, come a little closer).
-- None at M 0 (the static and the takeoff N1's thrust,
-- B747.42.ref_thrust_model.lua, as before) and from .438 up (the fitted
-- points as before), linear between. The thrust at the takeoff N1: +3.9 %
-- at M .1, +5.4 % at .2, +5.5 % at .25 (about 210 kN at 160 kt at sea
-- level), +5.6 % at .29, +3.2 % at .35, none by .438. Lower N1s fall a
-- little more (at 100 % corrected, M .2: 1.1 % more than the P&W's shape),
-- higher a little less. All estimates
M.LOW = {            -- Mach, dq
    {0.000, 0.00000},
    {0.100, -0.01448},
    {0.200, -0.02084},
    {0.290, -0.02217},
    {0.438, 0.00000},
}
local function low(m)
    local s = M.LOW
    if m <= s[1][1] or m >= s[#s][1] then return 0 end
    for i = 2, #s do
        if m <= s[i][1] then
            local a, b = s[i - 1], s[i]
            return a[2] + (b[2] - a[2]) * (m - a[1]) / (b[1] - a[1])
        end
    end
    return 0
end
M.low = low

-- the corrected N1 (%) for the corrected net thrust fc (lbf) and the Mach
function M.n1c(fc, mach)
    local m = math.max(0, mach or 0)
    local mk = math.min(m, M.M_MAX)
    local x = math.max(0, fc) / 10000
    local k = M.K[1] + mk * (M.K[2] + mk * (M.K[3] + mk * M.K[4]))
    return M.N0[1] + M.N0[2] * m + k * x ^ (M.Q[1] + M.Q[2] * mk + low(m))
end

-- the N1 (%) for an engine's net thrust (N) at the ambient pressure ratio
-- delta, the Mach and the static temperature ratio theta
function M.n1(thrust_n, delta, mach, theta)
    return M.n1c(thrust_n / delta / M.LBF, mach) * math.sqrt(theta)
end

return M
