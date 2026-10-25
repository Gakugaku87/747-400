-- Add the TCAS RA vertical guidance to the custom acf's PFDs (5-1 step 5d;
-- panel changes allowed anywhere since 2026-10-25). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_pfd_tcas.lua <acf in> <acf out>
-- It prints every change. In each PFD (the Captain's and the F/O's, each in
-- its outboard and its inboard copy), as the 570 PFD on FCOM p.1536-1537:
--  - the red outlined RA pitch regions (tcas_ra_up, tcas_ra_down:
--    make_pfd_tcas_images.ps1) after the bank scale (its picture is a sky
--    blue band over the top of the attitude display, with an arc cut out:
--    drawn after it, the regions reach the display's top as on FCOM
--    p.1536), under the bank pointer, the slip indicator and the airplane
--    symbol: a group turned with the horizon (the PFD's
--    roll) round the horizon's POS, and in it a pointer for each region
--    moved by laminar/B747/tcas/pfd/pitch_hi, pitch_lo (deg from the
--    airplane symbol, B747.34.tcas_model.lua) at the pitch scale's
--    613 px per 90 deg, held at 232 px, shown by hi_on, lo_on;
--  - the red RA vertical speed regions over the scale's tick column, after
--    the selected vertical speed pointer's mask so that they show over the
--    scale's notch too: a pointer for each moved by tcas/pfd/vs_hi, vs_lo
--    on the scale's ticks (0, 500, 1,000, 1,500, 2,000, 4,000, 6,000 fpm at
--    0, 38.5, 69, 94.5, 121, 133.5, 147 px: VSIscale), shown by hi_on, lo_on;
--  - the vertical speed pointer in red (VSIspdPtrR) over the white one while
--    tcas/pfd/vs_red is 1.
-- The positions, datarefs, buses and brightness come from the PFD's own
-- instruments (the horizon, the pitch scale, the VSI scale and pointer).
-- X-Plane takes one condition for each instrument or group (ARCHITECTURE.md
-- §5); every block here has at most one. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_tcas.lua <acf in> <acf out>")
local PX_PER_DEG = 613 / 90         -- the horizon's DEFLECT_PIX per 90 deg
local PITCH_HOLD = 232              -- px: the regions' clip is 464 x 464
-- the VSI scale's ticks (VSIscale: fpm, px from its centre line)
local VSI_TICKS = {{0, 0}, {500, 38.5}, {1000, 69}, {1500, 94.5}, {2000, 121}, {4000, 133.5}, {6000, 147}}
-- the tick column's centre from the scale's POS (VSIscale columns 20-26 of 60)
local VSI_BAND_DX = -6.5
local P = "laminar/B747/tcas/pfd/"

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
local function esc(s) return (s:gsub("%p", "%%%0")) end
local function insert(at, block)
    for i = #block, 1, -1 do table.insert(lines, at, block[i]) end
end

