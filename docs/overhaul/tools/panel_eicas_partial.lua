-- The custom acf's EICAS partial format and secondary engine exceedance cue
-- (5-2 step 6b, GAP DSP-24, ENG-22; panel changes allowed anywhere since
-- 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_eicas_partial.lua <acf in> <acf out>
-- It prints every change. With the EICAS format model's datarefs
-- (laminar/B747/eicas/*, B747.60.xt.displays.lua):
--  - secondary EICAS, GROUP ENG Synoptic: shown with eicas/sec_eng (the
--    full or partial format) instead of dsp/synoptic_display = 1; its rows
--    each in a new group shown with eicas/sec_rows[0..3]: N2 (the P&W, GE
--    and RB211 groups), FF (P&W and GE, RB211), the oil (pressure,
--    temperature, quantity), VIB (FCOM p.852-854);
--  - primary EICAS, GROUP CAS Messages: the STATUS cue in a new group
--    hidden with eicas/exceed_cue, and a copy of it showing
--    eicas/exceed_cue_text (VVVVVV) with eicas/exceed_cue in its place
--    (FCOM p.840).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_eicas_partial.lua <acf in> <acf out>")

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
-- a gen_ block's last line (the blank line after it included)
local function gen_end(i)
    local n, j = ind(i), i + 1
    while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do j = j + 1 end
    return j - 1
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
local function top(nm)
    local found
    for i, l in ipairs(lines) do
        if l == "GROUP " .. nm then assert(not found, "two " .. nm); found = i end
    end
    return assert(found, "no " .. nm)
end
-- the group (or gen_ block) at i and those after it to j, one level down
local function descendant(i, path)
    for _, nm in ipairs(path) do i = child(i, nm) end
    return i
end

local replace, before, after, shift = {}, {}, {}, {}
local changes = 0
local function change(fmt, ...)
    changes = changes + 1
    print(string.format(fmt, ...))
end
-- lines a to b (whole groups or gen_ blocks) in a new group shown with show
local function wrap(a, b, nm, show)
    local pre = lines[a]:match("^(%s*)")
    assert(not before[a] and not after[b], "lines " .. a .. "-" .. b .. " wrapped twice")
    before[a] = {pre .. "GROUP " .. nm, pre .. "  " .. show}
    after[b] = {pre .. "END_GROUP"}
    for k = a, b do assert(not shift[k], "line " .. k .. " twice"); shift[k] = true end
    change("lines %d-%d: in a new GROUP %s (%s)", a, b, nm, show)
end

local E = "laminar/B747/eicas/"

-- secondary EICAS: the engine page and its rows
local eng = descendant(top("LOWER EICAS POWER"), {"GROUP Lower EICAS", "GROUP Lower EICAS Vertica", "GROUP ENG Synoptic"})
assert(lines[eng + 1]:match("^%s*SHOW_EQUAL 1%.000000 laminar/B747/dsp/synoptic_display%s*$"), "the ENG page's SHOW")
replace[eng + 1] = lines[eng + 1]:match("^(%s*)") .. "SHOW_EQUAL 1.000000 " .. E .. "sec_eng"
change("line %d: the ENG page shown with %ssec_eng (was dsp/synoptic_display = 1)", eng + 1, E)
local ROWS = {
    {"N2 Rows", 0, {"GROUP N2", "GROUP N2 GE", "GROUP N2 N3 RR"}},
    {"FF Rows", 1, {"GROUP FF", "GROUP FF RR"}},
    {"Oil Rows", 2, {"GROUP Oil Pressure", "GROUP Oil Temp", "GROUP Oil Qty"}},
    {"VIB Row", 3, {"GROUP VIB"}},
}
for _, r in ipairs(ROWS) do
    local first, last
    for k, nm in ipairs(r[3]) do
        local g = child(eng, nm)
        if k == 1 then first = g
        else assert(g == last + 1, nm .. " not right after the one before") end
        last = group_end(g)
    end
    wrap(first, last, r[1], string.format("SHOW_EQUAL 1.000000 %ssec_rows[%d]", E, r[2]))
end

-- primary EICAS: the exceedance cue in the STATUS cue's place
local cas = descendant(top("Upper EICAS"), {"GROUP Lower EICAS Horizon", "GROUP Lower EICAS Vertica", "GROUP CAS Messages"})
local cue = child(cas, "gen_text STATUS cue")
local cue_end = gen_end(cue)
while not lines[cue_end]:match("%S") do cue_end = cue_end - 1 end
wrap(cue, cue_end, "Status Cue", "SHOW_EQUAL 0.000000 " .. E .. "exceed_cue")
local copy = {}
local n = ind(cue)
for k = cue, cue_end do
    local l = lines[k]
    local body = l:sub(n + 1)
    if body == "gen_text STATUS cue" then body = "gen_text Exceedance cue"
    elseif body:match("^  DATAREF ") then body = "  DATAREF " .. E .. "exceed_cue_text[0]"
    elseif body:match("^  SHOW_") then body = "  SHOW_EQUAL 1.000000 " .. E .. "exceed_cue" end
    copy[#copy + 1] = string.rep(" ", n) .. body
end
copy[#copy + 1] = ""
local a = after[cue_end]
for _, l in ipairs(copy) do a[#a + 1] = l end
change("after line %d: + gen_text Exceedance cue (%sexceed_cue_text with %sexceed_cue, %d lines)", cue_end, E, E, #copy)
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
    for _, x in ipairs(after[i] or {}) do out[#out + 1] = x end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
