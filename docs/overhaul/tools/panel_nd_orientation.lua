-- The custom acf's ND orientation, heading and track (5-2 step 5a; panel
-- changes allowed anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_orientation.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND (laminar/B747/
-- nd/<side>/... from B747.60.nd_model.lua; nd/up/<side> from nd.lua):
--  - centred: the APP/VOR and the MAP compass roses turn with nd/up/<side>
--    (before: the APP/VOR rose with the Captain's heading on the Captain's
--    side, the F/O's two roses with nothing), at -1 degree a degree (the
--    Captain's had a 1-degree offset, the F/O's turned the wrong way); the
--    pointer group turns with nd/up/<side> (before: the heading, so the MAP
--    CTR pointers ignored the track-up display); its heading pointer on that
--    side's heading (before: the other side's, with two keyframes at 0);
--    the PLN pointer on that side's heading;
--  - expanded: the digital track/heading on that side's mode (the
--    Captain's read the F/O's) and heading (the F/O's read the Captain's);
--    the track line on that side's track and nd/<side>/trk_line (gone
--    without a track); the selected heading bug on nd/<side>/hdg_bug and
--    its dashed line on hdg_line (before: both went together); a new
--    current heading pointer (the centred one's image at the expanded
--    rose's radius, estimate);
--  - both: the roses and digital readouts on nd/<side>/rose (before: the
--    IRS valid), the pointer groups too (they had no condition); PLN's
--    readout (at PLN's own box) shows the track like MAP (109: FCOM
--    p.1141), the heading readout only in APP and VOR;
--  - the MAP, VTK, TRK and HDG flags out of the IRS-off group (they showed
--    only with the IRS not aligned), on nd/<side>/map_flag, vtk_flag,
--    trk_flag, hdg_flag;
--  - the wind arrow on nd/<side>/wind_deg (with respect to the display
--    orientation) and wind (before: the bearing from the heading, and two
--    SHOW lines of which only the last worked).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_orientation.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local EXP_PTR_R = 457   -- the expanded heading pointer's radius (the centred one's 237 on a 230 rose, scaled: estimate)

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
-- a direct child by exact name, with or without the F/O's or Captain's " 2"
local function child(i, nm)
    for _, j in ipairs(children(i)) do
        local n = name(j)
        if n == nm or n == nm .. " 2" then return j end
    end
    error("no " .. nm .. " in " .. name(i))
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
local function note(i, what) count = count + 1; print(string.format("  %s: %s", name(i), what)) end
local function set_show(i, show)
    local first
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then
            if first then replace[j] = false else first = j; replace[j] = string.rep(" ", ind(i) + 2) .. show end
        end
    end
    assert(first, "no SHOW line in " .. name(i))
    note(i, show)
end
-- a SHOW line for an item that has none (before its first property)
local function add_show(i, show)
    for _, j in ipairs(props(i)) do assert(not lines[j]:match("^%s*SHOW_"), "a SHOW line already in " .. name(i)) end
    local j = props(i)[1]
    replace[j] = string.rep(" ", ind(i) + 2) .. show .. "\n" .. lines[j]
    note(i, "+ " .. show)
end
local function set_prop(i, key, value)
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*" .. key .. "%s") or lines[j]:match("^%s*" .. key .. "$") then
            replace[j] = string.rep(" ", ind(i) + 2) .. key .. " " .. value
            note(i, key .. " " .. value)
            return
        end
    end
    error("no " .. key .. " in " .. name(i))
