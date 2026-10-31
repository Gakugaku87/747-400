-- The FMC's landing altitude for the cabin pressure controllers (6-1/6-2
-- step 11b; notes/ATA-34-61-FMC.md §91). Logic and sources (FCOM p.1400,
-- p.993-994, p.608; ATA34_2 p.477):
--  - The FMCs send the active route's landing altitude to the cabin
--    pressure controllers (ATA34_2 p.477); without one the controllers
--    show LANDING ALT and take 2,000 ft (FCOM p.608).
--  - Before the arrivals page's switch point, the departure's: the
--    departure runway's elevation, the origin airport's without a runway
--    (FCOM p.993: the PFD's touchdown zone shows the same).
--  - The switch point (FCOM p.1400): more than 400 NM from the origin,
--    more than halfway along the active route, past the T/C and within two
--    minutes of the T/D, or past the T/D. From there the destination's:
--    the active approach's runway (its threshold elevation), the
--    destination airport's until an approach is selected.
-- Estimates: halfway from the direct distances from the origin and to the
-- destination (as the ILS's standby, §88); the switch checked in the air
-- with an active route only and kept until the flight completion or a new
-- flight; none (LANDING ALT) without the airport needed.
--
--   local M = B747_ldgalt_model           -- in XTLua, after dofile
--   local s = M.new()
--   local ft = M.update(s, inp)           -- once a second; nil: none

local M = setmetatable({}, {})
B747_ldgalt_model = M

M.SWITCH_NM = 400                          -- FCOM p.1400
M.TD_S = 120                               -- within two minutes of the T/D
M.MIN_GS_KT = 100                          -- the T/D's time with a ground speed (as RESET MCP ALT)

function M.new()
    return {switched = false}
end

-- inp: origin_ft, dep_rwy_ft, dest_ft, appr_rwy_ft (nil: none); from_nm,
-- to_nm (the direct distances from the origin and to the destination, nil
-- without them); phase ("CLB", "CRZ", "DES"); td_nm (to the T/D, negative
-- past it, nil without a path); gs_kt; air
function M.update(s, inp)
    if inp.air and not s.switched then
        local from, to = inp.from_nm, inp.to_nm
        if (from and from > M.SWITCH_NM) or (from and to and from > to) or inp.phase == "DES"
            or (inp.phase == "CRZ" and inp.td_nm and inp.gs_kt > M.MIN_GS_KT
                and inp.td_nm / inp.gs_kt * 3600 <= M.TD_S) then
            s.switched = true
        end
    end
    if s.switched then
        if inp.dest_ft == nil then return nil end
        return inp.appr_rwy_ft or inp.dest_ft
    end
    if inp.origin_ft == nil then return nil end
    return inp.dep_rwy_ft or inp.origin_ft
end

return M
