-- Change the custom acf's ECS data block on the primary EICAS (AIR-18; two
-- panel changes outside the approved list, approved by the user
-- 2026-10-24). Run from the repository root:
--   luajit docs/overhaul/tools/panel_data_block.lua <acf in> <acf out>
-- It touches only GROUP Cabin Alt and GROUP Landing Alt inside GROUP
-- Pressure, and prints every change.
--   CAB ALT: the red readout (10,000 ft and above: ATA21 p.451) draws 5
--     digits (the 5-row font x####0.red from make_led_fonts.ps1, LED_ROWS
--     5), so it shows in full (it drew 4: 28,575 ft read 8575). It moves
--     left by one digit, to x 1560 as the 5-digit LDG ALT below, so its
--     right end stays where it was. The white (below 8,500 ft) and amber
--     (below 10,000 ft) readouts keep their 4 digits.
--   LDG ALT: the readout and its minus sign show only while
--     air/press/ldg_alt_shown is 1 (blank with both controllers failed or
--     both outflow valves in MAN: FCOM p.586). AUTO and MAN stay: FCOM
--     inhibits the altitude only.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_data_block.lua <acf in> <acf out>")
local SHOWN = "SHOW_EQUAL 1.000000 laminar/B747/air/press/ldg_alt_shown"
local CAB_X_OLD, CAB_X_NEW = "1568.000000", "1560.000000"

local lines = {}
for l in io.lines(src) do lines[#lines + 1] = l:gsub("\r$", "") end

-- a group's first line and its END_GROUP (the same indent), inside from..to
local function group(name, from, to)
    for i = from, to do
        local ind = lines[i]:match("^(%s*)GROUP " .. name .. "$")
        if ind then
            for j = i + 1, to do
                if lines[j] == ind .. "END_GROUP" then return i, j end
            end
            error("no END_GROUP for " .. name)
        end
    end
    error("no GROUP " .. name)
end
local p0, p1 = group("Pressure", 1, #lines)
assert(lines[p0 + 1]:find("pressurization/EICAS1_display_status", 1, true), "GROUP Pressure is not the data block")
local c0, c1 = group("Cabin Alt", p0, p1)
local l0, l1 = group("Landing Alt", p0, p1)

local changes = 0
local function note(what) changes = changes + 1; print(what) end
local function set(i, old, new, what)
    assert(lines[i]:find(old, 1, true), string.format("line %d: no %q in %q", i, old, lines[i]))
    lines[i] = lines[i]:gsub(old:gsub("%p", "%%%0"), (new:gsub("%%", "%%%%")), 1)
    note(string.format("%d: %s", i, what))
end

-- CAB ALT: the red readout
local led = nil
local seen = {}
for i = c0 + 1, c1 - 1 do
    local l = lines[i]
    local colour = l:match("^%s*gen_LED LED (%a+)%s*$")
    if colour then led = colour; seen[colour] = true end
    local t = l:gsub("^%s*", "")
    if led == "Red" then
        if t:match("^POS ") then
            set(i, "POS " .. CAB_X_OLD .. " ", "POS " .. CAB_X_NEW .. " ", led .. ": POS x " .. CAB_X_OLD .. " -> " .. CAB_X_NEW)
        elseif t:match("^IMAGE ") then
            set(i, "LED_3.26B.xx###0.", "LED_3.26B.x####0.", led .. ": font xx###0 -> x####0")
        elseif t:match("^DIGITS ") then
            set(i, "DIGITS 4", "DIGITS 5", led .. ": DIGITS 4 -> 5")
        elseif t:match("^LED_ROWS ") then
            set(i, "LED_ROWS 4", "LED_ROWS 5", led .. ": LED_ROWS 4 -> 5")
        end
    end
end
assert(seen.White and seen.Amber and seen.Red, "GROUP Cabin Alt: not White, Amber and Red")

-- LDG ALT: the condition after the block's DATAREF line and its own
-- conditions
local inserts = {}
local block = nil
for i = l0 + 1, l1 - 1 do
    local l = lines[i]
    local name = l:match("^%s*(gen_%S+ .-)%s*$")
    if name then block = {name = name} end
    if block and l:match("^%s*DATAREF") then
        local k = i
        while lines[k + 1]:match("^%s*SHOW_") do
            assert(lines[k + 1]:gsub("^%s*", "") ~= SHOWN, block.name .. " already has the condition")
            k = k + 1
        end
        local ind = l:match("^(%s*)")
        inserts[k] = ind .. SHOWN
        block = nil
    end
end
local out = {}
for i, l in ipairs(lines) do
    out[#out + 1] = l
    if inserts[i] then
        out[#out + 1] = inserts[i]
        note(string.format("%d: LDG ALT: + %s", i, SHOWN))
    end
end
assert(changes == 6, "expected 6 changes, made " .. changes)

local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
io.stderr:write(string.format("%d changes, %d -> %d lines\n", changes, #lines, #out))
