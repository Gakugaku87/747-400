-- The custom acf's PFD flap maneuver speed bugs (5-2 step 3a, DSP-13; panel
-- changes allowed anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_flap_bugs.lua <acf in> <acf out>
-- It prints every change. Each bug (gen_pointer with DATAREF
-- laminar/B747/airspeed/Vf0 ... Vf30, in every PFD copy) showed by the flap
-- lever's ranges, which overlap (the 20 bug stayed at flaps 30), or by
-- showVf25/showVf30. Its conditions become one: laminar/B747/airspeed/
-- show_vf[k] is 1 (k 0 UP, 1, 5, 10, 20, 25, 6 30: the speed tape model
-- shows the current flap setting's and the next lesser's, FCOM p.972).
-- X-Plane takes one condition for each instrument (ARCHITECTURE.md §5).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_flap_bugs.lua <acf in> <acf out>")
local INDEX = {Vf0 = 0, Vf1 = 1, Vf5 = 2, Vf10 = 3, Vf20 = 4, Vf25 = 5, Vf30 = 6}

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local out, i, n = {}, 1, 0
while i <= #lines do
    local l = lines[i]
    local vf = l:match("^%s*DATAREF laminar/B747/airspeed/(Vf%d+)$")
    if vf and INDEX[vf] and lines[i - 3] and lines[i - 3]:match("^%s*gen_pointer ") then
        out[#out + 1] = l
        local ind = l:match("^(%s*)")
        local removed = {}
        i = i + 1
        while lines[i]:match("^%s*SHOW_") do
            removed[#removed + 1] = lines[i]:match("^%s*(.*)$")
            i = i + 1
        end
        assert(#removed >= 1, "no condition after line " .. (i - 1))
        out[#out + 1] = ind .. "SHOW_EQUAL 1.000000 laminar/B747/airspeed/show_vf[" .. INDEX[vf] .. "]"
        print(string.format("%s (%s): %s -> show_vf[%d]", lines[i - 1 - #removed - 3]:match("gen_pointer (.*)$") or "?",
            vf, table.concat(removed, " / "), INDEX[vf]))
        n = n + 1
    else
        out[#out + 1] = l
        i = i + 1
    end
end
assert(n == 28, "changed " .. n .. " bugs, expected 28 (7 in each of the 4 PFD copies)")

local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
