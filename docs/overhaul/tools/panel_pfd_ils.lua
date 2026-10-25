-- The custom acf's PFD ILS indications (5-2 step 4e; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_pfd_ils.lua <acf in> <acf out>
-- It prints every change. In each of the four PFD copies the ILS items go on
-- the PFD ILS model's datarefs (laminar/B747/pfd/<side>/...) instead of the
-- stock autopilot/ils_dots and the deviations themselves (one SHOW line per
-- item: X-Plane takes only the last one):
--  - GROUP Approach Ref, Approach Course, Glideslope and Localizer: ils_show
--    (tuned, the receiver working, the roll within 53 degrees);
--  - the glideslope: GROUP Pointer on gs_ptr above 0, its hollow and filled
--    pointers on gs_ptr 2 and 1 (before, a deviation below the centre never
--    had the hollow one); the pointers' travel 48.5 pixels a dot like the
--    scale's dots (before 38.8: 2.5 dots at the 2-dot mark) without CLIP
--    (their base image, 209 high, would cut them past 104 pixels); the scale
--    on gs_scale 1 and a new amber one on gs_scale 2;
--  - the localizer: GROUP Localizer Pointer on loc_ptr above 0, the hollow,
--    filled and expanded-scale pointers on loc_ptr 2, 1 and 3; the scale on
--    loc_scale 1, its second copy turned into the amber scale (loc_scale 2),
--    the expanded scale on 3 and a new amber expanded scale on 4 (before,
--    the expanded scale also showed right of the centreline);
--  - GROUP Rsng Rwy Offset and its symbol: rwy_show;
--  - in the IRS OFF group (the ATT and HDG flags' group), the G/S and LOC
--    flags (gs_flag, loc_flag) where the scales they replace are (ATA34_1
--    p.470).
-- The images come from make_pfd_ils_images.ps1. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_ils.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local GS_PX = 97 / 2 * 2.5      -- the glideslope pointer at 2.5 dots (the scale's dots 48.5 apart)
local IMG = "CRT Displays/PFD/"

local function ind(i) return #lines[i]:match("^(%s*)") end
local function name(i) return lines[i]:match("^%s*(.-)%s*$") end
local function group_end(i)
    local s = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. s .. "END_GROUP%s*$") do j = j + 1 end
    return j
end
-- a gen_ item's last line (its trailing blank lines included)
local function gen_end(i)
    local n, j = ind(i), i + 1
    while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do j = j + 1 end
    return j - 1
end
-- a group's direct children (GROUP and gen_ lines)
local function children(i)
    local n, out = ind(i), {}
    for j = i + 1, group_end(i) - 1 do
        if ind(j) == n + 2 and (lines[j]:match("^%s*GROUP ") or lines[j]:match("^%s*gen_")) then out[#out + 1] = j end
    end
    return out
end
local function child(i, pattern, nth)
    local k = 0
    for _, j in ipairs(children(i)) do
        if name(j):match(pattern) then
            k = k + 1
            if k == (nth or 1) then return j end
        end
    end
    error("no " .. pattern .. " in " .. name(i))
end
-- an item's own property lines (up to its first child)
local function props(i)
    local n, out, j = ind(i), {}, i + 1
    while lines[j] do
        local l = lines[j]
        if l:match("%S") then
            if ind(j) <= n then break end
            if ind(j) == n + 2 and (l:match("^%s*GROUP ") or l:match("^%s*gen_")) then break end
            if ind(j) == n + 2 then out[#out + 1] = j end
        end
        j = j + 1
    end
    return out
end

local replace, after = {}, {}
local changes = 0
local function set_show(i, show)
    local first
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then
            if first then replace[j] = false else first = j; replace[j] = string.rep(" ", ind(i) + 2) .. show end
        end
    end
    assert(first, "no SHOW line in " .. name(i))
    changes = changes + 1
    print(string.format("  %s: %s", name(i), show))
end
local function set_prop(i, key, value)
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*" .. key .. " ") or lines[j]:match("^%s*" .. key .. "$") then
            replace[j] = string.rep(" ", ind(i) + 2) .. key .. " " .. value
            return j
        end
    end
    error("no " .. key .. " in " .. name(i))
end
local function pos(i)
    for _, j in ipairs(props(i)) do
        local x, y = lines[j]:match("^%s*POS ([%d.%-]+) ([%d.%-]+)")
        if x then return tonumber(x), tonumber(y) end
    end
    error("no POS in " .. name(i))
end
-- a copy of a gen_ item: its header, IMAGE and POS set, its SHOW lines
-- replaced by one (after DATAREF), re-indented to the given depth
local function copy(i, header, image, show, at, depth)
    local n = ind(i)
    local pre = string.rep(" ", depth or n)
    local o = {}
    for j = i, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        if j == i then
            o[#o + 1] = pre .. header
        elseif body:match("^  POS ") and at then
            o[#o + 1] = pre .. string.format("  POS %.6f %.6f", at[1], at[2])
        elseif body:match("^  IMAGE ") then
            o[#o + 1] = pre .. "  IMAGE " .. image
        elseif body:match("^  SHOW_") then
            -- dropped
        elseif body:match("^  DATAREF") then
            o[#o + 1] = pre .. body
            o[#o + 1] = pre .. "  " .. show
        else
            o[#o + 1] = body == "" and "" or pre .. body
        end
    end
    return o
end

-- the four PFD copies: their top groups
local copies = {}
for i, l in ipairs(lines) do
    local top = l:match("^GROUP (.+)$")
    if top and (top:match("^Captain PFD$") or top:match("^First Officer PFD$")) then
        copies[#copies + 1] = {top = i, side = top:match("^Captain") and "capt" or "fo"}
    end
end
assert(#copies == 4, "found " .. #copies .. " PFD copies")

for _, c in ipairs(copies) do
    local sfx = c.side == "fo" and " 2" or ""
    local p = "laminar/B747/pfd/" .. c.side .. "/"
    print(string.format("%s copy (line %d):", c.side, c.top))
    -- the named groups anywhere in the copy
    local found = {}
    for j = c.top + 1, group_end(c.top) - 1 do
        local g = lines[j]:match("^%s*GROUP (.-)%s*$")
        if g then
            local base = g:gsub(" 2$", "")
            if base == "Rsng Rwy Offset" or base == "Glideslope" or base == "Localizer" or base == "Approach Ref"
                or base == "Approach Course" or base:match("IRS OFF PFD$") then
                assert(not found[base:match("IRS OFF PFD$") and "IRS OFF" or base], "two " .. g)
                found[base:match("IRS OFF PFD$") and "IRS OFF" or base] = j
            end
        end
    end
    for _, k in ipairs({"Rsng Rwy Offset", "Glideslope", "Localizer", "Approach Ref", "Approach Course", "IRS OFF"}) do
        assert(found[k], "no " .. k .. " in the " .. c.side .. " copy")
    end

    set_show(found["Approach Ref"], "SHOW_GREATER 0.500000 " .. p .. "ils_show")
    set_show(found["Approach Course"], "SHOW_GREATER 0.500000 " .. p .. "ils_show")
    local rwy = found["Rsng Rwy Offset"]
    set_show(rwy, "SHOW_GREATER 0.500000 " .. p .. "rwy_show")
    set_show(child(rwy, "^gen_pointer Symbol"), "SHOW_GREATER 0.500000 " .. p .. "rwy_show")

    -- the glideslope
    local gs = found["Glideslope"]
    set_show(gs, "SHOW_GREATER 0.500000 " .. p .. "ils_show")
    local ptr = child(gs, "^GROUP Pointer")
    set_show(ptr, "SHOW_GREATER 0.500000 " .. p .. "gs_ptr")
    for _, v in ipairs({{"^GROUP Pointer VDEF > 2%.3", 2}, {"^GROUP Pointer VDEF <= 2%.3", 1}}) do
        local g = child(ptr, v[1])
        set_show(g, string.format("SHOW_EQUAL %.6f %sgs_ptr", v[2], p))
        local gp = child(g, "^gen_pointer")
        for j = gp + 1, gen_end(gp) do
            local l = lines[j]
            local a, b, rest = l:match("^(%s*KEY_FRAME [%d.%-]+ )([%d.%-]+)(.*)$")
            if a and math.abs(math.abs(tonumber(b)) - 97) < 0.01 then
                replace[j] = a .. string.format("%.6f", (tonumber(b) > 0 and 1 or -1) * GS_PX) .. rest
            elseif l:match("^%s*CLIP%s*$") then
                replace[j] = false
            end
        end
        print(string.format("    %s: travel %.2f px at 2.5 dots, no CLIP", name(gp), GS_PX))
    end
    local scale = child(gs, "^gen_rotary Scale")
    set_show(scale, "SHOW_EQUAL 1.000000 " .. p .. "gs_scale")
    local gx, gy = pos(scale)
    after[gen_end(scale)] = copy(scale, "gen_rotary Scale Amber" .. sfx, IMG .. "Artificial Horizon/HrznGSscaleAmb",
        "SHOW_EQUAL 2.000000 " .. p .. "gs_scale")
    print("  + gen_rotary Scale Amber" .. sfx .. " (HrznGSscaleAmb): SHOW_EQUAL 2 " .. p .. "gs_scale")

    -- the localizer
    local loc = found["Localizer"]
    set_show(loc, "SHOW_GREATER 0.500000 " .. p .. "ils_show")
    local lp = child(loc, "^GROUP Localizer Pointer")
    set_show(lp, "SHOW_GREATER 0.500000 " .. p .. "loc_ptr")
    set_show(child(lp, "^gen_pointer Ptr >= 2%.34"), "SHOW_EQUAL 2.000000 " .. p .. "loc_ptr")
    set_show(child(lp, "^gen_pointer Ptr <= 2%.33"), "SHOW_EQUAL 1.000000 " .. p .. "loc_ptr")
    set_show(child(lp, "^gen_pointer Ptr <= 0%.5"), "SHOW_EQUAL 3.000000 " .. p .. "loc_ptr")
    local ls = child(loc, "^GROUP Localizer Scale")
    local s1 = child(ls, "^gen_rotary Scale >= 0%.51", 1)
    set_show(s1, "SHOW_EQUAL 1.000000 " .. p .. "loc_scale")
    local lx, ly = pos(s1)
    local s2 = child(ls, "^gen_rotary Scale >= 0%.51", 2)
    replace[s2] = string.rep(" ", ind(s2)) .. "gen_rotary Scale Amber" .. sfx
    set_prop(s2, "IMAGE", IMG .. "Artificial Horizon/HrznLOCscaleAmb")
    set_show(s2, "SHOW_EQUAL 2.000000 " .. p .. "loc_scale")
    print("    (renamed gen_rotary Scale Amber" .. sfx .. ", HrznLOCscaleAmb)")
    local ex = child(ls, "^gen_rotary Scale Exp <= 0%.5")
    set_show(ex, "SHOW_EQUAL 3.000000 " .. p .. "loc_scale")
    after[gen_end(ex)] = copy(ex, "gen_rotary Scale Exp Amber" .. sfx, IMG .. "Artificial Horizon/HrznLOCscaleExAmb",
        "SHOW_EQUAL 4.000000 " .. p .. "loc_scale")
    print("  + gen_rotary Scale Exp Amber" .. sfx .. " (HrznLOCscaleExAmb): SHOW_EQUAL 4 " .. p .. "loc_scale")

    -- the G/S and LOC flags in the IRS OFF group, before its first child,
    -- copied from its static airplane symbol
    local off = found["IRS OFF"]
    local sym = child(off, "^gen_rotary Airplane Symbol")
    local first = children(off)[1]
    local block = copy(sym, "gen_rotary GS X" .. sfx, IMG .. "Failure Flags/gsX", "SHOW_GREATER 0.500000 " .. p .. "gs_flag",
        {gx, gy})
    for _, l in ipairs(copy(sym, "gen_rotary LOC X" .. sfx, IMG .. "Failure Flags/locX",
        "SHOW_GREATER 0.500000 " .. p .. "loc_flag", {lx, ly})) do block[#block + 1] = l end
    after[first - 1] = block
    print(string.format("  + gen_rotary GS X%s at %.1f %.1f, LOC X%s at %.1f %.1f (%sgs_flag, loc_flag)",
        sfx, gx, gy, sfx, lx, ly, p))
end
print(changes .. " SHOW lines set")

local out = {}
for i, l in ipairs(lines) do
    if replace[i] ~= false then out[#out + 1] = replace[i] or l end
    if after[i] then for _, a in ipairs(after[i]) do out[#out + 1] = a end end
end
local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
