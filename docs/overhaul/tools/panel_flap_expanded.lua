-- The custom acf's expanded and alternate flap display (FCTL-12; panel
-- instruments may change without approval since 2026-10-25). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_flap_expanded.lua <acf in> <acf out>
-- It prints every change and keeps the file's line ends. Images:
-- docs/overhaul/tools/make_flap_images.ps1. FCOM p.937-938; ATA27 p.320-322,
-- p.398-400.
-- In GROUP Flaps Disagree (the expanded display, EICAS1_display_status 2):
--  - each TE tape (Ind Bgnd and Ind Tape) shows with laminar/B747/flt_ctrls/
--    flaps/te_tape[n] 0 (white); copies in amber with 1 (asymmetry or drive
--    failure in its group); its outline alone with an amber X with 2 (no
--    position data);
--  - the lever's numbers and lines: magenta with flap/transition_status 1
--    (the stock had only these), copies in green with 0; none of them in
--    the alternate display (flaps/altn_display 1);
--  - six LE boxes above the tapes (L OB, L MID, L IB over the left tapes and
--    left of them, R IB, R MID, R OB), one 7-frame instrument each chosen by
--    flaps/le_box[i]; they rise 3 px a box towards the fuselage, as the
--    leading edge on FCOM p.937-938;
--  - the alternate display's flap scale on the outer side of the outboard
--    tapes, with altn_display 1.
-- GROUP Gear Expanded moves up 25 px: its body gear boxes (y 678-712) sat
-- where the LE boxes go, and both expanded displays show together after an
-- alternate gear extension (the stock layout put the gear 48 px above the
-- tapes; on ATA27 p.321 it is about 0.85 of a tape's height above). Its
-- nose box's top (824) stays under the lowest EICAS message line (850).
-- X-Plane takes one condition for each instrument or group
-- (ARCHITECTURE.md §5).
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_flap_expanded.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n")):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end

local DIR = "CRT Displays/EICAS Upper/"
local FLAPS = "laminar/B747/flt_ctrls/flaps/"
local TRANS = "laminar/B747/flt_ctrls/flap/transition_status"
local ALTN = FLAPS .. "altn_display"
local GEAR_UP_PX = 25

local changes = 0
local repl, adds = {}, {}
local function note(msg) changes = changes + 1; print(msg) end
local function add_after(i, new)
    adds[i] = adds[i] or {}
    for _, l in ipairs(new) do adds[i][#adds[i] + 1] = l end
end
local function indent(l) return l:match("^(%s*)") end
local function group_name(l) return l:match("^%s*GROUP (.-)%s*$") end
local function group_end(i)
    local depth = 0
    for j = i, #lines do
        if group_name(lines[j]) then depth = depth + 1
        elseif lines[j]:match("^%s*END_GROUP%s*$") then
            depth = depth - 1
            if depth == 0 then return j end
        end
    end
    error("no END_GROUP for line " .. i)
end
local function find_group(name, from, to)
    for i = from or 1, to or #lines do
        if group_name(lines[i]) == name then return i end
    end
    error("no GROUP " .. name)
end
local function block_end(i)
    local j = i + 1
    while lines[j] ~= nil and lines[j]:match("%S") and not lines[j]:match("^%s*gen_")
        and not group_name(lines[j]) and not lines[j]:match("^%s*END_GROUP") do j = j + 1 end
    return j - 1
end
local function prop(i, key)
    for j = i + 1, block_end(i) do
        local v = lines[j]:match("^%s*" .. key .. " ?(.*)$")
        if v then return v, j end
    end
end
-- a condition after an instrument's DATAREF line
local function add_condition(i, show)
    assert(not prop(i, "SHOW_%u+"), "the instrument at " .. i .. " has a condition")
    local _, d = prop(i, "DATAREF")
    assert(d, "no DATAREF at " .. i)
    add_after(d, {indent(lines[d]) .. show})
    note(string.format("%d: %s + %s", i, lines[i]:gsub("^%s+", ""), show))
end
-- a copy of an instrument block: name, image (or a function of it), the
-- condition (replacing any), other properties replaced ({key = value})
local function clone(i, name, image, show, props)
    local out = {""}
    for k = i, block_end(i) do
        local l = lines[k]
        local key = l:match("^%s*(%u[%u_%d]*)")
        if k == i then
            l = l:gsub("^(%s*gen_%a+ ).*$", "%1" .. name)
            out[#out + 1] = l
        elseif key and key:match("^SHOW_") then
            -- dropped: the copy's condition goes after DATAREF
        elseif key == "IMAGE" then
            local img = l:match("^%s*IMAGE (.*)$")
            out[#out + 1] = indent(l) .. "IMAGE " .. (type(image) == "function" and image(img) or image)
        elseif key and props and props[key] ~= nil then
            if props[key] then out[#out + 1] = indent(l) .. key .. " " .. props[key] end
        else
            out[#out + 1] = l
        end
        if key == "DATAREF" and show then out[#out + 1] = indent(l) .. show end
    end
    return out
end

-- ======== the expanded gear display up
local ge = find_group("Gear Expanded")
local moved = 0
for j = ge, group_end(ge) do
    local ind, x, y = lines[j]:match("^(%s*)POS (%S+) (%S+)$")
    if ind then
        repl[j] = string.format("%sPOS %s %.6f", ind, x, tonumber(y) + GEAR_UP_PX)
        moved = moved + 1
    end
end
assert(moved == 21, "expected 21 instruments in GROUP Gear Expanded, found " .. moved)
note(string.format("GROUP Gear Expanded: %d instruments up %d px", moved, GEAR_UP_PX))

-- ======== the expanded flap display
local fd = find_group("Flaps Disagree")
local fd_end = group_end(fd)
local tape_g = find_group("Tape", fd, fd_end)
local tape_end = group_end(tape_g)

-- the TE tapes: white, amber, X
local tapes = 0
for j = tape_g, tape_end do
    if lines[j]:match("^%s*gen_tape Ind Tape%s*$") then
        local n = tonumber(prop(j, "DATAREF"):match("flap_deployed_ratio(%d)$"))
        assert(n, "a tape without its ratio at " .. j)
        local pos = prop(j, "POS")
        local bg = j - 1
        while not (lines[bg]:match("^%s*gen_rotary Ind Bgnd%s*$") and prop(bg, "POS") == pos) do bg = bg - 1 end
        local te = FLAPS .. "te_tape[" .. (n - 1) .. "]"
        add_condition(bg, "SHOW_EQUAL 0.000000 " .. te)
        add_condition(j, "SHOW_EQUAL 0.000000 " .. te)
        local copies = {}
        for _, c in ipairs({
            clone(bg, "Ind Bgnd Amber", DIR .. "flaps_tape_bgnd_amber", "SHOW_EQUAL 1.000000 " .. te),
            clone(j, "Ind Tape Amber", DIR .. "flaps_tape_amber", "SHOW_EQUAL 1.000000 " .. te),
            clone(bg, "Ind Frame No Data", DIR .. "flaps_tape_frame", "SHOW_EQUAL 2.000000 " .. te),
            clone(bg, "Ind X No Data", DIR .. "flaps_te_x", "SHOW_EQUAL 2.000000 " .. te)}) do
            for _, l in ipairs(c) do copies[#copies + 1] = l end
        end
        add_after(block_end(j), copies)
        note(string.format("%d: tape %d (%s): + amber tape, + frame and X with te_tape[%d]", j, n, pos, n - 1))
        tapes = tapes + 1
    end
end
assert(tapes == 4, "expected 4 tapes, found " .. tapes)

-- the lever's numbers: magenta while moving, green in place, none in ALTN
local labels = find_group("Ind Labels", tape_g, tape_end)
add_after(labels, {indent(lines[labels]) .. "  SHOW_EQUAL 0.000000 " .. ALTN})
note(string.format("%d: GROUP Ind Labels + SHOW_EQUAL 0 %s", labels, ALTN))
local mag = find_group("Selected(magenta)", labels, group_end(labels))
local mag_end = group_end(mag)
local ind = indent(lines[mag])
add_after(mag, {ind .. "  SHOW_EQUAL 1.000000 " .. TRANS})
note(string.format("%d: GROUP Selected(magenta) + SHOW_EQUAL 1 %s", mag, TRANS))
local green = {ind .. "GROUP Selected(green)", ind .. "  SHOW_EQUAL 0.000000 " .. TRANS}
local greens = 0
for k = mag + 1, mag_end do
    local l = lines[k]
    if l:match("^%s*IMAGE .*_magenta$") then l = l:gsub("_magenta$", "_green"); greens = greens + 1 end
    green[#green + 1] = l
end
assert(greens == 7, "expected 7 magenta numbers, found " .. greens)
add_after(mag_end, green)
note(string.format("%d: + GROUP Selected(green) (7 numbers) with SHOW_EQUAL 0 %s", mag_end, TRANS))

-- the lever's lines
local ind_line = find_group("Ind Line", tape_g, tape_end)
add_after(ind_line, {indent(lines[ind_line]) .. "  SHOW_EQUAL 0.000000 " .. ALTN})
note(string.format("%d: GROUP Ind Line + SHOW_EQUAL 0 %s", ind_line, ALTN))
local pointers = 0
for j = ind_line, group_end(ind_line) do
    local n = lines[j]:match("^%s*gen_pointer Line: In Transit (%d)%s*$")
    if n then
        add_condition(j, "SHOW_EQUAL 1.000000 " .. TRANS)
        add_after(block_end(j), clone(j, "Line: Selected " .. n, DIR .. "flaps_indLine_green", "SHOW_EQUAL 0.000000 " .. TRANS))
        note(string.format("%d: + gen_pointer Line: Selected %s (green)", j, n))
        pointers = pointers + 1
    end
end
assert(pointers == 4, "expected 4 lines, found " .. pointers)

-- the LE boxes and the alternate flap scale, last in the group (on top),
-- from the group's Background instrument
local bgd = fd + 1
while not lines[bgd]:match("^%s*gen_rotary Background%s*$") do bgd = bgd + 1 end
local BOXES = {
    {"LE Box L OB", 1825.5, 686, "flaps_le_box_L"}, {"LE Box L MID", 1855.5, 689, "flaps_le_box_L"},
    {"LE Box L IB", 1885.5, 692, "flaps_le_box_L"}, {"LE Box R IB", 1945.5, 692, "flaps_le_box_R"},
    {"LE Box R MID", 1975.5, 689, "flaps_le_box_R"}, {"LE Box R OB", 2005.5, 686, "flaps_le_box_R"}}
local tail = {}
for i, b in ipairs(BOXES) do
    local c = clone(bgd, b[1], DIR .. b[4], nil, {
        POS = string.format("%.6f %.6f", b[2], b[3]),
        DATAREF = FLAPS .. "le_box[" .. (i - 1) .. "]",
        DIGITS = "7"})
    -- the frames: the value is the frame (0-6)
    local kf = 0
    for k, l in ipairs(c) do
        if l:match("^%s*KEY_FRAME ") then
            kf = kf + 1
            c[k] = indent(l) .. (kf == 1 and "KEY_FRAME 0.000000 0.000000 1.000000" or "KEY_FRAME 1.000000 1.000000")
        end
    end
    assert(kf == 2, "the template has " .. kf .. " key frames")
    for _, l in ipairs(c) do tail[#tail + 1] = l end
    note(string.format("+ gen_rotary %s at (%.1f, %d), %s, frame le_box[%d]", b[1], b[2], b[3], b[4], i - 1))
end
for _, s in ipairs({{"Altn Scale L", 1827, "flaps_altn_scale_L"}, {"Altn Scale R", 2004, "flaps_altn_scale_R"}}) do
    local c = clone(bgd, s[1], DIR .. s[3], "SHOW_EQUAL 1.000000 " .. ALTN, {POS = string.format("%.6f %.6f", s[2], 604)})
    for _, l in ipairs(c) do tail[#tail + 1] = l end
    note(string.format("+ gen_rotary %s at (%d, 604), %s, with altn_display 1", s[1], s[2], s[3]))
end
-- before the group's END_GROUP: after its last instrument line
local last = fd_end - 1
while not lines[last]:match("%S") do last = last - 1 end
add_after(last, tail)

local out = {}
for j, l in ipairs(lines) do
    out[#out + 1] = repl[j] or l
    if adds[j] then for _, a in ipairs(adds[j]) do out[#out + 1] = a end end
end
f = assert(io.open(dst, "wb"))
f:write(table.concat(out, nl), nl)
f:close()
print(changes .. " changes")
