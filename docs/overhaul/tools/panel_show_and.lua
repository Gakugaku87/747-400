-- The custom acf's instruments and groups with SHOW lines on more than one
-- dataref (5-2 step 7; panel changes allowed anywhere since 2026-10-25). A
-- panel instrument or group takes one condition: one dataref, an EQUAL or a
-- LESS and GREATER range on it; with lines on several datarefs only the last
-- counts (memory: the PFD's altitude box, 2026-10-25). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_show_and.lua <acf in> <acf out>
-- It prints every change. For each instrument or group with SHOW lines:
--  - lines on a nameless dataref ("[3]" only) go, alone or not: they decide
--    nothing (the STAT page's readouts with two of them show);
--  - known junk goes: the F/O's active FLARE annunciation's
--    "SHOW_LESS 0 laminar/B747/CAS/caution_status" (an array without its
--    index; the Captain's has only the pitch mode);
--  - with lines left on two or more datarefs, all must hold (what each was
--    meant for): the instrument keeps the last dataref's line or range, and
--    each other dataref's goes to a group around it, outermost first.
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_show_and.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function ind(i) return #lines[i]:match("^(%s*)") end
local function group_end(i)
    local s = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. s .. "END_GROUP%s*$") do j = j + 1 end
    return j
end
local function gen_end(i)
    local n, j = ind(i), i + 1
    while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do j = j + 1 end
    return j - 1
end
local JUNK = {["SHOW_LESS 0.000000 laminar/B747/CAS/caution_status"] = true}

local drop, before, after, shift, own = {}, {}, {}, {}, {}
local stats = {nameless = 0, junk = 0, nested = 0, wraps = 0}
local function block_end(i)
    if lines[i]:match("^%s*GROUP ") then return group_end(i) end
    local e = gen_end(i)
    while not lines[e]:match("%S") do e = e - 1 end
    return e
end
for i, l in ipairs(lines) do
    local head = l:match("^%s*(GROUP .-)%s*$") or l:match("^%s*(gen_%S+.-)%s*$")
    if head then
        local n = ind(i)
        -- the block's own SHOW lines: right below the header, before any
        -- child (a group's SHOW lines come first)
        local shows = {}
        local j = i + 1
        while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do
            if ind(j) == n + 2 then
                if lines[j]:match("^%s*GROUP ") or lines[j]:match("^%s*gen_") then break end
                local op, v, d = lines[j]:match("^%s*(SHOW_%u+) (%S+) ?(%S*)%s*$")
                if op then shows[#shows + 1] = {line = j, op = op, v = v, d = d, name = (d:gsub("%[%d+%]$", ""))} end
            end
            j = j + 1
        end
        if #shows == 1 and shows[1].name == "" then
            drop[shows[1].line] = true; stats.nameless = stats.nameless + 1
        end
        if #shows >= 2 then
            local kept = {}
            for _, s in ipairs(shows) do
                local text_ = s.op .. " " .. s.v .. " " .. s.d
                if s.name == "" then
                    drop[s.line] = true; stats.nameless = stats.nameless + 1
                elseif JUNK[text_] then
                    drop[s.line] = true; stats.junk = stats.junk + 1
                    print(string.format("line %d: %s: dropped %s", s.line, head, text_))
                else
                    kept[#kept + 1] = s
                end
            end
            -- the datarefs in their order, each with its lines
            local order, by = {}, {}
            for _, s in ipairs(kept) do
                if not by[s.d] then by[s.d] = {}; order[#order + 1] = s.d end
                local t = by[s.d]
                t[#t + 1] = s
            end
            if #order >= 2 then
                stats.nested = stats.nested + 1
                local e = block_end(i)
                local pre = lines[i]:match("^(%s*)")
                local wraps = {}
                for k = 1, #order - 1 do
                    local w = {pre .. "GROUP " .. head:gsub("^GROUP ", ""):gsub("^gen_%a+ ", "") .. " and " .. k}
                    for _, s in ipairs(by[order[k]]) do
                        w[#w + 1] = pre .. "  " .. s.op .. " " .. s.v .. " " .. s.d
                        drop[s.line] = true
                    end
                    wraps[#wraps + 1] = w
                end
                -- each wrap one level further in: the block shifts by 2 a wrap
                assert(not before[i] and not after[e], "line " .. i .. " wrapped twice")
                local b, a = {}, {}
                for k, w in ipairs(wraps) do
                    for _, x in ipairs(w) do b[#b + 1] = string.rep(" ", 2 * (k - 1)) .. x end
                end
                for k = #wraps, 1, -1 do a[#a + 1] = pre .. string.rep(" ", 2 * (k - 1)) .. "END_GROUP" end
                before[i], after[e] = b, a
                own[i], own[-e] = 2 * #wraps, 2 * #wraps
                for x = i, e do shift[x] = (shift[x] or 0) + 2 * #wraps end
                stats.wraps = stats.wraps + #wraps
                local conds = {}
                for _, d in ipairs(order) do conds[#conds + 1] = d end
                print(string.format("line %d: %s: all of %s", i, head, table.concat(conds, " & ")))
            end
        end
    end
end
print(string.format("%d nameless lines dropped, %d junk lines dropped, %d blocks nested in %d groups",
    stats.nameless, stats.junk, stats.nested, stats.wraps))

local out = {}
-- inserted lines take the shift of the wraps around their block (the
-- block's own wraps are in them already)
for i, l in ipairs(lines) do
    for _, b in ipairs(before[i] or {}) do out[#out + 1] = string.rep(" ", (shift[i] or 0) - (own[i] or 0)) .. b end
    if not drop[i] then
        if shift[i] and l:match("%S") then l = string.rep(" ", shift[i]) .. l end
        out[#out + 1] = l
    end
    for _, x in ipairs(after[i] or {}) do out[#out + 1] = string.rep(" ", (shift[i] or 0) - (own[-i] or 0)) .. x end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
