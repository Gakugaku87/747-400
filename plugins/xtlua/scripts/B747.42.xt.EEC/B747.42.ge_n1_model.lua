-- The N1 the EICAS shows for the CF6-80C2B1F in the air (ENG-33,
-- 2026-11-10, notes/ATA-70-80.md §17 and §18), without X-Plane: from an engine's
-- net thrust, the ambient pressure ratio, the Mach and the static
-- temperature ratio. The EEC and the A/T hold this N1, so it decides the
-- thrust at every N1 setting (the max climb N1 of the FCOM's tables, the
-- climb rate). On the takeoff the display is X-Plane's N1 times a factor
-- (B747.42.xt.EEC.GE.lua's N1_display_GE), not this.
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
-- not fitted: the freighter's FCOM needs 7 to 8 % more N1 at flaps 10 and 20
-- than at 5 where the PW4056's passenger airplane needs no more (an airframe
-- difference); there this N1 shows about 10 % under the freighter's. Above
-- M_MAX (the points end at .84) the Mach terms of k and q are held.
-- Estimates: the form, n0, the anchor, M_MAX
local M = setmetatable({}, {})
B747_ge_n1_model = M

M.N0 = {20.96, 36.93}                   -- corrected N1 at zero net thrust: + M x
M.K = {27.6178, 17.3244, -56.2495, 32.6853}  -- k: + M x, + M^2 x, + M^3 x
M.Q = {0.63, -0.02}                     -- the power: + M x
M.M_MAX = 0.86
M.LBF = 4.4482216                       -- N a lbf

-- the corrected N1 (%) for the corrected net thrust fc (lbf) and the Mach
function M.n1c(fc, mach)
    local m = math.max(0, mach or 0)
    local mk = math.min(m, M.M_MAX)
    local x = math.max(0, fc) / 10000
    local k = M.K[1] + mk * (M.K[2] + mk * (M.K[3] + mk * M.K[4]))
    return M.N0[1] + M.N0[2] * m + k * x ^ (M.Q[1] + M.Q[2] * mk)
end

-- the N1 (%) for an engine's net thrust (N) at the ambient pressure ratio
-- delta, the Mach and the static temperature ratio theta
function M.n1(thrust_n, delta, mach, theta)
    return M.n1c(thrust_n / delta / M.LBF, mach) * math.sqrt(theta)
end

return M
