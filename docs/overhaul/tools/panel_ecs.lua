-- Add the upper half of the custom acf's ECS synoptic and draw the packs
-- and the flow lines from the models (3-1 step 3, AIR-15, PNEU-11; the
-- panel changes approved 2026-10-23: GAP_ANALYSIS.md §4). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_ecs.lua <acf in> <acf out>
-- It prints every change. In GROUP ECS Synoptic (FCOM p.576-578):
--   zones F/D, U/D, A-E: the target (small, left; while
--     air/temp/target_shown) and the actual (right), in °C
--     (air/temp/zone_target, zone_actual), and °C after TEMP (ATA21 p.29,
--     p.250 show °C; FCOM's figure °F)
--   MASTER (air/temp/master), FWD and AFT (air/temp/cargo)
--   the outflow valve pointers (air/outflow_valve_left|right/pos, -1
--     closed .. +1 open) and MAN (amber: ATA21 p.420) or AUTO under each
--     (air/press/valve_man)
--   HI FLOW above each pack's number (air/pack/high_flow) and EXT AIR
--     (air/ext_air)
--   the packs' OFF, A and B from the valve and the controller in use
--     (air/pack/valve_pos, air/pack/ptc; they followed the selectors, and
--     A needed 1 < selector < 2)
--   the flow from each engine with its bleed valve open, from the APU with
--     its valve open (they followed the engine's bleed pressure and the
--     centre duct)
-- Positions: the background (ECS/background-1.png, 672 x 680) is drawn
-- with its centre at POS 1704, 108, so a point x, y of the image (from its
-- top left) is at 1368 + x, 448 - y on the panel.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_ecs.lua <acf in> <acf out>")
local A = "laminar/B747/air/"
local IMG = "CRT Displays/EICAS Lower/ECS/"
-- the LED fonts and their rows: an "xxx#00" font takes LED_ROWS 3, an
-- "xx###0" font 4, as the acf's other readouts have them (other rows draw
-- parts of the next glyphs over the digits)
local LED_BIG, ROWS_BIG = "CRT Displays/LED/LED_3.26B.xxx#00.white", 3     -- as the duct pressure
local LED_SMALL, ROWS_SMALL = "CRT Displays/LED/LED_2.18R.xx###0.white", 4

