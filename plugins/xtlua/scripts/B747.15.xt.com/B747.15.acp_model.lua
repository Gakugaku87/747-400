-- 747-400 audio control panels without X-Plane (7-1b;
-- docs/overhaul/notes/ATA-23.md §12): each seat's panel (L the Captain's,
-- C the observer's, R the F/O's) on its own (FCOM p.683-685; ATA23 p.30-31,
-- p.54):
--  - one transmitter selected (VHF L, C, R, FLT, CAB, PA, HF L, R, SAT L,
--    R), its MIC light; selecting it also puts its receiver on. Before, VHF
--    L and R pressed on one panel selected them on all three (COM-02)
--  - each receiver pushed on and off (its volume knob), its light showing
--    a receiver put on by hand (estimate: FCOM p.683, p.685; before, the
--    transmitter's own lit it too: COM-13). Not off while it is the seat's
--    transmitter, or a VHF's active frequency is 121.500 (FCOM p.685)
--  - the VOR/ADF and APP receiver selectors and the navigation filter per
--    seat (before, one panel's turned all three: COM-02)
-- Pure: the glue gives the 121.5 VHF and maps the seats to X-Plane's
-- audio panels (the Captain's the pilot's, the F/O's the copilot's).
--   local A = B747_acp_model                     -- in XTLua, after dofile
--   local A = dofile(".../B747.15.acp_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_acp_model = M

M.SEATS = {"L", "C", "R"}
M.XMT = {"vhf_L", "vhf_C", "vhf_R", "flt", "cab", "pa", "hf_L", "hf_R", "sat_L", "sat_R"}
M.RCV = {"vhf_L", "vhf_C", "vhf_R", "flt", "cab", "pa", "hf_L", "hf_R", "sat_L", "sat_R", "spkr", "vor_adf", "app_mkr"}
-- the selectors' positions (the datarefs' values)
M.VOR_ADF = {[0] = "vor_L", "vor_R", "adf_L", "adf_R"}
M.APP = {[0] = "ils_L", "ils_C", "ils_R", "mkr"}
M.FILTER = {[0] = "V", "B", "R"} -- voice, both, range (the identifier)

function M.new()
    local s = {seat = {}}
    for _, seat in ipairs(M.SEATS) do s.seat[seat] = {xmt = nil, man = {}} end
    return s
end

-- a transmitter selector pushed
function M.xmt(s, seat, ch)
    s.seat[seat].xmt = ch
end

-- a receiver pushed: on, or off unless it is the seat's transmitter or held
-- on (a VHF on 121.5)
function M.rcv(s, seat, ch, held)
    local p = s.seat[seat]
    if not p.man[ch] then
        p.man[ch] = true
    elseif p.xmt ~= ch and not held then
        p.man[ch] = false
    end
end

-- what a seat hears of a channel: by hand, its transmitter, or 121.5
function M.hears(s, seat, ch, held)
    local p = s.seat[seat]
    return (p.man[ch] or p.xmt == ch or held) and true or false
end

-- a seat's navigation audio (X-Plane's receivers: the glue's names):
-- returns {receiver = volume knob's channel} for the receivers heard. The
-- VOR/ADF receiver gives the selected VOR or ADF, the APP receiver the
-- selected ILS or the markers; the filter V (voice) takes the identifiers
-- out (X-Plane's navigation audio is the identifier: estimate), the
-- markers not filtered (ATA23 p.28, p.71-72)
function M.nav_audio(s, seat, sel)
    local out = {}
    local idents = M.FILTER[sel.filter] ~= "V"
    if M.hears(s, seat, "vor_adf") and idents then
        out[M.VOR_ADF[sel.vor_adf]] = "vor_adf"
    end
    if M.hears(s, seat, "app_mkr") then
        local a = M.APP[sel.app]
        if a == "mkr" or idents then out[a] = "app_mkr" end
    end
    return out
end

return M
