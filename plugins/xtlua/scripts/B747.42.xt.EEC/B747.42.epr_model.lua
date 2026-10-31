-- The EPR the EICAS shows for the PW4056 (ENG-33), without X-Plane: from an
-- engine's net thrust, the ambient pressure and the Mach. The EEC and the
-- A/T hold this EPR, so it decides the thrust at every EPR setting.
--   local P = B747_epr_model
--   local epr = P.epr(thrust_kn, delta, mach)  -- delta: ambient p / 101,325 Pa
--
-- The form: the corrected net thrust F/delta (kN) = k * (NPR - 1)^q, with
-- NPR = EPR * (1 + 0.2 M^2)^3.5, the exhaust's pressure to the ambient
-- (EPR is the exhaust's to the inlet's total pressure). At low power this
-- keeps the FCOM's EPR falling with the speed at the same thrust (the ram
-- raises the inlet's pressure), at high power the ram drag asks for more.
-- k and q at each Mach go through two points: the FCOM's EPR and the thrust
-- the custom acf needs there (its drag, and for the climbs the FCOM's climb
-- rate; 270 t, measured 2026-10-29/30, notes/AERO.md 3.8). Between the
-- Machs k and q are interpolated (the takeoff run between the static point
-- and 0.438: no figures, estimate). The FCOM points (PW4056):
-- - takeoff: the rated thrust standing at sea level, 252.4 kN (ICAO_EEDB
--   1PW041), at EPR 1.51 (the go-around table, PI.10.37 p.263, sea level
--   15 deg C; the EEC takes it for the takeoff rating, estimate); the ground
--   idle's 10.3 kN at EPR 1.01 (estimate);
-- - level flight at 290 KIAS (.84 above, the Flight With Unreliable Airspeed
--   cruise table, PI.10.38-10.40 p.264-266) and the Long Range Cruise
--   Control table (PI.11.2 p.268) at 29,000-35,000 ft;
-- - the climb at 290 KIAS/.84 with the Max Climb EPR (PI.10.36 p.262): the
--   climb rates of PI.10.38.
local M = setmetatable({}, {})
B747_epr_model = M

-- Mach, k (kN), q, and the two points (corrected thrust kN, EPR)
M.STATIONS = {
    {0.000, 436.5, 0.8136},   -- ground idle 10.3 / 1.01; takeoff 252.4 / 1.51
    {0.438, 353.7, 0.9844},   -- sea level, 290 KIAS: level 44.8 / 0.984; climb 152.7 / 1.25
    {0.523, 282.4, 0.8924},   -- 10,000 ft: level 64.3 / 0.988; climb 186.1 / 1.35
    {0.631, 246.7, 0.8344},   -- 20,000 ft: level 94.2 / 1.006; climb 219.6 / 1.43
    {0.766, 205.5, 0.7338},   -- 30,000 ft: level 143.5 / 1.094; climb 251.2 / 1.57
    {0.797, 201.2, 0.6898},   -- LRC 29,000 ft: 145.7 / 1.07; the climb between 30,000 and 35,000 ft
    {0.813, 197.9, 0.6891},   -- LRC 31,000 ft: 154.6 / 1.10; the same
    {0.830, 196.3, 0.6685},   -- LRC 33,000 ft: 166.7 / 1.135; the same
    {0.843, 201.0, 0.5915},   -- LRC 35,000 ft: 186.2 / 1.18; climb 35,000 ft (.84) 266.5 / 1.64
}
local function ram(mach) return (1 + 0.2 * mach * mach) ^ 3.5 end

-- the least EPR: that of no net thrust at the Mach (the exhaust at the
-- ambient pressure, NPR 1). X-Plane's idle reads a little above it: 0.68 at
-- FL300, M.78 (2 kN an engine), 1.01 at ground idle (estimate: the FCOM
-- gives no idle EPR). Before (2026-10-31), 0.97 at any Mach (the previous
-- code's): the EEC's thrust control holds this EPR, and at FL300, M.78 it
-- could set no thrust between X-Plane's idle and 34 kN an engine, the 0.97's
-- (the FMC's step 9d2: the early descent's 1,250 fpm needs 26 kN)
function M.zero(mach)
    if mach < 0 then mach = 0 end
    return 1 / ram(mach)
end

-- k and q at a Mach (held beyond the first and last)
local function kq(mach)
    local s = M.STATIONS
    if mach <= s[1][1] then return s[1][2], s[1][3] end
    for i = 2, #s do
        if mach <= s[i][1] then
            local a, b = s[i - 1], s[i]
            local w = (mach - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * w, a[3] + (b[3] - a[3]) * w
        end
    end
    return s[#s][2], s[#s][3]
end

-- the EPR shown for an engine's net thrust (kN)
function M.epr(thrust_kn, delta, mach)
    if mach < 0 then mach = 0 end
    local f = thrust_kn / math.max(delta, 0.05)
    if f <= 0 then return M.zero(mach) end
    local k, q = kq(mach)
    return (1 + (f / k) ^ (1 / q)) / ram(mach)
end

-- the other way: the net thrust (kN) an EPR gives (for the tests and tools)
function M.thrust(epr, delta, mach)
    if mach < 0 then mach = 0 end
    local k, q = kq(mach)
    local y = epr * ram(mach) - 1
    if y <= 0 then return 0 end
    return k * y ^ q * delta
end

return M
