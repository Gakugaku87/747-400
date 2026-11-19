-- 747-400 FMC ATC uplinks without X-Plane (6-1/6-2 step 12f; docs/overhaul/
-- notes/ATA-34-61-FMC.md §114): an uplink's response, status and pages,
-- and the ATC key's page (FCOM p.752-754, p.758-765; FMSPG p.286-291):
--   the response the uplink allows: "WU" WILCO or UNABLE, "AN" AFFIRM or
--   NEGATIVE, "R" ROGER, "NE" none; the ground's attribute when the
--   provider gives one (2026-11-20, GAP N19-ATC-02), else the highest of
--   its elements' (CPDLC p.177; N19-ATC-01: before, the first words'), each
--   from its words after its condition (AT [x], BY [x], AFTER PASSING [x],
--   WHEN READY, WHEN ABLE; the FANS elements' attributes are not in the
--   FCOM: an estimate, CPDLC p.179-198's SC-214 table) - instructions
--   (CLIMB, DESCEND, MAINTAIN, PROCEED, CLEARED, CROSS, FLY, TURN, CONTACT,
--   SQUAWK ...) WU, questions (CAN YOU ...) AN, ATC's own answers (UNABLE,
--   STANDBY, REQUEST DEFERRED, ROGER, AFFIRM, NEGATIVE, REQUEST FORWARDED,
--   ERROR ...) and the logon's NE, EXPECT R, the rest (REPORT, CONFIRM,
--   free text) R;
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
--   U.response(text, rr) ; U.elements(text) ; U.status(u) ; U.pages(lines)
--   U.page_lines(lines, pg)
--   U.route(comm, uplinks)       -- "LOGON", "INDEX", "LOG" or the uplink's index

local M = setmetatable({}, {})
B747_atc_uplink_model = M

local NE_START = {"UNABLE", "STANDBY", "REQUEST DEFERRED", "ROGER", "AFFIRM", "NEGATIVE", "LOGON",
    "SERVICE TERMINATED", "WILCO",
    -- (2026-11-20, GAP N19-ATC-01) ATC's messages needing no response
    -- (CPDLC p.179-198's N: before ROGER) and the reasons ("DUE TO ...")
    "REQUEST FORWARDED", "REQUEST AGAIN WITH NEXT", "ERROR", "MESSAGE NOT SUPPORTED",
    "REQUEST ALREADY RECEIVED", "DUE TO"}
local WU_START = {"CLIMB", "DESCEND", "MAINTAIN", "PROCEED", "CLEARED", "CROSS", "FLY", "TURN",
    "CONTACT", "SQUAWK", "RESUME", "HOLD", "OFFSET", "IMMEDIATELY", "REDUCE", "INCREASE",
    "STOP", "LEAVE", "REACH", "EXPEDITE", "DIRECT", "MONITOR", "ADJUST", "NO SPEED RESTRICTION"}
local function starts(text, list)
    for _, w in ipairs(list) do
        if string.sub(text, 1, #w) == w then return true end
    end
    return false
end
-- (2026-11-20, GAP N19-ATC-01) a message's elements: by their "/" (FCOM
-- p.758, p.760's concatenations), and in a run of words a new one where a
-- parameter (a word with a digit: FL350, 1605Z, .80) is followed by an
-- element's first word (estimate: the providers' text marks no other
-- boundary: "EXPECT FL350 MAINTAIN FL330"); an element's condition (AT
-- [x], BY [x], AFTER PASSING [x], WHEN READY, WHEN ABLE) is part of it
local FIRST = {}
for _, w in ipairs({"EXPECT", "REPORT", "CONFIRM", "WHEN", "AT", "BY", "AFTER", "CAN", "ARE", "UNABLE",
    "STANDBY", "REQUEST", "ROGER", "AFFIRM", "NEGATIVE", "ERROR", "MESSAGE", "DUE", "CLIMB", "DESCEND",
    "MAINTAIN", "PROCEED", "CLEARED", "CROSS", "FLY", "TURN", "CONTACT", "SQUAWK", "RESUME", "HOLD",
    "OFFSET", "IMMEDIATELY", "REDUCE", "INCREASE", "STOP", "LEAVE", "REACH", "EXPEDITE", "DIRECT",
    "MONITOR", "ADJUST", "NO"}) do FIRST[w] = true end
