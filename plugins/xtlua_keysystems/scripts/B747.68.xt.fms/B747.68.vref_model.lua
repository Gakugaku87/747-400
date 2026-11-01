-- 747-400 VREF without X-Plane (notes/ATA-34-61-FMC.md §128): VREF 25 and
-- 30 (KIAS) for a gross weight as the FMC shows them on APPROACH REF and
-- the PFD's flap maneuver speeds take them (FCOM p.1409-1412, PI.10.3):
--  - the FCOM's table (PI.10.2, 1,000 kg) for every engine type: VREF is
--    the airframe's, and the FCOM's 570 (GE) APPROACH REF shows 142/136 kt
--    at 502.8 (1,000 lb), the table's (p.1411); the 747-400F's CF6 table
--    (PI.20.2) is up to 1 kt lower. Air China's QRH (PW4056, 1,000 lb:
--    PI-QRH.10.5) agrees within 1 kt up to its 900,000 lb (408 t), with
--    the table's last step carried on beyond 400 t (below 200 t its first:
--    estimate)
--  - "Increase VREF 1 knot/4000 ft above sea level" (PI.10.2) with the
--    landing airport's elevation (the FMC's landing altitude; the table
--    gives the rule, which elevation the FMC takes is an estimate)
-- Before: VREF 30 from Laminar's table by the airplane's weight and its
-- present altitude in bands, VREF 25 the FCOM's by the present altitude
-- (at FL350 8.75 kt above the landing's).
--   local V = B747_vref_model                     -- in XTLua, after dofile
--   local V = dofile(".../B747.68.vref_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_vref_model = M

M.FT_PER_KT = 4000
M.W = {200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400}
M.TABLE = {
    [30] = {127, 133, 140, 146, 152, 157, 163, 168, 174, 179, 184},
    [25] = {132, 139, 146, 152, 158, 164, 170, 176, 181, 187, 192},
}

-- VREF (KIAS, not rounded) for flaps 25 or 30, a weight (kg) and the
-- landing elevation (ft)
function M.vref(flaps, weight_kg, elev_ft)
    local row = M.TABLE[flaps] or M.TABLE[30]
    local ws, t = M.W, weight_kg / 1000
    local i = 2
    while i < #ws and t > ws[i] do i = i + 1 end
    local v = row[i - 1] + (row[i] - row[i - 1]) * (t - ws[i - 1]) / (ws[i] - ws[i - 1])
    return v + math.max(0, elev_ft or 0) / M.FT_PER_KT
end

return M
