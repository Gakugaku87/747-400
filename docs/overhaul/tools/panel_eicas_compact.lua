-- The custom acf's compact EICAS format (5-2 step 6b-2, GAP DSP-24, ENG-22;
-- FCOM p.855-857, p.874-875; panel changes allowed anywhere since
-- 2026-10-25). Run from the repository root after panel_eicas_partial.lua:
--   luajit docs/overhaul/tools/panel_eicas_compact.lua <acf in> <acf out>
-- It prints every change. On primary EICAS (GROUP Engine), with
-- laminar/B747/eicas/compact (0 off, 1 every row, 2 the partial rows) and
-- cmp_rows[0..3] (B747.60.eicas_format_model.lua):
--  - in the compact format the normal labels (EPR, N1, EGT), the P&W and
--    RB211 N1 tapes and the EGT tapes are hidden, and the P&W and RB211 EGT
--    readouts and boxes go up below the N1 readouts (+108 px: the figure's
--    rows by the column spacing, 0.806 panel px a figure px);
--  - a new GROUP Compact: the labels on their rows (EPR, N1 and EGT, or for
--    the CF6 N1 and EGT: images from make_eicas_cmp_images.ps1), and the
--    secondary rows below the EGT readouts, each shown with its cmp_rows:
--    N2, FF (P&W and CF6, RB211), OIL P, OIL T, OIL Q, VIB with its source,
--    copies of the secondary engine page's readouts in the columns of
--    primary EICAS with that page's labels; for the CF6 (thrust_ref 1) each
--    row moved to its place in FCOM p.855 below its EGT readouts; all on
--    primary EICAS's brightness rheostat.
-- Positions from FCOM p.856 (P&W) and p.855 (CF6); the RB211's as the
-- P&W's, without N3 (no source). The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_eicas_compact.lua <acf in> <acf out>")

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
local function gen_end(i)
    local n, j = ind(i), i + 1
    while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do j = j + 1 end
    return j - 1