local function param(w) return string.find(w, "%d") ~= nil end
function M.elements(text)
    local out = {}
    for piece in (string.upper(text or "") .. "/"):gmatch("([^/]*)/") do
        local words = {}
        for w in piece:gmatch("%S+") do words[#words + 1] = w end
        local cur, head, need = {}, false, 0
        for k, w in ipairs(words) do
            if head and param(words[k - 1] or "") and FIRST[w] then
                out[#out + 1] = table.concat(cur, " ")
                cur, head, need = {}, false, 0
            end
            cur[#cur + 1] = w
            if not head then
                -- the condition before the element's own words
                if need > 0 then
                    need = need - 1
                elseif (w == "AT" or w == "BY") and #cur == 1 then
                    need = 1
                elseif w == "AFTER" and words[k + 1] == "PASSING" and #cur == 1 then
                    need = 2
                elseif w == "WHEN" and (words[k + 1] == "READY" or words[k + 1] == "ABLE") and #cur == 1 then
                    need = 1
                else
                    head = true
                end
            end
        end
        if #cur > 0 then out[#out + 1] = table.concat(cur, " ") end
    end
    return out
end
-- an element's words after its condition
local function own_words(e)
    local t = e
    t = string.gsub(t, "^AT %S+ ", "", 1)
    t = string.gsub(t, "^BY %S+ ", "", 1)
    t = string.gsub(t, "^AFTER PASSING %S+ ", "", 1)
    t = string.gsub(t, "^WHEN READY ", "", 1)
    t = string.gsub(t, "^WHEN ABLE ", "", 1)
    return t
end
-- an element's response: nil for a condition alone
local function element_response(e)
    if string.find(e, "%?%s*$") then return "AN" end
    local t = own_words(e)
    if t == e and (string.find(e, "^AT %S+$") or string.find(e, "^BY %S+$")) then return nil end
    if starts(t, NE_START) then return "NE" end
    if starts(t, {"CAN YOU", "ARE YOU"}) then return "AN" end
    if starts(t, {"EXPECT"}) then return "R" end
    if starts(t, WU_START) then return "WU" end
    return "R"
end
-- (2026-11-20, GAP N19-ATC-02) the ground's response attribute (the
-- provider's RR: AutoATC's, Hoppie's; CPDLC p.177 F-1.2: W/U, A/N, R, N),
-- used before the words; Y (any downlink: the SC-214 reports' and
-- confirmations') has no ACCEPT or REJECT of its own in the FCOM: the
-- words' (estimate)
local GROUND = {WU = "WU", ["W/U"] = "WU", AN = "AN", ["A/N"] = "AN", R = "R", NE = "NE", N = "NE"}
-- the response attributes' order (CPDLC p.177: a message takes its
-- elements' highest)
local RANK = {NE = 1, R = 2, AN = 3, WU = 4}
-- the response an uplink allows: the ground's attribute `rr`, else its
-- elements' highest (an estimate from the words: the FANS elements'
-- attributes are not in the FCOM; CPDLC p.179-198's SC-214 table)
function M.response(text, rr)
    local g = type(rr) == "string" and GROUND[string.upper((string.gsub(rr, "%s", "")))] or nil
    if g then return g end
    local best = nil
    for _, e in ipairs(M.elements(text)) do
        local r = element_response(e)
        if r and (not best or RANK[r] > RANK[best]) then best = r end
    end
    return best or "R"
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

-- the text in lines of up to width (24) characters, at the spaces.
-- (2026-11-20, GAP N19-ATC-06: no change) a concatenation's elements not
-- each from a new line: FCOM p.758's figure has "MAINTAIN FL310/MAINTAIN"
-- on one line and p.760's "/REPORT REACHING" from a new one (its text
-- small, the values large); the FCOM and FMSPG give no rule
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
