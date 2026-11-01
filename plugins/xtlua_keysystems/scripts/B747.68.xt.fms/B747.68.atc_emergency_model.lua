-- 747-400 FMC ATC emergency reports without X-Plane (6-1/6-2 step 12g4;
-- docs/overhaul/notes/ATA-34-61-FMC.md §121): EMERGENCY REPORT's data and
-- its message (FCOM p.728-733; FMSPG p.345-356):
--  - MAYDAY (with an abbreviated POSITION REPORT, and DESCENDING TO when
--    the airplane is more than 150 ft above DESCEND TO's altitude) or PAN,
--    the other blank once one is selected; DELETE deselects (MAYDAY with
--    its POSITION REPORT and DESCENDING TO);
--  - DIVERT TO: the active destination by default (DIVERTING TO it VIA
--    ROUTE CLEARANCE with the route), or a position entered (no route
--    data); OFFSET (L, R and 1-99, or the distance: OFFSETTING); DESCEND
--    TO: the MCP altitude by default, pushed or an altitude entered
--    (DESCENDING TO); SOB and FUEL REMAINING (hh+mm, the FMC's by
--    default once SOB is in: [fuel] OF FUEL REMAINING AND [souls] SOULS ON
--    BOARD);
--  - CANCEL EMERGENCY in the emergency mode with nothing selected; ERASE
--    EMERGENCY with something; five elements at most (MSG LIMIT
--    EXCEEDED); VERIFY EMERGENCY's rows and free text as VERIFY REQUEST's.
-- Estimates: the elements' order after DESCENDING TO and their lines; the
-- POSITION REPORT element sent but not shown (FCOM p.731's page has none);
-- FT after feet in the text.
--
--   local E = B747_atc_emergency_model
--   local e = E.new() ; E.select(e, "mayday", ctx) ; E.enter(e, "sob", "395")
--   local rows = E.verify_rows(e, ctx, true) ; local text = E.text(e, ctx)

local M = setmetatable({}, {})
B747_atc_emergency_model = M
M.INVALID = "INVALID ENTRY"
M.LIMIT = "MSG LIMIT EXCEEDED"
M.MAX_ELEMENTS = 5
M.LEVEL_FT = 150
M.ROWS = 5
M.FREE_LINES = 4

function M.new()
    return {mayday = false, pan = false, divert = nil, divert_sel = false, offset = nil, descend = nil,
        descend_sel = false, sob = nil, fuel = nil, cancel = false, free = {"", "", "", ""}, rev = 0}
end
-- ERASE EMERGENCY (the emergency mode stays: the FMS's)
function M.erase(e)
    local f = M.new()
    f.rev = e.rev + 1
    for k in pairs(e) do e[k] = nil end
    for k, v in pairs(f) do e[k] = v end
end

-- an altitude's text in the message: FL350, 14000FT, 4000M
local function alt_words(t)
    if not t then return nil end
    if string.match(t, "^%d+$") then return t .. "FT" end
    return t
end
-- DESCEND TO's altitude: the entry, else the MCP's (ctx.mcp text, ctx.mcp_ft)
local function descend_alt(e, c)
    if e.descend then
        local _, ft = B747_atc_request_model.alt_text(e.descend)
        return e.descend, ft
    end
    return c.mcp, c.mcp_ft
end
-- DIVERT TO: the entry, else the active destination
local function divert_pos(e, c) return e.divert or c.dest end

-- the elements: each {text, rows}; c: the FMC's values (dest, route, mcp,
-- mcp_ft, alt_ft, ppos, alt, now, endurance)
local function el(text, rows, hidden) return {text = text, rows = rows, hidden = hidden} end
function M.elements(e, c)
    c = c or {}
    local out = {}
    if e.mayday then
        out[#out + 1] = el("MAYDAY MAYDAY MAYDAY", {{data = "MAYDAY MAYDAY MAYDAY"}})
        -- the abbreviated POSITION REPORT: sent, not shown (estimate)
        local pr = "POSITION REPORT"
        if c.ppos then pr = pr .. " " .. c.ppos end
        if c.alt then pr = pr .. " " .. c.alt end
        if c.now then pr = pr .. " AT " .. c.now end
        out[#out + 1] = el(pr, {}, true)
    end
    if e.pan then out[#out + 1] = el("PAN PAN PAN", {{data = "PAN PAN PAN"}}) end
    local at, aft = descend_alt(e, c)
    local auto = e.mayday and aft and c.alt_ft and c.alt_ft > aft + M.LEVEL_FT
    if at and (e.descend_sel or e.descend or auto) then
        out[#out + 1] = el("DESCENDING TO " .. alt_words(at), {{head = "DESCENDING TO", data = alt_words(at)}})
    end
    local pos = divert_pos(e, c)
    if pos and (e.divert or e.divert_sel) then
        if e.divert and e.divert ~= c.dest then
            out[#out + 1] = el("DIVERTING TO " .. pos .. " VIA ROUTE CLEARANCE",
                {{head = "DIVERTING TO", data = pos}, {head = "VIA ROUTE CLEARANCE"}})
        else
            out[#out + 1] = el("DIVERTING TO " .. pos .. " VIA ROUTE CLEARANCE" .. (c.route and (" " .. c.route) or ""),
                {{head = "DIVERTING TO", data = pos}, {head = "VIA ROUTE CLEARANCE"}})
        end
    end
    if e.offset then
        out[#out + 1] = el("OFFSETTING " .. e.offset .. "NM", {{head = "OFFSETTING", data = e.offset .. "NM"}})
    end
    if e.sob then
        local fuel = e.fuel or c.endurance
        if fuel then
            out[#out + 1] = el(fuel .. " OF FUEL REMAINING AND " .. e.sob .. " SOULS ON BOARD",
                {{head = "", data = fuel}, {head = "OF FUEL REMAINING AND", data = e.sob}, {head = "SOULS ON BOARD"}})
        end
    end
    if e.cancel then out[#out + 1] = el("CANCEL EMERGENCY", {{data = "CANCEL EMERGENCY"}}) end
    return out
end
-- anything selected (ERASE EMERGENCY shown; CANCEL EMERGENCY not)
function M.any(e)
    return e.mayday or e.pan or e.divert ~= nil or e.divert_sel or e.offset ~= nil or e.descend ~= nil
        or e.descend_sel or e.sob ~= nil or e.cancel
end

-- a change kept unless it makes more than five elements (the hidden
-- POSITION REPORT not counted: estimate)
local SAVE = {"mayday", "pan", "divert", "divert_sel", "offset", "descend", "descend_sel", "sob", "fuel", "cancel"}
local function count(e, c)
    local n = 0
    for _, x in ipairs(M.elements(e, c)) do if not x.hidden then n = n + 1 end end
    return n
end
local function apply(e, c, change)
    local before = {}
    for _, k in ipairs(SAVE) do before[k] = e[k] end
    change()
    if count(e, c) > M.MAX_ELEMENTS then
        for _, k in ipairs(SAVE) do e[k] = before[k] end
        return M.LIMIT
    end
    e.rev = e.rev + 1
    return nil
end

-- a prompt pushed: mayday, pan, divert (the destination), descend (the
-- MCP altitude), cancel (in the emergency mode)
function M.select(e, field, c, emergency)
    if field == "mayday" then
        if e.pan then return nil end
        return apply(e, c, function() e.mayday = true end)
    elseif field == "pan" then
        if e.mayday then return nil end
        return apply(e, c, function() e.pan = true end)
    elseif field == "divert" then
        if not c or not c.dest then return nil end
        return apply(e, c, function() e.divert_sel = true end)
    elseif field == "descend" then
        if not c or not c.mcp then return nil end
        return apply(e, c, function() e.descend_sel = true end)
    elseif field == "cancel" then
        if not emergency or M.any(e) then return nil end
        return apply(e, c, function() e.cancel = true end)
    end
    return M.INVALID
end
-- an entry: offset, descend, sob, fuel (a position for divert: M.set_divert)
function M.enter(e, field, text, c)
    local Q = B747_atc_request_model
    if field == "offset" then
        local t = Q.offset_text(text)
        if not t then return M.INVALID end
        return apply(e, c, function() e.offset = t end)
    elseif field == "descend" then
        if string.find(text, "/", 1, true) then return M.INVALID end
        local t = Q.alt_text(text)
        if not t then return M.INVALID end
        return apply(e, c, function() e.descend = t end)
    elseif field == "sob" then
        if not string.match(text, "^%d%d?%d?$") then return M.INVALID end
        return apply(e, c, function() e.sob = text end)
    elseif field == "fuel" then
        if not e.sob then return M.INVALID end
        local h, m = string.match(text, "^(%d%d)%+(%d%d)$")
        if not h or tonumber(h) > 23 or tonumber(m) > 59 then return M.INVALID end
        return apply(e, c, function() e.fuel = text end)
    end
    return M.INVALID
end
-- DIVERT TO's position (checked by the FMS)
function M.set_divert(e, name, c) return apply(e, c, function() e.divert = name end) end
-- DELETE: a field or a selection (MAYDAY with its DESCENDING TO: FMSPG p.348)
function M.delete(e, field)
    if field == "mayday" then
        if not e.mayday then return "INVALID DELETE" end
        e.mayday, e.descend_sel = false, false
    elseif field == "divert" then
        if not e.divert and not e.divert_sel then return "INVALID DELETE" end
        e.divert, e.divert_sel = nil, false
    elseif field == "descend" then
        if not e.descend and not e.descend_sel then return "INVALID DELETE" end
        e.descend, e.descend_sel = nil, false
    elseif field == "sob" then
        if not e.sob then return "INVALID DELETE" end
        e.sob, e.fuel = nil, nil
    elseif field == "pan" or field == "cancel" or field == "offset" or field == "fuel" then
        if not e[field] then return "INVALID DELETE" end
        e[field] = (type(e[field]) == "boolean") and false or nil
    else
        return "INVALID DELETE"
    end
    e.rev = e.rev + 1
    return nil
end
function M.set_free(e, k, text)
    if text == "DELETE" then
        if e.free[k] == "" then return "INVALID DELETE" end
        text = ""
    end
    e.free[k] = text
    e.rev = e.rev + 1
    return nil
end

-- the shown rows, the next element after "/"
local function element_rows(e, c)
    local rows, n = {}, 0
    for _, x in ipairs(M.elements(e, c)) do
        if not x.hidden then
            n = n + 1
            for k, row in ipairs(x.rows) do
                local h = row.head or ""
                if n > 1 and k == 1 then h = "/" .. h end
                rows[#rows + 1] = {head = h, data = row.data or ""}
            end
        end
    end
    return rows
end
function M.free_count(e, c)
    local used = #element_rows(e, c) % M.ROWS
    if used == 4 then return M.FREE_LINES end
    return M.FREE_LINES - used
end
-- VERIFY EMERGENCY's rows, five a page, then the free text lines
function M.verify_rows(e, c, editable)
    local rows = element_rows(e, c)
    if #rows % M.ROWS == 4 then rows[#rows + 1] = {head = "", data = ""} end
    local any = #rows > 0
    for k = 1, M.free_count(e, c) do
        local t = e.free[k]
        local row = {head = "", data = "", free = k}
        if t ~= "" then row.data = t elseif editable then row.data = "<" end
        if k == 1 and (editable or t ~= "") then row.head = any and "/FREE TEXT" or "FREE TEXT" end
        rows[#rows + 1] = row
    end
    return rows
end
-- the text sent
function M.text(e, c)
    local parts = {}
    for _, x in ipairs(M.elements(e, c)) do parts[#parts + 1] = x.text end
    for k = 1, M.free_count(e, c) do
        if e.free[k] ~= "" then parts[#parts + 1] = e.free[k] end
    end
    return table.concat(parts, " ")
end
-- the rows of a sent report (XXXXZ EMERGENCY)
function M.sent_rows(e, c)
    local rows = element_rows(e, c)
    local first = true
    for k = 1, M.free_count(e, c) do
        if e.free[k] ~= "" then
            rows[#rows + 1] = {head = first and (#rows > 0 and "/FREE TEXT" or "FREE TEXT") or "", data = e.free[k]}
            first = false
        end
    end
    return rows
end

return M