-- a pointer moving its picture up and down, clipped to its base image
local function pointer(out, indent, name, x, y, image, dref, cond, rheostat, bus, frames)
    local sub = indent .. "  "
    out[#out + 1] = indent .. "gen_pointer " .. name
    out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
    out[#out + 1] = sub .. "IMAGE " .. image
    out[#out + 1] = sub .. "DATAREF " .. dref
    out[#out + 1] = sub .. cond
    for _, l in ipairs({"HIDE", "CLIP", "LIGHT_MODE GLASS_AUTO", "LIGHT_RHEOSTAT " .. rheostat, "BUS_SRC " .. bus}) do
        out[#out + 1] = sub .. l
    end
    for i, k in ipairs(frames) do
        out[#out + 1] = sub .. "KEY_FRAME " .. f6(k[1]) .. " " .. f6(k[2]) .. (i < #frames and " 1.000000" or "")
    end
    for _, l in ipairs({"IS_DRAGGABLE 0", "IS_VERTICAL 1", "OFFSET 0.000000"}) do out[#out + 1] = sub .. l end
    out[#out + 1] = ""
end

local hold = PITCH_HOLD / PX_PER_DEG
local PITCH_FRAMES = {{-999, -PITCH_HOLD}, {-hold, -PITCH_HOLD}, {hold, PITCH_HOLD}, {999, PITCH_HOLD}}
local VS_FRAMES = {{-99999, -147}}
for i = #VSI_TICKS, 2, -1 do VS_FRAMES[#VS_FRAMES + 1] = {-VSI_TICKS[i][1], -VSI_TICKS[i][2]} end
for i = 1, #VSI_TICKS do VS_FRAMES[#VS_FRAMES + 1] = VSI_TICKS[i] end
VS_FRAMES[#VS_FRAMES + 1] = {99999, 147}

-- the PFD groups, from the bottom of the file up so that the line numbers
-- above stay good: {first line, side's name suffix}
local copies = {}
for i = 1, #lines do
    if lines[i] == "GROUP Captain PFD" then copies[#copies + 1] = {i, ""}
    elseif lines[i] == "GROUP First Officer PFD" then copies[#copies + 1] = {i, " 2"} end
end
assert(#copies == 4, "expected 4 PFD copies, found " .. #copies)
for c = #copies, 1, -1 do
    local s, sfx = copies[c][1], copies[c][2]
    local e = group_end(s)
    local name = lines[s]:match("^GROUP (.*)$") .. " (" .. c .. ")"
    assert(not table.concat(lines, "\n", s, e):find("TCAS RA", 1, true), "already has the RA guidance: " .. name)

    -- the VSI: the regions after the selected pointer's mask, the red pointer after the white one
    local vsi = find(s, e, "^%s*GROUP VSI Display" .. esc(sfx) .. "$", "VSI Display")
    local vsie = group_end(vsi)
    local scale = find(vsi, vsie, "^%s*gen_rotary Scale" .. esc(sfx) .. "$", "VSI Scale")
    local sx, sy = pos_of(scale)
    local srheo, sbus = field(scale, "LIGHT_RHEOSTAT"), field(scale, "BUS_SRC")
    local needle = find(vsi, vsie, "^%s*gen_needle Needle" .. esc(sfx) .. "$", "VSI Needle")
    local mask = find(vsi, vsie, "^%s*gen_rotary Sel VSI Ptr Mask" .. esc(sfx) .. "$", "Sel VSI Ptr Mask")
    assert(needle < mask)
    local out = {}
    pointer(out, ind(mask), "TCAS RA VS Up" .. sfx, sx + VSI_BAND_DX, sy, "CRT Displays/PFD/VSI/tcas_ra_vs_up",
        P .. "vs_hi", "SHOW_EQUAL 1.000000 " .. P .. "hi_on", srheo, sbus, VS_FRAMES)
    pointer(out, ind(mask), "TCAS RA VS Down" .. sfx, sx + VSI_BAND_DX, sy, "CRT Displays/PFD/VSI/tcas_ra_vs_down",
        P .. "vs_lo", "SHOW_EQUAL 1.000000 " .. P .. "lo_on", srheo, sbus, VS_FRAMES)
    insert(block_end(mask) + 2, out)
    print(string.format("%s: RA vertical speed regions at (%.1f, %.1f), after %s", name, sx + VSI_BAND_DX, sy,
        lines[mask]:match("^%s*(.*)$")))

    out = {}
    local ne = block_end(needle)
    local dref_line = find(needle, ne, "^%s*DATAREF ", "the needle's DATAREF")
    assert(not table.concat(lines, "\n", needle, ne):find("SHOW_", 1, true), "the needle has a condition")
    for i = needle, ne do
        local l = lines[i]
        if i == needle then
            l = ind(needle) .. "gen_needle TCAS RA Needle" .. sfx
        elseif l:match("^%s*IMAGE ") then
            assert(l:match("VSI/VSIspdPtr$"), "the needle's image: " .. l)
            l = l .. "R"
        end
        out[#out + 1] = l
        if i == dref_line then out[#out + 1] = ind(dref_line) .. "SHOW_EQUAL 1.000000 " .. P .. "vs_red" end
    end
    out[#out + 1] = ""
    insert(ne + 2, out)
    print(string.format("%s: the red vertical speed pointer after %s", name, lines[needle]:match("^%s*(.*)$")))

    -- the pitch regions after the bank scale
    local att = find(s, e, "^%s*GROUP Attitude Indicator$", "Attitude Indicator")
    local atte = group_end(att)
    local hor = find(att, atte, "^%s*gen_needle Artificial Horizon$", "Artificial Horizon")
    local hx, hy = pos_of(hor)
    local roll = field(hor, "DATAREF")
    local ps = find(att, atte, "^%s*gen_needle Pitch Scale" .. esc(sfx) .. "$", "Pitch Scale")
    local prheo, pbus = field(ps, "LIGHT_RHEOSTAT"), field(ps, "BUS_SRC")
    local bs = find(ps, atte, "^%s*gen_rotary Bank Scale" .. esc(sfx) .. "$", "Bank Scale")
    assert(ind(bs) == ind(ps), "the bank scale is not beside the pitch scale")
    local gi = ind(bs)
    out = {}
    out[#out + 1] = gi .. "GROUP TCAS RA Pitch" .. sfx
    for _, l in ipairs({"GROUP_ANIMATE_MODE ROTATE", "GROUP_WIDTH 0", "GROUP_HEIGHT 0", "DATAREF " .. roll,
            "POS " .. f6(hx) .. " " .. f6(hy), "KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 45.000000 -45.000000",
            "ROTATE_OFFSET_X 0.000000", "ROTATE_OFFSET_Y 0.000000"}) do
        out[#out + 1] = gi .. "  " .. l
    end
    pointer(out, gi .. "  ", "TCAS RA Pitch Up" .. sfx, hx, hy, "CRT Displays/PFD/Artificial Horizon/tcas_ra_up",
        P .. "pitch_hi", "SHOW_EQUAL 1.000000 " .. P .. "hi_on", prheo, pbus, PITCH_FRAMES)
    pointer(out, gi .. "  ", "TCAS RA Pitch Down" .. sfx, hx, hy, "CRT Displays/PFD/Artificial Horizon/tcas_ra_down",
        P .. "pitch_lo", "SHOW_EQUAL 1.000000 " .. P .. "lo_on", prheo, pbus, PITCH_FRAMES)
    out[#out + 1] = gi .. "END_GROUP"
    insert(block_end(bs) + 2, out)
    print(string.format("%s: RA pitch regions round (%.1f, %.1f) turned by %s, after %s", name, hx, hy, roll,
        lines[bs]:match("^%s*(.*)$")))
end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print("written " .. dst)
