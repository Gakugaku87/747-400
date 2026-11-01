-- 747-400 FMC ATC requests without X-Plane (6-1/6-2 step 12g2a; docs/
-- overhaul/notes/ATA-34-61-FMC.md §116): a request's data and its message
-- (FCOM p.736-747; FMSPG p.298-327):
--   ALTITUDE  XXX or FLXXX (FL030 to the maximum certified altitude,
--             FL451), XXXXX feet (0-25,000), XXXXXM metres (0-16,000), or a
--             block of feet or flight levels (XXXXX/XXXXX, FLXXX/FLXXX); the
--             element chosen at the entry by the altitude then (more than
--             150 ft above: CLIMB TO, below: DESCENT TO, else level); STEP
--             AT a position or a time (a climb or a descent, no CRZ CLB),
--             CRZ CLB (a climb, no STEP AT), AT PILOT DISC, MAINTAIN OWN
--             SEPARATION/VMC, DUE TO PERFORMANCE, DUE TO WEATHER; its
--             deletion deletes these;
--   SPEED     IAS 100-380 to the nearest 10 kt, or Mach .XXX .61-.91 to the
--             nearest .01; DUE TO PERFORMANCE, DUE TO WEATHER;
--   OFFSET    L or R and 1-99 NM, or just the distance (FCOM p.737); OFFSET
--             AT a position or a time, or DUE TO WEATHER (WEATHER DEVIATION
--             UP TO: one or the other);
--   ROUTE     DIRECT TO a position, HEADING and GROUND TRACK 000-360;
--             (step 12g2b) RTE 1 or RTE 2 (one or the other: REQUEST ROUTE
--             CLEARANCE with the route, the FMS's text of it), DEP/ARR (a
--             procedure, with its transition: REQUEST [procedure name]);
-- no more than five elements (MSG LIMIT EXCEEDED: FMSPG p.298); the
-- CLEARANCE and VOICE requests of ATC INDEX (FMSPG p.298-300); (step 12g3a)
-- WHEN CAN WE EXPECT's (kind "WCW": FCOM p.769-770; FMSPG p.319-323): CRZ
-- CLB TO, CLIMB TO, DESCENT TO (an altitude, no block), HIGHER ALT, LOWER
-- ALT (one of these five), SPEED, BACK ON RTE. A position
-- is checked by the FMS (B747_fmc_with_fix) and set here by its name.
-- VERIFY REQUEST's rows: each element's lines, the fixed words small in
-- the header and the values large (FCOM p.744; FMSPG p.299-300, p.324),
-- the next element's header after a "/", then the free text lines ("<")
-- to the page's fourth line (FMSPG p.325: at least one; four without an
-- element). Estimates: how the elements without a value are split into
-- lines; the text sent the elements' words joined with spaces; the time
-- XXXXZ.
--
--   local Q = B747_atc_request_model
--   local r = Q.new("REQUEST")
--   local err = Q.enter(r, "alt", "FL350", present_ft)   -- nil or the message
--   Q.select(r, "alt_wx") ; Q.delete(r, "alt")
--   local rows = Q.verify_rows(r, true)                 -- {head, data, unit, free}
--   local text = Q.text(r)                              -- "REQUEST CLIMB TO FL350 DUE TO WEATHER"

local M = setmetatable({}, {})
B747_atc_request_model = M
M.INVALID = "INVALID ENTRY"
M.LIMIT = "MSG LIMIT EXCEEDED"
M.MAX_ELEMENTS = 5
M.LEVEL_FT = 150          -- within it of the altitude now: a level request (FMSPG p.304)
M.MAX_FL = 451            -- the maximum certified altitude, 45,100 ft (FCOM p.1311)
M.FREE_LINES = 4
M.ROWS = 5                -- a page's rows (lines 1-5)

