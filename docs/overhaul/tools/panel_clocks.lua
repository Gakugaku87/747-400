-- The custom acf's clocks (5-2 step 6a, GAP DSP-33; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_clocks.lua <acf in> <acf out>
-- It prints every change. In GROUP Clocks, for the Captain's and the F/O's
-- clock (laminar/B747/fltInst/<side>/clock_*, B747.60.xt.fltInst03.lua):
--  - the upper LCD's UTC from the clock's own time (clock_utc_hours,
--    clock_utc_minutes, not X-Plane's zulu_time_hours and minutes), the
--    date from its own date (clock_day, clock_month, not X-Plane's local
--    current_day and current_month);
--  - both LCDs' digits in a new GROUP Digits shown with clock_on (the APU
--    battery bus; the black backgrounds stay);
--  - the ET digits shown with clock_et_show alone (they had two SHOW lines,
--    and the last one, clock_et_seconds > 0, won: the ET showed under the
--    chronograph).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_clocks.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function ind(i) return #lines[i]:match("^(%s*)") end
local function name(i) return lines[i]:match("^%s*(.-)%s*$") end
local function group_end(i)
    local s = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. s .. "END_GROUP%s*$") do j = j + 1 end
    return j
end
local function child(i, nm)
    local n, found = ind(i), nil
    for j = i + 1, group_end(i) - 1 do
        if ind(j) == n + 2 and name(j) == nm then
            assert(not found, "two " .. nm .. " in " .. name(i))
            found = j
        end
    end
    return assert(found, "no " .. nm .. " in " .. name(i))
end

local replace, before, after, shift = {}, {}, {}, {}
local changes = 0
local function change(fmt, ...)
    changes = changes + 1
    print(string.format(fmt, ...))
end
-- a line's DATAREF from one to another, in the block from i to j
local function rebind(i, j, old, new)
    local n = 0
    for k = i, j do
        local pre = lines[k]:match("^(%s*)DATAREF " .. old:gsub("%p", "%%%0") .. "%s*$")
        if pre then
            assert(not replace[k], "line " .. k .. " twice")
            replace[k] = pre .. "DATAREF " .. new
            n = n + 1
            change("line %d: DATAREF %s -> %s", k, old, new)
        end
    end
    assert(n == 1, n .. " " .. old .. " in lines " .. i .. "-" .. j)
end
-- the groups from line a to line b (their END_GROUP) in a new group shown
-- with a dataref, two spaces in
local function wrap(a, b, nm, show)
    local pre = lines[a]:match("^(%s*)")
    before[a] = {pre .. "GROUP " .. nm, pre .. "  " .. show}
    after[b] = {pre .. "END_GROUP"}
    for k = a, b do shift[k] = true end
    change("lines %d-%d: in a new GROUP %s (%s)", a, b, nm, show)
end

local top
for i, l in ipairs(lines) do
    if l == "GROUP Clocks" then assert(not top, "two GROUP Clocks"); top = i end
end
assert(top, "no GROUP Clocks")
for _, c in ipairs({{"GROUP Captain", "capt"}, {"GROUP First Officer", "fo"}}) do
    local side = child(top, c[1])
    local P = "laminar/B747/fltInst/" .. c[2] .. "/clock_"
    print(c[1] .. " (line " .. side .. ")")
    local upper = child(side, "GROUP Upper LCD/GMT")
    local utc, date = child(upper, "GROUP UTC"), child(upper, "GROUP Date")
    rebind(utc, group_end(utc), "sim/cockpit2/clock_timer/zulu_time_hours", P .. "utc_hours")
    rebind(utc, group_end(utc), "sim/cockpit2/clock_timer/zulu_time_minutes", P .. "utc_minutes")
    rebind(date, group_end(date), "sim/cockpit2/clock_timer/current_day", P .. "day")
    rebind(date, group_end(date), "sim/cockpit2/clock_timer/current_month", P .. "month")
    assert(utc < date and group_end(utc) + 1 == date, "UTC then Date")
    wrap(utc, group_end(date), "Digits", "SHOW_EQUAL 1.000000 " .. P .. "on")
    local lower = child(side, "GROUP Lower LCD/ET/CHR")
    local et, chr = child(lower, "GROUP Elapsed Time"), child(lower, "GROUP Chronograph")
    assert(lines[et + 1]:match("^%s*SHOW_EQUAL 0%.000000 " .. P .. "et_chr_display%s*$"), "ET's first SHOW")
    assert(lines[et + 2]:match("^%s*SHOW_GREATER 0%.000001 " .. P .. "et_seconds%s*$"), "ET's second SHOW")
    replace[et + 1] = lines[et + 1]:match("^(%s*)") .. "SHOW_EQUAL 1.000000 " .. P .. "et_show"
    replace[et + 2] = false
    change("lines %d-%d: the ET's two SHOW lines -> SHOW_EQUAL 1 %set_show", et + 1, et + 2, P)
    assert(et < chr and group_end(et) + 1 == chr, "Elapsed Time then Chronograph")
    wrap(et, group_end(chr), "Digits", "SHOW_EQUAL 1.000000 " .. P .. "on")
end
print(changes .. " changes")

local out = {}
for i, l in ipairs(lines) do
    for _, b in ipairs(before[i] or {}) do out[#out + 1] = b end
    local v = replace[i]
    if v == nil then v = l end
    if v then
        if shift[i] and v:match("%S") then v = "  " .. v end
        out[#out + 1] = v
    end
    for _, a in ipairs(after[i] or {}) do out[#out + 1] = a end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
