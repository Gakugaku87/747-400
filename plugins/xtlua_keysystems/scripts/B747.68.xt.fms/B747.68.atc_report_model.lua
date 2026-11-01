-- 747-400 FMC ATC reports without X-Plane (6-1/6-2 step 12g3c; docs/
-- overhaul/notes/ATA-34-61-FMC.md §120): ATC's report and confirmation
-- requests and the reports that answer them (FCOM p.748-751; FMSPG
-- p.328-340):
--  - an uplink's request found in its text (M.parse): CONFIRM ALTITUDE,
--    ASSIGNED ALTITUDE, ASSIGNED ROUTE, ASSIGNED SPEED, ATIS CODE,
--    ENSUING WAYPOINT, GROUND TRACK, HEADING, NEXT WAYPOINT (ETA),
--    POSITION, REPORTED WAYPOINT, SPEED, SQUAWK, TIME OVER REPORTED
--    WAYPOINT; REPORT REMAINING FUEL AND SOULS ON BOARD, BACK ON ROUTE,
--    DISTANCE TO/FROM, LEAVING, LEVEL, PASSING, REACHING (BLOCK); REQUEST
--    POSITION REPORT (POS REPORT's); WHEN CAN YOU ACCEPT (WE CAN ACCEPT ...
--    AT [time], or CANNOT ACCEPT);
--  - its report's elements: the fixed words, the data (the FMC's, the
--    crew's entry, or boxes where an entry is needed: no SEND until then),
--    CLIMBING/DESCENDING TO with the MCP altitude more than 150 ft away,
--    DEVIATING [offset] OF ROUTE with an offset; LEVEL, REACHING and
--    PASSING armable (sent when the condition comes);
--  - the entries' forms (FMSPG p.336): altitude, ATIS code (one
--    character), beacon code (four digits 0-7), degrees (000-360),
--    distance (0-999.9), remaining fuel (hh+mm), souls (1-3 digits),
--    speed, time; a position the FMS checks.
-- The report list (up to nine), RTE REPORT (ASSIGNED ROUTE RTE X) and a
-- free text report are the FMS's. Estimates: the uplink texts' forms
-- (the FANS phrases), the arming's thresholds, how the elements split
-- into lines.
--
--   local A = B747_atc_report_model
--   local req = A.parse("CLIMB TO AND MAINTAIN FL350 REPORT REACHING FL350")  -- {id, args, armable, ...}
--   local rep = A.new(req)
--   local els = A.elements(rep, ctx)       -- ctx: the FMC's values
--   local err = A.enter(rep, "alt", "FL330", ctx)

local M = setmetatable({}, {})
B747_atc_report_model = M
M.INVALID = "INVALID ENTRY"
M.LEVEL_FT = 150
M.MAX_LIST = 9
M.ARM_FT = 200            -- REACHING and LEVEL: within it of the altitude (estimate)
M.LEVEL_FPM = 300         -- LEVEL: under it (estimate)