-- kind: "REQUEST" (the ATC REQUEST pages), "CLEARANCE", "VOICE" (ATC INDEX),
-- "WCW" (WHEN CAN WE EXPECT)
function M.new(kind)
    return {kind = kind or "REQUEST", alt = nil, alt_dir = nil, step_at = nil, pilot_disc = false,
        crz_clb = false, own_sep = false, alt_perf = false, alt_wx = false,
        spd = nil, spd_perf = false, spd_wx = false,
        off = nil, off_at = nil, off_wx = false,
        direct = nil, hdg = nil, trk = nil,
        rte = nil, route_text = nil, proc = nil,
        wcw_crz = nil, wcw_clb = nil, wcw_des = nil, wcw_spd = nil, wcw_higher = false, wcw_lower = false,
        wcw_back = false,
        free = {"", "", "", ""}, rev = 0}
end
-- ERASE REQUEST: everything (its free text too)
function M.erase(r)
    local f = M.new(r.kind)
    f.rev = r.rev + 1
    for k in pairs(r) do r[k] = nil end
    for k, v in pairs(f) do r[k] = v end
end

-- an altitude: its text and feet (nil if not one); metres only alone
local function one_alt(s, block)
    local fl = string.match(s, "^FL(%d%d%d)$") or string.match(s, "^(%d%d%d)$")
    if fl then
        local n = tonumber(fl)
        if n < 30 or n > M.MAX_FL then return nil end
        return "FL" .. fl, n * 100
    end
    local m = string.match(s, "^(%d%d?%d?%d?%d?)M$")
    if m then
        if block or tonumber(m) > 16000 then return nil end
        return tonumber(m) .. "M", tonumber(m) / 0.3048
    end
    local ft = string.match(s, "^(%d%d%d%d%d?)$")
    if ft then
        local n = tonumber(ft)
        if n > 25000 then return nil end
        return tostring(n), n
    end
    return nil
end
-- an altitude entry: its text and feet (a block: both, lower first)
function M.alt_text(s)
    local a, b = string.match(s or "", "^([^/]+)/([^/]+)$")
    if a then
        local ta, fa = one_alt(a, true)
        local tb, fb = one_alt(b, true)
        if not ta or not tb or fa >= fb then return nil end
        return ta .. "/" .. tb, fa, fb
    end
    return one_alt(s or "", false)
end
-- a time hhmm: "1234Z" (nil if not one)
function M.time_text(s)
    local h, m = string.match(s or "", "^(%d%d)(%d%d)Z?$")
    if not h or tonumber(h) > 23 or tonumber(m) > 59 then return nil end
    return h .. m .. "Z"
end
-- a speed: ".86" (Mach) or "350" (IAS, kt)
function M.speed_text(s)
    local d = string.match(s or "", "^%.(%d%d?%d?)$")
    if d then
        local n = tonumber(d)
        local hundredths = #d == 1 and n * 10 or (#d == 2 and n or math.floor((n + 5) / 10))
        if hundredths < 61 or hundredths > 91 then return nil end
        return string.format(".%02d", hundredths)
    end
    local ias = string.match(s or "", "^(%d%d%d)$")
    if ias then
        local n = tonumber(ias)
        if n < 100 or n > 380 then return nil end
        return tostring(math.floor((n + 5) / 10) * 10)
    end
    return nil
end
-- an offset: "L10", "R5", "10"
function M.offset_text(s)
    local side, nm = string.match(s or "", "^([LR]?)(%d%d?)$")
    if not nm then return nil end
    local n = tonumber(nm)
    if n < 1 or n > 99 then return nil end
    return side .. n
end
-- a heading or ground track: "270"
function M.degrees_text(s)
    if not string.match(s or "", "^%d%d?%d?$") then return nil end
    local n = tonumber(s)
    if n > 360 then return nil end
    return string.format("%03d", n)
end

