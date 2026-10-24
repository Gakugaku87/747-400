-- Fix the custom acf's GEAR synoptic (4-2 step 5, GEAR-18; the panel changes
-- approved 2026-10-23: GAP_ANALYSIS.md §4). Run from the repository root:
--   luajit docs/overhaul/tools/panel_gear_synoptic.lua <acf in> <acf out>
-- It prints every change.
-- - The door boxes: CLOSED and the crosshatched box were shown by the gear's
--   position (X-Plane's deploy_ratio), so a gear down read open; now by the
--   door (laminar/B747/gear/door, 0 closed .. 1 open, from the gear model:
--   FCOM p.1508). X-Plane's gear 0-4 (nose, right body, left body, right
--   wing, left wing) to the door array's 0-4 (nose, left body, right body,
--   left wing, right wing).
-- - The tire pressures (notes/ATA-32.md §6.5): the left body tire 7's
--   (index 6) amber low figure looked at tire 10's pressure (index 9); the
--   white figures of tires 8 and 16 (indices 7, 15) had no conditions and
--   showed over the amber ones.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_gear_synoptic.lua <acf in> <acf out>")

local lines = {}
for l in io.lines(src) do lines[#lines + 1] = l end
local changes = 0
local function note(i, old, new)
    changes = changes + 1
    print(string.format("%d: %s\n    -> %s", i, old:gsub("^%s+", ""), new:gsub("^%s+", "")))
end

-- the door boxes
local DOOR = {[0] = 0, [1] = 2, [2] = 1, [3] = 4, [4] = 3}
for i, l in ipairs(lines) do
    local ind, op, xp = l:match("^(%s*)SHOW_(%u+) [%d%.]+ sim/flightmodel2/gear/deploy_ratio%[(%d)%]$")
    if ind then
        assert(op == "LESS" or op == "GREATER", "unexpected condition at " .. i)
        local new = string.format("%sSHOW_%s 0.001000 laminar/B747/gear/door[%d]", ind, op, DOOR[tonumber(xp)])
        note(i, l, new)
        lines[i] = new
    end
end
assert(changes == 10, "expected 10 door conditions, found " .. changes)

-- a gen_LED block of a tire's figure: its line, from its DATAREF line
local function led_block(dref_line)
    local s = dref_line
    while not lines[s]:match("gen_LED ") do s = s - 1 end
    return s
end
-- tire 7 (index 6): the amber low figure's condition on index 9
local fixed6 = false
for i, l in ipairs(lines) do
    if l:match("DATAREF laminar/B747/gear/tire_pressure%[6%]$") and lines[i + 1]:match("SHOW_LESS 100%.000000 laminar/B747/gear/tire_pressure%[9%]$") then
        local new = lines[i + 1]:gsub("%[9%]$", "[6]")
        note(i + 1, lines[i + 1], new)
        lines[i + 1] = new
        fixed6 = true
    end
end
assert(fixed6, "no tire 7 amber figure on index 9")
-- tires 8 and 16 (indices 7, 15): the white figures without conditions
local out = {}
local added = {}
for i, l in ipairs(lines) do
    out[#out + 1] = l
    local ind, n = l:match("^(%s*)DATAREF laminar/B747/gear/tire_pressure%[(%d+)%]$")
    if ind and (n == "7" or n == "15") and lines[led_block(i)]:match("Norm") and not lines[i + 1]:match("SHOW_") then
        local a = ind .. "SHOW_LESS 239.990005 laminar/B747/gear/tire_pressure[" .. n .. "]"
        local b = ind .. "SHOW_GREATER 100.010002 laminar/B747/gear/tire_pressure[" .. n .. "]"
        out[#out + 1], out[#out + 2] = a, b
        changes = changes + 2
        added[#added + 1] = n
        print(string.format("%d: after %s\n    + %s\n    + %s", i, l:gsub("^%s+", ""), a:gsub("^%s+", ""), b:gsub("^%s+", "")))
    end
end
assert(#added == 2, "expected the white figures of indices 7 and 15, found " .. #added)

local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
print(changes .. " changes")
