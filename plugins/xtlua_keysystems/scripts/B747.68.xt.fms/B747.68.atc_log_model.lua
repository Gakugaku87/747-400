-- 747-400 FMC ATC LOG without X-Plane (6-1/6-2 step 12g1; docs/overhaul/
-- notes/ATA-34-61-FMC.md §115): the log's entries and pages (FCOM
-- p.752-754; FMSPG p.357-362): the uplinks and downlinks newest first, five
-- a page; each entry the time (HHMMZ) and its status in the header, the
-- first characters of its text (cut with two periods) and a caret in the
-- data line; a left key with DELETE deletes an entry, ERASE LOG then
-- CONFIRM every non-pending one (ERASE LOG blank without one).
--
--   local G = B747_atc_log_model
--   local list = G.sorted(entries)          -- {seq, up, time, text, status, pending}
--   G.pages(list) ; G.page(list, pg)        -- five entries of page pg
--   G.line(entry)                           -- the data line's text
--   G.erasable(list)                        -- a non-pending entry to erase

local M = setmetatable({}, {})
B747_atc_log_model = M

M.PER_PAGE = 5

-- newest first (the higher sequence)
function M.sorted(entries)
    local out = {}
    for _, e in ipairs(entries) do
        if not e.deleted then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.seq > b.seq end)
    return out
end
function M.pages(list) return math.max(1, math.ceil(#list / M.PER_PAGE)) end
function M.page(list, pg)
    local out = {}
    for k = 1, M.PER_PAGE do out[k] = list[(pg - 1) * M.PER_PAGE + k] end
    return out
end
-- the data line: the text's first 21 characters, or 19 and two periods
-- when it goes on (FCOM p.753), then the caret
function M.line(e)
    local t = string.upper(e.text or "")
    if #t > 21 then t = string.sub(t, 1, 19) .. ".." end
    return string.format("%-23s>", t)
end
-- the header: the time and the status
function M.header(e)
    local h = (e.time or "") .. "Z"
    return " " .. h .. string.format("%" .. (23 - #h) .. "s", e.status or "")
end
function M.erasable(list)
    for _, e in ipairs(list) do
        if not e.pending then return true end
    end
    return false
end

return M
