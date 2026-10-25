-- The heading reference (5-2 step 5d). Logic and sources:
-- docs/overhaul/notes/ATA-31.md §33.
--  - The HDG REF switch's TRUE, or NORM in the polar areas (north of 82°N,
--    or of 70°N between 80°W and 130°W; south of 82°S, or of 60°S between
--    120°E and 160°E), refers the PFDs, NDs, AFDS and FMCs to true north
--    (FCOM p.1046, p.1110; ATA34_2 p.336: each IRU puts out true and
--    magnetic headings; ATA22 p.358: the heading modes on the selected one).
--  - The PFD: MAG, or TRU in a box (FCOM p.998).
--  - The ND: MAG, or TRU in a white box; the box amber when the airplane,
--    referred to true north, descends 2,000 ft at more than 800 fpm,
--    flashing for 10 s, white again after it climbs 2,000 ft at more than
--    500 fpm (FCOM p.1110); MAG in a box for 10 s after TRU (FCOM p.1142).
--    "Descends 2,000 ft at more than 800 fpm": 2,000 ft lost while the
--    descent stays faster than 800 fpm (estimate; the climb likewise); the
--    flash at 2 Hz (estimate).
-- Pure functions: the display glue (B747.60.xt.displays.lua) runs them.
--   local HR = B747_hdg_ref_model             -- in XTLua, after dofile
--   local HR = dofile(".../B747.60.hdg_ref_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_hdg_ref_model = M

M.DESCENT_FT, M.DESCENT_FPM = 2000, 800
M.CLIMB_FT, M.CLIMB_FPM = 2000, 500
M.FLASH_S, M.MAG_BOX_S = 10, 10
M.FLASH_HZ = 2
-- the ND's label (the panel image's frames): MAG; TRU in a white box; TRU
-- in an amber box; TRU without its box (the amber box's flash off); MAG in
-- a white box. The PFD's: MAG; TRU in a box
M.ND_MAG, M.ND_TRU, M.ND_TRU_AMBER, M.ND_TRU_OFF, M.ND_MAG_BOX = 0, 1, 2, 3, 4
M.PFD_MAG, M.PFD_TRU = 0, 1

-- the areas referred to true north with the switch in NORM
function M.polar(lat, lon)
    if lat > 82 or lat < -82 then return true end
    if lat > 70 and lon >= -130 and lon <= -80 then return true end
    if lat < -60 and lon >= 120 and lon <= 160 then return true end
    return false
end

-- a heading in the reference: the magnetic one, or the true one (mag_diff:
-- the magnetic heading less the true)
function M.heading(mag, mag_diff, true_ref)
    if not true_ref then return mag % 360 end
    return (mag - mag_diff) % 360
end

function M.new()
    return {t = 0, true_ref = false, amber = false, flash_until = -1, mag_box_until = -1,
        descent_from = nil, climb_from = nil,
        out = {true_ref = false, nd = M.ND_MAG, pfd = M.PFD_MAG}}
end

-- inp: switch_true (the HDG REF switch in TRUE), lat, lon, alt_ft, vs_fpm
function M.update(s, inp, dt)
    s.t = s.t + (dt or 0)
    local t = s.t
    local tr = inp.switch_true or M.polar(inp.lat, inp.lon)
    if tr ~= s.true_ref then
        s.mag_box_until = tr and -1 or t + M.MAG_BOX_S
        s.amber, s.flash_until, s.descent_from, s.climb_from = false, -1, nil, nil
        s.true_ref = tr
    end
    if tr then
        if inp.vs_fpm < -M.DESCENT_FPM then
            s.descent_from = s.descent_from or inp.alt_ft
            if not s.amber and s.descent_from - inp.alt_ft >= M.DESCENT_FT then
                s.amber, s.flash_until, s.climb_from = true, t + M.FLASH_S, nil
            end
        else
            s.descent_from = nil
        end
        if s.amber then
            if inp.vs_fpm > M.CLIMB_FPM then
                s.climb_from = s.climb_from or inp.alt_ft
                if inp.alt_ft - s.climb_from >= M.CLIMB_FT then
                    s.amber, s.flash_until, s.climb_from = false, -1, nil
                end
            else
                s.climb_from = nil
            end
        end
    end
    local o = s.out
    o.true_ref = tr
    if tr then
        o.pfd = M.PFD_TRU
        if s.amber then
            local lit = true
            if t < s.flash_until then
                local period = 1 / M.FLASH_HZ
                lit = (s.flash_until - t) % period < period / 2
            end
            o.nd = lit and M.ND_TRU_AMBER or M.ND_TRU_OFF
        else
            o.nd = M.ND_TRU
        end
    else
        o.pfd = M.PFD_MAG
        o.nd = t < s.mag_box_until and M.ND_MAG_BOX or M.ND_MAG
    end
    return o
end

return M