-- a field: name, kind, the FMC's value, required (boxes without one),
-- fixed (the uplink's: no entry)
local function F(name, kind, default, opts)
    opts = opts or {}
    return {f = name, kind = kind, default = default, required = opts.required ~= false, fixed = opts.fixed,
        dashes = opts.dashes}
end
local function fixed(name, value) return F(name, "fixed", value, {fixed = true}) end

-- the requests: id, the text's pattern (the FANS phrase), what the report
-- holds (`a` the pattern's captures, `c` the FMC's values, `r` the report)
local TYPES = {
    {id = "CONFIRM ASSIGNED ALTITUDE", pat = "CONFIRM ASSIGNED ALTITUDE", el = function(a, c, r)
        if r.entries.alt2 then
            return {{"ASSIGNED BLOCK", F("alt", "alt", c.mcp), "TO", F("alt2", "alt", nil, {required = false, dashes = true})}}
        end
        return {{"ASSIGNED ALTITUDE", F("alt", "alt", c.mcp), F("alt2", "alt", nil, {required = false, dashes = true})}}
    end},
    {id = "CONFIRM ASSIGNED ROUTE", pat = "CONFIRM ASSIGNED ROUTE", el = function(a, c)
        return {{"ASSIGNED ROUTE", fixed("route", c.route)}}
    end, deviating = true},
    {id = "CONFIRM ASSIGNED SPEED", pat = "CONFIRM ASSIGNED SPEED", el = function()
        return {{"ASSIGNED SPEED", F("spd", "speed", nil)}}
    end},
    {id = "CONFIRM ATIS CODE", pat = "CONFIRM ATIS CODE", el = function()
        return {{"ATIS", F("atis", "atis", nil)}}
    end},
    {id = "CONFIRM ENSUING WAYPOINT", pat = "CONFIRM ENSUING WAYPOINT", el = function(a, c)
        return {{"ENSUING WAYPOINT", F("pos", "pos", c.ensuing)}}
    end, deviating = true},
    {id = "CONFIRM GROUND TRACK", pat = "CONFIRM GROUND TRACK", el = function(a, c)
        return {{"PRESENT GROUND TRACK", F("deg", "deg", c.trk)}}
    end},
    {id = "CONFIRM HEADING", pat = "CONFIRM HEADING", el = function(a, c)
        return {{"PRESENT HEADING", F("deg", "deg", c.hdg)}}
    end},
    {id = "CONFIRM NEXT WAYPOINT ETA", pat = "CONFIRM NEXT WAYPOINT ETA", el = function(a, c)
        return {{"NEXT WAYPOINT ETA", F("time", "time", c.next_eta)}}
    end},
    {id = "CONFIRM NEXT WAYPOINT", pat = "CONFIRM NEXT WAYPOINT", el = function(a, c)
        return {{"NEXT WAYPOINT", F("pos", "pos", c.next_wpt)}}
    end, deviating = true},
    {id = "CONFIRM POSITION", pat = "CONFIRM POSITION", el = function(a, c)
        return {{"PRESENT POSITION", F("pos", "pos", c.ppos)}}
    end},
    {id = "CONFIRM REPORTED WAYPOINT", pat = "CONFIRM REPORTED WAYPOINT", el = function(a, c)
        return {{"REPORTED WAYPOINT", fixed("pos", c.last)}}
    end},
    {id = "CONFIRM SPEED", pat = "CONFIRM SPEED", el = function(a, c)
        return {{"PRESENT SPEED", F("spd", "speed", c.spd)}}
    end},
    {id = "CONFIRM SQUAWK", pat = "CONFIRM SQUAWK", el = function()
        return {{"SQUAWKING", F("code", "squawk", nil)}}
    end},
    {id = "CONFIRM TIME OVER REPORTED WAYPOINT", pat = "CONFIRM TIME OVER REPORTED WAYPOINT", el = function(a, c)
        return {{"REPORTED WAYPOINT", F("time", "time", c.ata)}}
    end},
    {id = "CONFIRM ALTITUDE", pat = "CONFIRM ALTITUDE", el = function(a, c)
        local e = {{"PRESENT ALTITUDE", F("alt", "alt", c.alt)}}
        if c.mcp_dir then e[2] = {c.mcp_dir .. " TO", F("alt2", "alt", c.mcp)} end
        return e
    end},
    {id = "REPORT REMAINING FUEL AND SOULS ON BOARD", pat = "REPORT REMAINING FUEL AND SOULS ON BOARD", el = function(a, c)
        return {{F("fuel", "fuel", c.endurance), "OF FUEL REMAINING AND", F("souls", "souls", nil), "SOULS ON BOARD"}}
    end},
    {id = "REPORT BACK ON ROUTE", pat = "REPORT BACK ON ROUTE", el = function()
        return {{"BACK ON ROUTE"}}
    end},
    {id = "REPORT DISTANCE", pat = "REPORT DISTANCE (%u+) (%S+)", el = function(a, c)
        return {{"AT", F("time", "time", c.now), F("dist", "dist", nil), a[1], fixed("pos", a[2])}}
    end},
    {id = "REPORT LEAVING", pat = "REPORT LEAVING (%S+)", el = function(a)
        return {{"LEAVING", fixed("alt", a[1])}}
    end},
    {id = "REPORT LEVEL", pat = "REPORT LEVEL (%S+)", armable = "LEVEL", el = function(a)
        return {{"LEVEL", fixed("alt", a[1])}}
    end},
    {id = "REPORT PASSING", pat = "REPORT PASSING (%S+)", armable = "PASSING", el = function(a)
        return {{"PASSING", fixed("pos", a[1])}}
    end},
    {id = "REPORT REACHING BLOCK", pat = "REPORT REACHING BLOCK (%S+) TO (%S+)", el = function(a)
        return {{"REACHING BLOCK", fixed("alt", a[1]), "TO", fixed("alt2", a[2])}}
    end},
    {id = "REPORT REACHING", pat = "REPORT REACHING (%S+)", armable = "REACHING", el = function(a)
        return {{"REACHING", fixed("alt", a[1])}}
    end},
    {id = "REQUEST POSITION REPORT", pat = "REQUEST POSITION REPORT", posrep = true, el = function() return {} end},
    {id = "WHEN CAN YOU ACCEPT", pat = "WHEN CAN YOU ACCEPT (.+)$", wcya = true, el = function(a, c, r)
        if r.cannot then return {{"WE CANNOT ACCEPT", fixed("x", a[1])}} end
        return {{"WE CAN ACCEPT", fixed("x", a[1]), "AT", F("time", "time", nil)}}
    end},
}
-- the free text report and RTE REPORT (ATC REPORT's 1R, 1L)
local FREE = {id = "FREE TEXT", el = function() return {} end}
local RTE = {id = "RTE REPORT", el = function(a, c)
    return {{"ASSIGNED ROUTE", fixed("rte", c.rte_name), fixed("route", c.route)}}
end, deviating = true}

-- the request in an uplink's text: {id, args, armable, posrep, wcya, text
-- (the request's own words)}; nil without one
function M.parse(text)
    text = string.upper(text or "")
    for _, t in ipairs(TYPES) do
        local i, j = string.find(text, t.pat)
        if i then
            local caps = {string.match(string.sub(text, i, j), "^" .. t.pat)}
            if #caps == 1 and caps[1] == string.sub(text, i, j) and not string.find(t.pat, "(", 1, true) then caps = {} end
            return {id = t.id, args = caps, armable = t.armable, posrep = t.posrep, wcya = t.wcya, text = string.sub(text, i)}
        end
    end
    return nil
end
local function type_of(rep)
    if rep.id == "FREE TEXT" then return FREE end
    if rep.id == "RTE REPORT" then return RTE end
    for _, t in ipairs(TYPES) do
        if t.id == rep.id then return t end
    end
    return FREE
end

-- a report for a request (or "FREE TEXT", "RTE REPORT"): its entries,
-- CANNOT ACCEPT, ARMED, the free text lines
function M.new(req)
    req = req or {id = "FREE TEXT", args = {}}
    return {id = req.id, args = req.args or {}, armable = req.armable, wcya = req.wcya, posrep = req.posrep,
        text = req.text or req.id, entries = {}, cannot = false, armed = false, free = {"", "", "", ""}, rev = 0}
end

-- the elements: each a list of words and fields; with the FMC's values `c`
-- (alt, mcp, mcp_dir, route, rte_name, offset_text, ensuing, next_wpt,
-- next_eta, ppos, last, ata, spd, hdg, trk, endurance, now)
function M.elements(rep, c)
    local t = type_of(rep)
    local out = t.el(rep.args, c or {}, rep)
    if t.deviating and c and c.offset_text then out[#out + 1] = {"DEVIATING", fixed("off", c.offset_text), "OF ROUTE"} end
    return out
end
-- a field's value: the entry, else the FMC's (nil: boxes or dashes)
local function value(rep, fld)
    if fld.fixed then return fld.default end
    local e = rep.entries[fld.f]
    if e ~= nil then return e end
    return fld.default
end
local BOXES = {alt = 5, speed = 3, deg = 3, time = 4, squawk = 4, atis = 1, dist = 5, pos = 5, fuel = 5, souls = 3}
-- the rows of the report (VERIFY REPORT, XXXXZ ATC REPORT): {head, data,
-- field, boxes}; the next element's header after "/"
function M.rows(rep, c)
    local rows = {}
    for n, e in ipairs(M.elements(rep, c)) do
        local head, first = "", true
        local function emit(row)
            if first and n > 1 then row.head = "/" .. (row.head or "") end
            first = false
            rows[#rows + 1] = row
        end
        for _, tok in ipairs(e) do
            if type(tok) == "string" then
                head = (head == "") and tok or (head .. " " .. tok)
            else
                local v = value(rep, tok)
                local data = v or (tok.dashes and string.rep("-", BOXES[tok.kind] or 5)) or string.rep("*", BOXES[tok.kind] or 5)
                -- a long value (a route) on more lines, by words
                local lines = {data}
                if #data > 24 then
                    lines = {}
                    local cur = ""
                    for w in string.gmatch(data, "%S+") do
                        if cur == "" then cur = w
                        elseif #cur + 1 + #w <= 24 then cur = cur .. " " .. w
                        else lines[#lines + 1] = cur cur = w end
                    end
                    if cur ~= "" then lines[#lines + 1] = cur end
                end
                emit({head = head, data = lines[1], field = (not tok.fixed) and tok.f or nil, boxes = v == nil and not tok.dashes})
                for k = 2, #lines do rows[#rows + 1] = {head = "", data = lines[k]} end
                head = ""
            end
        end
        if head ~= "" then emit({head = head, data = ""}) end
    end
    return rows
end
-- every field needed has a value (SEND shown)
function M.complete(rep, c)
    for _, r in ipairs(M.rows(rep, c)) do
        if r.boxes then return false end
    end
    return true
end
-- the report's text: the elements' words and values, the free text
function M.text(rep, c)
    local parts = {}
    for _, e in ipairs(M.elements(rep, c)) do
        local words = {}
        for _, tok in ipairs(e) do
            if type(tok) == "string" then words[#words + 1] = tok
            else
                local v = value(rep, tok)
                if v then words[#words + 1] = v end
            end
        end
        if #words > 0 then parts[#parts + 1] = table.concat(words, " ") end
    end
    for _, f in ipairs(rep.free) do
        if f ~= "" then parts[#parts + 1] = f end
    end
    return table.concat(parts, " ")
end

-- an entry's form (FMSPG p.336): the value shown, nil when not one
local VALID = {
    alt = function(s)
        if string.find(s, "/", 1, true) then return nil end
        return B747_atc_request_model.alt_text(s)
    end,
    speed = function(s) return B747_atc_request_model.speed_text(s) end,
    time = function(s) return B747_atc_request_model.time_text(s) end,
    deg = function(s)
        if not string.match(s, "^%d%d%d$") or tonumber(s) > 360 then return nil end
        return s
    end,
    squawk = function(s) return string.match(s, "^[0-7][0-7][0-7][0-7]$") end,
    atis = function(s) return string.match(s, "^%S$") end,
    dist = function(s)
        if #s > 5 or not string.match(s, "^%d+%.?%d*$") then return nil end
        local n = tonumber(s)
        if not n or n > 999.9 then return nil end
        return s .. "NM"
    end,
    fuel = function(s)
        local h, m = string.match(s, "^(%d%d)%+(%d%d)$")
        if not h or tonumber(h) > 23 or tonumber(m) > 59 then return nil end
        return s
    end,
    souls = function(s) return string.match(s, "^%d%d?%d?$") end,
}
function M.valid(kind, text)
    local v = VALID[kind]
    return v and v(text) or nil
end
-- the field a row (from M.rows) takes; nil when it takes none
function M.field_kind(rep, c, name)
    for _, e in ipairs(M.elements(rep, c)) do
        for _, tok in ipairs(e) do
            if type(tok) == "table" and tok.f == name and not tok.fixed then return tok.kind end
        end
    end
    return nil
end
-- an entry into a field (a position the FMS checked: kind "pos" takes the
-- text): nil or the message; DELETE back to the FMC's value or boxes
function M.enter(rep, name, text, c)
    local kind = M.field_kind(rep, c, name)
    if not kind then return M.INVALID end
    if text == "DELETE" then
        if rep.entries[name] == nil then return "INVALID DELETE" end
        rep.entries[name] = nil
    elseif kind == "pos" then
        rep.entries[name] = text
    else
        local v = M.valid(kind, text)
        if not v then return M.INVALID end
        rep.entries[name] = v
    end
    rep.rev = rep.rev + 1
    return nil
end
-- CANNOT ACCEPT (WHEN CAN YOU ACCEPT's): selected or deleted
function M.cannot(rep, on)
    if not rep.wcya then return M.INVALID end
    if not on and not rep.cannot then return "INVALID DELETE" end
    rep.cannot = on
    rep.rev = rep.rev + 1
    return nil
end
-- ARM (LEVEL, REACHING, PASSING): armed or disarmed
function M.arm(rep, on)
    if not rep.armable then return M.INVALID end
    if not on and not rep.armed then return "INVALID DELETE" end
    rep.armed = on
    return nil
end
-- an armed report's condition met: `s` the airplane (alt_ft, vs_fpm,
-- passed: the waypoints sequenced, a set of names), `target_ft` the
-- report's altitude in feet (LEVEL, REACHING)
function M.triggered(rep, s, target_ft)
    if not rep.armed then return false end
    if rep.armable == "PASSING" then return s.passed ~= nil and s.passed[rep.args[1]] == true end
    if not target_ft then return false end
    local near = math.abs(s.alt_ft - target_ft) <= M.ARM_FT
    if rep.armable == "LEVEL" then return near and math.abs(s.vs_fpm or 0) < M.LEVEL_FPM end
    return near
end
-- a free text line (1-4)
function M.set_free(rep, k, text)
    if text == "DELETE" then
        if rep.free[k] == "" then return "INVALID DELETE" end
        text = ""
    end
    rep.free[k] = text
    rep.rev = rep.rev + 1
    return nil
end

return M
