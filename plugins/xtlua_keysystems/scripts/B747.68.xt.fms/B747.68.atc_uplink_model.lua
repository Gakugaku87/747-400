-- 747-400 FMC ATC uplinks without X-Plane (6-1/6-2 step 12f; docs/overhaul/
-- notes/ATA-34-61-FMC.md §114): an uplink's response, status and pages,
-- and the ATC key's page (FCOM p.752-754, p.758-765; FMSPG p.286-291):
--   the response the uplink allows: "WU" WILCO or UNABLE, "AN" AFFIRM or
--   NEGATIVE, "R" ROGER, "NE" none; from its words (the FANS elements'
--   response attributes are not in the sources: an estimate) -
--   instructions (CLIMB, DESCEND, MAINTAIN, PROCEED, CLEARED, CROSS, FLY,
--   TURN, CONTACT, SQUAWK ...) WU, questions (CAN YOU ...) AN, ATC's own
--   answers (UNABLE, STANDBY, REQUEST DEFERRED, ROGER, AFFIRM, NEGATIVE)
--   and the logon's NE, the rest (EXPECT, REPORT, free text) R;
--   the status (FCOM p.753): NEW until reviewed, then OLD without a
--   response or OPEN until ACCEPTED or REJECTED (the response's network
--   acknowledgement; STANDBY keeps it OPEN), ABORTED pending when ATC COMM
--   ends;
--   the pages: the text from line 2 of page 1 (CDU line 4), 8 lines there
--   and CONTINUED, 10 on a middle page, 6 on the last with STANDBY,
--   REJECT, ACCEPT; one page when it fits in 4 (an estimate of the
--   figures' lines);
--   the ATC key: LOGON/STATUS without ATC COMM; the uplink's page with only
--   one new or pending; ATC LOG with more than one new, or none new and
--   more than one pending; ATC INDEX otherwise (FCOM p.752, p.758; FMSPG
--   p.286, p.288).
--
--   local U = B747_atc_uplink_model
--   U.response(text) ; U.status(u) ; U.pages(lines) ; U.page_lines(lines, pg)
--   U.route(comm, uplinks)       -- "LOGON", "INDEX", "LOG" or the uplink's index

local M = setmetatable({}, {})
B747_atc_uplink_model = M

local NE_START = {"UNABLE", "STANDBY", "REQUEST DEFERRED", "ROGER", "AFFIRM", "NEGATIVE", "LOGON",
    "SERVICE TERMINATED", "WILCO"}
local WU_START = {"CLIMB", "DESCEND", "MAINTAIN", "PROCEED", "CLEARED", "CROSS", "FLY", "TURN",
    "CONTACT", "SQUAWK", "AT ", "RESUME", "HOLD", "OFFSET", "IMMEDIATELY", "REDUCE", "INCREASE",
    "STOP", "LEAVE", "REACH", "EXPEDITE", "DIRECT", "MONITOR", "ADJUST", "NO SPEED RESTRICTION"}
local function starts(text, list)
    for _, w in ipairs(list) do
        if string.sub(text, 1, #w) == w then return true end
    end
    return false
end
-- the response an uplink allows
function M.response(text)
    local t = string.upper(text or "")
    t = string.gsub(t, "^%s+", "")
    if starts(t, NE_START) then return "NE" end
    if starts(t, {"CAN YOU", "ARE YOU"}) or string.find(t, "%?%s*$") then return "AN" end
    if starts(t, WU_START) then return "WU" end
    return "R"
end
-- the response's words: ACCEPT's and REJECT's (nil: not offered)
local ACCEPT = {WU = "WILCO", AN = "AFFIRM", R = "ROGER"}
local REJECT = {WU = "UNABLE", AN = "NEGATIVE"}
function M.accept_word(resp) return ACCEPT[resp] end
function M.reject_word(resp) return REJECT[resp] end

-- an uplink's state: read (reviewed), resp, sent ("ACCEPT", "REJECT",
-- "STANDBY"), acked (the network's acknowledgement of a final response),
-- aborted
function M.status(u)
    if u.aborted then return "ABORTED" end
    if not u.read then return "NEW" end
    if u.resp == "NE" then return "OLD" end
    if u.acked == "ACCEPT" then return "ACCEPTED" end
    if u.acked == "REJECT" then return "REJECTED" end
    return "OPEN"
end
function M.pending(u)
    local st = M.status(u)
    return st == "NEW" or st == "OPEN"
end
-- a response still to make (ACCEPT, REJECT, STANDBY offered)
function M.awaiting(u)
    return M.status(u) == "OPEN" and u.resp ~= "NE"
end

-- the text in lines of up to width (24) characters, at the spaces
function M.wrap(text, width)
    width = width or 24
    local lines, cur = {}, ""
    for word in string.gmatch(text or "", "%S+") do
        while #word > width do
            if cur ~= "" then lines[#lines + 1] = cur cur = "" end
            lines[#lines + 1] = string.sub(word, 1, width)
            word = string.sub(word, width + 1)
        end
        if cur == "" then
            cur = word
        elseif #cur + 1 + #word <= width then
            cur = cur .. " " .. word
        else
            lines[#lines + 1] = cur
            cur = word
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

-- the pages for the text's lines: their number
local ONE, FIRST, MIDDLE, LAST = 4, 8, 10, 6
function M.pages(lines)
    local n = #lines
    if n <= ONE then return 1 end
    if n <= FIRST + LAST then return 2 end
    return 2 + math.ceil((n - FIRST - LAST) / MIDDLE)
end
-- page pg's text lines: the first CDU line, the lines; continued
function M.page_lines(lines, pg)
    local np = M.pages(lines)
    local from, count, line
    if np == 1 then
        from, count, line = 1, ONE, 4
    elseif pg == 1 then
        from, count, line = 1, FIRST, 4
    elseif pg < np then
        from, count, line = FIRST + (pg - 2) * MIDDLE + 1, MIDDLE, 2
    else
        from, count, line = FIRST + (np - 2) * MIDDLE + 1, LAST, 2
    end
    local out = {}
    for i = 0, count - 1 do out[#out + 1] = lines[from + i] end
    return line, out, pg < np
end

-- the ATC key's page: uplinks a list of states
function M.route(comm, uplinks)
    if not comm then return "LOGON" end
    local new, pend, firstNew, firstPend = 0, 0, nil, nil
    for i, u in ipairs(uplinks) do
        local st = M.status(u)
        if st == "NEW" then
            new = new + 1
            firstNew = firstNew or i
        end
        if st == "NEW" or st == "OPEN" then
            pend = pend + 1
            firstPend = firstPend or i
        end
    end
    if new > 1 or (new == 0 and pend > 1) then return "LOG" end
    if new == 1 then return firstNew end
    if pend == 1 then return firstPend end
    return "INDEX"
end

return M
