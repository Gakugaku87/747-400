-- The FMC's tuning of the VOR and ADF radios (6-1/6-2 step 10b;
-- notes/ATA-34-61-FMC.md §87): NAV RADIO's VOR and ADF entries and the
-- FMC's choice of the VOR stations. Logic and sources:
--  - VOR L and R (FCOM p.1303-1304; FMSPG p.206-207; ATA34_2 p.605-606):
--    P (procedure: a navaid the active procedure needs), R (route: the
--    previous VOR or a downpath VOR within 250 nm), A (the best for the
--    position), M (manual: an identifier of a VOR or a DME not an ILS's,
--    a frequency, either with /course; manual first, DELETE back to the
--    FMC's tuning and the course cleared). The course: blank when the FMC
--    tunes, dashes or the entry when manual (a three-digit course).
--  - ADF L and R (FCOM p.1304; FMSPG p.207; ATA34_2 p.586): manual only,
--    XXX.X or XXXX.X, A (ANT) or B (BFO) after it or alone; DELETE takes
--    ANT or BFO back to ADF, no other deletion.
-- Estimates (none in the sources): VOR L takes the first of the
-- procedure's navaid, the downpath route VOR, the previous one, the
-- position's stations, VOR R the next not on VOR L; with none the radio
-- keeps its station. The position's stations: the DME-DME pair's (the
-- glue's), else the nearest VOR/DMEs in reach. A station by identifier
-- the nearest; VOR frequencies 108.00-117.95 on 50 kHz, ADF 190-1750 kHz.
--
--   local M = B747_tune_model              -- in XTLua, after dofile
--   local s = M.new()
--   M.choose(s, cands)                     -- the FMC's stations, each update

local M = setmetatable({}, {})
B747_tune_model = M

M.ROUTE_NM = 250
M.VOR_LO, M.VOR_HI = 10800, 11795           -- 10 kHz
M.ADF_LO, M.ADF_HI = 190, 1750              -- kHz
M.OK, M.INVALID, M.INVALID_DELETE, M.NOT_IN_DB = "ok", "INVALID ENTRY", "INVALID DELETE", "NOT IN DATA BASE"

function M.new()
    return {
        -- each VOR: mode ("P", "R", "A", "M"), st (a station: {ident, freq
        -- (10 kHz), lat, lon}; a manual frequency without ident), crs
        vor = {{}, {}},
        -- each ADF: khz (the entry, tenths), mode ("ADF", "ANT", "BFO")
        adf = {{mode = "ADF"}, {mode = "ADF"}},
        -- the ILS (step 10c): the crew's (mode "M", st); the FMC's output
        ils = {}, ils_out = nil,
    }
end

local function same(a, b)
    if not (a and b) then return false end
    if a.ident and b.ident then
        return a.ident == b.ident and math.abs((a.lat or 0) - (b.lat or 0)) < 0.01 and math.abs((a.lon or 0) - (b.lon or 0)) < 0.01
    end
    return a.freq == b.freq
end
M.same = same

-- a VOR frequency: 108.00-117.95 on 50 kHz channels, 10 kHz units
local function vor_freq(text)
    local int, frac = string.match(text, "^(1%d%d)%.(%d%d?)$")
    if not int then int, frac = string.match(text, "^(1%d%d)$"), "0" end
    if not int then return nil end
    if string.len(frac) == 1 then frac = frac .. "0" end
    local f = tonumber(int) * 100 + tonumber(frac)
    if f < M.VOR_LO or f > M.VOR_HI or f % 5 ~= 0 then return nil end
    return f
end
-- a course: one to three digits, 0-360 (360 as 0)
local function course(text)
    if not string.match(text, "^%d%d?%d?$") then return nil end
    local c = tonumber(text)
    if c > 360 then return nil end
    return c % 360
end
M.vor_freq, M.course = vor_freq, course

-- VOR L or R's entry (`find(ident)`: the nearest VOR or DME not an ILS's
-- with it, a station, or false when the identifier is another navaid's
-- or point's, nil when none has it)
function M.vor_entry(s, side, text, find)
    local v = s.vor[side]
    if text == "DELETE" then
        if v.mode ~= "M" then return M.INVALID_DELETE end
        s.vor[side] = {}
        return M.OK
    end
    local id, crsText = string.match(text, "^([%w%.]+)/(%d+)$")
    if not id then id = text end
    local crs = nil
    if crsText then
        crs = course(crsText)
        if not crs then return M.INVALID end
    end
    local f = vor_freq(id)
    local st
    if f then
        st = {freq = f}
    elseif string.match(id, "^%w%w?%w?%w?$") and string.match(id, "%a") then
        st = find(id)
        if st == nil then return M.NOT_IN_DB end
        if st == false then return M.INVALID end
    else
        return M.INVALID
    end
    s.vor[side] = {mode = "M", st = st, crs = crs}
    return M.OK
end

-- the course: only with a manual VOR (dashes or a course); DELETE clears it
function M.crs_entry(s, side, text)
    local v = s.vor[side]
    if v.mode ~= "M" then return text == "DELETE" and M.INVALID_DELETE or M.INVALID end
    if text == "DELETE" then
        if not v.crs then return M.INVALID_DELETE end
        v.crs = nil
        return M.OK
    end
    local c = course(text)
    if not c then return M.INVALID end
    v.crs = c
    return M.OK
end

-- ADF L or R's entry (`khz`: the radio's frequency now, for A or B alone)
function M.adf_entry(s, side, text, khz)
    local a = s.adf[side]
    if text == "DELETE" then
        if a.mode == "ADF" then return M.INVALID_DELETE end
        a.mode = "ADF"
        return M.OK
    end
    local num, sfx = string.match(text, "^(%d%d%d%d?%.?%d?)([AB]?)$")
    if not num then
        sfx = string.match(text, "^([AB])$")
        if not sfx or not (khz and khz > 0) then return M.INVALID end
        a.mode = sfx == "A" and "ANT" or "BFO"
        return M.OK
    end
    if string.sub(num, -1) == "." then return M.INVALID end
    local f = tonumber(num)
    if not f or f < M.ADF_LO or f > M.ADF_HI then return M.INVALID end
    a.khz = f
    a.mode = sfx == "A" and "ANT" or (sfx == "B" and "BFO" or "ADF")
    return M.OK
end

-- the FMC's stations for the VORs not manual: `cands` in order ({st, mode
-- ("P", "R", "A"), crs}); VOR L the first, VOR R the next not on the
-- other; a radio with none keeps its station
function M.choose(s, cands)
    local taken = {}
    for side = 1, 2 do
        local v = s.vor[side]
        if v.mode == "M" then taken[#taken + 1] = v.st end
    end
    for side = 1, 2 do
        local v = s.vor[side]
        if v.mode ~= "M" then
            local pick = nil
            for _, c in ipairs(cands) do
                local used = false
                for _, t in ipairs(taken) do if same(c.st, t) then used = true break end end
                if not used then pick = c break end
            end
            if pick then
                s.vor[side] = {mode = pick.mode, st = pick.st, crs = pick.crs}
                taken[#taken + 1] = pick.st
            end
        end
    end
end

-- the candidates in the FMC's order: the procedure's navaids (P), the
-- downpath and the previous route VORs within 250 nm (R), the position's
-- stations (A); the same station once
function M.candidates(proc, nextVor, prevVor, auto)
    local list = {}
    local function add(st, mode, crs)
        if not st then return end
        for _, c in ipairs(list) do if same(c.st, st) then return end end
        list[#list + 1] = {st = st, mode = mode, crs = crs}
    end
    for _, p in ipairs(proc or {}) do add(p.st, "P", p.crs) end
    add(nextVor, "R")
    add(prevVor, "R")
    for _, a in ipairs(auto or {}) do add(a, "A") end
    return list
end

-- (6-1/6-2 step 10c; notes/ATA-34-61-FMC.md §88) the ILS (FCOM p.1304-1307;
-- FMSPG p.208; ATA34_2 p.470, p.586): PARK (at power up, and far); the
-- destination runway's frequency/course small with PARK (STBY: within
-- 200 nm of the T/D and past halfway, whichever is nearer the
-- destination); A (within 50 nm of the T/D, 150 nm of the threshold, or
-- in the descent; not for ten minutes after takeoff); M (XXX.XX/YYY, /YYY
-- with a frequency shown, the standby line's select; DELETE back to the
-- FMC). The FCCs' ILS TUNE INHIBIT holds the tuning, an entry then ILS
-- TUNE INHIBITED - MCP (FCOM p.1432). RW/ILS FREQ ERROR and CRS ERROR
-- (FCOM p.1434): the tuned ILS not the destination runway's (estimates:
-- while the FMC would tune it; the course 5 degrees off).
M.ILS_LO, M.ILS_HI = 10810, 11195           -- 10 kHz, odd tenths
M.STANDBY_TD_NM, M.AUTO_TD_NM, M.AUTO_THR_NM = 200, 50, 150
M.TAKEOFF_S = 600
M.CRS_ERR_DEG = 5
M.ILS_INHIBITED = "ILS TUNE INHIBITED - MCP"

-- an ILS frequency: 108.10-111.95, odd tenths, 50 kHz channels
local function ils_freq(text)
    local int, frac = string.match(text, "^(1%d%d)%.(%d%d?)$")
    if not int then return nil end
    if string.len(frac) == 1 then frac = frac .. "0" end
    local f = tonumber(int) * 100 + tonumber(frac)
    if f < M.ILS_LO or f > M.ILS_HI or f % 5 ~= 0 or math.floor(f / 10) % 2 ~= 1 then return nil end
    return f
end
M.ils_freq = ils_freq

-- the ILS line's entry (`shown`: the frequency/course shown, `inhibited`:
-- the FCCs' ILS TUNE INHIBIT)
function M.ils_entry(s, text, shown, inhibited)
    if inhibited then return M.ILS_INHIBITED end
    s.ils = s.ils or {}
    if text == "DELETE" then
        if s.ils.mode ~= "M" then return M.INVALID_DELETE end
        s.ils = {}
        return M.OK
    end
    local fText, cText = string.match(text, "^([%d%.]*)/(%d%d?%d?)$")
    if not fText then return M.INVALID end
    local crs = course(cText)
    if not crs then return M.INVALID end
    local f
    if fText == "" then
        if not (shown and shown.freq) then return M.INVALID end
        f = shown.freq
    else
        f = ils_freq(fText)
        if not f then return M.INVALID end
    end
    s.ils = {mode = "M", st = {freq = f, crs = crs}}
    return M.OK
end
-- the standby line's select: the shown ILS manually tuned (FCOM p.1306)
function M.ils_select(s, shown, inhibited)
    if inhibited then return M.ILS_INHIBITED end
    if not (shown and shown.freq) then return M.INVALID end
    s.ils = {mode = "M", st = {freq = shown.freq, crs = shown.crs, ident = shown.ident}}
    return M.OK
end

-- the FMC's ILS each update: `inp` = {ils (the destination runway's:
-- {freq, crs, ident}), standby, auto, after_takeoff (the ten minutes),
-- inhibit (the FCCs')}. The state's out: mode ("PARK", "STBY", "A", "M"),
-- st (the ILS shown), tune (the receivers': A, M), freq_err, crs_err,
-- held_change (the destination's ILS changed while inhibited)
function M.ils_update(s, inp)
    s.ils = s.ils or {}
    local o = s.ils_out
    if not o then o = {mode = "PARK"}; s.ils_out = o end
    local held = inp.inhibit and o.mode ~= "STBY" and o.mode ~= "PARK"
    o.held_change = held and o.mode == "A" and inp.ils ~= nil and not same(inp.ils, o.st)
    if s.ils.mode == "M" then
        o.mode, o.st = "M", s.ils.st
    elseif held then
        -- the tuning held
    elseif inp.ils and inp.auto and not inp.after_takeoff then
        o.mode, o.st = "A", inp.ils
    elseif inp.ils and (inp.standby or inp.auto) then
        o.mode, o.st = "STBY", inp.ils
    else
        o.mode, o.st = "PARK", nil
    end
    o.tune = (o.mode == "A" or o.mode == "M") and o.st or nil
    local check = o.tune ~= nil and inp.ils ~= nil and inp.auto and true or false
    o.freq_err = check and o.tune.freq ~= inp.ils.freq
    o.crs_err = check and o.tune.freq == inp.ils.freq
        and math.abs((o.tune.crs - inp.ils.crs + 180) % 360 - 180) > M.CRS_ERR_DEG
    return o
end

-- the CDU's texts: a VOR frequency 116.80, an ADF frequency 1304.5, an ILS
-- 110.90/130
function M.freq_text(f) return f and string.format("%6.2f", f / 100) or "" end
function M.adf_text(khz) return khz and string.format("%.1f", khz) or "" end
function M.ils_text(st) return st and string.format("%6.2f/%03d", st.freq / 100, math.floor(st.crs + 0.5) % 360) or "" end

return M
