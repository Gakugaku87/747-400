-- The EICAS formats (5-2 step 6b, GAP DSP-24, ENG-22). Logic and sources:
-- docs/overhaul/notes/ATA-31.md §36.
--  - The secondary engine indications (N2, FF, OIL P, OIL T, OIL Q, VIB)
--    show on secondary EICAS when the ENG switch selects them. Not selected,
--    a secondary engine exceedance brings up its rows alone, the partial
--    format: N2 at its operating limit; OIL P, OIL T, OIL Q at a caution
--    range or operating limit (the CF6's oil quantity low or differential
--    too); VIB at the high band. ENG then shows every row, and again only
--    the partial ones (FCOM p.852-854, p.874).
--  - The secondary engine exceedance cue (cyan, in the status cue's field
--    and over it) while a parameter exceeds (FCOM p.839-840).
--  - Another secondary EICAS display selected in the partial format: the
--    partial rows go with the primary engine indications to primary EICAS
--    in compact format. One display unit for EICAS: compact format on
--    primary EICAS, every row with ENG, the partial rows on an exceedance
--    (FCOM p.855-857, p.874-875).
--  - ENG comes up when the displays first get power (FCOM p.872); a FUEL
--    CONTROL switch to CUTOFF in flight selects it in the fuel module.
--  - The partial rows and the cue stay while the parameter exceeds (FCOM
--    p.875).
-- Estimate: "the displays first get power" taken as primary EICAS coming up
-- on a display unit.
-- Pure functions: the display glue (B747.60.xt.displays.lua) runs them.
--   local FM = B747_eicas_format_model             -- in XTLua, after dofile
--   local FM = dofile(".../B747.60.eicas_format_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_eicas_format_model = M

-- dsp/synoptic_display: none, ENG, STAT, ELEC, FUEL, ECS, HYD, DRS, GEAR
M.SYN_NONE, M.SYN_ENG = 0, 1
-- the compact format on primary EICAS: off, every row (ENG), the partial rows
M.COMPACT_OFF, M.COMPACT_FULL, M.COMPACT_PARTIAL = 0, 1, 2
-- the rows (eicas/sec_rows, cmp_rows)
M.ROW_N2, M.ROW_FF, M.ROW_OIL, M.ROW_VIB = 1, 2, 3, 4

function M.new()
    return {pri_shown = nil, out = {select_eng = false, cue = false, sec = false,
        sec_rows = {false, false, false, false}, compact = M.COMPACT_OFF,
        cmp_rows = {false, false, false, false}}}
end

local function rows(t, on, all, inp)
    t[M.ROW_N2] = on and (all or inp.exceed_n2)
    t[M.ROW_FF] = on and all
    t[M.ROW_OIL] = on and (all or inp.exceed_oil)
    t[M.ROW_VIB] = on and (all or inp.exceed_vib)
end

-- inp: synoptic (dsp/synoptic_display); exceed_n2, exceed_oil, exceed_vib
-- (any engine); pri_shown, sec_shown (primary and secondary EICAS each on a
-- display unit)
function M.update(s, inp)
    local o = s.out
    o.select_eng = s.pri_shown == false and inp.pri_shown
    s.pri_shown = inp.pri_shown
    local syn = inp.synoptic
    if o.select_eng then syn = M.SYN_ENG end
    local full = syn == M.SYN_ENG
    local partial = (inp.exceed_n2 or inp.exceed_oil or inp.exceed_vib) and not full
    o.cue = inp.exceed_n2 or inp.exceed_oil or inp.exceed_vib
    if inp.sec_shown then
        o.sec = full or (partial and syn == M.SYN_NONE)
        o.compact = (partial and syn ~= M.SYN_NONE) and M.COMPACT_PARTIAL or M.COMPACT_OFF
    else
        o.sec = false
        if full then o.compact = M.COMPACT_FULL
        elseif partial then o.compact = M.COMPACT_PARTIAL
        else o.compact = M.COMPACT_OFF end
    end
    rows(o.sec_rows, o.sec, full, inp)
    rows(o.cmp_rows, o.compact ~= M.COMPACT_OFF, o.compact == M.COMPACT_FULL, inp)
    return o
end

return M
