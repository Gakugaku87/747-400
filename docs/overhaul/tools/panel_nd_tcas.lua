-- Add the TCAS traffic and messages to the custom acf's NDs (5-1 step 5b;
-- the panel changes approved 2026-10-23: GAP_ANALYSIS.md §4, DSP-18). Run
-- from the repository root:
--   luajit docs/overhaul/tools/panel_nd_tcas.lua <acf in> <acf out>
-- It prints every change. In each ND (the captain's and the first officer's):
--  - 30 TCAS slots at the end of "ND Text Center", so that they move with
--    the map's centre as the icons do and draw over them: each turned and
--    moved as an icon (laminar/B747/nd/capt|fo/tcas/heading, distance), its
--    symbol (tcas/sym: tcas_symbols, make_nd_tcas_images.ps1) and its data
--    tag (tcas/tag<n>) in white, amber or red (tcas/tag_color 1, 2, 3; the
--    ND folder's "red" font is magenta, so the red is CRT Displays/TEXT's),
--    moved up or down by tcas/tag_dy (B747.61.xt.nd.lua);
--  - TRAFFIC and OFFSCALE (amber or red: nd/capt|fo/traffic, offscale) at the
--    right, higher in the centred modes; TA ONLY (nd/capt|fo/ta_only) above
--    TFC; TCAS FAIL (nd/capt|fo/tcas_fail) where TCAS OFF is (FCOM p.1534-1535,
--    p.1153; ATA34_2 p.44).
-- The positions are taken from the icons', TFC's and TCAS OFF's and checked
-- in X-Plane. X-Plane takes one condition for each instrument or group
-- (ARCHITECTURE.md §5); every block here has at most one. The line endings
-- are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_tcas.lua <acf in> <acf out>")
local SLOTS = 30
-- the data tag's text from the symbol's centre (dy 0), panel pixels: three
-- characters of the ND font centred (checked in X-Plane)
local TAG_DX, TAG_DY = -19, 0
-- TRAFFIC and OFFSCALE from the airplane symbol (the icons' POS) in the
-- expanded modes: at the right, about the middle, inside the compass arc
-- (FCOM p.1534), right-aligned; up by CTR_DY in the centred modes (ATA34_2
-- p.44: the upper right)
local TRAFFIC_DX, TRAFFIC_DY, OFFSCALE_DX, OFFSCALE_DY, CTR_DY = 239.5, 150, 234, 172, 173.5
-- TA ONLY above TFC, left-aligned with it (from TFC's POS: its letters sit
-- 124 px below the middle of its image). TFC's image is a tall black box, so
-- the messages come after its group (EFIS Data Annun) to be drawn over it.
local TAONLY_DX, TAONLY_DY = 22, -102
-- TCAS FAIL left-aligned with TCAS OFF's and TFC's letters (from tcasX's POS)
local FAIL_DX, FAIL_DY = 4, -27

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function f6(v) return string.format("%.6f", v) end
local function group_end(s)
    local ind = lines[s]:match("^(%s*)GROUP ")
    for i = s + 1, #lines do
        if lines[i] == ind .. "END_GROUP" then return i end
    end
    error("no END_GROUP for line " .. s)
end
local function find(a, b, pattern, what)
    for i = a, b do
        if lines[i]:match(pattern) then return i end
    end
    error("no " .. what .. " in lines " .. a .. "-" .. b)
end
local function find_exact(a, b, line, what)
    for i = a, b do
        if lines[i] == line then return i end
    end
    error("no " .. what .. " in lines " .. a .. "-" .. b)
end
local function block_end(s)
    local e = s
    while lines[e + 1] ~= "" do e = e + 1 end
    return e
end
local function field(s, key)
    return lines[find(s, block_end(s), "^%s*" .. key .. " ", key)]:match(key .. " (.*)$")
end
local function pos_of(s)
    local x, y = field(s, "POS"):match("([-%d.]+) ([-%d.]+)")
    return tonumber(x), tonumber(y)
end
local function ind(i) return lines[i]:match("^(%s*)") end

local function rotary_tail(out, sub, rheostat, bus, k1, digits)
    out[#out + 1] = sub .. "LIGHT_MODE GLASS_AUTO"
    out[#out + 1] = sub .. "LIGHT_RHEOSTAT " .. rheostat
    out[#out + 1] = sub .. "BUS_SRC " .. bus
    out[#out + 1] = sub .. "KEY_FRAME 0.000000 0.000000 1.000000"
    out[#out + 1] = sub .. "KEY_FRAME 1.000000 " .. k1
    out[#out + 1] = sub .. "DIGITS " .. digits
    for _, l in ipairs({"ROTARY_TYPE NO_CLICK", "CLICK_RADIUS 0.000000", "CLICK_RADIUS_DY 0.000000",
            "OFFSET 0.000000", "STEP1 1.000000", "STEP2 1.000000", "CURSOR DEFAULT", "CLICK_DX 0", "CLICK_DY 0"}) do
        out[#out + 1] = sub .. l
    end
    out[#out + 1] = ""
end
-- a picture with frames chosen by a dataref
local function framed(out, indent, name, x, y, image, dref, rheostat, bus, frames)
    local sub = indent .. "  "
    out[#out + 1] = indent .. "gen_rotary " .. name
    out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
    out[#out + 1] = sub .. "IMAGE " .. image
    out[#out + 1] = sub .. "DATAREF " .. dref
    rotary_tail(out, sub, rheostat, bus, "1.000000", frames)
end
-- a picture shown when a dataref is 1 (as the stock TFC)
local function shown(out, indent, name, x, y, image, dref, rheostat, bus)
    local sub = indent .. "  "
    out[#out + 1] = indent .. "gen_rotary " .. name
    out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
    out[#out + 1] = sub .. "IMAGE " .. image
    out[#out + 1] = sub .. "DATAREF "
    out[#out + 1] = sub .. "SHOW_EQUAL 1.000000 " .. dref
    out[#out + 1] = sub .. "HIDE"
    rotary_tail(out, sub, rheostat, bus, "6.000000", 1)
end
local function gtext(out, indent, name, x, y, image, dref, cond, bus)
    local sub = indent .. "  "
    out[#out + 1] = indent .. "gen_text " .. name
    out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
    out[#out + 1] = sub .. "IMAGE " .. image
    out[#out + 1] = sub .. "DATAREF " .. dref
    out[#out + 1] = sub .. cond
    for _, l in ipairs({"LIGHT_MODE GLASS_AUTO", "LIGHT_RHEOSTAT 0", "BUS_SRC " .. bus,
            "KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 1.000000 1.000000", "OFFSET_X 0", "OFFSET_Y 0.000000"}) do
        out[#out + 1] = sub .. l
    end
    out[#out + 1] = ""
end
local function group_head(out, indent, name, mode, dref, k0, vertical, cond)
    local sub = indent .. "  "
    out[#out + 1] = indent .. "GROUP " .. name
    if cond then out[#out + 1] = sub .. cond end
    out[#out + 1] = sub .. "GROUP_ANIMATE_MODE " .. mode
    out[#out + 1] = sub .. "GROUP_WIDTH 0"
    out[#out + 1] = sub .. "GROUP_HEIGHT 0"
    out[#out + 1] = sub .. "DATAREF " .. dref
    out[#out + 1] = sub .. "POS 0.000000 0.000000"
    for i, k in ipairs(k0) do out[#out + 1] = sub .. k end
    if vertical then
        out[#out + 1] = sub .. "IS_VERTICAL 1"
        out[#out + 1] = sub .. "OFFSET 0.000000"
    else
        out[#out + 1] = sub .. "ROTATE_OFFSET_X 0.000000"
        out[#out + 1] = sub .. "ROTATE_OFFSET_Y 0.000000"
    end
end

local function insert(at, block)
    for i = #block, 1, -1 do table.insert(lines, at, block[i]) end
end

local SIDES = {
    {side = "capt", nd = "GROUP Captain ND", tfc = "gen_rotary TFC 2", tcasx = "gen_rotary TCAS X CAPT"},
    {side = "fo", nd = "GROUP First Officer ND", tfc = "gen_rotary TFC", tcasx = "gen_rotary TCAS X FO"},
}
for _, sd in ipairs(SIDES) do
    local ND = "laminar/B747/nd/" .. sd.side .. "/"
    local T = ND .. "tcas/"
    local nd = find_exact(1, #lines, sd.nd, sd.nd)
    local nde = group_end(nd)
    assert(not table.concat(lines, "\n", nd, nde):find("GROUP ND TCAS0", 1, true), "already has TCAS slots: " .. sd.nd)
    local tc = find(nd, nde, "^%s*GROUP ND Text Center$", "ND Text Center")
    local tce = group_end(tc)
    local icon = find(tc, tce, "^%s*gen_rotary Text0 Icon$", "Text0 Icon")
    local ix, iy = pos_of(icon)
    local irheo, ibus = field(icon, "LIGHT_RHEOSTAT"), field(icon, "BUS_SRC")
    local wtext = find(icon, tce, "^%s*gen_text Text0 White$", "Text0 White")
    local tbus = field(wtext, "BUS_SRC")
    local slot_ind = ind(find(tc, tce, "^%s*GROUP ND Text Icons0 ?$", "Text Icons0"))
    local annun = find(tce, nde, "^%s*GROUP EFIS Data Annun", "EFIS Data Annun")
    local annune = group_end(annun)
    local tfc = find(nd, nde, "^%s*" .. sd.tfc .. "$", sd.tfc)
    local fx, fy = pos_of(tfc)
    local frheo, fbus = field(tfc, "LIGHT_RHEOSTAT"), field(tfc, "BUS_SRC")
    local tx = find(nd, nde, "^%s*" .. sd.tcasx .. "$", sd.tcasx)
    local ox, oy = pos_of(tx)
    local xrheo, xbus = field(tx, "LIGHT_RHEOSTAT"), field(tx, "BUS_SRC")

    -- from the bottom up: TCAS FAIL after TCAS OFF's block, the messages after
    -- the EFIS annunciators (over TFC's box), the slots at the end of ND Text Center
    local out = {}
    shown(out, ind(tx), "TCAS FAIL " .. sd.side:upper(), ox + FAIL_DX, oy + FAIL_DY,
        "CRT Displays/ND/tcas_fail", ND .. "tcas_fail", xrheo, xbus)
    assert(tx > annune and annune > tce)
    insert(block_end(tx) + 2, out)
    print(string.format("%s: TCAS FAIL at (%.1f, %.1f)", sd.side, ox + FAIL_DX, oy + FAIL_DY))

    out = {}
    local mi = ind(tc)
    out[#out + 1] = mi .. "GROUP TCAS Messages"
    shown(out, mi .. "  ", "TCAS TA ONLY", fx + TAONLY_DX, fy + TAONLY_DY, "CRT Displays/ND/tcas_taonly",
        ND .. "ta_only", frheo, fbus)
    group_head(out, mi .. "  ", "TCAS Alerts", "TRANSLATE", "laminar/B747/nd/map_center/" .. sd.side,
        {"KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 1.000000 " .. f6(CTR_DY)}, true)
    framed(out, mi .. "    ", "TCAS TRAFFIC", ix + TRAFFIC_DX, iy + TRAFFIC_DY, "CRT Displays/ND/tcas_traffic",
        ND .. "traffic", frheo, fbus, 3)
    framed(out, mi .. "    ", "TCAS OFFSCALE", ix + OFFSCALE_DX, iy + OFFSCALE_DY, "CRT Displays/ND/tcas_offscale",
        ND .. "offscale", frheo, fbus, 3)
    out[#out + 1] = mi .. "  END_GROUP"
    out[#out + 1] = mi .. "END_GROUP"
    insert(annune + 1, out)
    print(string.format("%s: TA ONLY at (%.1f, %.1f), TRAFFIC at (%.1f, %.1f), OFFSCALE at (%.1f, %.1f), +%.1f centred",
        sd.side, fx + TAONLY_DX, fy + TAONLY_DY, ix + TRAFFIC_DX, iy + TRAFFIC_DY, ix + OFFSCALE_DX, iy + OFFSCALE_DY, CTR_DY))

    out = {}
    for k = 0, SLOTS - 1 do
        local i0, i1, i2, i3 = slot_ind, slot_ind .. "  ", slot_ind .. "    ", slot_ind .. "      "
        local idx = "[" .. k .. "]"
        group_head(out, i0, "ND TCAS" .. k, "ROTATE", T .. "heading" .. idx,
            {"KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 45.000000 45.000000"}, false,
            "SHOW_GREATER 1.000000 " .. T .. "show" .. idx)
        group_head(out, i1, "ND TCAS" .. k .. " Y", "TRANSLATE", T .. "distance" .. idx,
            {"KEY_FRAME -640.000000 -465.000000 1.000000", "KEY_FRAME 0.000000 0.000000 1.000000",
             "KEY_FRAME 640.000000 465.000000"}, true)
        group_head(out, i2, "ND TCAS" .. k .. " backrotate", "ROTATE", T .. "heading" .. idx,
            {"KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 45.000000 -45.000000"}, false)
        framed(out, i3, "TCAS" .. k .. " Symbol", ix, iy, "CRT Displays/ND/tcas_symbols", T .. "sym" .. idx,
            irheo, ibus, 13)
        group_head(out, i3, "ND TCAS" .. k .. " Tag", "TRANSLATE", T .. "tag_dy" .. idx,
            {"KEY_FRAME -100.000000 -100.000000 1.000000", "KEY_FRAME 100.000000 100.000000"}, true)
        local i4 = i3 .. "  "
        gtext(out, i4, "TCAS" .. k .. " White", ix + TAG_DX, iy + TAG_DY, "CRT Displays/TEXT/ND/TXT.2.28.white",
            T .. "tag" .. k, "SHOW_EQUAL 1.000000 " .. T .. "tag_color" .. idx, tbus)
        gtext(out, i4, "TCAS" .. k .. " Amber", ix + TAG_DX, iy + TAG_DY, "CRT Displays/TEXT/TXT.2.28.amber",
            T .. "tag" .. k, "SHOW_EQUAL 2.000000 " .. T .. "tag_color" .. idx, tbus)
        gtext(out, i4, "TCAS" .. k .. " Red", ix + TAG_DX, iy + TAG_DY, "CRT Displays/TEXT/TXT.2.28.red",
            T .. "tag" .. k, "SHOW_EQUAL 3.000000 " .. T .. "tag_color" .. idx, tbus)
        out[#out + 1] = i3 .. "END_GROUP"
        out[#out + 1] = i2 .. "END_GROUP"
        out[#out + 1] = i1 .. "END_GROUP"
        out[#out + 1] = i0 .. "END_GROUP"
    end
    insert(tce, out)
    print(string.format("%s: %d TCAS slots at the end of ND Text Center (symbol at (%.2f, %.2f), tag at %+.1f, %+.1f)",
        sd.side, SLOTS, ix, iy, TAG_DX, TAG_DY))
end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print("written " .. dst)
