-- panel_thrust_ref.lua <acf>: the EICAS thrust display (the FMC's step 9g4;
-- docs/overhaul/ACF_DIFF.md §5): the 12 magenta reference cursors without the
-- A/T's THR REF condition, the thrust limit mode text from
-- laminar/B747/fms/thrlim/eicas (run once on the custom acf, 2026-10-31)
local P = arg[1]
local f = assert(io.open(P, "rb")); local s = f:read("*a"); f:close()
assert(not s:find("\r", 1, true), "not LF")
local lines = {}
for l in (s .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end
local out, dropped, swapped = {}, {}, 0
local FMA = "SHOW_EQUAL 5.000000 laminar/B747/autopilot/FMA/autothrottle_mode"
local i = 1
while i <= #lines do
    local l = lines[i]
    out[#out + 1] = l
    if l:match("GROUP .*REF MAGENT and 2$") and lines[i + 1] and lines[i + 1]:match("^%s*" .. FMA:gsub("%.", "%%.") .. "$") then
        dropped[#dropped + 1] = (i + 1) .. ": " .. lines[i + 1]
        i = i + 1
    end
    i = i + 1
end
for k, l in ipairs(out) do
    if l:match("^%s*DATAREF laminar/B747/engines/ref_thr_limit_mode$") then
        out[k] = l:gsub("laminar/B747/engines/ref_thr_limit_mode", "laminar/B747/fms/thrlim/eicas")
        swapped = swapped + 1
    end
end
assert(#dropped == 12, "dropped " .. #dropped)
assert(swapped == 1, "swapped " .. swapped)
f = assert(io.open(P, "wb")); f:write(table.concat(out, "\n") .. "\n"); f:close()
for _, d in ipairs(dropped) do print("dropped " .. d) end
print("swapped the mode text's DATAREF")
