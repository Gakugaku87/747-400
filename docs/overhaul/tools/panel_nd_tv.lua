-- The custom acf's ND position trend vector (5-2 step 5e, FCOM p.1147;
-- panel changes allowed anywhere since 2026-10-25). Run from the repository
-- root:
--   luajit docs/overhaul/tools/panel_nd_tv.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, at the end of
-- the map symbols' group (GROUP ND Text Center: it moves with MAP CTR), the
-- 9 pieces of the trend vector's dashes from the display glue's
-- laminar/B747/nd/<side>/tv_* (B747.60.nd_model.lua): each shown with
-- tv_show[k], moved tv_x[k] right and tv_y[k] up from the airplane symbol
-- (pixels), turned by tv_rot[k] about its middle, the image's frame
-- tv_frame[k]. Image from make_nd_tv_image.ps1 (40 frames). Names within
-- the panel's 19 characters. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_tv.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local PIECES = 9
local FRAMES = 40

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
-- a copy of a gen_ block at depth: a new header, POS, IMAGE, DATAREF, SHOW,
-- DIGITS
local function copy(i, depth, header, x, y, image, dref, show, digits)
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
        elseif key == "DIGITS" and digits then
            o[#o + 1] = pre .. "  DIGITS " .. digits
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
-- right (vertical false) or up by pixels
local function slide_props(dref, vertical)
    return {"GROUP_ANIMATE_MODE TRANSLATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        "POS 0.000000 0.000000", "KEY_FRAME -1000.000000 -1000.000000 1.000000", "KEY_FRAME 1000.000000 1000.000000",
        "IS_VERTICAL " .. (vertical and 1 or 0), "OFFSET 0.000000"}
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
    local slot = child(child(child(center, "GROUP ND Text Icons0"), "GROUP ND Text0 Y"), "GROUP ND Text0 backrotate")
    local icon = child(slot, "gen_rotary Text0 Icon")
    local P = "laminar/B747/nd/" .. d.side .. "/"
    local depth = ind(center) + 2
    local o = {}
    group(o, depth, "ND Trend")
    for k = 0, PIECES - 1 do
        local A = function(field) return string.format("%s%s[%d]", P, field, k) end
        group(o, depth + 2, "TV" .. k, {"SHOW_GREATER 0.500000 " .. A("tv_show")})
        group(o, depth + 4, "TV" .. k .. " X", slide_props(A("tv_x"), false))
        group(o, depth + 6, "TV" .. k .. " Y", slide_props(A("tv_y"), true))
        group(o, depth + 8, "TV" .. k .. " Rot", turn_props(A("tv_rot"), ax, ay))
        add(o, copy(icon, depth + 10, "gen_rotary TV" .. k .. " Piece", ax, ay, "CRT Displays/ND/tv_piece", A("tv_frame"),
            nil, FRAMES))
        for dd = depth + 8, depth + 2, -2 do group_close(o, dd) end
    end
    group_close(o, depth)
    local at = group_end(center) - 1
    assert(not after[at], "two insertions after line " .. at)
    after[at] = o
    changes = changes + 1
    print(string.format("%s (line %d): + ND Trend (%d pieces) at the airplane %.2f %.2f (%d lines)", d.top, top, PIECES, ax, ay, #o))
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
