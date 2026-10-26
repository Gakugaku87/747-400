-- The CDUs' scratchpads, keys and messages, and the data entry forms (6-1/
-- 6-2 step 2; the plan: docs/overhaul/notes/ATA-34-61-FMC.md §10; the
-- rules and sources: notes/ATA-34-61-CDU.md §3.1, §3.2, §4.1).
--  - The scratchpad: up to 24 characters, typed in from the left; nothing
--    goes in while a message shows (FMSPG p.39, p.41). +/-: "-" the first
--    push, then "+" and "-" by turns (FCOM p.1212; FMSPG p.42). CLR: the
--    message shown, else the last character; held a second: the whole
--    scratchpad (FCOM p.1213; FMSPG p.43). DEL: "DELETE" into an empty
--    scratchpad with no message, else nothing; CLR takes it back (FCOM
--    p.1213; FMSPG p.43).
--  - Each CDU's scratchpad and its entry messages are its own; the FMC's
--    messages show on every CDU and a CLR on any clears them from all
--    (FMSPG p.39). A condition's message goes when the condition clears;
--    cleared by CLR, it comes again only when the condition comes again
--    (FCOM p.1430). The MSG light while a message waits; >FMC MESSAGE
--    while an alert does (FCOM p.1429-1430).
--  - The entry forms: altitudes XXX (hundreds of feet), XXXX (up to 9,994
--    ft), XXXXX, FLXXX, rounded to 10 ft, down to -1,000 ft, shown in feet
--    up to the transition altitude and as flight levels above it; speeds:
--    CAS three digits, Mach a point and one to three digits; pairs with a
--    slash, needed before the inboard value alone (FCOM p.1269-1270).
-- Estimates: a CDU's entry messages show before the FMC's, alerts before
-- advisories, each kind in the order it came; a full scratchpad takes no
-- more; SP, for ACARS and SATCOM (FCOM p.1213), types a space; an altitude
-- equal to the transition altitude shows in feet (ICAO: at or below it).
-- Pure functions: the CDU glue (B744.createfms.lua) runs them.
--   local C = B747_cdu_model                       -- in XTLua, after dofile
--   local C = dofile(".../B747.68.cdu_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_cdu_model = M

M.MAX = 24
M.CLR_HOLD_S = 1
M.DELETE = "DELETE"
-- the messages of the entry rules (FCOM p.1435)
M.INVALID_ENTRY, M.INVALID_DELETE = "INVALID ENTRY", "INVALID DELETE"
M.NOT_IN_DATA_BASE, M.KEY_INOP = "NOT IN DATA BASE", "KEY/FUNCTION INOP"

local floor, tonumber, match = math.floor, tonumber, string.match

-- a CDU: its scratchpad, whether the last key was +/-, its entry messages
-- (the FMC's are shared: M.fmc_new)
function M.new()
    return setmetatable({sp = "", pm = false, msgs = {}, clr_all = false}, {})
end

-- the FMC's messages: {text, alert, cond (a condition's), seen (cleared
-- while the condition holds)}
function M.fmc_new()
    return setmetatable({list = {}, n = 0}, {})
end

local function find_msg(fmc, text)
    for i, m in ipairs(fmc.list) do
        if m.text == text then return i, m end
    end
