-- A CDU's ALTN NAV RADIO (6-1/6-2 step 11e3; notes/ATA-34-61-FMC.md §104).
-- Logic and sources (FCOM p.1422, p.1427-1428; FMSPG p.252-254; ATA34_2
-- p.592):
--  - With no FMC to connect to, each CDU tunes its own side's radios by
--    hand (no autotune): the left CDU VOR L with its DME, ADF L and ILS L,
--    the right CDU the right ones, the centre CDU the centre ILS (FCOM
--    p.1422). The FMC sends its tuning at each change (FMSPG p.252): the
--    CDU starts on what the FMC tuned, the ILS too (FCOM p.1428).
--  - VOR (1L): a frequency or frequency/course, tuned M; DELETE dashes.
--    CRS (2L): a course or frequency/course; DELETE clears it. Both blank
--    on the centre CDU (FCOM p.1427).
--  - ADF (3L): a frequency, A (ANT) or B (BFO) after it, or A or B alone
--    with one; DELETE dashes (FCOM p.1428; FMSPG p.253). Blank on the
--    centre CDU (ATA34_2 p.592).
--  - ILS-MLS (4L): a frequency (its course the active route's runway's,
--    else the last one or 000), frequency/course, /course with a
--    frequency; DELETE parks it (PARK) (FCOM p.1428).
--  - PRESELECT (6L, 6R): any entry valid on a line, kept; with an empty
--    scratchpad its line select key copies it there (FMSPG p.254).
-- Estimates: a course without a frequency on the VOR line INVALID ENTRY;
-- DELETE on a PRESELECT line clears it.
--
--   local M = B747_altn_radio_model    -- in XTLua, after dofile (and the tune model's)

local M = setmetatable({}, {})
B747_altn_radio_model = M
local TM = B747_tune_model

M.INVALID, M.INVALID_DELETE = "INVALID ENTRY", "INVALID DELETE"

function M.new()
    return {vor = {}, adf = {mode = "ADF"}, ils = {}, pre = {}}
end

-- the copy of what the FMC tuned (`r`: vor_freq, vor_crs (10 kHz, deg),
-- adf_khz, adf_mode ("ADF", "ANT", "BFO"), ils_freq, ils_crs; nil parts
-- untuned)
function M.copy(s, r)
    s.vor = {freq = r.vor_freq, crs = r.vor_crs}
    s.adf = {khz = r.adf_khz, mode = r.adf_khz and (r.adf_mode or "ADF") or "ADF"}
    s.ils = {freq = r.ils_freq, crs = r.ils_crs or s.ils.crs}
end

local function is_course(text) return string.match(text, "^%d%d?%d?$") and TM.course(text) end
-- "F/C", "/C" or "F" with `freqf` the frequency's parser: frequency (or
-- false for "/C"), course; nil when neither
local function freq_crs(text, freqf)
    local f, c = string.match(text, "^([%d%.]*)/(%d%d?%d?)$")
    if f then
        local crs = TM.course(c)
        if not crs then return nil end
        if f == "" then return false, crs end
        local fr = freqf(f)
        if not fr then return nil end
        return fr, crs
    end
    local fr = freqf(text)
    if fr then return fr, nil end
    return nil
end

function M.vor(s, text)
    if text == "DELETE" then
        if not s.vor.freq then return M.INVALID_DELETE end
        s.vor = {}
        return nil
    end
    local f, c = freq_crs(text, TM.vor_freq)
    if not f then return M.INVALID end
    s.vor.freq = f
    if c then s.vor.crs = c end
    return nil
end

function M.crs(s, text)
    if text == "DELETE" then
        if not s.vor.crs then return M.INVALID_DELETE end
        s.vor.crs = nil
        return nil
    end
    local c = is_course(text)
    if c then s.vor.crs = c return nil end
    local f, cc = freq_crs(text, TM.vor_freq)
    if f == nil or not cc then return M.INVALID end
    if f then s.vor.freq = f end
    s.vor.crs = cc
    return nil
end

function M.adf(s, text)
    if text == "DELETE" then
        if not s.adf.khz then return M.INVALID_DELETE end
        s.adf = {mode = "ADF"}
        return nil
    end
    local num, sfx = string.match(text, "^(%d%d%d%d?%.?%d?)([AB]?)$")
    if not num then
        sfx = string.match(text, "^([AB])$")
        if not sfx or not s.adf.khz then return M.INVALID end
        s.adf.mode = sfx == "A" and "ANT" or "BFO"
        return nil
    end
    if string.sub(num, -1) == "." then return M.INVALID end
    local f = tonumber(num)
    if not f or f < TM.ADF_LO or f > TM.ADF_HI then return M.INVALID end
    s.adf = {khz = f, mode = sfx == "A" and "ANT" or (sfx == "B" and "BFO" or "ADF")}
    return nil
end

-- `rwy_crs`: the active route's runway's course (nil without one)
function M.ils(s, text, rwy_crs)
    if text == "DELETE" then
        if not s.ils.freq then return M.INVALID_DELETE end
        s.ils.freq = nil
        return nil
    end
    local f, c = freq_crs(text, TM.ils_freq)
    if f == nil then return M.INVALID end
    if f == false then
        if not s.ils.freq then return M.INVALID end
        s.ils.crs = c
        return nil
    end
    s.ils.freq = f
    s.ils.crs = c or rwy_crs or s.ils.crs or 0
    return nil
end

-- an entry valid on one of the lines
local function valid_any(text)
    if is_course(text) or text == "A" or text == "B" then return true end
    if freq_crs(text, TM.vor_freq) ~= nil or freq_crs(text, TM.ils_freq) ~= nil then return true end
    local num = string.match(text, "^(%d%d%d%d?%.?%d?)[AB]?$")
    local f = num and string.sub(num, -1) ~= "." and tonumber(num)
    return f ~= nil and f ~= false and f >= TM.ADF_LO and f <= TM.ADF_HI
end
function M.preselect(s, k, text)
    if text == "DELETE" then
        if not s.pre[k] then return M.INVALID_DELETE end
        s.pre[k] = nil
        return nil
    end
    if not valid_any(text) then return M.INVALID end
    s.pre[k] = text
    return nil
end

return M
