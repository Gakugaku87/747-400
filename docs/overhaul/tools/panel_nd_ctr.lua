-- The custom acf's ND MAP CTR as the real airplane's (5-2, 2026-10-28: the
-- user's choice; panel changes allowed anywhere since 2026-10-25). Run from
-- the repository root:
--   luajit docs/overhaul/tools/panel_nd_ctr.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND:
--  1. the centred displays' current heading pointer (Hdg Ptr:APP/VOR/MAP)
--     touching the compass rose's outer edge (FCOM p.1142: it points at
--     the heading on the rose): the rose's tick marks reach 229 pixels from
--     its centre (roseM_S, rose_S: 460 pixels, their top marks from row 1),
--     the pointer's tip is the image's middle row (hdg_ptr: 28 pixels, the
--     tip on row 14), one pixel inside OFFSET, so OFFSET 230 (before 237:
--     7 pixels beyond the rose);
--  2. X-Plane's centred map (EFIS_map_s_HM) at its size while the display
--     glue's nd/<side>/xp_map_half is 0, and a copy at half the size (SIZE
--     1.75, the same POS: the map's origin) while it is 1: MAP CTR at 640
--     NM, X-Plane's map having no range above 640 NM (MAP CTR's range is
--     the compass rose, half the expanded scale: B747.60.nd_model.lua);
--  3. MAP CTR's track line and range scale (FCOM p.1143, MAP CTR; p.1009's
--     figure), after the centred MAP rose, shown with nd/<side>/
--     trk_line_ctr: the line image from make_nd_ctr_image.ps1 on the rose's
--     centre, and the half range (nd/range_display_<side>, the expanded
--     map's number) at its two marks, each placed against its mark as the
--     expanded map's number is against the expanded line's half range mark;
--  4. MAP CTR's airplane symbol (gen_rotary Aircraft Triangle in GROUP
--     Map:Centered) with its apex on the map's origin (FCOM p.1251: the FMC
--     position at the apex, all the map's data relative to it): the
--     image's apex 16 pixels above its centre (aircraft_triangle: 52
--     pixels, the apex on row 10), so POS y 62.5 for the origin's 78.5
--     (before 49: the apex 13.5 pixels below the map's origin).
-- Names within the panel's 19 characters. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_ctr.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local PTR_PX = 230              -- the heading pointer's OFFSET: its tip 229 from the rose's centre, the rose's outer edge
local PTR_OLD = 237
local HALF_SIZE = 1.75          -- X-Plane's centred map at half its 3.5
local ORIGIN_UP = 6.5           -- the map's origin above the rose's centre (the symbols' 78.5, the rose's 72)
local RANGE_PX = 232.5          -- MAP CTR's selected range
local EXP_MARK = -85 + 222.5    -- the expanded line's half range mark (its pivot -85, the image's middle mark)
local APEX_UP = 16              -- the airplane symbol's apex above its image's centre
local TRI_OLD = 49

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
        if ind(j) == n + 2 and (lines[j]:match("^%s*GROUP ") or lines[j]:match("^%s*gen_")
            or lines[j]:match("^%s*EFIS_map")) then out[#out + 1] = j end
    end
    return out
end
-- the child whose name is nm, or nm and " 2" (the Captain's copies)
local function child(i, nm)
    for _, j in ipairs(children(i)) do
        local n = name(j):gsub("%s+", " ")
        if n == nm or n == nm .. " 2" then return j end
    end
    error("no " .. nm .. " in " .. name(i))
end
local function find_in(i, nm)
    for j = i + 1, group_end(i) - 1 do
        local n = name(j):gsub("%s+", " ")
        if n == nm or n == nm .. " 2" then return j end
    end
    error("no " .. nm .. " in " .. name(i))
end
local function prop(i, key)
    for j = i + 1, gen_end(i) do
        local v = lines[j]:match("^%s*" .. key .. " (.*)$")
        if v then return v, j end
    end
    error("no " .. key .. " in " .. name(i))
end
local function pos(i)
    local v = prop(i, "POS")
    local x, y = v:match("^([%d.%-]+) ([%d.%-]+)")
    return tonumber(x), tonumber(y)
end
local NAME_MAX = 19
local function short(nm)
    local kind, rest = nm:match("^(%S+) (.*)$")
    return kind .. " " .. rest:sub(1, NAME_MAX)
end
-- a copy of a block at depth: a new header, POS, IMAGE, DATAREF, SIZE; the
-- SHOW_ conditions dropped
local function copy(i, depth, header, x, y, image, dref, size)
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
        elseif key == "DATAREF" and dref then
            o[#o + 1] = pre .. "  DATAREF " .. dref
        elseif key == "SIZE" and size then
            o[#o + 1] = pre .. string.format("  SIZE %.6f", size)
        elseif key == "SHOW_LESS" or key == "SHOW_EQUAL" or key == "SHOW_GREATER" then
            -- dropped
        else
            o[#o + 1] = body == "" and "" or pre .. body
        end
    end
    return o
end
-- a block moved to depth as it is
local function moved(i, depth)
    local n, pre, o = ind(i), string.rep(" ", depth), {}
    for j = i, gen_end(i) do
        local l = lines[j]
        o[#o + 1] = l:match("%S") and pre .. l:sub(n + 1) or ""
    end
    return o
end
local function add(o, block) for _, l in ipairs(block) do o[#o + 1] = l end end

local replace = {}      -- [first line] = {last line, new lines}
local changes = 0
local NDS = {{top = "Captain ND", side = "capt", led = "gen_LED Range Display ND CA"},
    {top = "First Officer ND", side = "fo", led = "gen_LED Range Display ND FO"}}
for _, d in ipairs(NDS) do
    local top
    for i, l in ipairs(lines) do if l == "GROUP " .. d.top then top = i break end end
    assert(top, "no " .. d.top)
    local P = "laminar/B747/nd/" .. d.side .. "/"
    local function in_nd(nm)
        local hit
        for j = top + 1, group_end(top) - 1 do
            local n = name(j):gsub("%s+", " ")
            if n == nm or n == nm .. " 2" then assert(not hit, "two " .. nm); hit = j end
        end
        return assert(hit, "no " .. nm .. " in " .. d.top)
    end

    -- 1. the centred heading pointer
    local ptr = in_nd("gen_needle Hdg Ptr:APP/VOR/MAP")
    local px, py = pos(ptr)
    local off, oj = prop(ptr, "OFFSET")
    local noff, nj = prop(ptr, "NEEDLE_OFFSET_Y")
    assert(math.abs(tonumber(off) - PTR_OLD) < 1e-6 and math.abs(tonumber(noff) + PTR_OLD) < 1e-6,
        d.top .. ": the heading pointer is not at " .. PTR_OLD)
    local pivot = py - PTR_OLD
    local _, pj = prop(ptr, "POS")
    local pre = lines[pj]:match("^(%s*)")
    lines[pj] = pre .. string.format("POS %.6f %.6f", px, pivot + PTR_PX)
    lines[oj] = pre .. string.format("OFFSET %.6f", PTR_PX)
    lines[nj] = pre .. string.format("NEEDLE_OFFSET_Y %.6f", -PTR_PX)
    changes = changes + 1
    print(string.format("%s (line %d): Hdg Ptr:APP/VOR/MAP POS y %.1f -> %.1f, OFFSET %d -> %d, NEEDLE_OFFSET_Y -%d -> -%d (pivot %.1f)",
        d.top, ptr, py, pivot + PTR_PX, PTR_OLD, PTR_PX, PTR_OLD, PTR_PX, pivot))

    -- 2. X-Plane's centred map, full or half size
    local centred = in_nd("GROUP Map:Centered")
    local rose_grp = child(centred, "GROUP Map/Rose")
    local map = child(rose_grp, "EFIS_map_s_HM map_s_HM.png")
    local mx, my = pos(map)
    local size = tonumber((prop(map, "SIZE")))
    assert(math.abs(size - 2 * HALF_SIZE) < 1e-6, d.top .. ": X-Plane's centred map is not at SIZE 3.5")
    local depth = ind(map)
    local o = {}
    o[#o + 1] = string.rep(" ", depth) .. "GROUP XP Map Full"
    o[#o + 1] = string.rep(" ", depth + 2) .. "SHOW_LESS 0.500000 " .. P .. "xp_map_half"
    add(o, moved(map, depth + 2))
    o[#o + 1] = string.rep(" ", depth) .. "END_GROUP"
    o[#o + 1] = string.rep(" ", depth) .. "GROUP XP Map Half"
    o[#o + 1] = string.rep(" ", depth + 2) .. "SHOW_GREATER 0.500000 " .. P .. "xp_map_half"
    add(o, copy(map, depth + 2, name(map), mx, my, nil, nil, HALF_SIZE))
    o[#o + 1] = string.rep(" ", depth) .. "END_GROUP"
    assert(not replace[map], "two changes at line " .. map)
    replace[map] = {gen_end(map), o}
    changes = changes + 1
    print(string.format("%s (line %d): X-Plane's centred map at %.1f %.1f in GROUP XP Map Full (xp_map_half 0) + a SIZE %.2f copy in GROUP XP Map Half (xp_map_half 1)",
        d.top, map, mx, my, HALF_SIZE))

    -- 3. MAP CTR's track line and range scale after the centred MAP rose
    local compass = child(rose_grp, "GROUP Compass Rose")
    local rose = child(compass, "gen_needle Rose:MAP")
    local rx, ry = pos(rose)
    local mask = child(rose_grp, "gen_rotary Mask:Centered:0:1:2")
    local led = in_nd(d.led)
    local lx, ly = pos(led)
    local trk = in_nd("gen_needle Track Line")
    local tx = pos(trk)
    local dx, dy = lx - tx, ly - EXP_MARK
    local origin = ry + ORIGIN_UP
    local up_y, dn_y = origin + RANGE_PX / 2 + dy, origin - RANGE_PX / 2 + dy
    depth = ind(rose)
    o = {}
    o[#o + 1] = string.rep(" ", depth) .. "GROUP Trk Line Ctr"
    o[#o + 1] = string.rep(" ", depth + 2) .. "SHOW_GREATER 0.500000 " .. P .. "trk_line_ctr"
    add(o, copy(mask, depth + 2, "gen_rotary Trk Line Ctr", rx, ry, "EFIS/Maps/Centered/track_line_ctr", nil))
    add(o, copy(led, depth + 2, "gen_LED Range Ctr Up", rx + dx, up_y, nil, nil))
    add(o, copy(led, depth + 2, "gen_LED Range Ctr Dn", rx + dx, dn_y, nil, nil))
    o[#o + 1] = string.rep(" ", depth) .. "END_GROUP"
    local last = gen_end(rose)
    assert(not replace[last + 1], "two changes at line " .. (last + 1))
    replace[last + 1] = {last, o, after = true}
    changes = changes + 1
    print(string.format("%s (line %d): + GROUP Trk Line Ctr after Rose:MAP: the line at %.1f %.1f, the half range at %.1f %.1f and %.1f %.1f (the expanded number %.1f %.1f against its mark %.1f %.1f)",
        d.top, rose, rx, ry, rx + dx, up_y, rx + dx, dn_y, lx, ly, tx, EXP_MARK))

    -- 4. MAP CTR's airplane symbol, its apex on the map's origin
    local tri = child(centred, "gen_rotary Aircraft Triangle")
    local tri_x, tri_y = pos(tri)
    assert(math.abs(tri_y - TRI_OLD) < 1e-6, d.top .. ": MAP CTR's airplane symbol is not at y " .. TRI_OLD)
    local _, tj = prop(tri, "POS")
    lines[tj] = lines[tj]:match("^(%s*)") .. string.format("POS %.6f %.6f", tri_x, origin - APEX_UP)
    changes = changes + 1
    print(string.format("%s (line %d): MAP CTR's Aircraft Triangle POS y %.1f -> %.1f (the apex %.1f -> %.1f, the map's origin %.1f)",
        d.top, tri, tri_y, origin - APEX_UP, tri_y + APEX_UP, origin, origin))
end
print(changes .. " changes")

local out = {}
local i = 1
while i <= #lines do
    local r = replace[i]
    if r and r.after then
        for _, a in ipairs(r[2]) do out[#out + 1] = a end
        r = nil
    end
    if r then
        for _, a in ipairs(r[2]) do out[#out + 1] = a end
        i = r[1] + 1
    else
        out[#out + 1] = lines[i]
        i = i + 1
    end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
