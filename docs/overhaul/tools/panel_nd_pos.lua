-- The custom acf's ND POS switch symbols (5-2 step 5c; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_pos.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, at the end of
-- the map symbols' group (GROUP ND Text Center: it moves with MAP CTR), from
-- the display glue's laminar/B747/nd/<side>/pos_* (B747.60.nd_model.lua):
--  - the IRU positions (three stars, pos_iru[0..2]) and the GPS position
--    (pos_gps) at the airplane symbol (FCOM p.1150), as the map symbols'
--    distance 0 (the altitude range arc's place);
--  - the VOR L and R raw data radials (FCOM p.1145): turned from the
--    airplane by pos_rad_l_brg, 24-pixel segments up to pos_rad_l_len, the
--    last one ending there (pos_rad_l_end), the tick mark at the DME
--    distance (pos_rad_l_tick), the radial's text (pos_rad_l_text, R-310)
--    along the line from 50 pixels out, turned to read (pos_rad_l_tbrg) on
--    the line's right or left (pos_rad_l_tside 1, 2).
-- Images from make_nd_pos_images.ps1. Names within the panel's 19
-- characters. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_pos.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local SEG_PX = 24                   -- a segment (pos_seg 3 x 24)
local SEGS = 20                     -- up to 480 pixels: the range arc's 465
local LABEL_PX = 50                 -- the text's start from the airplane
local LABEL_W = 70                  -- five letters of the ND font
local LABEL_DY = 4                  -- just off the line

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
local NAME_MAX = 19
local function short(nm)
    local kind, rest = nm:match("^(%S+) (.*)$")
    return kind .. " " .. rest:sub(1, NAME_MAX)
end
local function child(i, nm)
    for _, j in ipairs(children(i)) do
        if name(j):gsub("%s+", " ") == short(nm) then return j end
    end
    error("no " .. nm .. " in " .. name(i))
end
local function pos(i)
    for j = i + 1, gen_end(i) do
        local x, y = lines[j]:match("^%s*POS ([%d.%-]+) ([%d.%-]+)")
        if x then return tonumber(x), tonumber(y) end
    end
    error("no POS in " .. name(i))
end
-- a copy of a gen_ block at depth: a new header, POS, IMAGE, DATAREF, SHOW
local function copy(i, depth, header, x, y, image, dref, show)
    local n = ind(i)
    local pre = string.rep(" ", depth)
    local o = {pre .. short(header)}
    for j = i + 1, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        local key = body:match("^  (%u[%u_]*)")
        if key == "POS" then
            o[#o + 1] = pre .. string.format("  POS %.6f %.6f", x, y)
        elseif key == "IMAGE" and image then
            o[#o + 1] = pre .. "  IMAGE " .. image
        elseif key == "DATAREF" then
            o[#o + 1] = pre .. "  DATAREF " .. (dref or "")
            if show then o[#o + 1] = pre .. "  " .. show end
        elseif key == "SHOW_LESS" or key == "SHOW_EQUAL" or key == "SHOW_GREATER" then
            -- dropped
        else
            o[#o + 1] = body == "" and "" or pre .. body
        end
    end
    return o
end
local function add(o, block) for _, l in ipairs(block) do o[#o + 1] = l end end
local function group(o, depth, nm, props)
    local pre = string.rep(" ", depth)
    o[#o + 1] = pre .. short("GROUP " .. nm)
    for _, p in ipairs(props or {}) do o[#o + 1] = pre .. "  " .. p end
end
local function group_close(o, depth) o[#o + 1] = string.rep(" ", depth) .. "END_GROUP" end
local function turn_props(dref, x, y)
    return {"GROUP_ANIMATE_MODE ROTATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        string.format("POS %.6f %.6f", x, y), "KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 45.000000 45.000000",
        "ROTATE_OFFSET_X 0.000000", "ROTATE_OFFSET_Y 0.000000"}
end
local function slide_props(dref)
    return {"GROUP_ANIMATE_MODE TRANSLATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        "POS 0.000000 0.000000", "KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 1000.000000 1000.000000",
        "IS_VERTICAL 1", "OFFSET 0.000000"}
end

local after = {}
local changes = 0
local NDS = {{top = "Captain ND", side = "capt", banana = "GROUP ND CAPT BANANA Y", arc = "gen_rotary CAPT BANANA"},
    {top = "First Officer ND", side = "fo", banana = "GROUP ND FO BANANA Y", arc = "gen_rotary FO BANANA"}}
for _, d in ipairs(NDS) do
    local top
    for i, l in ipairs(lines) do if l == "GROUP " .. d.top then top = i break end end
    assert(top, "no " .. d.top)
    local center
    for j = top + 1, group_end(top) - 1 do
        if name(j) == "GROUP ND Text Center" then assert(not center, "two ND Text Center"); center = j end
    end
    assert(center, "no ND Text Center in " .. d.top)
    local arc = child(child(center, d.banana), d.arc)
    local ax, ay = pos(arc)
    local green = child(child(child(child(center, "GROUP ND Text Icons0"), "GROUP ND Text0 Y"), "GROUP ND Text0 backrotate"),
        "gen_text Text0 Green")
    local P = "laminar/B747/nd/" .. d.side .. "/"
    local depth = ind(center) + 2
    local o = {}
    -- the IRU and GPS positions
    group(o, depth, "POS Symbols")
    for k, nmk in ipairs({"L", "C", "R"}) do
        add(o, copy(arc, depth + 2, "gen_rotary POS IRU " .. nmk, ax, ay, "CRT Displays/ND/pos_iru", "",
            string.format("SHOW_GREATER 0.500000 %spos_iru[%d]", P, k - 1)))
    end
    add(o, copy(arc, depth + 2, "gen_rotary POS GPS", ax, ay, "CRT Displays/ND/pos_gps", "",
        "SHOW_GREATER 0.500000 " .. P .. "pos_gps"))
    group_close(o, depth)
    -- the radials
    for _, k in ipairs({"l", "r"}) do
        local K = k:upper()
        local R = P .. "pos_rad_" .. k
        group(o, depth, "POS Rad " .. K, {"SHOW_GREATER 0.500000 " .. R})
        group(o, depth + 2, "POS Rad " .. K .. " Turn", turn_props(R .. "_brg", ax, ay))
        for s = 0, SEGS - 1 do
            add(o, copy(arc, depth + 4, string.format("gen_rotary R%s Seg%d", K, s), ax, ay + SEG_PX / 2 + SEG_PX * s,
                "CRT Displays/ND/pos_seg", "", string.format("SHOW_GREATER %.6f %s_len", SEG_PX * (s + 1) - 0.5, R)))
        end
        group(o, depth + 4, "R" .. K .. " End", slide_props(R .. "_end"))
        add(o, copy(arc, depth + 6, "gen_rotary R" .. K .. " SegE", ax, ay + SEG_PX / 2, "CRT Displays/ND/pos_seg", "",
            string.format("SHOW_GREATER %.6f %s_len", SEG_PX - 0.5, R)))
        group_close(o, depth + 4)
        group(o, depth + 4, "R" .. K .. " Tick", {"SHOW_GREATER 0.500000 " .. R .. "_tick"})
        group(o, depth + 6, "R" .. K .. " Tick Slide", slide_props(R .. "_len"))
        add(o, copy(arc, depth + 8, "gen_rotary R" .. K .. " Tick", ax, ay, "CRT Displays/ND/pos_tick", ""))
        group_close(o, depth + 6)
        group_close(o, depth + 4)
        group_close(o, depth + 2)
        for side = 1, 2 do
            group(o, depth + 2, string.format("R%s Label %d", K, side), {string.format("SHOW_EQUAL %.6f %s_tside", side, R)})
            group(o, depth + 4, string.format("R%s Label %d Turn", K, side), turn_props(R .. "_tbrg", ax, ay))
            local tx = side == 1 and ax + LABEL_PX or ax - LABEL_PX - LABEL_W
            add(o, copy(green, depth + 6, string.format("gen_text R%s Text %d", K, side), tx, ay + LABEL_DY, nil, R .. "_text"))
            group_close(o, depth + 4)
            group_close(o, depth + 2)
        end
        group_close(o, depth)
    end
    local at = group_end(center) - 1
    assert(not after[at], "two insertions after line " .. at)
    after[at] = o
    changes = changes + 1
    print(string.format("%s (line %d): + POS Symbols, POS Rad L, POS Rad R at the airplane %.2f %.2f (%d lines)",
        d.top, top, ax, ay, #o))
end
print(changes .. " changes")

local out = {}
for i, l in ipairs(lines) do
    out[#out + 1] = l
    if after[i] then for _, a in ipairs(after[i]) do out[#out + 1] = a end end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