end
local function children(i)
    local n, out = ind(i), {}
    for j = i + 1, group_end(i) - 1 do
        if ind(j) == n + 2 and (lines[j]:match("^%s*GROUP ") or lines[j]:match("^%s*gen_")) then out[#out + 1] = j end
    end
    return out
end
local function child(i, nm)
    local found
    for _, j in ipairs(children(i)) do
        if name(j) == nm then assert(not found, "two " .. nm .. " in " .. name(i)); found = j end
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
local function descendant(i, path)
    for _, nm in ipairs(path) do i = child(i, nm) end
    return i
end

local before, after, shift = {}, {}, {}
local changes = 0
local function change(fmt, ...)
    changes = changes + 1
    print(string.format(fmt, ...))
end
-- lines a to b (whole groups or gen_ blocks) in a new group with props
local function wrap(a, b, nm, props)
    local pre = lines[a]:match("^(%s*)")
    assert(not before[a] and not after[b], "lines " .. a .. "-" .. b .. " wrapped twice")
    local head = {pre .. "GROUP " .. nm}
    for _, p in ipairs(props) do head[#head + 1] = pre .. "  " .. p end
    before[a] = head
    after[b] = {pre .. "END_GROUP"}
    for k = a, b do assert(not shift[k], "line " .. k .. " twice"); shift[k] = true end
    change("lines %d-%d: in a new GROUP %s (%s)", a, b, nm, table.concat(props, "; "))
end
local function last_line(i)
    local e = gen_end(i)
    while not lines[e]:match("%S") do e = e - 1 end
    return e
end

local E = "laminar/B747/eicas/"
local TYPE = "laminar/B747/engines/type"
local REF = "laminar/B747/engines/thrust_ref"
local function translate(dref, frames)
    local p = {"GROUP_ANIMATE_MODE TRANSLATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref, "POS 0.000000 0.000000"}
    for k, fr in ipairs(frames) do
        p[#p + 1] = string.format("KEY_FRAME %.6f %.6f", fr[1], fr[2]) .. (k < #frames and " 1.000000" or "")
    end
    p[#p + 1] = "IS_VERTICAL 1"
    p[#p + 1] = "OFFSET 0.000000"
    return p
end

-- the compact rows' positions (P&W; the CF6's 30 px lower) and the columns
local EGT_UP = 108                          -- the P&W EGT readouts: 674 -> 782
-- the CF6's rows (FCOM p.855 from its EGT readouts at 752.5) less the P&W's
local CF6_DY = {n2 = -34, ff = -37, oil = -23.5, vib = -23}
local Y = {n2 = 746, ff = 717, oilp = 643, oilt = 617, oilq = 592, vib = 567}
local LABEL_X = 1589.5
local function col(k) return 1430.5 + 106 * k end                 -- primary EICAS
local function lower_col(k) return 1432.5 + 105 * k end           -- secondary EICAS

-- primary EICAS's brightness rheostat (the secondary page's is 10: copies
-- keeping it would dim with the secondary EICAS's display unit)
local RHEOSTAT
-- an instrument copied to depth, at x, y; its IMAGE replaced if image;
-- SHOW lines kept unless drop_show; primary EICAS's rheostat. A panel instrument obeys only its last
-- SHOW line (the source has instruments with two, meant together): all but
-- the last go to groups around the copy, one each, so that all must hold
local function copy(i, depth, x, y, image, drop_show)
    local n = ind(i)
    local shows = {}
    if not drop_show then
        for j = i + 1, gen_end(i) do
            if lines[j]:match("^%s*SHOW_") then shows[#shows + 1] = name(j) end
        end
    end
    local out = {}
    for k = 1, #shows - 1 do
        out[#out + 1] = string.rep(" ", depth) .. "GROUP " .. name(i):gsub("^gen_%a+ ", "") .. " " .. k
        out[#out + 1] = string.rep(" ", depth + 2) .. shows[k]
        depth = depth + 2
    end
    for j = i, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        local key = body:match("^  (%u[%u_]*)")
        if body ~= "" then
            if key == "POS" then body = string.format("  POS %.6f %.6f", x, y)
            elseif key == "IMAGE" and image then body = "  IMAGE " .. image
            elseif key == "LIGHT_RHEOSTAT" then body = "  LIGHT_RHEOSTAT " .. assert(RHEOSTAT)
            elseif key and key:match("^SHOW_") and (drop_show or name(j) ~= shows[#shows]) then body = nil end
            if body then out[#out + 1] = string.rep(" ", depth) .. body end
        else
            out[#out + 1] = ""
        end
    end
    if out[#out] ~= "" then out[#out + 1] = "" end
    for _ = 1, #shows - 1 do
        depth = depth - 2
        out[#out + 1] = string.rep(" ", depth) .. "END_GROUP"
    end
    return out
end
local function add(o, block) for _, l in ipairs(block) do o[#o + 1] = l end end
local function pos(i)
    for j = i + 1, gen_end(i) do
        local x, y = lines[j]:match("^%s*POS ([%d.%-]+) ([%d.%-]+)")
        if x then return tonumber(x), tonumber(y) end
    end
    error("no POS in " .. name(i))
end
-- the engine (0..3) an instrument draws: its dataref's index, else its SHOW's
local function engine(i)
    local show
    for j = i + 1, gen_end(i) do
        local k = lines[j]:match("^%s*DATAREF %S+%[(%d)%]")
        if k then return tonumber(k) end
        show = show or lines[j]:match("^%s*SHOW_%u+ %S+ %S+%[(%d)%]")
    end
    return show and tonumber(show)
end
-- a group's subtree copied to depth: its SHOW lines, its subgroups, and the
-- instruments place(i) gives a position for (nil: left out)
local function copy_tree(g, depth, nm, place)
    local o = {string.rep(" ", depth) .. "GROUP " .. nm}
    for j = g + 1, group_end(g) - 1 do
        if ind(j) == ind(g) + 2 and lines[j]:match("^%s*SHOW_") then
            o[#o + 1] = string.rep(" ", depth + 2) .. name(j)
        end
    end
    for _, c in ipairs(children(g)) do
        if lines[c]:match("^%s*GROUP ") then
            local sub = copy_tree(c, depth + 2, name(c):sub(7), place)
            if #sub > 2 then add(o, sub) end
        else
            local x, y = place(c)
            if x then add(o, copy(c, depth + 2, x, y)) end
        end
    end
    o[#o + 1] = string.rep(" ", depth) .. "END_GROUP"
    return o
end

-- the readouts only (no boxes, labels, tapes or pointers), each to its
-- engine's column at the row's height
local function readouts(dx_of, y)
    return function(c)
        local nm = name(c)
        if not nm:match("^gen_LED ") then return nil end
        local k = assert(engine(c), "no engine for " .. nm .. " at line " .. c)
        return dx_of(c, k), y
    end
end
local function keep_offset(c, k) local x = pos(c) return col(k) + (x - lower_col(k)) end
local function centred(c, k) return col(k) - 0.5 end

-- primary EICAS: the engine group
local up = top("Upper EICAS")
local eng = descendant(up, {"GROUP Lower EICAS Horizon", "GROUP Lower EICAS Vertica", "GROUP Engine"})
local kids = children(eng)
assert(name(kids[1]) == "gen_rotary Background" and name(kids[2]) == "gen_rotary Background", "the two labels first")
wrap(kids[1], last_line(kids[2]), "Normal Labels", {"SHOW_EQUAL 0.000000 " .. E .. "compact"})
local n1 = child(eng, "GROUP N1")
local n1_tape = child(n1, "GROUP N1 Tape")
wrap(n1_tape, group_end(n1_tape), "N1 Tape Normal", {"SHOW_EQUAL 0.000000 " .. E .. "compact"})
local egt = child(eng, "GROUP EGT")
local egt_tape, egt_tape_ge = child(egt, "GROUP EGT Tape"), child(egt, "GROUP EGT Tape GE")
assert(group_end(egt_tape) + 1 == egt_tape_ge, "the EGT tapes together")
wrap(egt_tape, group_end(egt_tape_ge), "EGT Tapes Normal", {"SHOW_EQUAL 0.000000 " .. E .. "compact"})
local egt_led = child(egt, "GROUP EGT LED")
wrap(egt_led, group_end(egt_led), "EGT LED Compact", translate(E .. "compact", {{0, 0}, {1, EGT_UP}, {2, EGT_UP}}))

-- the new compact group at the end of the engine group
local label = kids[1]                       -- the instrument the labels copy
for j = label + 1, gen_end(label) do
    RHEOSTAT = RHEOSTAT or lines[j]:match("^%s*LIGHT_RHEOSTAT (%d+)")
end
local depth = ind(eng) + 2
local o = {string.rep(" ", depth) .. "GROUP Compact", string.rep(" ", depth + 2) .. "SHOW_GREATER 0.500000 " .. E .. "compact"}
local d = depth + 2
local U = "CRT Displays/EICAS Upper/"
o[#o + 1] = string.rep(" ", d) .. "GROUP Cmp Labels EPR"
o[#o + 1] = string.rep(" ", d + 2) .. "SHOW_EQUAL 0.000000 " .. REF
add(o, copy(label, d + 2, LABEL_X, 980, U .. "eicas_cmp_epr", true))
add(o, copy(label, d + 2, LABEL_X, 841, U .. "eicas_cmp_n1", true))
add(o, copy(label, d + 2, LABEL_X, 674 + EGT_UP, U .. "eicas_cmp_egt", true))
o[#o + 1] = string.rep(" ", d) .. "END_GROUP"
o[#o + 1] = string.rep(" ", d) .. "GROUP Cmp Labels N1"
o[#o + 1] = string.rep(" ", d + 2) .. "SHOW_EQUAL 1.000000 " .. REF
add(o, copy(label, d + 2, LABEL_X, 959.5, U .. "eicas_cmp_n1", true))
add(o, copy(label, d + 2, LABEL_X, 752.5, U .. "eicas_cmp_egt", true))
o[#o + 1] = string.rep(" ", d) .. "END_GROUP"

o[#o + 1] = string.rep(" ", d) .. "GROUP Cmp Rows"
local r = d + 2
-- a row's group: shown with its cmp_rows, moved for the CF6
local function row_group(nm, k, dy)
    o[#o + 1] = string.rep(" ", r) .. "GROUP " .. nm
    o[#o + 1] = string.rep(" ", r + 2) .. string.format("SHOW_EQUAL 1.000000 %scmp_rows[%d]", E, k)
    for _, p in ipairs(translate(REF, {{0, 0}, {1, dy}})) do o[#o + 1] = string.rep(" ", r + 2) .. p end
end
local sec = descendant(top("LOWER EICAS POWER"), {"GROUP Lower EICAS", "GROUP Lower EICAS Vertica", "GROUP ENG Synoptic"})
local function row_label(group, y)
    local bg = child(group, "gen_rotary Background")
    return copy(bg, r + 2, LABEL_X, y, nil, true)
end
-- N2 (the P&W page's readouts: display_N2 for every engine type)
local n2 = descendant(sec, {"GROUP N2 Rows", "GROUP N2"})
row_group("Cmp N2", 0, CF6_DY.n2)
add(o, row_label(n2, Y.n2))
add(o, copy_tree(child(n2, "GROUP LED"), r + 2, "N2 LED", readouts(keep_offset, Y.n2)))
o[#o + 1] = string.rep(" ", r) .. "END_GROUP"
-- FF (P&W and CF6; RB211)
local ff_rows = child(sec, "GROUP FF Rows")
local ff, ff_rr = child(ff_rows, "GROUP FF"), child(ff_rows, "GROUP FF RR")
row_group("Cmp FF", 1, CF6_DY.ff)
add(o, row_label(ff, Y.ff))
for _, g in ipairs({ff, ff_rr}) do
    local sub = {string.rep(" ", r + 2) .. "GROUP Cmp " .. name(g):sub(7)}
    for j = g + 1, group_end(g) - 1 do
        if ind(j) == ind(g) + 2 and lines[j]:match("^%s*SHOW_") then sub[#sub + 1] = string.rep(" ", r + 4) .. name(j) end
    end
    add(sub, copy_tree(child(g, "GROUP LED"), r + 4, "FF LED", readouts(keep_offset, Y.ff)))
    sub[#sub + 1] = string.rep(" ", r + 2) .. "END_GROUP"
    add(o, sub)
end
o[#o + 1] = string.rep(" ", r) .. "END_GROUP"
-- the oil: pressure, temperature, quantity
local oil = child(sec, "GROUP Oil Rows")
local oil_p, oil_t, oil_q = child(oil, "GROUP Oil Pressure"), child(oil, "GROUP Oil Temp"), child(oil, "GROUP Oil Qty")
row_group("Cmp Oil", 2, CF6_DY.oil)
add(o, row_label(oil_p, Y.oilp))
add(o, copy_tree(child(oil_p, "GROUP LED"), r + 2, "Oil P LED", readouts(centred, Y.oilp)))
add(o, row_label(oil_t, Y.oilt))
add(o, copy_tree(child(oil_t, "GROUP LED"), r + 2, "Oil T LED", readouts(centred, Y.oilt)))
local oil_q_led = child(oil_q, "GROUP LED")
add(o, row_label(oil_q_led, Y.oilq))
add(o, copy_tree(oil_q_led, r + 2, "Oil Q LED", readouts(centred, Y.oilq)))
o[#o + 1] = string.rep(" ", r) .. "END_GROUP"
-- VIB: the source label left of the readout (FCOM p.855-856)
local vib = descendant(sec, {"GROUP VIB Row", "GROUP VIB"})
row_group("Cmp VIB", 3, CF6_DY.vib)
add(o, row_label(child(vib, "GROUP Tape"), Y.vib))
add(o, copy_tree(child(vib, "GROUP Source"), r + 2, "VIB Source", function(c)
    local k = assert(engine(c), "no engine for " .. name(c))
    return col(k) - 22, Y.vib
end))
add(o, copy_tree(child(vib, "GROUP LED"), r + 2, "VIB LED", readouts(function(c, k) return col(k) + 10 end, Y.vib)))
o[#o + 1] = string.rep(" ", r) .. "END_GROUP"
o[#o + 1] = string.rep(" ", d) .. "END_GROUP"
o[#o + 1] = string.rep(" ", depth) .. "END_GROUP"
local at = group_end(eng) - 1
after[at] = after[at] or {}
for _, l in ipairs(o) do after[at][#after[at] + 1] = l end
change("after line %d: + GROUP Compact (%d lines)", at, #o)
print(changes .. " changes")

local out = {}
for i, l in ipairs(lines) do
    for _, b in ipairs(before[i] or {}) do out[#out + 1] = b end
    if shift[i] and l:match("%S") then l = "  " .. l end
    out[#out + 1] = l
    for _, x in ipairs(after[i] or {}) do out[#out + 1] = x end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