end
local function set_keyframes(i, frames)
    local first
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*KEY_FRAME ") then
            if first then replace[j] = false else first = j end
        end
    end
    assert(first, "no KEY_FRAME in " .. name(i))
    local pre = string.rep(" ", ind(i) + 2)
    local o = {}
    for k, kf in ipairs(frames) do
        o[k] = pre .. string.format("KEY_FRAME %.6f %.6f", kf[1], kf[2]) .. (k < #frames and " 1.000000" or "")
    end
    replace[first] = table.concat(o, "\n")
    note(i, "keyframes " .. #frames)
end
local function get_prop(i, key)
    for _, j in ipairs(props(i)) do
        local v = lines[j]:match("^%s*" .. key .. " (.*)$")
        if v then return v end
    end
end
-- the lines of an item, re-indented by delta (positive: deeper)
local function block(i, delta)
    local o = {}
    for j = i, item_end(i) do
        local l = lines[j]
        if not l:match("%S") then o[#o + 1] = l
        elseif delta >= 0 then o[#o + 1] = string.rep(" ", delta) .. l
        else o[#o + 1] = l:sub(1 - delta) end
    end
    return o
end

local NEG = {{0, 0}, {90, -90}}       -- a compass card: turned back by the value
local POS = {{0, 0}, {90, 90}}        -- a pointer: turned by the value

local nds = {}
for i, l in ipairs(lines) do
    local top = l:match("^GROUP (.+)$")
    if top == "Captain ND" then nds[#nds + 1] = {top = i, side = "capt", P = "pilot", S = "CAPT"} end
    if top == "First Officer ND" then nds[#nds + 1] = {top = i, side = "fo", P = "copilot", S = "FO"} end
end
assert(#nds == 2, "found " .. #nds .. " NDs")

for _, d in ipairs(nds) do
    local nd = "laminar/B747/nd/" .. d.side .. "/"
    local mode = "laminar/B747/nd/mode/" .. d.side .. "/sel_dial_pos"
    local up = "laminar/B747/nd/up/" .. d.side
    local hdg = "sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_" .. d.P
    local trk = "sim/cockpit2/gauges/indicators/ground_track_mag_" .. d.P
    print(string.format("%s ND (line %d):", d.side, d.top))

    -- centred
    local cen = descendant(d.top, "GROUP Map:Centered")
    local rose = child(cen, "GROUP Map/Rose")
    set_show(rose, "SHOW_GREATER 0.500000 " .. nd .. "rose")
    local compass = child(rose, "GROUP Compass Rose")
    for _, nm in ipairs({"gen_needle Rose", "gen_needle Rose:MAP"}) do
        local r = child(compass, nm)
        set_prop(r, "DATAREF", up)
        set_keyframes(r, NEG)
    end
    local dig = child(cen, "GROUP Digital HDG/TRK")
    set_show(dig, "SHOW_GREATER 0.500000 " .. nd .. "rose")
    local tr = child(dig, "GROUP TRACK")
    set_show(tr, "SHOW_EQUAL 2.000000 " .. mode)
    for _, j in ipairs(children(tr)) do
        if lines[j]:match("^%s*gen_LED") then set_show(j, "SHOW_EQUAL 2.000000 " .. mode) end
    end
    -- PLN's readout (at PLN's own box) shows the track, as MAP's (109)
    local hd = child(dig, "GROUP HDG")
    local plnr = child(hd, "GROUP PLN")
    set_show(plnr, "SHOW_EQUAL 3.000000 " .. mode)
    for _, j in ipairs(children(plnr)) do
        local img = get_prop(j, "IMAGE")
        if img and img:match("label_HDG") then set_prop(j, "IMAGE", "EFIS/Maps/label_TRK") end
        if lines[j]:match("^%s*gen_LED") then set_prop(j, "DATAREF", trk) end
    end
    local ofs = child(cen, "GROUP Hdg Ofst:APP/VOR/MA")
    add_show(ofs, "SHOW_GREATER 0.500000 " .. nd .. "rose")
    set_prop(ofs, "DATAREF", up)
    local ptr = child(ofs, "gen_needle Hdg Ptr:APP/VOR/MAP")
    set_prop(ptr, "DATAREF", hdg)
    set_show(ptr, "SHOW_GREATER 0.500000 " .. nd .. "hdg_ptr")
    set_keyframes(ptr, POS)
    local pln = child(child(cen, "GROUP Hdg Ofst:PLN"), "gen_needle Hdg Ptr:PLN")
    set_prop(pln, "DATAREF", hdg)
    set_show(pln, "SHOW_GREATER 0.500000 " .. nd .. "hdg_ptr_pln")

    -- expanded
    local exp = descendant(d.top, "GROUP Map:Expanded")
    set_show(child(exp, "GROUP Map/Rose"), "SHOW_GREATER 0.500000 " .. nd .. "rose")
    dig = child(exp, "GROUP Digital HDG/TRK")
    set_show(dig, "SHOW_GREATER 0.500000 " .. nd .. "rose")
    tr = child(dig, "GROUP TRACK")
    set_show(tr, "SHOW_EQUAL 2.000000 " .. mode)
    hd = child(dig, "GROUP HDG")
    local av = child(hd, "GROUP APP/VOR")
    set_show(av, "SHOW_LESS 1.000000 " .. mode)
    for _, j in ipairs(children(av)) do
        if get_prop(j, "DATAREF") and get_prop(j, "DATAREF"):match("heading_AHARS") then set_prop(j, "DATAREF", hdg) end
    end
    set_show(child(hd, "GROUP PLAN"), "SHOW_LESS -1.000000 " .. mode)
    local hofs = child(exp, "GROUP Heading Offset")
    add_show(hofs, "SHOW_GREATER 0.500000 " .. nd .. "rose")
    local tl = child(hofs, "gen_needle Track Line")
    set_prop(tl, "DATAREF", trk)
    set_show(tl, "SHOW_GREATER 0.500000 " .. nd .. "trk_line")
    local bugs = child(hofs, "GROUP ND Heading Bug")
    set_show(bugs, "SHOW_GREATER 0.500000 " .. nd .. "hdg_bug")
    local bug = child(bugs, "gen_needle Heading Bug")
    set_show(bug, "SHOW_GREATER 0.500000 " .. nd .. "hdg_bug")
    set_show(child(bugs, "gen_needle Heading Bug Line"), "SHOW_GREATER 0.500000 " .. nd .. "hdg_line")
    -- the expanded current heading pointer: the bug's needle with the
    -- centred pointer's image at the expanded radius
    local bx, by = get_prop(bug, "POS"):match("([%d.%-]+) ([%d.%-]+)")
    local cy = tonumber(by) - tonumber(get_prop(bug, "OFFSET"))
    local pre = string.rep(" ", ind(bug) - 2)
    local o = {}
    for _, l in ipairs(block(bug, -2)) do
        local body = l:match("^%s*(.-)$")
        if l:match("^%s*gen_needle ") then o[#o + 1] = pre .. "gen_needle Hdg Ptr Exp" .. (d.side == "fo" and "" or " 2")
        elseif body:match("^POS ") then o[#o + 1] = pre .. "  " .. string.format("POS %s %.6f", bx, cy + EXP_PTR_R)
        elseif body:match("^IMAGE ") then o[#o + 1] = pre .. "  IMAGE EFIS/Maps/hdg_ptr"
        elseif body:match("^DATAREF") then o[#o + 1] = pre .. "  DATAREF " .. hdg
        elseif body:match("^SHOW_") then o[#o + 1] = pre .. "  SHOW_GREATER 0.500000 " .. nd .. "hdg_ptr"
        elseif body:match("^OFFSET ") then o[#o + 1] = pre .. "  " .. string.format("OFFSET %.6f", EXP_PTR_R)
        elseif body:match("^NEEDLE_OFFSET_Y ") then o[#o + 1] = pre .. "  " .. string.format("NEEDLE_OFFSET_Y %.6f", -EXP_PTR_R)
        else o[#o + 1] = l end
    end
    after[group_end(bugs)] = o
    note(bugs, "+ gen_needle Hdg Ptr Exp after it (radius " .. EXP_PTR_R .. ")")

    -- the flags out of the IRS-off group, after it, each on its own condition
    local info = descendant(d.top, "GROUP " .. d.S .. " IRS INFO")
    local off = child(info, "GROUP " .. d.S .. " IRS OFF")
    local moved = {}
    for _, f in ipairs({{"MAP X", "map_flag"}, {"VTK X", "vtk_flag"}, {"TRK X", "trk_flag"}, {"HDG X", "hdg_flag"}}) do
        -- "MAP X CAPT ND" on the Captain's side, "MAP X FO" on the F/O's
        local j
        for _, k in ipairs(children(off)) do
            if name(k):find("gen_rotary " .. f[1] .. " " .. d.S, 1, true) == 1 then j = k end
        end
        assert(j, "no " .. f[1] .. " flag in " .. name(off))
        local b = block(j, -2)
        for k, l in ipairs(b) do
            if l:match("^%s*SHOW_") then b[k] = l:match("^(%s*)") .. "SHOW_GREATER 0.500000 " .. nd .. f[2] end
        end
        for k = j, item_end(j) do replace[k] = false end
        for _, l in ipairs(b) do moved[#moved + 1] = l end
        note(j, "moved out of the IRS-off group, SHOW_GREATER 0.5 " .. nd .. f[2])
    end
    after[group_end(off)] = moved

    -- the wind arrow
    local on = child(info, "GROUP " .. d.S .. " IRS ON")
    local wind = child(on, "gen_needle wind_" .. d.P)
    set_prop(wind, "DATAREF", nd .. "wind_deg")
    set_show(wind, "SHOW_GREATER 0.500000 " .. nd .. "wind")
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
local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
