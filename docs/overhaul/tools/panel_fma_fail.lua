-- The custom acf's FMA mode failure lines and F/D bars (6-3 step 5c; panel
-- changes allowed anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_fma_fail.lua <acf in> <acf out>
-- It prints every change. In each PFD's `GROUP Flight Mode Annun` (the
-- F/O's with " 2"; two PFDs a side) the roll's and the pitch's `GROUP
-- Active` get a gen_rotary `Mode Fail`: the amber line through the active
-- mode (FCOM p.653, p.660), shown with laminar/B747/autopilot/FMA/roll_fail
-- (pitch_fail) = 1, centred on the mode change box across and on the modes'
-- letters up and down, made from the group's first mode as a template (the
-- image: make_fma_fail_images.ps1). In each `GROUP Flight Director` the
-- roll bar showed with a roll mode on the FMA (SHOW_GREATER 1
-- FMA/active_roll_mode), the pitch bar with a pitch mode; now with
-- laminar/B747/autopilot/fd/roll_bar (pitch_bar) = 1: a mode on the FMA and
-- not failed (FCOM p.660: the 109's bar of the failed axis goes, the 570's
-- both). The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_fma_fail.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local IMAGE = "CRT Displays/PFD/Flight Mode Annun/mode_fail"
local AXES = {{group = "Roll Modes", dref = "laminar/B747/autopilot/FMA/roll_fail"},
    {group = "Pitch Modes", dref = "laminar/B747/autopilot/FMA/pitch_fail"}}

-- the END_GROUP closing the GROUP at line i
local function group_end(i)
    local depth = 0
    for j = i, #lines do
        if lines[j]:match("^%s*GROUP ") then depth = depth + 1 end
        if lines[j]:match("^%s*END_GROUP%s*$") then
            depth = depth - 1
            if depth == 0 then return j end
        end
    end
    error("no END_GROUP for line " .. i)
end
-- the next line from i to last matching pattern
local function find(i, last, pattern)
    for j = i, last do
        if lines[j]:match(pattern) then return j end
    end
    return nil
end
-- the gen_rotary block starting at line i: its lines up to (not with) the
-- blank line that ends it
local function block(i)
    local b = {}
    local j = i
    while lines[j] and lines[j]:match("%S") do
        b[#b + 1] = lines[j]
        j = j + 1
    end
    return b
end

-- the failure lines: collected first, inserted from the end
local inserts = {}
local fma = 0
for i, l in ipairs(lines) do
    local side = l:match("^%s*GROUP Flight Mode Annun( ?2?)%s*$")   -- "" the Captain's, " 2" the F/O's
    if side then
        fma = fma + 1
        local last = group_end(i)
        for _, ax in ipairs(AXES) do
            local g = assert(find(i, last, "^%s*GROUP " .. ax.group .. side .. "%s*$"), "no " .. ax.group .. " in line " .. i)
            local gend = group_end(g)
            local a = assert(find(g, gend, "^%s*GROUP Active" .. side .. "%s*$"), "no Active in " .. ax.group .. " at " .. g)
            local aend = group_end(a)
            local box = assert(find(a, aend, "^%s*gen_rotary Mode Change Box" .. side .. "%s*$"), "no box at " .. a)
            local bx = tonumber(lines[box + 1]:match("^%s*POS (%S+) %S+"))
            -- the first mode after the box: the template
            local m = assert(find(box + 1, aend, "^%s*gen_rotary "), "no mode at " .. box)
            local t = block(m)
            local my = tonumber(t[2]:match("^%s*POS %S+ (%S+)"))
            assert(bx and my, "no POS at " .. m)
            local out = {}
            for k, line in ipairs(t) do
                local pre = line:match("^(%s*)")
                if k == 1 then
                    out[k] = pre .. "gen_rotary Mode Fail" .. side
                elseif line:match("^%s*POS ") then
                    out[k] = pre .. string.format("POS %.6f %.6f", bx, my)
                elseif line:match("^%s*IMAGE ") then
                    out[k] = pre .. "IMAGE " .. IMAGE
                elseif line:match("^%s*SHOW_") then
                    out[k] = pre .. "SHOW_EQUAL 1.000000 " .. ax.dref
                else
                    out[k] = line
                end
            end
            out[#out + 1] = ""
            inserts[#inserts + 1] = {at = aend, lines = out}
            print(string.format("  %s (line %d), %s Active: Mode Fail at %.1f %.1f on %s",
                l:match("^%s*(.-)%s*$"), i, ax.group, bx, my, ax.dref))
        end
    end
end
assert(fma == 4, "found " .. fma .. " FMA groups")
table.sort(inserts, function(a, b) return a.at > b.at end)
for _, ins in ipairs(inserts) do
    for k = #ins.lines, 1, -1 do table.insert(lines, ins.at, ins.lines[k]) end
end

-- the F/D bars
local BARS = {{name = "FD Bar %- Roll", from = "laminar/B747/autopilot/FMA/active_roll_mode", to = "laminar/B747/autopilot/fd/roll_bar"},
    {name = "FD Bar %- Pitch", from = "laminar/B747/autopilot/FMA/active_pitch_mode", to = "laminar/B747/autopilot/fd/pitch_bar"}}
local bars = 0
for i, l in ipairs(lines) do
    for _, b in ipairs(BARS) do
        if l:match("^%s*gen_pointer " .. b.name .. "%s*$") or l:match("^%s*gen_pointer " .. b.name .. " 2%s*$") then
            local j = i + 1
            while lines[j]:match("%S") do
                local pre, dref = lines[j]:match("^(%s*)SHOW_GREATER 1%.000000 (.-)%s*$")
                if dref then
                    assert(dref == b.from, "line " .. j .. ": " .. lines[j])
                    lines[j] = pre .. "SHOW_EQUAL 1.000000 " .. b.to
                    bars = bars + 1
                    print(string.format("  %s (line %d): SHOW_GREATER 1 %s -> SHOW_EQUAL 1 %s", l:match("^%s*(.-)%s*$"), j, b.from, b.to))
                    break
                end
                j = j + 1
            end
        end
    end
end
assert(bars == 8, "changed " .. bars .. " F/D bars")
print((#inserts + bars) .. " changes")

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print("written " .. dst)