end
-- a condition's message: on while the condition holds
function M.fmc_set(fmc, text, on, alert)
    local i, m = find_msg(fmc, text)
    if on and not m then
        fmc.n = fmc.n + 1
        fmc.list[#fmc.list + 1] = {text = text, alert = alert and true or false, cond = true, seen = false, seq = fmc.n}
    elseif not on and m and m.cond then
        table.remove(fmc.list, i)
    end
end
-- an event's message (TAKEOFF SPEEDS DELETED...): until cleared
function M.fmc_post(fmc, text, alert)
    local _, m = find_msg(fmc, text)
    if m then
        if m.seen then m.seen = false end
        return
    end
    fmc.n = fmc.n + 1
    fmc.list[#fmc.list + 1] = {text = text, alert = alert and true or false, cond = false, seen = false, seq = fmc.n}
end
-- the FMC message to show: the oldest alert, else the oldest advisory
local function fmc_top(fmc)
    local best
    for _, m in ipairs(fmc.list) do
        if not m.seen and (not best or (m.alert and not best.alert)
            or (m.alert == best.alert and m.seq < best.seq)) then best = m end
    end
    return best
end
-- whether an alert is waiting (>FMC MESSAGE) and any message (MSG light)
function M.fmc_alert(fmc)
    for _, m in ipairs(fmc.list) do
        if m.alert and not m.seen then return true end
    end
    return false
end

-- a message for this CDU only (an entry's)
function M.error(cdu, text)
    local msgs = cdu.msgs
    if msgs[#msgs] ~= text then msgs[#msgs + 1] = text end
end

-- the message this CDU shows, or nil
function M.message(cdu, fmc)
    if cdu.msgs[1] then return cdu.msgs[1] end
    local m = fmc and fmc_top(fmc)
    return m and m.text or nil
end
function M.msg_light(cdu, fmc)
    return M.message(cdu, fmc) ~= nil
end
-- the scratchpad line: the message, else the scratchpad
function M.line(cdu, fmc)
    return M.message(cdu, fmc) or cdu.sp
end

-- CLR on the message shown: an entry's goes from this CDU, the FMC's from
-- all (a condition's stays away while its condition holds)
local function clear_message(cdu, fmc)
    if cdu.msgs[1] then
        table.remove(cdu.msgs, 1)
        return true
    end
    local m = fmc and fmc_top(fmc)
    if not m then return false end
    if m.cond then
        m.seen = true
    else
        table.remove(fmc.list, (find_msg(fmc, m.text)))
    end
    return true
end

-- a key: "A".."Z", "0".."9", "." "/" "SP" "+/-" "CLR" "DEL"; phase and
-- duration as XTLua's command handlers get them (0 down, 1 held, 2 up).
-- Returns true when the key is the scratchpad's (the others: the page's).
local CHARS = {["."] = ".", ["/"] = "/", SP = " "}
function M.key(cdu, fmc, key, phase, duration)
    phase = phase or 0
    if key == "CLR" then
        if phase == 0 then
            cdu.clr_all = false
            if not clear_message(cdu, fmc) then
                if cdu.sp == M.DELETE then cdu.sp = ""
                else cdu.sp = cdu.sp:sub(1, -2) end
            end
        elseif phase == 1 and (duration or 0) >= M.CLR_HOLD_S and not cdu.clr_all then
            cdu.clr_all = true
            if not M.message(cdu, fmc) then cdu.sp = "" end
        elseif phase == 2 then
            cdu.clr_all = false
        end
        cdu.pm = false
        return true
    end
    if phase ~= 0 then return CHARS[key] ~= nil or key == "+/-" or key == "DEL" or #key == 1 end
    if key == "DEL" then
        if cdu.sp == "" and not M.message(cdu, fmc) then cdu.sp = M.DELETE end
        cdu.pm = false
        return true
    end
    local c = CHARS[key] or (#key == 1 and match(key, "^[%u%d]$") and key)
    if key == "+/-" or c then
        if M.message(cdu, fmc) or cdu.sp == M.DELETE then return true end
        if key == "+/-" then
            local last = cdu.sp:sub(-1)
            if cdu.pm and (last == "-" or last == "+") then
                cdu.sp = cdu.sp:sub(1, -2) .. (last == "-" and "+" or "-")
            elseif #cdu.sp < M.MAX then
                cdu.sp = cdu.sp .. "-"
            end
            cdu.pm = true
        else
            if #cdu.sp < M.MAX then cdu.sp = cdu.sp .. c end
            cdu.pm = false
        end
        return true
    end
    cdu.pm = false
    return false
end

-- the scratchpad taken by a line select key: its text and whether it is
-- DELETE; empty: nil (a copy to the scratchpad instead)
function M.entry(cdu)
    if cdu.sp == "" then return nil, false end
    return cdu.sp, cdu.sp == M.DELETE
end
-- the entry accepted: the scratchpad empties
function M.accept(cdu)
    cdu.sp = ""
    cdu.pm = false
end
-- a value copied into an empty scratchpad (boxes and dashes, or pairs of
-- them, are not)
function M.copy(cdu, text)
    if cdu.sp ~= "" or not text or match(text, "^[%*%-%s/]*$") then return false end
    cdu.sp = text:sub(1, M.MAX)
    cdu.pm = false
    return true
end

-- altitudes: the entry in feet (nil when not a valid form)
function M.parse_alt(s)
    local neg, body = match(s or "", "^(%-?)(.+)$")
    if not body then return nil end
    local ft
    local fl = match(body, "^FL(%d%d%d)$")
    if fl then
        ft = tonumber(fl) * 100
    elseif match(body, "^%d%d%d$") then
        ft = tonumber(body) * 100
    elseif match(body, "^%d%d%d%d$") then
        ft = tonumber(body)
        if ft > 9994 then return nil end
        ft = floor(ft / 10 + 0.5) * 10
    elseif match(body, "^%d%d%d%d%d$") then
        ft = floor(tonumber(body) / 10 + 0.5) * 10
    else
        return nil
    end
    if neg == "-" then
        if fl then return nil end
        ft = -ft
        if ft < -1000 then return nil end
    end
    return ft
end
-- an altitude as the CDU shows it: feet up to the transition altitude,
-- flight levels above
function M.format_alt(ft, trans_alt)
    if ft > (trans_alt or 18000) then
        return string.format("FL%03d", floor(ft / 100 + 0.5))
    end
    return string.format("%d", ft)
end

-- speeds: a CAS in knots or a Mach number (nil when not a valid form)
function M.parse_speed(s)
    s = s or ""
    if match(s, "^%d%d%d$") then return tonumber(s), nil end
    local m = match(s, "^0?(%.%d%d?%d?)$")
    if m then return nil, tonumber(m) end
    return nil
end

-- a pair "a/b" at a line select key: the outboard value (the key's side)
-- and the inboard one, "" when not given; nil when the inboard value
-- comes alone without its slash. side: "L" or "R".
function M.pair(s, side)
    local a, b = match(s or "", "^([^/]*)/([^/]*)$")
    if not a then
        if (s or "") == "" or s:find("/", 1, true) then return nil end
        return s, ""
    end
    if side == "L" then return a, b end
    return b, a
end

-- weights: XXX or XXX.X (thousands of kilograms or pounds)
function M.parse_weight(s)
    if match(s or "", "^%d%d?%d?$") or match(s or "", "^%d%d?%d?%.%d$") then return tonumber(s) end
    return nil
end

-- whole numbers in a range
function M.parse_int(s, lo, hi)
    if not match(s or "", "^%d+$") then return nil end
    local v = tonumber(s)
    if (lo and v < lo) or (hi and v > hi) then return nil end
    return v
end

return M
