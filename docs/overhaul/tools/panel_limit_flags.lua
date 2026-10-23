-- Rewrite the custom acf's engine indications to draw their red colour and
-- their red boxes from the engine indication model's flags instead of fixed
-- numbers in the panel (2-3 step 3, ENG-21). Run from the repository root:
--   luajit docs/overhaul/tools/panel_limit_flags.lua <acf in> <acf out>
-- It touches only SHOW conditions inside the upper EICAS N1, EPR and EGT
-- groups and the lower EICAS N2 and N3 groups, and prints every change.
--   N1, N2, N3: red readout and tape <- N1/red_on, N2/red_on, N3/red_on;
--     red box <- N1/box_red, ... (the box stays red after an exceedance
--     until CANC; FCOM p.873)
--   EPR (P&W, RR): the tape is red at max EPR <- EPR/red_on; the digital EPR
--     and its box stay white (FCOM p.833)
--   EGT: the box is red while EGT/box_red, else the readout's colour
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_limit_flags.lua <acf in> <acf out>")
local F = "laminar/B747/engines/"

local groups, name, changes = {}, "", 0
local out = {}
local function path() local t = {} for i = 1, #groups do t[i] = groups[i].name end return table.concat(t, " > ") end
local function in_group(g) for i = 1, #groups do if groups[i].name == g then return true end end return false end

local function replace(line, n)
    local ind, kind, val, dref = line:match("^(%s*)(SHOW_%u+)%s+(%S+)%s+(%S+)%s*$")
    if not ind then return line end
    local box = name:match("^gen_rotary Box") ~= nil
    local red = name:find("Red") ~= nil or in_group("Red") or in_group("Red N2") or in_group("Red N3")
    local i = dref:match("%[(%d)%]$")
    local new
    -- N1: the upper EICAS N1 tapes and readouts (P&W and RR, GE)
    if (in_group("N1 LED") or in_group("N1 LED GE") or in_group("N1 Tape") or in_group("N1 Tape GE"))
        and (dref:find("engines/display_N1%[") or dref:find("indicators/N1_percent%[")) and kind ~= "SHOW_EQUAL" then
        local flag = box and "N1/box_red" or "N1/red_on"
        new = string.format("%sSHOW_EQUAL %s %s%s[%s]", ind, kind == "SHOW_GREATER" and "1.000000" or "0.000000", F, flag, i)
    -- EPR: the tapes red at max EPR; the readouts and boxes white
    elseif (in_group("EPR Tapes PW") or in_group("EPR Tapes RR")) and dref:find("engines/display_EPR%[") then
        new = string.format("%sSHOW_EQUAL %s %sEPR/red_on[%s]", ind, kind == "SHOW_GREATER" and "1.000000" or "0.000000", F, i)
    elseif in_group("EPR LED") and dref:find("engines/display_EPR%[") then
        if kind == "SHOW_GREATER" then
            -- never: the flag is 0 or 1 (the digital EPR is white, FCOM p.833)
            new = string.format("%sSHOW_GREATER 1.000000 %sEPR/red_on[%s]", ind, F, i)
        else
            new = false     -- always: drop the condition
        end
    -- the P&W EGT red box: X-Plane's EGT (another scale) before
    elseif in_group("EGT LED") and box and dref:find("indicators/EGT_deg_C%[") and kind == "SHOW_GREATER" then
        new = string.format("%sSHOW_EQUAL 1.000000 %sEGT/box_red[%s]", ind, F, i)
    -- N2 and N3: the lower EICAS tapes, readouts and boxes
    elseif (in_group("N2") or in_group("N2 GE") or in_group("N2 N3 RR"))
        and (dref:find("engines/display_N2%[") or dref:find("engines/display_N3%[")) and kind ~= "SHOW_EQUAL" then
        local p = dref:find("display_N3") and "N3" or "N2"
        local flag = p .. (box and "/box_red" or "/red_on")
        new = string.format("%sSHOW_EQUAL %s %s%s[%s]", ind, kind == "SHOW_GREATER" and "1.000000" or "0.000000", F, flag, i)
    end
    if new == nil then return line end
    changes = changes + 1
    print(string.format("%d\t%s\t%s\t%s\t->\t%s", n, path(), name, line:gsub("^%s+", ""), new and new:gsub("^%s+", "") or "(removed)"))
    return new
end

local n = 0
for line in io.lines(src) do
    n = n + 1
    local l = line:gsub("\r$", "")
    local ind, rest = l:match("^(%s*)(.*)$")
    local g = rest:match("^GROUP%s*(.*)$")
    if g then
        while #groups > 0 and groups[#groups].depth >= #ind do table.remove(groups) end
        groups[#groups + 1] = {name = g, depth = #ind}
        name = ""
    elseif rest == "END_GROUP" then
        while #groups > 0 and groups[#groups].depth >= #ind do table.remove(groups) end
        name = ""
    elseif rest:match("^gen_") then
        name = rest
    end
    local r = l
    if name ~= "" and rest:match("^SHOW_") then r = replace(l, n) end
    -- the EGT boxes: red while the exceedance is stored
    if r and name:match("^gen_rotary") and in_group("EGT") and rest:match("^SHOW_EQUAL") then
        local ind2, i = l:match("^(%s*)SHOW_EQUAL 1%.000000 laminar/B747/engines/EGT/%a+_on%[(%d)%]$")
        if ind2 and rest:find("EGT/red_on") then
            r = string.format("%sSHOW_EQUAL 1.000000 %sEGT/box_red[%s]", ind2, F, i)
            changes = changes + 1
            print(string.format("%d\t%s\t%s\t%s\t->\t%s", n, path(), name, rest, r:gsub("^%s+", "")))
        elseif ind2 then
            out[#out + 1] = l
            r = string.format("%sSHOW_EQUAL 0.000000 %sEGT/box_red[%s]", ind2, F, i)
            changes = changes + 1
            print(string.format("%d\t%s\t%s\t%s\t->\t+ %s", n, path(), name, rest, r:gsub("^%s+", "")))
        end
    end
    if r then out[#out + 1] = r end
end
local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
io.stderr:write(string.format("%d changes\n", changes))
