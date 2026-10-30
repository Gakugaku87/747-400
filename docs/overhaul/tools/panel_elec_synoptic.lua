-- The custom acf's ELEC synoptic inhibited for autoland (ELEC-18; FCOM
-- p.789 (6.10.11), p.802 (6.20.8)). Run from the repository root:
--   luajit docs/overhaul/tools/panel_elec_synoptic.lua <acf in> <acf out>
-- It prints every change.
-- While laminar/B747/electrical/synoptic_inhibit is 1 (the buses isolated
-- for autoland: the electrical model) the synoptic is not shown, only
-- "ELECTRICAL SYNOPTIC INHIBITED FOR AUTOLAND" (EICAS Lower/ELEC/
-- synoptic_inhibited, make_synoptic_images.ps1). An instrument obeys one
-- condition, a group's condition ANDs with its instruments': the group's
-- instruments go into a group of their own, shown while the dataref is 0
-- (not indented again: X-Plane reads the keywords, as panel_clocks.lua's
-- groups); the message is a copy of the background's gen_rotary (the same
-- POS and size), shown while it is 1.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_elec_synoptic.lua <acf in> <acf out>")

local lines = {}
for l in io.lines(src) do lines[#lines + 1] = l end
local INHIBIT = "laminar/B747/electrical/synoptic_inhibit"

local g0
for i, l in ipairs(lines) do
    if l == "      GROUP ELEC Synoptic" then
        assert(not g0, "two ELEC Synoptic groups")
        g0 = i
    end
end
assert(g0, "no GROUP ELEC Synoptic")
assert(lines[g0 + 1] == "        SHOW_EQUAL 3.000000 laminar/B747/dsp/synoptic_display", "unexpected condition: " .. lines[g0 + 1])
assert(lines[g0 + 2] == "        HIDE", "unexpected group line: " .. lines[g0 + 2])
local g1 = g0 + 3
while lines[g1] ~= "      END_GROUP" do g1 = g1 + 1 end
for i = g0, g1 do assert(not lines[i]:find(INHIBIT, 1, true), "already changed (line " .. i .. ")") end
-- the background's block, to copy for the message
local b0 = g0 + 3
assert(lines[b0] == "        gen_rotary background", "the background first: " .. lines[b0])
local b1 = b0 + 1
while lines[b1] ~= "" do b1 = b1 + 1 end

local out = {}
for i = 1, g0 + 2 do out[#out + 1] = lines[i] end
local added = 0
local function add(l)
    out[#out + 1] = l
    added = added + 1
    print("    + " .. l:gsub("^%s+", ""))
end
print(string.format("%d: in GROUP ELEC Synoptic, its %d lines (%d to %d) into a group of their own:", g0, g1 - g0 - 3, g0 + 3, g1 - 1))
add("        GROUP ELEC Synoptic shown")
add("          SHOW_EQUAL 0.000000 " .. INHIBIT)
for i = g0 + 3, g1 - 1 do out[#out + 1] = lines[i] end
add("        END_GROUP")
print("  the message:")
local image = false
for i = b0, b1 do
    local l = lines[i]
    if i == b0 then
        l = "        gen_rotary synoptic inhibited"
    elseif l:match("^%s+IMAGE ") then
        l, image = l:gsub("ELEC/background$", "ELEC/synoptic_inhibited")
        assert(image == 1, "unexpected image: " .. lines[i])
    end
    add(l)
    if l:match("^%s+DATAREF") then add("          SHOW_EQUAL 1.000000 " .. INHIBIT) end
end
for i = g1, #lines do out[#out + 1] = lines[i] end

local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
print(added .. " lines added")
