-- The custom acf's transponder code display (5-1 step 5d, NAV-67; panel
-- changes allowed anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_xpdr.lua <acf in> <acf out>
-- It prints every change. In GROUP Transponder:
--  - the code (gen_LED Freq LCD L) shows with either transponder selected
--    while the panel has power (laminar/B747/xpdr/panel_on: the AC standby
--    bus or AC bus 2, ATA34_1 p.584). It showed only with L selected;
--  - the INOP picture shown with R selected (gen_rotary Freq LCD R (INOP))
--    becomes the selected transponder's label above the code, at the
--    window's upper left: ATC L or ATC R (Radios/atc_lr from
--    make_xpdr_images.ps1, frames chosen by the XPDR switch), as on FCOM
--    p.1218.
-- The window and the code's place were measured on X-Plane screenshots
-- (the window x 1834-2048, y 1125-1234; the code's digits y 1150-1208).
-- X-Plane takes one condition for each instrument (ARCHITECTURE.md §5).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_xpdr.lua <acf in> <acf out>")
local LABEL_X, LABEL_Y = 1870, 1221        -- the label's centre (60 x 20 frames)
local POWER = "SHOW_EQUAL 1.000000 laminar/B747/xpdr/panel_on"
local SWITCH = "laminar/B747/flt_mgmt/transponder/sel_dial_pos"

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function find(a, b, line, what)
    for i = a, b do
        if lines[i] == line then return i end
    end
    error("no " .. what .. " in lines " .. a .. "-" .. b)
end
local s = find(1, #lines, "GROUP Transponder", "GROUP Transponder")
local e = find(s, #lines, "END_GROUP", "its END_GROUP")
local led = find(s, e, "  gen_LED Freq LCD L", "the code")
local cond = find(led, e, "    SHOW_EQUAL 0.000000 " .. SWITCH, "the code's condition")
lines[cond] = "    " .. POWER
print(string.format("line %d: the code shows while the panel has power (%s)", cond, POWER))

local inop = find(s, e, "  gen_rotary Freq LCD R (INOP)", "the INOP picture")
local edits = {
    ["  gen_rotary Freq LCD R (INOP)"] = "  gen_rotary ATC L R",
    ["    POS 1948.000000 1178.500000"] = string.format("    POS %.6f %.6f", LABEL_X, LABEL_Y),
    ["    IMAGE Radios/FreqLCD_INOP"] = "    IMAGE Radios/atc_lr",
    ["    DATAREF "] = "    DATAREF " .. SWITCH,
    ["    SHOW_EQUAL 1.000000 " .. SWITCH] = "    " .. POWER,
    ["    KEY_FRAME 1.000000 6.000000"] = "    KEY_FRAME 1.000000 1.000000",
    ["    DIGITS 1"] = "    DIGITS 2",
}
local done, i = 0, inop
while lines[i] ~= "" do
    local l = lines[i]
    if l == "    SIZE 1.250000" then
        table.remove(lines, i)
        done = done + 1
    else
        if edits[l] then lines[i] = edits[l]; done = done + 1 end
        i = i + 1
    end
end
assert(done == 8, "changed " .. done .. " lines of the INOP block, expected 8")
print(string.format("lines %d-%d: the INOP picture is now the ATC L/R label at (%d, %d)", inop, i - 1, LABEL_X, LABEL_Y))

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print("written " .. dst)
