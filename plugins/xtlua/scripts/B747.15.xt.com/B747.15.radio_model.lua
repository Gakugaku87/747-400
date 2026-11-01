-- 747-400 communication radios and radio tuning panels without X-Plane
-- (7-1a; docs/overhaul/notes/ATA-23.md §11): five radios (VHF L, C, R and
-- HF L, R), each with its active and standby frequencies, VHF C's data
-- mode (ACARS) and the HF's AM or USB, and three panels (RTP L, C, R),
-- each with the radio it tunes, OFF and the offside tuning light (FCOM
-- p.685-688, p.714-715):
--  - any panel tunes any radio; a panel's knobs set the standby frequency
--    of its radio, the transfer switch swaps standby and active (the radio
--    tuned to the new active); the radios keep their frequencies whatever
--    the panels show
--  - OFF disconnects the panel: no tuning, its windows blank (estimate)
--  - the offside light: the panel tunes a radio of another panel, or
--    another panel tunes its own (L: VHF L and HF L; C: VHF C; R: VHF R
--    and HF R)
--  - the AM switch sets the selected HF's AM or USB (before, it was taken
--    as a radio: COM-04)
--  - VHF C carries ACARS (data) normally (109); ACARS in a window is
--    M.DATA. The standby shows ACARS when the transfer would put VHF C in
--    data mode (after a transfer from data, or, estimate, the MHz knob
--    turned below 118)
-- VHF L and R are X-Plane's COM1 and COM2: their frequencies stay in
-- X-Plane's datarefs and the glue tunes them with X-Plane's commands; the
-- model keeps VHF C's and the HF's. The 109's VHF on 25 kHz channels, the
-- 570's on 8.33 kHz ones (FCOM p.714: "405, 570").
--   local R = B747_radio_model                     -- in XTLua, after dofile
--   local R = dofile(".../B747.15.radio_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_radio_model = M

M.RADIOS = {"vhf_L", "vhf_C", "vhf_R", "hf_L", "hf_R"}
M.PANELS = {"L", "C", "R"}
M.ONSIDE = {L = {vhf_L = true, hf_L = true}, C = {vhf_C = true}, R = {vhf_R = true, hf_R = true}}
M.DATA = 0
-- kHz; the HF's range and step are not in the sources (estimate)
M.VHF_LO, M.VHF_HI, M.VHF_STEP = 118000, 136975, 25
M.HF_LO, M.HF_HI, M.HF_STEP = 2000, 29999, 1
-- the windows (laminar/B747/comm/rtp_*/lcd_to_display, the active one and
-- the old standby ones; rtp_*/stby_show, the standby window; notes §6.2):
-- VHF L (X-Plane's COM1), VHF R (COM2), VHF C, HF L, HF R, VHF C's ACARS,
-- blank
M.SHOW = {vhf_L = 0, vhf_R = 1, vhf_C = 2, hf_L = 3, hf_R = 4, acars = 98, blank = 90}

local function is_hf(r) return r == "hf_L" or r == "hf_R" end

function M.new()
    return {
        radio = {
            vhf_C = {active = M.DATA, standby = 131550},
            hf_L = {active = 8891, standby = 11330, am = false},
            hf_R = {active = 5598, standby = 13306, am = false},
        },
        rtp = {L = {sel = "vhf_L", off = false}, C = {sel = "vhf_C", off = false}, R = {sel = "vhf_R", off = false}},
    }
end

-- a radio tuning switch
function M.select(s, panel, radio)
    local p = s.rtp[panel]
    if not p.off then p.sel = radio end
end

-- the OFF switch
function M.off(s, panel)
    local p = s.rtp[panel]
    p.off = not p.off
end

-- the AM switch: the selected HF's AM or USB
function M.am(s, panel)
    local p = s.rtp[panel]
    if p.off or not is_hf(p.sel) then return end
    local r = s.radio[p.sel]
    r.am = not r.am
end

-- a step of a frequency (kHz) within its band, the MHz part (the outer
-- knob) or the kHz part (the inner), wrapping as the panel's knobs do
-- (estimate); spacing: the VHF's channel spacing (25, or 8.33 on the 570)
local function step_khz(f, band_lo, band_hi, knob, dir, kstep)
    local mhz, khz = math.floor(f / 1000), f % 1000
    if knob == "MHz" then
        local lo, hi = math.floor(band_lo / 1000), math.floor(band_hi / 1000)
        mhz = mhz + dir
        if mhz > hi then mhz = lo elseif mhz < lo then mhz = hi end
    else
        khz = khz + dir * kstep
        if khz >= 1000 then khz = 0 elseif khz < 0 then khz = 1000 - kstep end
    end
    return math.max(band_lo, math.min(band_hi, mhz * 1000 + khz))
end

-- (model radios) a knob turned on a panel: the selected radio's standby;
-- X-Plane's radios (VHF L, R) are the glue's: returns "xp", the radio
function M.knob(s, panel, knob, dir)
    local p = s.rtp[panel]
    if p.off or not p.sel then return nil end
    if p.sel == "vhf_L" or p.sel == "vhf_R" then return "xp", p.sel end
    local r = s.radio[p.sel]
    if p.sel == "vhf_C" then
        if r.standby == M.DATA then
            -- out of ACARS: the band's lowest (turned up) or highest (down)
            r.standby = dir > 0 and M.VHF_LO or M.VHF_HI
        elseif knob == "MHz" and dir < 0 and r.standby < M.VHF_LO + 1000 then
            -- (estimate) below 118: ACARS
            r.standby = M.DATA
        else
            r.standby = step_khz(r.standby, M.VHF_LO, M.VHF_HI, knob, dir, M.VHF_STEP)
        end
    else
        r.standby = step_khz(r.standby, M.HF_LO, M.HF_HI, knob, dir, M.HF_STEP)
    end
    return nil
end

-- the transfer switch: standby and active swapped (X-Plane's radios: the
-- glue's flip; returns "xp", the radio)
function M.transfer(s, panel)
    local p = s.rtp[panel]
    if p.off or not p.sel then return nil end
    if p.sel == "vhf_L" or p.sel == "vhf_R" then return "xp", p.sel end
    local r = s.radio[p.sel]
    r.active, r.standby = r.standby, r.active
    return nil
end

-- the panels' lights and windows: {L = {offside, show, stby}}: show the
-- active window's, stby the standby window's
-- (powered: panel -> true when the panel has power)
function M.panels(s, powered)
    local out = {}
    for _, name in ipairs(M.PANELS) do
        local p = s.rtp[name]
        local o = {offside = false, show = M.SHOW.blank, stby = M.SHOW.blank}
        if not p.off and powered[name] and p.sel then
            if not M.ONSIDE[name][p.sel] then o.offside = true end
            o.show, o.stby = M.SHOW[p.sel], M.SHOW[p.sel]
            if p.sel == "vhf_C" then
                local r = s.radio.vhf_C
                if r.active == M.DATA then o.show = M.SHOW.acars end
                if r.standby == M.DATA then o.stby = M.SHOW.acars end
            end
        end
        out[name] = o
    end
    -- another panel tuning this panel's radio
    for _, name in ipairs(M.PANELS) do
        for _, other in ipairs(M.PANELS) do
            local q = s.rtp[other]
            if other ~= name and not q.off and powered[other] and q.sel and M.ONSIDE[name][q.sel] then
                if powered[name] and not s.rtp[name].off then out[name].offside = true end
            end
        end
    end
    return out
end

-- VHF C in data mode (ACARS through VHF C)
function M.vhf_c_data(s) return s.radio.vhf_C.active == M.DATA end

return M
