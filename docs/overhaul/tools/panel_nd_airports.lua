-- The custom acf's ND origin and destination airports and runways (5-2 step
-- 5c, FCOM p.1149; panel changes allowed anywhere since 2026-10-25). Run
-- from the repository root:
--   luajit docs/overhaul/tools/panel_nd_airports.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, at the end of
-- the map symbols' group (GROUP ND Text Center: it moves with MAP CTR), for
-- each of the two airports k (0 the origin, 1 the destination) from the ND
-- module's laminar/B747/nd/<side>/apt/* (B747.61.xt.nd.lua), each placed as
-- the map symbols are (turned by a bearing from the airplane symbol, moved
-- out by a distance of 640 units to the selected range's 465 pixels, turned
-- back upright):
--  - Apt<k> (sym[k]): the airport symbol at heading[k], distance[k], its
--    identifier (id<k>) and the selected runway's (rwy<k>) under it as the
--    map symbols' text and route data lines, the line along the runway
--    (line[k]) turned by dir[k] from the circle out;
--  - Rwy<k> (rwy_show[k]): the runway's middle at rwy_heading[k],
--    rwy_distance[k] (out to 2560 units: the middle can be off the map while
--    the dashes are on it), turned by dir[k] (its top the selected
--    threshold's end): the runway image's frame rwy_frame[k] (none for -1),
--    the dashed centrelines' dashes (dash[k * 60 + j] beyond the top end,
--    dash[k * 60 + 30 + j] beyond the other) moved out by half the runway's
--    length rwy_len[k];
--  - Thr<k> (thr_show[k]): the runway's identifier at its threshold
--    (thr_heading[k], thr_distance[k]) as the map symbols' text.
-- Images from make_nd_apt_images.ps1; the dashes as B747.61.nd_data.lua's
-- DASH_PX, DASH_GAP_PX, DASH_START_PX, DASHES. Names within the panel's 19
-- characters. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_airports.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local CIRCLE_R = 12                 -- apt_w's circle
local LINE_PX = 30                  -- apt_line
local LINE_DY = 26                  -- the route data lines' spacing
local DASH_PX, DASH_GAP_PX, DASH_START_PX, DASHES = 12, 10, 4, 30
local RWY_FRAMES = 40

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
local function turn_props(dref, x, y, back)
    return {"GROUP_ANIMATE_MODE ROTATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        string.format("POS %.6f %.6f", x, y), "KEY_FRAME 0.000000 0.000000 1.000000",
        back and "KEY_FRAME 45.000000 -45.000000" or "KEY_FRAME 45.000000 45.000000",
        "ROTATE_OFFSET_X 0.000000", "ROTATE_OFFSET_Y 0.000000"}
end
-- out by a map symbol's distance: 640 units the selected range's 465
-- pixels, to four times that
local function out_props(dref)
    return {"GROUP_ANIMATE_MODE TRANSLATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        "POS 0.000000 0.000000", "KEY_FRAME -2560.000000 -1860.000000 1.000000", "KEY_FRAME 0.000000 0.000000 1.000000",
        "KEY_FRAME 2560.000000 1860.000000", "IS_VERTICAL 1", "OFFSET 0.000000"}
end
-- up (sign 1) or down (-1) by half a length in pixels
local function half_props(dref, sign)
    return {"GROUP_ANIMATE_MODE TRANSLATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        "POS 0.000000 0.000000", "KEY_FRAME 0.000000 0.000000 1.000000",
        string.format("KEY_FRAME 1000.000000 %.6f", sign * 500), "IS_VERTICAL 1", "OFFSET 0.000000"}
end
-- a placed symbol's groups: turned, out, turned back
local function placed(o, depth, nm, show, hdg, dist, x, y)
    group(o, depth, nm, {show})
    group(o, depth + 2, nm .. " Turn", turn_props(hdg, x, y))
    group(o, depth + 4, nm .. " Y", out_props(dist))
    group(o, depth + 6, nm .. " Back", turn_props(hdg, x, y, true))
    return depth + 8
