-- 747-400 takeoff stabilizer greenband without X-Plane (4-1 step 2c): the
-- band the MAWEA selects, the stabilizer trim indicators' band and the
-- band CONFIG STAB compares the stabilizer with. Logic and sources:
-- docs/overhaul/notes/ATA-27.md §4.6 (FCOM p.944, p.958; ATA27 p.502-521,
-- p.729-730).
--
--   local G = B747_greenband_model       -- in XTLua, after dofile
--   local G = dofile(".../B747.45.greenband_model.lua")   -- in the tests

local M = setmetatable({}, {})
B747_greenband_model = M

-- the three bands in trim units (ATA27 p.521 figure; FCOM p.944): the mid
-- band (painted), the nose up band (forward CG: the mid band and more nose
-- up) and the nose down band (aft CG: the mid band and more nose down)
M.MID, M.NOSE_UP, M.NOSE_DOWN = 1, 2, 3
M.BAND = {{3.35, 8.15}, {3.35, 10.15}, {1.35, 8.15}}

-- the 3D (objects/747_cockpit/Cockpit_Pedestal1.obj, the band and the trim
-- bar measured along the scale): one green band 4.63 units long, its centre
-- at 3.81 units with laminar/B747/flt_ctrls/elevator_trim/mid/indicator 0
-- and 8.12 units with 1
M.IND_CENTER_0, M.IND_CENTER_1 = 3.81, 8.12
M.IND_HALF = 2.32

-- the band the MAWEA selects from the FMC's CG, gross weight and thrust
-- (ATA27 p.514). Its table is not in the sources (estimate): from the FMC's
-- takeoff trim, the mid band when the trim is in it, otherwise the band on
-- the trim's side; no takeoff trim (no CG entered): the mid band
function M.select(fmc_trim)
    if not fmc_trim or fmc_trim <= 0 then return M.MID end
    if fmc_trim > M.BAND[M.MID][2] then return M.NOSE_UP end
    if fmc_trim < M.BAND[M.MID][1] then return M.NOSE_DOWN end
    return M.MID
end

function M.within(band, units)
    local b = M.BAND[band]
    return units >= b[1] and units <= b[2]
end

-- the indicators: the selected band's lights while the takeoff enable is
-- active, out above V1 (ATA27 p.514); otherwise the painted mid band. The
-- 3D's one band is shorter than the nose up and nose down bands: it shows
-- their outer end (the lit segment)
function M.indicator(band, lit)
    local b = lit and band or M.MID
    local lo, hi = M.BAND[b][1], M.BAND[b][2]
    local center = (lo + hi) / 2
    if b == M.NOSE_UP then center = hi - M.IND_HALF
    elseif b == M.NOSE_DOWN then center = lo + M.IND_HALF end
    local x = (center - M.IND_CENTER_0) / (M.IND_CENTER_1 - M.IND_CENTER_0)
    if x < 0 then x = 0 elseif x > 1 then x = 1 end
    return x
end

return M
