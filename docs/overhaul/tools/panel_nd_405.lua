-- The custom acf's ND for the airplane's effectivity (the user's choice,
-- 2026-10-27: the P&W airplane as the 405, heading up in all modes; the GE
-- as the 570, MAP track up; RR as P&W) and the expanded heading pointer's
-- place (panel changes allowed anywhere since 2026-10-25). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_nd_405.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND:
--  - the heading/track box's label and number on laminar/B747/nd/<side>/box
--    (B747.60.nd_model.lua: 1 HDG, 2 TRK, in PLAN 3 HDG, 4 TRK; FCOM
--    p.1141) instead of the mode selector: centred and expanded, the TRK
--    group on 2 and the HDG group on 1; PLAN's box (centred) TRK on 4 and a
--    new HDG copy (HDG label, that side's heading) on 3;
--  - the expanded current heading pointer (step 5a's estimate: radius 457
--    about a point 11 pixels below the rose's centre, so it sank into the
--    rose near the top and floated off it at the bottom, and moved left
--    and right as the display turned) turns about the rose's centre (the
--    Heading Offset group's pivot) at a radius that puts its tip on the
--    rose's outer edge (rose_L-1.png: radius 449.7; hdg_ptr-1.png: the tip
--    1.5 pixels below the image's middle; 451);
--  - the expanded rose and its mask (the Captain's only: 340.5, 5.5 pixels
--    right of the pivot, the track line, the heading bug and the box) at
--    the pivot plus half a pixel, as the F/O's (1022.5 on 1022) and the
--    Captain's PLAN rose and mask (335.5): measured in X-Plane, the rose's
--    tick at the track stood 5 pixels right of the track line.
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_405.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local PTR_R = 451       -- the expanded heading pointer's radius: its tip on the rose's outer edge

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
local function item_end(i) return lines[i]:match("^%s*GROUP ") and group_end(i) or gen_end(i) end
local function children(i)
    local n, out = ind(i), {}
    for j = i + 1, group_end(i) - 1 do
        if ind(j) == n + 2 and (lines[j]:match("^%s*GROUP ") or lines[j]:match("^%s*gen_")) then out[#out + 1] = j end
    end
    return out
end
-- a direct child by exact name, with or without the Captain's " 2"
local function child(i, nm)
    for _, j in ipairs(children(i)) do
        local n = name(j)
        if n == nm or n == nm .. " 2" then return j end
    end
    error("no " .. nm .. " in " .. name(i))
end
local function all_children(i, nm)
    local out = {}
    for _, j in ipairs(children(i)) do
        local n = name(j)
        if n == nm or n == nm .. " 2" then out[#out + 1] = j end
    end
    assert(#out > 0, "no " .. nm .. " in " .. name(i))
    return out
end
local function descendant(i, nm)
    for j = i + 1, group_end(i) - 1 do
        local n = name(j)
        if n == nm or n == nm .. " 2" then return j end
    end
    error("no " .. nm .. " under " .. name(i))
end
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
local count = 0
local function note(i, what) count = count + 1; print(string.format("  %s (line %d): %s", name(i), i, what)) end
local function set_show(i, show)
    local first
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then
            if first then replace[j] = false else first = j; replace[j] = string.rep(" ", ind(i) + 2) .. show end
        end
    end
    assert(first, "no SHOW line in " .. name(i))
    note(i, lines[first]:match("^%s*(.-)%s*$") .. " -> " .. show)
end
local function get_prop(i, key)
    for _, j in ipairs(props(i)) do
        local v = lines[j]:match("^%s*" .. key .. " (.*)$")
        if v then return v, j end
    end
end
local function set_prop(i, key, value)
    local old, j = get_prop(i, key)
    assert(j, "no " .. key .. " in " .. name(i))
    replace[j] = string.rep(" ", ind(i) + 2) .. key .. " " .. value
    note(i, key .. " " .. old .. " -> " .. value)
end
local function pos(i)
    local x, y = get_prop(i, "POS"):match("([%d.%-]+) ([%d.%-]+)")
    return tonumber(x), tonumber(y)
end
-- the lines of an item (unchanged indentation)
local function block(i)
    local o = {}
    for j = i, item_end(i) do o[#o + 1] = lines[j] end
    return o
end

local nds = {}
for i, l in ipairs(lines) do
    local top = l:match("^GROUP (.+)$")
    if top == "Captain ND" then nds[#nds + 1] = {top = i, side = "capt"} end
    if top == "First Officer ND" then nds[#nds + 1] = {top = i, side = "fo"} end
end
assert(#nds == 2, "found " .. #nds .. " NDs")

for _, d in ipairs(nds) do
    local nd = "laminar/B747/nd/" .. d.side .. "/"
    local box = nd .. "box"
    local function on_box(v) return string.format("SHOW_EQUAL %.6f %s", v, box) end
    print(string.format("%s ND (line %d):", d.side, d.top))

    -- centred
    local cen = descendant(d.top, "GROUP Map:Centered")
    local dig = child(cen, "GROUP Digital HDG/TRK")
    local tr = child(dig, "GROUP TRACK")
    set_show(tr, on_box(2))
    for _, j in ipairs(children(tr)) do
        if get_prop(j, "SHOW_EQUAL") or get_prop(j, "SHOW_LESS") or get_prop(j, "SHOW_GREATER") then set_show(j, on_box(2)) end
    end
    local hd = child(dig, "GROUP HDG")
    set_show(child(hd, "GROUP APP/VOR/MAP"), on_box(1))
    local plnr = child(hd, "GROUP PLN")
    set_show(plnr, on_box(4))
    -- the 405's PLAN: HDG and that side's heading, the same place
    local o = {}
    for _, l in ipairs(block(plnr)) do
        local body = l:match("^%s*(.-)%s*$")
        local pre = l:match("^(%s*)")
        if body:match("^GROUP PLN") then o[#o + 1] = pre .. "GROUP PLN HDG" .. (d.side == "capt" and " 2" or "")
        elseif body:match("^SHOW_") and #pre == ind(plnr) + 2 then o[#o + 1] = pre .. on_box(3)
        elseif body == "IMAGE EFIS/Maps/label_TRK" then o[#o + 1] = pre .. "IMAGE EFIS/Maps/label_HDG"
        elseif body == "DATAREF laminar/B747/pfd/" .. d.side .. "/trk_deg" then o[#o + 1] = pre .. "DATAREF laminar/B747/pfd/" .. d.side .. "/hdg_deg"
        else o[#o + 1] = l end
    end
    local swapped = 0
    for k, l in ipairs(o) do if l ~= block(plnr)[k] then swapped = swapped + 1 end end
    assert(swapped == 4, "the PLN copy changed " .. swapped .. " lines, not 4")
    after[group_end(plnr)] = o
    note(plnr, "+ GROUP PLN HDG after it (" .. on_box(3) .. ", label_HDG, pfd/" .. d.side .. "/hdg_deg)")

    -- expanded
    local exp = descendant(d.top, "GROUP Map:Expanded")
    dig = child(exp, "GROUP Digital HDG/TRK")
    tr = child(dig, "GROUP TRACK")
    set_show(tr, on_box(2))
    for _, j in ipairs(children(tr)) do assert(not get_prop(j, "SHOW_EQUAL") and not get_prop(j, "SHOW_LESS"), "a SHOW line in " .. name(j)) end
    hd = child(dig, "GROUP HDG")
    local av = child(hd, "GROUP APP/VOR")
    set_show(av, on_box(1))
    for _, j in ipairs(children(av)) do assert(not get_prop(j, "SHOW_EQUAL") and not get_prop(j, "SHOW_LESS"), "a SHOW line in " .. name(j)) end

    -- the pivot: the Heading Offset group's (the rose, the track line, the
    -- heading bug and line turn about it)
    local hofs = child(exp, "GROUP Heading Offset")
    local gx, gy = pos(hofs)
    local px = gx + tonumber((get_prop(hofs, "ROTATE_OFFSET_X")))
    local py = gy + tonumber((get_prop(hofs, "ROTATE_OFFSET_Y")))
    local ptr = child(hofs, "gen_needle Hdg Ptr Exp")
    set_prop(ptr, "POS", string.format("%.6f %.6f", px, py + PTR_R))
    set_prop(ptr, "OFFSET", string.format("%.6f", PTR_R))
    set_prop(ptr, "NEEDLE_OFFSET_Y", string.format("%.6f", -PTR_R))

    -- the rose and its mask at the pivot plus half a pixel (the F/O's are)
    local rg = child(exp, "GROUP Map/Rose")
    local rx = px + 0.5
    local items = all_children(rg, "gen_needle Rose")
    items[#items + 1] = child(rg, "gen_rotary Mask:Expanded")
    for _, j in ipairs(items) do
        local x, y = pos(j)
        if math.abs(x - rx) > 0.01 then set_prop(j, "POS", string.format("%.6f %.6f", rx, y)) end
        if lines[j]:match("gen_needle") then
            assert(math.abs(y + tonumber((get_prop(j, "NEEDLE_OFFSET_Y"))) - py) < 0.01, "the rose's pivot is not the group's in " .. name(j))
        end
    end
end
print(count .. " changes")

local out = {}
for i, l in ipairs(lines) do
    local r = replace[i]
    if r ~= false then
        for part in ((r or l) .. "\n"):gmatch("(.-)\n") do out[#out + 1] = part end
    end
    if after[i] then for _, a in ipairs(after[i]) do out[#out + 1] = a end end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