end
local function placed_close(o, depth)
    for d = depth + 6, depth, -2 do group_close(o, d) end
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
    local white = child(slot, "gen_text Text0 White")
    local ix, iy = pos(icon)
    local wx, wy = pos(white)
    local tx, ty = ax + (wx - ix), ay + (wy - iy)
    local P = "laminar/B747/nd/" .. d.side .. "/apt/"
    local depth = ind(center) + 2
    local o = {}
    group(o, depth, "ND Airports")
    for k = 0, 1 do
        local A = function(field) return string.format("%s%s[%d]", P, field, k) end
        -- the airport symbol, its texts, the runway line
        local in_ = placed(o, depth + 2, "Apt" .. k, "SHOW_GREATER 0.500000 " .. A("sym"), A("heading"), A("distance"), ax, ay)
        add(o, copy(arc, in_, "gen_rotary Apt" .. k .. " Circle", ax, ay, "CRT Displays/ND/apt_w", ""))
        add(o, copy(white, in_, "gen_text Apt" .. k .. " Id", tx, ty, nil, P .. "id" .. k))
        add(o, copy(white, in_, "gen_text Apt" .. k .. " Rwy", tx, ty - LINE_DY, nil, P .. "rwy" .. k))
        group(o, in_, "Apt" .. k .. " Line", {"SHOW_GREATER 0.500000 " .. A("line")})
        group(o, in_ + 2, "Apt" .. k .. " Line Turn", turn_props(A("dir"), ax, ay))
        add(o, copy(arc, in_ + 4, "gen_rotary Apt" .. k .. " Rline", ax, ay + CIRCLE_R + LINE_PX / 2,
            "CRT Displays/ND/apt_line", ""))
        group_close(o, in_ + 2)
        group_close(o, in_)
        placed_close(o, depth + 2)
        -- the runway: its outline and the dashes of its centrelines
        in_ = placed(o, depth + 2, "Rwy" .. k, "SHOW_GREATER 0.500000 " .. A("rwy_show"), A("rwy_heading"),
            A("rwy_distance"), ax, ay)
        group(o, in_, "Rwy" .. k .. " Dir", turn_props(A("dir"), ax, ay))
        add(o, copy(icon, in_ + 2, "gen_rotary Rwy" .. k .. " Outline", ax, ay, "CRT Displays/ND/rwy_outline",
            A("rwy_frame"), "SHOW_GREATER -0.500000 " .. A("rwy_frame"), RWY_FRAMES))
        for e = 0, 1 do
            local sign = e == 0 and 1 or -1
            group(o, in_ + 2, string.format("Rwy%d End%d", k, e), half_props(A("rwy_len"), sign))
            for j = 0, DASHES - 1 do
                local c = DASH_START_PX + j * (DASH_PX + DASH_GAP_PX) + DASH_PX / 2
                add(o, copy(arc, in_ + 4, string.format("gen_rotary Rwy%d D%d %d", k, e, j), ax, ay + sign * c,
                    "CRT Displays/ND/rwy_dash", "",
                    string.format("SHOW_GREATER 0.500000 %sdash[%d]", P, k * 2 * DASHES + e * DASHES + j)))
            end
            group_close(o, in_ + 2)
        end
        group_close(o, in_)
        placed_close(o, depth + 2)
        -- the runway's identifier at its threshold
        in_ = placed(o, depth + 2, "Thr" .. k, "SHOW_GREATER 0.500000 " .. A("thr_show"), A("thr_heading"),
            A("thr_distance"), ax, ay)
        add(o, copy(white, in_, "gen_text Thr" .. k .. " Rwy", tx, ty, nil, P .. "rwy" .. k))
        placed_close(o, depth + 2)
    end
    group_close(o, depth)
    local at = group_end(center) - 1
    assert(not after[at], "two insertions after line " .. at)
    after[at] = o
    changes = changes + 1
    print(string.format("%s (line %d): + ND Airports (origin, destination) at the airplane %.2f %.2f, text at %+.2f %+.2f (%d lines)",
        d.top, top, ax, ay, tx - ax, ty - ay, #o))
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
