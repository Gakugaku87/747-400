-- The custom acf's flight director command bars (6-3 step 1e; panel
-- changes allowed anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_fd_shown.lua <acf in> <acf out>
-- It prints every change. Each PFD's `GROUP Flight Director` (the F/O's
-- with " 2"; the roll and pitch bars; two PFDs a side) showed with its
-- side's F/D switch ON
-- (laminar/B747/toggle_switch/position[23] the Captain's, [24] the F/O's);
-- now with laminar/B747/autopilot/fd/<side>/shown, the switch ON or a
-- TO/GA push's display with the switches OFF (FCOM p.661: above 80 kt, the
-- flaps out of up). The bars inside keep their own conditions (a roll or
-- pitch mode active). The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_fd_shown.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local SIDE = {["laminar/B747/toggle_switch/position[23]"] = "capt", ["laminar/B747/toggle_switch/position[24]"] = "fo"}
local count = {capt = 0, fo = 0}
for i, l in ipairs(lines) do
    if l:match("^%s*GROUP Flight Director%s*$") or l:match("^%s*GROUP Flight Director 2%s*$") then
        local pre = l:match("^(%s*)") .. "  "
        local j = i + 1
        local dref = lines[j]:match("^%s*SHOW_EQUAL 1%.000000 (.-)%s*$")
        assert(dref and SIDE[dref], "line " .. j .. ": not a F/D switch condition: " .. lines[j])
        local side = SIDE[dref]
        lines[j] = pre .. "SHOW_EQUAL 1.000000 laminar/B747/autopilot/fd/" .. side .. "/shown"
        count[side] = count[side] + 1
        print(string.format("  GROUP Flight Director (line %d): SHOW_EQUAL 1 %s -> laminar/B747/autopilot/fd/%s/shown", i, dref, side))
    end
end
assert(count.capt == 2 and count.fo == 2, "found " .. count.capt .. " Captain's and " .. count.fo .. " F/O's groups")
print((count.capt + count.fo) .. " changes")

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print("written " .. dst)
