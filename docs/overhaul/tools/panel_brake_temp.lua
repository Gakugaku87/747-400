-- The custom acf's GEAR synoptic brake temperature figures turn amber at the
-- indication 5 (ATA29_32 p.428: "at level 5 (482 c) the numeral changes
-- color"), not above 484.1 °C (4-2 step 5; approved by the user 2026-10-25).
-- Run from the repository root:
--   luajit docs/overhaul/tools/panel_brake_temp.lua <acf in> <acf out>
-- It prints every change: each brake's white figure on brake_temp < 484.0
-- becomes brake_temp_ind < 4.5, its amber figure on brake_temp > 484.1
-- becomes brake_temp_ind > 4.5 (the indication is a whole number 0-9). The
-- line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_brake_temp.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local changes = 0
for i, l in ipairs(lines) do
    local ind, op, n = l:match("^(%s*)SHOW_(%u+) 484%.[01]0000[06] laminar/B747/gear/brake_temp%[(%d+)%]$")
    if ind then
        assert(op == "LESS" or op == "GREATER", "unexpected condition at " .. i)
        local new = string.format("%sSHOW_%s 4.500000 laminar/B747/gear/brake_temp_ind[%s]", ind, op, n)
        print(string.format("%d: %s\n    -> %s", i, l:gsub("^%s+", ""), new:gsub("^%s+", "")))
        lines[i] = new
        changes = changes + 1
    end
end
assert(changes == 33, "expected 33 brake temperature conditions (16 brakes and the nose's amber one), found " .. changes)

f = assert(io.open(dst, "wb"))
f:write(table.concat(lines, nl), nl)
f:close()
print(changes .. " changes")