-- text in lines of `width`, by words
local function wrap(text, width)
    local lines, cur = {}, ""
    for w in string.gmatch(text, "%S+") do
        if cur == "" then cur = w
        elseif #cur + 1 + #w <= width then cur = cur .. " " .. w
        else
            lines[#lines + 1] = cur
            cur = w
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

-- the elements (nil for CLEARANCE and VOICE's fixed one): each {text, rows}
local function el(text, rows) return {text = text, rows = rows} end
local function alt_element(r)
    local a, b = string.match(r.alt, "^([^/]+)/([^/]+)$")
    local rows = {}
    if r.step_at then rows[#rows + 1] = {head = "AT", data = r.step_at} end
    local words
    if a then
        rows[#rows + 1] = {head = "REQUEST BLOCK", data = a}
        rows[#rows + 1] = {head = "TO", data = b}
        words = "REQUEST BLOCK " .. a .. " TO " .. b
    else
        local head = r.crz_clb and "REQUEST CRUISE CLIMB TO"
            or (r.alt_dir == "CLIMB" and "REQUEST CLIMB TO" or (r.alt_dir == "DESCENT" and "REQUEST DESCENT TO" or "REQUEST"))
        rows[#rows + 1] = {head = head, data = r.alt}
        words = head .. " " .. r.alt
    end
    return el((r.step_at and ("AT " .. r.step_at .. " ") or "") .. words, rows)
end
local function due(what) return el("DUE TO " .. what, {{head = "DUE TO", data = what}}) end
local function speed_rows(spd)
    if string.sub(spd, 1, 1) == "." then return {{head = "REQUEST", data = spd}}, spd end
    return {{head = "REQUEST", data = spd, unit = "KT"}}, spd .. "KT"
end
function M.elements(r)
    if r.kind == "CLEARANCE" then return {el("REQUEST CLEARANCE", {{head = "REQUEST", data = "CLEARANCE"}})} end
    if r.kind == "VOICE" then return {el("REQUEST VOICE CONTACT", {{head = "REQUEST VOICE CONTACT"}})} end
    -- (step 12g3a) WHEN CAN WE EXPECT: its words in the header, the
    -- query's under them (estimate), the speed beside them
    if r.kind == "WCW" then
        local out = {}
        local W = "WHEN CAN WE EXPECT"
        local function q(words, rows) out[#out + 1] = el(W .. " " .. words, rows) end
        if r.wcw_crz then q("CRUISE CLIMB TO " .. r.wcw_crz, {{head = W}, {head = "CRUISE CLIMB TO", data = r.wcw_crz}}) end
        if r.wcw_clb then q("CLIMB TO " .. r.wcw_clb, {{head = W}, {head = "CLIMB TO", data = r.wcw_clb}}) end
        if r.wcw_des then q("DESCENT TO " .. r.wcw_des, {{head = W}, {head = "DESCENT TO", data = r.wcw_des}}) end
        if r.wcw_higher then q("HIGHER ALTITUDE", {{head = W}, {head = "HIGHER ALTITUDE"}}) end
        if r.wcw_lower then q("LOWER ALTITUDE", {{head = W}, {head = "LOWER ALTITUDE"}}) end
        if r.wcw_spd then
            local rows, words = speed_rows(r.wcw_spd)
            rows[1].head = W
            q(words, rows)
        end
        if r.wcw_back then q("BACK ON ROUTE", {{head = W}, {head = "BACK ON ROUTE"}}) end
        return out
    end
    local out = {}
    if r.off then
        if r.off_wx then
            out[#out + 1] = el("REQUEST WEATHER DEVIATION UP TO " .. r.off .. "NM",
                {{head = "REQUEST WEATHER"}, {head = "DEVIATION UP TO", data = r.off, unit = "NM"}})
        elseif r.off_at then
            out[#out + 1] = el("AT " .. r.off_at .. " REQUEST OFFSET " .. r.off .. "NM",
                {{head = "AT", data = r.off_at}, {head = "REQUEST OFFSET", data = r.off, unit = "NM"}})
        else
            out[#out + 1] = el("REQUEST OFFSET " .. r.off .. "NM", {{head = "REQUEST OFFSET", data = r.off, unit = "NM"}})
        end
    end
    if r.alt then
        out[#out + 1] = alt_element(r)
        if r.pilot_disc then out[#out + 1] = el("AT PILOTS DISCRETION", {{head = "AT PILOTS DISCRETION"}}) end
        if r.own_sep then
            out[#out + 1] = el("MAINTAIN OWN SEPARATION AND VMC", {{head = "MAINTAIN OWN SEPARATION"}, {head = "AND VMC"}})
        end
        if r.alt_perf then out[#out + 1] = due("AIRCRAFT PERFORMANCE") end
        if r.alt_wx then out[#out + 1] = due("WEATHER") end
    end
    if r.spd then
        local rows, words = speed_rows(r.spd)
        out[#out + 1] = el("REQUEST " .. words, rows)
        if r.spd_perf then out[#out + 1] = due("AIRCRAFT PERFORMANCE") end
        if r.spd_wx then out[#out + 1] = due("WEATHER") end
    end
    if r.direct then out[#out + 1] = el("REQUEST DIRECT TO " .. r.direct, {{head = "REQUEST DIRECT TO", data = r.direct}}) end
    -- (step 12g2b) the route's lines from its header's (estimate)
    if r.rte and r.route_text then
        local rows = {}
        for k, t in ipairs(wrap(r.route_text, 24)) do
            rows[k] = {head = (k == 1) and "REQUEST ROUTE CLEARANCE" or nil, data = t}
        end
        if #rows == 0 then rows[1] = {head = "REQUEST ROUTE CLEARANCE"} end
        out[#out + 1] = el("REQUEST ROUTE CLEARANCE " .. r.route_text, rows)
    end
    if r.proc then out[#out + 1] = el("REQUEST " .. r.proc, {{head = "REQUEST", data = r.proc}}) end
    if r.hdg then out[#out + 1] = el("REQUEST HEADING " .. r.hdg, {{head = "REQUEST HEADING", data = r.hdg}}) end
    if r.trk then out[#out + 1] = el("REQUEST GROUND TRACK " .. r.trk, {{head = "REQUEST GROUND TRACK", data = r.trk}}) end
    return out
end
-- anything entered or selected on the ATC REQUEST pages (ERASE REQUEST
-- shown: FMSPG p.303)
function M.any(r) return (r.kind == "REQUEST" or r.kind == "WCW") and #M.elements(r) > 0 end

-- a change applied unless it makes more than five elements
local SAVE = {"alt", "alt_dir", "step_at", "pilot_disc", "crz_clb", "own_sep", "alt_perf", "alt_wx", "spd", "spd_perf",
    "spd_wx", "off", "off_at", "off_wx", "direct", "hdg", "trk", "rte", "route_text", "proc", "wcw_crz", "wcw_clb",
    "wcw_des", "wcw_spd", "wcw_higher", "wcw_lower", "wcw_back"}
local function apply(r, change)
    local before = {}
    for _, k in ipairs(SAVE) do before[k] = r[k] end
    change()
    if #M.elements(r) > M.MAX_ELEMENTS then
        for _, k in ipairs(SAVE) do r[k] = before[k] end
        return M.LIMIT
    end
    r.rev = r.rev + 1
    return nil
end

-- what may be entered or selected now
local VERTICAL = {wcw_crz = true, wcw_clb = true, wcw_des = true, wcw_higher = true, wcw_lower = true}
function M.can(r, field)
    if field == "step_at" then return r.alt ~= nil and (r.alt_dir == "CLIMB" or r.alt_dir == "DESCENT") and not r.crz_clb end
    if field == "crz_clb" then return r.alt ~= nil and r.alt_dir == "CLIMB" and not r.step_at end
    if field == "pilot_disc" or field == "own_sep" or field == "alt_perf" or field == "alt_wx" then return r.alt ~= nil end
    if field == "spd_perf" or field == "spd_wx" then return r.spd ~= nil end
    if field == "off_at" then return r.off ~= nil and not r.off_wx end
    if field == "off_wx" then return r.off ~= nil and not r.off_at end
    -- (step 12g2b) RTE 1 or RTE 2 (FMSPG p.317-318: the other blank)
    if field == "rte1" then return r.rte ~= 2 end
    if field == "rte2" then return r.rte ~= 1 end
    -- (step 12g3a) WHEN CAN WE's vertical ones: one at a time, the others
    -- blank (FMSPG p.320-322)
    if VERTICAL[field] then
        for k in pairs(VERTICAL) do
            if k ~= field and r[k] then return false end
        end
        return true
    end
    return true
end

-- an entry: nil, or the scratchpad message. present_ft the altitude now
-- (the altitude's element). A position for step_at, off_at, direct goes
-- to M.set_place (the FMS checks it); a time to step_at or off_at here
function M.enter(r, field, text, present_ft)
    if field == "alt" then
        local t, fa, fb = M.alt_text(text)
        if not t then return M.INVALID end
        local dir = "LEVEL"
        if fb then dir = "BLOCK"
        elseif fa > (present_ft or 0) + M.LEVEL_FT then dir = "CLIMB"
        elseif fa < (present_ft or 0) - M.LEVEL_FT then dir = "DESCENT" end
        return apply(r, function()
            r.alt, r.alt_dir = t, dir
            -- a STEP AT or CRZ CLB the new one cannot have
            if dir ~= "CLIMB" and dir ~= "DESCENT" then r.step_at = nil end
            if dir ~= "CLIMB" then r.crz_clb = false end
        end)
    elseif field == "step_at" or field == "off_at" then
        local t = M.time_text(text)
        if not t or not M.can(r, field) then return M.INVALID end
        return apply(r, function() r[field] = t end)
    elseif field == "spd" or field == "wcw_spd" then
        local t = M.speed_text(text)
        if not t then return M.INVALID end
        return apply(r, function() r[field] = t end)
    elseif field == "wcw_crz" or field == "wcw_clb" or field == "wcw_des" then
        -- (step 12g3a) one altitude (FCOM p.769-770: no block)
        local t = not string.find(text, "/", 1, true) and M.alt_text(text)
        if not t or not M.can(r, field) then return M.INVALID end
        return apply(r, function() r[field] = t end)
    elseif field == "off" then
        local t = M.offset_text(text)
        if not t then return M.INVALID end
        return apply(r, function() r.off = t end)
    elseif field == "hdg" or field == "trk" then
        local t = M.degrees_text(text)
        if not t then return M.INVALID end
        return apply(r, function() r[field] = t end)
    end
    return M.INVALID
end
-- (step 12g2b) RTE n selected with its route's text (nothing when the
-- other is); the text as the route is at VERIFY and SEND
function M.select_route(r, n, text)
    if not M.can(r, "rte" .. n) then return nil end
    return apply(r, function() r.rte, r.route_text = n, text end)
end
function M.update_route(r, text)
    if r.rte and text and text ~= r.route_text then
        r.route_text = text
        r.rev = r.rev + 1
    end
end
-- a procedure's form: its name (a letter first, seven characters at most)
-- and a transition (five) after a period
function M.proc_form(s)
    local a, b = string.match(s or "", "^(%a%w*)%.(%w+)$")
    if a then return #a <= 7 and #b <= 5 end
    return string.match(s or "", "^%a%w*$") ~= nil and #s <= 7
end
-- DEP/ARR's procedure (checked by the FMS)
function M.set_proc(r, text) return apply(r, function() r.proc = text end) end
-- a position checked by the FMS: its name into step_at, off_at, direct
function M.set_place(r, field, name)
    if not M.can(r, field) then return M.INVALID end
    return apply(r, function() r[field] = name end)
end
-- a selection (the key without an entry): nil, or the message; nothing
-- when it cannot be selected now
function M.select(r, field)
    if not M.can(r, field) then return nil end
    return apply(r, function() r[field] = true end)
end
-- DELETE: a field or a selection, with what depends on it (FMSPG p.302,
-- p.307, p.310); nil, or INVALID DELETE when there is nothing
local DEPENDS = {alt = {"alt_dir", "step_at", "pilot_disc", "crz_clb", "own_sep", "alt_perf", "alt_wx"},
    spd = {"spd_perf", "spd_wx"}, off = {"off_at", "off_wx"}, rte = {"route_text"}}
local function cleared(v)
    if type(v) == "boolean" then return false end
    return nil
end
function M.delete(r, field)
    local v = r[field]
    if v == nil or v == false then return "INVALID DELETE" end
    r[field] = cleared(v)
    for _, k in ipairs(DEPENDS[field] or {}) do r[k] = cleared(r[k]) end
    r.rev = r.rev + 1
    return nil
end
-- a free text line (1-4): nil, or the message
function M.set_free(r, k, text)
    if text == "DELETE" then
        if r.free[k] == "" then return "INVALID DELETE" end
        text = ""
    end
    r.free[k] = text
    r.rev = r.rev + 1
    return nil
end

-- the free text lines in use: from the line after the elements' to the
-- page's fourth (one when the elements end on the third or fourth; the
-- fifth left for SEND)
local function element_rows(r)
    local rows = {}
    for n, e in ipairs(M.elements(r)) do
        for k, row in ipairs(e.rows) do
            local h = row.head or ""
            if n > 1 and k == 1 then h = "/" .. h end
            rows[#rows + 1] = {head = h, data = row.data or "", unit = row.unit}
        end
    end
    return rows
end
function M.free_count(r)
    local used = #element_rows(r) % M.ROWS
    if used == 4 then return M.FREE_LINES end
    return M.FREE_LINES - used
end
-- the message text: the elements' words and the free text lines in use
function M.text(r)
    local parts = {}
    for _, e in ipairs(M.elements(r)) do parts[#parts + 1] = e.text end
    for k = 1, M.free_count(r) do
        if r.free[k] ~= "" then parts[#parts + 1] = r.free[k] end
    end
    return table.concat(parts, " ")
end
-- something to send (SEND>: an element or free text)
function M.sendable(r) return M.text(r) ~= "" end

-- VERIFY REQUEST's rows, five a page: {head, data, unit} and the free text
-- rows {free = k} (editable: "<" prompts; else only the text entered)
function M.verify_rows(r, editable)
    local rows = element_rows(r)
    if #rows % M.ROWS == 4 then rows[#rows + 1] = {head = "", data = ""} end
    local any = #rows > 0
    for k = 1, M.free_count(r) do
        local t = r.free[k]
        local row = {head = "", data = "", free = k}
        -- the "<" while the line is empty (24 characters fill it: estimate)
        if t ~= "" then row.data = t
        elseif editable then row.data = "<" end
        if k == 1 and (editable or t ~= "") then row.head = any and "/FREE TEXT" or "FREE TEXT" end
        rows[#rows + 1] = row
    end
    return rows
end
-- the rows of a sent request (XXXXZ ATC REQUEST): the elements' and the
-- free text sent
function M.sent_rows(r)
    local rows = element_rows(r)
    local first = true
    for k = 1, M.free_count(r) do
        if r.free[k] ~= "" then
            rows[#rows + 1] = {head = first and (#rows > 0 and "/FREE TEXT" or "FREE TEXT") or "", data = r.free[k]}
            first = false
        end
    end
    return rows
end
-- pages of rows: `first` rows on page 1 (5, or 4 under XXXXZ ATC REQUEST's
-- UPLINK and STATUS), five on each after
function M.pages(rows, first)
    first = first or M.ROWS
    if #rows <= first then return 1 end
    return 1 + math.ceil((#rows - first) / M.ROWS)
end
-- page pg's rows and the line (1-5) of its first
function M.page_rows(rows, pg, first)
    first = first or M.ROWS
    local from, n, line = 1, first, M.ROWS - first + 1
    if pg > 1 then from, n, line = first + (pg - 2) * M.ROWS + 1, M.ROWS, 1 end
    local out = {}
    for k = from, math.min(#rows, from + n - 1) do out[#out + 1] = rows[k] end
    return out, line
end

-- a copy of the data (a sent request's)
function M.copy(r)
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    c.free = {r.free[1], r.free[2], r.free[3], r.free[4]}
    return c
end

return M
