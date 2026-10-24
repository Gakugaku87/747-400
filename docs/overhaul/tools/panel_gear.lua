-- Add the expanded gear position indication and the empty box to the custom
-- acf's upper EICAS (4-2 step 1, GEAR-11; the panel changes approved
-- 2026-10-23: GAP_ANALYSIS.md §4). Run from the repository root:
--   luajit docs/overhaul/tools/panel_gear.lua <acf in> <acf out>
-- It prints every change. In GROUP Gear (the normal display,
-- gear/EICAS1_display_status 1): the empty box (FCOM p.1505: all position
-- indications lost) at gear/gear_position/annun_status 3. After it, a new
-- GROUP Gear Expanded (EICAS1_display_status 2; FCOM p.1505-1506): the GEAR
-- label and a box for each gear, DN (green), crosshatched (white), UP (white)
-- or an amber X from gear/gear_position/annun_gear [0]-[4] (nose, left body,
-- right body, left wing, right wing; 1, 2, 0, 3). The layout follows the
-- FCOM's figure (nose above GEAR, wing gear beside it, body gear below and
-- inboard), scaled from its DOWN box to the panel's 79 pixels, and raised so
-- the body gear boxes stay above the flap tapes (their top at 673): GEAR at
-- 739, the boxes 39 x 30 (images by make_gear_images.ps1).
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_gear.lua <acf in> <acf out>")
local IMG = "CRT Displays/EICAS Upper/"
local D = "laminar/B747/gear/gear_position/"

local lines = {}
for l in io.lines(src) do lines[#lines + 1] = l end
local changes = 0
local function note(what) changes = changes + 1; print(what) end
local function f6(v) return string.format("%.6f", v) end

-- GROUP Gear and its END_GROUP
local g0, g1, gind
for i, l in ipairs(lines) do
    local ind = l:match("^(%s*)GROUP Gear$")
    if ind then g0, gind = i, ind break end
end
assert(g0, "no GROUP Gear")
for i = g0 + 1, #lines do
    if lines[i] == gind .. "END_GROUP" then g1 = i break end
end
assert(g1, "no END_GROUP for GROUP Gear")
for i = g0, g1 do assert(not lines[i]:find("annun_gear_box"), "the empty box is there already") end

-- an instrument block inside the group: its first line to the line before the next blank
local function find(name)
    for i = g0, g1 do
        local ind = lines[i]:match("^(%s*)" .. name:gsub("%p", "%%%0") .. "$")
        if ind then
            local e = i
            while lines[e + 1] ~= "" and lines[e + 1] ~= gind .. "END_GROUP" do e = e + 1 end
            return {s = i, e = e, ind = ind}
        end
    end
    error("no " .. name .. " in GROUP Gear")
end
-- a copy of a block with a new name, position, image and condition
local function make(b, name, x, y, image, cond, ind)
    ind = ind or b.ind
    local sub = ind .. "  "
    local out = {ind .. name}
    for k = b.s + 1, b.e do
        local l = lines[k]:gsub("^%s*", ""):gsub("%s+$", "")
        if l:match("^POS ") then out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
        elseif l:match("^IMAGE ") then out[#out + 1] = sub .. "IMAGE " .. IMG .. image
        elseif l:match("^DATAREF") then
            out[#out + 1] = sub .. "DATAREF "
            if cond then out[#out + 1] = sub .. cond end
        elseif not l:match("^SHOW_") then out[#out + 1] = sub .. l end
    end
    return out
end

local down = find("gen_rotary annun_gear_down")
local label = find("gen_rotary Gear Background")
local out = {}
for i = 1, g1 - 1 do out[#out + 1] = lines[i] end
-- the empty box of the normal display
out[#out + 1] = ""
for _, l in ipairs(make(down, "gen_rotary annun_gear_box", 1915.5, 752.5, "gear_annun_box",
        "SHOW_EQUAL 3.000000 " .. D .. "annun_status")) do out[#out + 1] = l end
note("GROUP Gear: + gen_rotary annun_gear_box (annun_status 3)")
out[#out + 1] = lines[g1]

-- the expanded display
local sub = gind .. "  "
out[#out + 1] = gind .. "GROUP Gear Expanded"
out[#out + 1] = sub .. "SHOW_EQUAL 2.000000 laminar/B747/gear/EICAS1_display_status"
for _, l in ipairs(make(label, "gen_rotary Gear Expanded Label", 1916, 739, "EICAS_gear_bgnd", nil, sub)) do out[#out + 1] = l end
note("GROUP Gear Expanded: + the GEAR label at 1916, 739")
local GEARS = {
    {"nose", 1916, 782}, {"left body", 1865, 695}, {"right body", 1967, 695},
    {"left wing", 1843, 739}, {"right wing", 1989, 739},
}
local STATES = {{"up", 0, "gear_box_up"}, {"dn", 1, "gear_box_dn"}, {"transit", 2, "gear_box_transit"}, {"x", 3, "gear_box_x"}}
for i, gear in ipairs(GEARS) do
    for _, st in ipairs(STATES) do
        out[#out + 1] = ""
        local name = "gen_rotary gear " .. gear[1] .. " " .. st[1]
        for _, l in ipairs(make(down, name, gear[2], gear[3], st[3],
                "SHOW_EQUAL " .. f6(st[2]) .. " " .. D .. "annun_gear[" .. (i - 1) .. "]", sub)) do out[#out + 1] = l end
        note("GROUP Gear Expanded: + " .. name .. " at " .. gear[2] .. ", " .. gear[3] .. " (annun_gear[" .. (i - 1) .. "] " .. st[2] .. ")")
    end
end
out[#out + 1] = ""
out[#out + 1] = gind .. "END_GROUP"
for i = g1 + 1, #lines do out[#out + 1] = lines[i] end

local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
io.stderr:write(string.format("%d changes, %d -> %d lines\n", changes, #lines, #out))
