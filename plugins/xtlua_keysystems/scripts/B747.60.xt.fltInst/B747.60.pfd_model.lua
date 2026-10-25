-- 747-400 PFD sources (5-2 step 4a): what each pilot's PFD can show from the
-- IRS and the air data, as the EIU picks the sources: the attitude, the
-- heading, the track and the vertical speed, and the ATT, HDG and VERT
-- flags. The values themselves are X-Plane's pilot and copilot AHRS (they
-- stand for each pilot's IRU, as for >ATTITUDE and >HEADING). Step 4b: the
-- barometric setting's amber box at the transition altitude (baro_alert).
-- Step 4d: the flight path vector's place (fpv_place) and the PITCH and
-- ROLL flags (attitude_disagree).
-- Logic and sources: docs/overhaul/notes/ATA-31.md §15-§17 (FCOM p.995-999,
-- p.1044, p.1228; ATA31 p.15-17).
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

-- the barometric setting boxed in amber (step 4b; FCOM p.995 (10.10.33)): a
-- setting set (not STD), the MCP altitude above the transition altitude and
-- the airplane 300 ft above it; or STD, the MCP altitude below the
-- transition altitude and the airplane 300 ft below the transition level
-- (the FCOM's words: "MCP altitude below transition altitude ... below
-- transition flight level"). alt_ft is that side's barometric altitude.
-- The FMC's defaults: transition altitude 18,000 ft (FCOM p.1329), level
-- FL180 (FCOM p.1396)
M.TRANS_ALT_FT, M.TRANS_LVL_FT, M.BARO_MARGIN_FT = 18000, 18000, 300
function M.baro_alert(std, alt_ft, mcp_ft, trans_alt_ft, trans_lvl_ft)
    if std then
        return mcp_ft < trans_alt_ft and alt_ft < trans_lvl_ft - M.BARO_MARGIN_FT
    end
    return mcp_ft > trans_alt_ft and alt_ft > trans_alt_ft + M.BARO_MARGIN_FT
end

-- the flight path vector's place (step 4d; FCOM p.980 (10.10.18)): the
-- flight path angle above the horizon and the drift angle across the pitch
-- scale's centreline, both in the attitude display's frame, which turns
-- with the bank (right bank: the frame turns anticlockwise). Returned as
-- panel pixels from the display's centre (x right, y up), 6.81 a degree as
-- the pitch scale (the RA's pitch limits, panel_pfd_tcas.lua), held inside
-- the attitude display (estimate)
M.PX_PER_DEG = 232 / 34.06199
M.FPV_MAX_X, M.FPV_MAX_Y = 110, 140
function M.fpv_place(pitch, roll, fpa, drift)
    local v = (fpa - pitch) * M.PX_PER_DEG
    local h = drift * M.PX_PER_DEG
    local r = math.rad(roll)
    local c, s = math.cos(r), math.sin(r)
    local x = math.max(-M.FPV_MAX_X, math.min(M.FPV_MAX_X, h * c - v * s))
    local y = math.max(-M.FPV_MAX_Y, math.min(M.FPV_MAX_Y, h * s + v * c))
    return x, y
end

-- the PITCH and ROLL flags (FCOM p.975, p.977): the Captain's and the F/O's
-- attitudes apart by the >ATTITUDE comparison's 3 degrees (FCOM p.1197;
-- the flags' own threshold is not given: estimate)
M.ATT_DISAGREE_DEG = 3
function M.attitude_disagree(pitch1, roll1, pitch2, roll2)
    local dp = math.abs(pitch1 - pitch2)
    local dr = math.abs((roll1 - roll2 + 180) % 360 - 180)
    return dp >= M.ATT_DISAGREE_DEG, dr >= M.ATT_DISAGREE_DEG
end

return M
