-- 747-400 PFD sources (5-2 step 4a): what each pilot's PFD can show from the
-- IRS and the air data, as the EIU picks the sources: the attitude, the
-- heading, the track and the vertical speed, and the ATT, HDG and VERT
-- flags. The values themselves are X-Plane's pilot and copilot AHRS (they
-- stand for each pilot's IRU, as for >ATTITUDE and >HEADING). Logic and
-- sources: docs/overhaul/notes/ATA-31.md §15 (FCOM p.996-999, p.1044,
-- p.1228; ATA31 p.15-17).
--
--   local P = B747_pfd_model                -- in XTLua, after dofile
--   local P = dofile(".../B747.60.pfd_model.lua")   -- in the tests
--   local s = P.new()
--   local inp = P.inputs()                  -- fill it every frame
--   local out = P.update(s, inp)            -- the same table every frame

local M = setmetatable({}, {})
B747_pfd_model = M

M.CAPT, M.FO = 1, 2
M.L, M.C, M.R = 1, 2, 3
-- the IRU an FMC takes the heading and track from when it is the pilot's NAV
-- source: the first in NAV in this order (estimate: FCOM p.1228 says only
-- "an IRU operating in the navigation mode")
local FMC_ORDER = {{M.L, M.C, M.R}, {M.R, M.C, M.L}}

local function three(v) return {v, v, v} end

function M.inputs()
    return {
        att_valid = three(true),    -- laminar/B747/irs/att_valid[0..2]
        hdg_valid = three(true),    -- laminar/B747/irs/hdg_valid[0..2]
        nav_valid = three(true),    -- laminar/B747/irs/nav_valid[0..2]
        irs = {M.L, M.R},           -- each pilot's IRS source selector (the IRU)
        fmc = {1, 2},               -- each pilot's NAV source: the FMC (1 L, 2 R), 0 a CDU
        air_data = {true, true},    -- each pilot's air data valid
    }
end

local function side_out()
    return {
        att = false,        -- the attitude shown (else the ATT flag)
        hdg = false,        -- the heading scale shown (else the HDG flag)
        hdg_iru = 0,        -- the IRU the heading comes from, 0 none
        trk = false,        -- the track indicator shown
        vsi = false,        -- the vertical speed shown
        vert = false,       -- the VERT flag
    }
end

function M.new()
    return {out = {side_out(), side_out()}}
end

function M.update(s, inp)
    for p = M.CAPT, M.FO do
        local o = s.out[p]
        local sel = inp.irs[p]
        -- the attitude: the selected IRU (NAV, or ATT after its 30 s)
        o.att = inp.att_valid[sel]
        -- the heading: an IRU in NAV through the FMC when the NAV source is
        -- an FMC, whatever the IRS selector (FCOM p.1228); else the selected
        -- IRU (NAV, or ATT with a heading set)
        local iru = 0
        if inp.fmc[p] > 0 then
            for _, i in ipairs(FMC_ORDER[p]) do
                if inp.nav_valid[i] then iru = i; break end
            end
        end
        if iru == 0 and inp.hdg_valid[sel] then iru = sel end
        o.hdg_iru = iru
        o.hdg = iru > 0
        -- the track: the FMC's, else the selected IRU's (FCOM p.997); an IRU
        -- gives it in NAV only
        o.trk = (iru > 0 and inp.nav_valid[iru]) or inp.nav_valid[sel]
        -- the vertical speed: the ADC's smoothed by the selected IRU's
        -- inertial vertical speed (FCOM p.996), which only NAV gives
        -- (estimate). The inertial one invalid: the VERT flag; the air data
        -- invalid: removed without a flag (ATA31 p.16)
        o.vert = not inp.nav_valid[sel]
        o.vsi = not o.vert and inp.air_data[p]
    end
    return s.out
end

return M