-- where things go, in the background image (FCOM p.577's figure)
local ZONES = {     -- the zone boxes' centres, 2 down from the middle (their labels sit on the top line)
    {"F/D", 90, 113}, {"U/D", 155, 113},
    {"A", 90, 162}, {"B", 153.5, 162}, {"C", 216.5, 162}, {"D", 280, 162}, {"E", 343.5, 162},
}
local TT_DX, AA_DX = -18, 12            -- target and actual from the box centre
local MASTER = {310, 108}
local CARGO = {{"Fwd", 122.5, 223.5}, {"Aft", 313.5, 223.5}}  -- under their labels
local UNIT = {301, 76}                  -- after TEMP
local POINTER = {{"left", 512, 220}, {"right", 584, 220}}     -- the pivots
local POINTER_DEG = 64      -- from pointing left to the OP and CL ticks (10 left, 21 up or down)
local MODE_Y = 262                      -- MAN/AUTO under the gauges
local MODE_X = {495, 567}
local PACK_X, HI_FLOW_Y = {111, 336, 560}, 300
local EXT_AIR = {336, 400}

local lines = {}
for l in io.lines(src) do lines[#lines + 1] = l:gsub("\r$", "") end

-- the ECS Synoptic group: its first line and its END_GROUP
local g0, g1, gind
for i, l in ipairs(lines) do
    local ind = l:match("^(%s*)GROUP ECS Synoptic$")
    if ind then g0, gind = i, ind break end
end
assert(g0, "no GROUP ECS Synoptic")
for i = g0 + 1, #lines do
    if lines[i] == gind .. "END_GROUP" then g1 = i break end
end
assert(g1, "no END_GROUP for ECS Synoptic")
for i = g0, g1 do
    assert(not lines[i]:find("air/temp/", 1, true), "the ECS synoptic already has the temperatures")
end

-- the instrument blocks of the group (not inside its turning groups)
local blocks = {}
do
    local i = g0 + 1
    while i < g1 do
        local ind, rest = lines[i]:match("^(%s*)(gen_.*)$")
        if rest then
            local j = i + 1
            while j < g1 and not lines[j]:match("^%s*$") and #lines[j]:match("^(%s*)") > #ind do j = j + 1 end
            blocks[#blocks + 1] = {s = i, e = j - 1, ind = ind, name = rest:gsub("%s+$", "")}
            i = j
        else
            i = i + 1
        end
    end
end
local function has(b, text)
    for k = b.s, b.e do if lines[k]:find(text, 1, true) then return true end end
    return false
end
local function find(name, text)
    for _, b in ipairs(blocks) do
        if b.name == name and (not text or has(b, text)) then return b end
    end
    error("no block " .. name)
end

local changes = 0
local function note(what) changes = changes + 1; print(what) end
local function px(x) return 1368 + x end
local function py(y) return 448 - y end
local function f6(v) return string.format("%.6f", v) end
local function show_eq(v, dref) return "SHOW_EQUAL " .. f6(v) .. " " .. dref end
local function show_gt(v, dref) return "SHOW_GREATER " .. f6(v) .. " " .. dref end
local function show_lt(v, dref) return "SHOW_LESS " .. f6(v) .. " " .. dref end

-- a copy of a block with a new name, position (nil keeps it), image,
-- dataref and conditions (the block's own conditions dropped; HIDE kept),
-- and the LED rows (nil keeps them)
local function make(b, name, x, y, image, dref, conds, rows)
    local ind = b.ind
    local sub = ind .. "  "
    local out = {ind .. name}
    for k = b.s + 1, b.e do
        local l = lines[k]:gsub("^%s*", ""):gsub("%s+$", "")
        if l:match("^POS ") and x then out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
        elseif l:match("^IMAGE ") and image then out[#out + 1] = sub .. "IMAGE " .. image
        elseif l:match("^DATAREF") then
            local d = dref
            if d == nil then d = l:match("^DATAREF%s*(.*)$") end
            out[#out + 1] = (sub .. "DATAREF " .. d):gsub("%s+$", " ")
            for _, c in ipairs(conds or {}) do out[#out + 1] = sub .. c end
        elseif l:match("^LED_ROWS ") and rows then out[#out + 1] = sub .. "LED_ROWS " .. rows
        elseif not l:match("^SHOW_") then out[#out + 1] = sub .. l end
    end
    return out
end

local led = find("gen_LED Left Duct Pressure", ".white")      -- the white duct pressure
local img = find("gen_rotary background")
local new = {}      -- the instruments added at the end of the group
local function add(t) new[#new + 1] = ""; for _, l in ipairs(t) do new[#new + 1] = l end end

-- zone temperatures, MASTER, the cargo, the unit
for z, zone in ipairs(ZONES) do
    local name, x, y = zone[1], zone[2], zone[3]
    add(make(led, "gen_LED Zone " .. name .. " Target", px(x + TT_DX), py(y), LED_SMALL,
        A .. "temp/zone_target[" .. (z - 1) .. "]", {show_eq(1, A .. "temp/target_shown")}, ROWS_SMALL))
    add(make(led, "gen_LED Zone " .. name .. " Actual", px(x + AA_DX), py(y), LED_BIG,
        A .. "temp/zone_actual[" .. (z - 1) .. "]", nil, ROWS_BIG))
    note("zone " .. name .. ": target (with temp/target_shown) and actual")
end
add(make(led, "gen_LED Master Temp", px(MASTER[1]), py(MASTER[2]), LED_BIG, A .. "temp/master", nil, ROWS_BIG))
note("MASTER")
for c, cargo in ipairs(CARGO) do
    add(make(led, "gen_LED " .. cargo[1] .. " Cargo Temp", px(cargo[2]), py(cargo[3]), LED_BIG,
        A .. "temp/cargo[" .. (c - 1) .. "]", nil, ROWS_BIG))
    note(cargo[1]:upper() .. " cargo")
end
add(make(img, "gen_rotary temp unit", px(UNIT[1]), py(UNIT[2]), IMG .. "temp_c"))
note("TEMP °C")

-- the outflow valves: MAN or AUTO under each
for v, side in ipairs({"left", "right"}) do
    local man = A .. "press/valve_man[" .. (v - 1) .. "]"
    add(make(img, "gen_rotary outflow " .. side .. " man", px(MODE_X[v]), py(MODE_Y), IMG .. "press_mode_man_amber",
        nil, {show_eq(1, man)}))
    add(make(img, "gen_rotary outflow " .. side .. " auto", px(MODE_X[v]), py(MODE_Y), IMG .. "press_mode_auto",
        nil, {show_eq(0, man)}))
    note("outflow valve " .. side .. ": MAN (amber) or AUTO")
end

-- the pointers: copies of GROUP left air isln (a group turned by its
-- dataref about its POS) holding the pointer; 0 points left, +1 (open) to
-- the OP tick, -1 (closed) to the CL tick
local r0, r1
for i = g0, g1 do
    if lines[i]:match("^%s*GROUP left air isln%s*$") then r0 = i end
    if r0 and not r1 and i > r0 and lines[i] == lines[r0]:match("^(%s*)") .. "END_GROUP" then r1 = i end
end
assert(r0 and r1, "no GROUP left air isln")
for _, p in ipairs(POINTER) do
    local side, x, y = p[1], px(p[2]), py(p[3])
    new[#new + 1] = ""
    local first_kf = true
    for k = r0, r1 do
        local l = lines[k]
        local ind = l:match("^(%s*)")
        local t = l:gsub("^%s*", "")
        if k == r0 then l = ind .. "GROUP outflow " .. side .. " pointer"
        elseif t:match("^DATAREF laminar") then l = ind .. "DATAREF " .. A .. "outflow_valve_" .. side .. "/pos"
        elseif t:match("^POS ") then l = ind .. "POS " .. f6(x) .. " " .. f6(y)
        elseif t:match("^IMAGE ") then l = ind .. "IMAGE " .. IMG .. "outflow_pointer"
        elseif t:match("^gen_rotary ") then l = ind .. "gen_rotary outflow " .. side .. " pointer"
        elseif t:match("^KEY_FRAME") and k < r0 + 10 then
            -- the group's key frames (value, angle)
            if first_kf then l = ind .. "KEY_FRAME -1.000000 " .. f6(-POINTER_DEG) .. " 1.000000"; first_kf = false
            else l = ind .. "KEY_FRAME 1.000000 " .. f6(POINTER_DEG) end
        end
        new[#new + 1] = l
    end
    note("outflow valve " .. side .. ": pointer")
end

-- HI FLOW above each pack's number, EXT AIR across pack 2's line
for p, x in ipairs(PACK_X) do
    add(make(img, "gen_rotary pack " .. p .. " hi flow", px(x), py(HI_FLOW_Y), IMG .. "hiflow",
        nil, {show_eq(1, A .. "pack/high_flow[" .. (p - 1) .. "]")}))
    note("pack " .. p .. ": HI FLOW")
end
add(make(img, "gen_rotary ext air", px(EXT_AIR[1]), py(EXT_AIR[2]), IMG .. "ext_air", nil, {show_eq(1, A .. "ext_air")}))
note("EXT AIR")

-- edits of the group's blocks: the packs, the engine and APU flow
local edits = {}
local function edit(b, conds, what)
    local t = make(b, b.name, nil, nil, nil, nil, conds)
    t[1] = lines[b.s]           -- the name line as it was
    edits[b.s] = {e = b.e, lines = t}
    note(what)
end
for p = 1, 3 do
    local valve, ptc = A .. "pack/valve_pos[" .. (p - 1) .. "]", A .. "pack/ptc[" .. (p - 1) .. "]"
    edit(find("gen_rotary pack " .. p .. " off"), {show_lt(0.5, valve)}, "pack " .. p .. " OFF: the valve closed")
    edit(find("gen_rotary pack " .. p .. " A"), {show_gt(0.5, valve), show_eq(1, ptc)}, "pack " .. p .. " A: controller A")
    edit(find("gen_rotary pack " .. p .. " B"), {show_gt(0.5, valve), show_eq(2, ptc)}, "pack " .. p .. " B: controller B")
end
for n = 1, 4 do
    edit(find("gen_rotary eng " .. n), {show_gt(0.5, A .. "engine" .. n .. "/bleed_valve_pos")},
        "engine " .. n .. " flow: its bleed valve open")
end
edit(find("gen_rotary apu"), {show_gt(0.5, A .. "apu/bleed_valve_pos")}, "APU flow: its valve open")

-- write: the edited blocks in place, the new instruments before END_GROUP
local out, k = {}, 1
while k <= #lines do
    local e = edits[k]
    if e then
        for _, l in ipairs(e.lines) do out[#out + 1] = l end
        k = e.e + 1
    else
        if k == g1 then for _, l in ipairs(new) do out[#out + 1] = l end end
        out[#out + 1] = lines[k]
        k = k + 1
    end
end
local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
io.stderr:write(string.format("%d changes, %d -> %d lines\n", changes, #lines, #out))
