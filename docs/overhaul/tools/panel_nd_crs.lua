-- The custom acf's ND course lines of the manually tuned VORs (5-2 step
-- 5c, FCOM p.1145; panel changes allowed anywhere since 2026-10-25). Run
-- from the repository root:
--   luajit docs/overhaul/tools/panel_nd_crs.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, at the end of
-- the map symbols' group (GROUP ND Text Center: it moves with MAP CTR), for
-- VOR L (k 0) and R (k 1) from the ND module's laminar/B747/nd/<side>/crs/*
-- (B747.61.xt.nd.lua), placed as the map symbols are (turned by a bearing
-- from the airplane symbol, moved out by a distance of 640 units to the
-- selected range's 465 pixels, turned back upright):
--  - Crs<k> (show[k]): at the course line's point nearest the airplane
--    (heading[k], distance[k]), turned by dir[k], moved along by phase[k]:
--    dashes D<j> 22 pixels apart (dash[k * 85 + j + 42], j -42 to 42);
--  - CrsLbl<k> (show[k]): at the station (lbl_heading[k], lbl_distance[k]),
--    the course (text<k * 2>) and the reciprocal (text<k * 2 + 1>), each
--    (lbl_show) turned by tbrg along its side of the line and readable,
--    starting 50 pixels from the station (tside 1) or ending there (tside
--    2), just off the line, as the POS radials' text.
-- Image from make_nd_crs_image.ps1; the dashes as B747.61.nd_data.lua's
-- DASH_PX, DASH_GAP_PX and CRS_DASHES. Names within the panel's 19
-- characters. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_crs.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local DASH_P = 12 + 10              -- a dash and its gap
local DASHES = 42                   -- each side of the nearest point
local LABEL_PX = 50                 -- the numbers' start from the station
local LABEL_W = 42                  -- three letters of the ND font
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
-- along the line by pixels
local function slide_props(dref)
    return {"GROUP_ANIMATE_MODE TRANSLATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. dref,
        "POS 0.000000 0.000000", "KEY_FRAME -1000.000000 -1000.000000 1.000000", "KEY_FRAME 1000.000000 1000.000000",
        "IS_VERTICAL 1", "OFFSET 0.000000"}
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
    local green = child(slot, "gen_text Text0 Green")
    local P = "laminar/B747/nd/" .. d.side .. "/crs/"
    local depth = ind(center) + 2
    local o = {}
    group(o, depth, "ND Courses")
    for k = 0, 1 do
        local A = function(field, n) return string.format("%s%s[%d]", P, field, n or k) end
        -- the dashes about the line's point nearest the airplane
        local in_ = placed(o, depth + 2, "Crs" .. k, "SHOW_GREATER 0.500000 " .. A("show"), A("heading"), A("distance"), ax, ay)
        group(o, in_, "Crs" .. k .. " Dir", turn_props(A("dir"), ax, ay))
        group(o, in_ + 2, "Crs" .. k .. " Phase", slide_props(A("phase")))
        for j = -DASHES, DASHES do
            add(o, copy(arc, in_ + 4, string.format("gen_rotary Crs%d D%d", k, j), ax, ay + j * DASH_P,
                "CRT Displays/ND/crs_dash", "",
                string.format("SHOW_GREATER 0.500000 %sdash[%d]", P, k * (2 * DASHES + 1) + j + DASHES)))
        end
        group_close(o, in_ + 2)
        group_close(o, in_)
        placed_close(o, depth + 2)
        -- the course and the reciprocal at the station
        in_ = placed(o, depth + 2, "CrsLbl" .. k, "SHOW_GREATER 0.500000 " .. A("show"), A("lbl_heading"),
            A("lbl_distance"), ax, ay)
        for m = 0, 1 do
            local L = k * 2 + m
            group(o, in_, string.format("Crs%d L%d", k, m), {"SHOW_GREATER 0.500000 " .. A("lbl_show", L)})
            for side = 1, 2 do
                group(o, in_ + 2, string.format("Crs%d L%d S%d", k, m, side),
                    {string.format("SHOW_EQUAL %.6f %s", side, A("tside", L))})
                group(o, in_ + 4, string.format("Crs%d L%d S%d Turn", k, m, side), turn_props(A("tbrg", L), ax, ay))
                local tx = side == 1 and ax + LABEL_PX or ax - LABEL_PX - LABEL_W
                add(o, copy(green, in_ + 6, string.format("gen_text Crs%d L%d S%d", k, m, side), tx, ay + LABEL_DY, nil,
                    P .. "text" .. L))
                group_close(o, in_ + 4)
                group_close(o, in_ + 2)
            end
            group_close(o, in_)
        end
        placed_close(o, depth + 2)
    end
    group_close(o, depth)
    local at = group_end(center) - 1
    assert(not after[at], "two insertions after line " .. at)
    after[at] = o
    changes = changes + 1
    print(string.format("%s (line %d): + ND Courses (VOR L, R) at the airplane %.2f %.2f (%d lines)", d.top, top, ax, ay, #o))
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
