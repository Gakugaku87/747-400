-- The custom acf's PFD pitch limit indication and VR's "R" (5-2 step 4c;
-- panel changes allowed anywhere since 2026-10-25). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_pfd_pli_vr.lua <acf in> <acf out>
-- It prints every change. In each of the four PFD copies:
--  - after GROUP TCAS RA Pitch (the attitude display's group that turns
--    with the bank, panel_pfd_tcas.lua), a GROUP PLI made the same way
--    with one pointer: the HrznPLI image moved up by laminar/B747/pfd/pli
--    (degrees above the airplane symbol, 6.81 pixels a degree as the RA's
--    pitch limits, held at 30), shown with laminar/B747/pfd/pli_show
--    (FCOM p.975, p.977);
--  - the VR bug (gen_pointer Vr) in a GROUP Vr Bugs that takes its radio
--    altitude condition (gone at lift-off), with the stock VR pointer shown
--    when laminar/B747/airspeed/vr_r is 0 and a copy with the VrR image
--    (R only) when it is 1 (FCOM p.972: R within 4 kt of V1).
-- The images come from make_pfd_pli_vr_images.ps1. The line endings are
-- kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_pli_vr.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

-- the pixels a degree of the RA's pitch limits (232 at 34.06 degrees)
local PX_PER_DEG = 232 / 34.06199
local HOLD_DEG = 30

local function append(dstt, block) for _, l in ipairs(block) do dstt[#dstt + 1] = l end end
local function indent(block, by)
    local o = {}
    for k, l in ipairs(block) do o[k] = (l == "" and l) or (by .. l) end
    return o
end
-- the block of an item starting at line i: up to the next item or END_GROUP
-- at its indent (the trailing blank line included)
local function item_block(i)
    local ind = lines[i]:match("^(%s*)")
    local j = i + 1
    while lines[j] and not (lines[j]:match("^" .. ind .. "%S") and lines[j]:sub(#ind + 1, #ind + 1) ~= " ") do j = j + 1 end
    local b = {}
    for k = i, j - 1 do b[#b + 1] = lines[k] end
    return b, j
end
-- a group's block: from its header to its END_GROUP at the same indent
local function group_block(i)
    local ind = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. ind .. "END_GROUP%s*$") do j = j + 1 end
    local b = {}
    for k = i, j do b[#b + 1] = lines[k] end
    return b, j + 1
end

local out, plis, vrs = {}, 0, 0
local i = 1
while i <= #lines do
    local l = lines[i]
    local gname = l:match("^%s*GROUP (TCAS RA Pitch.*)$")
    local pname = l:match("^%s*gen_pointer (Vr.*)$")
    if gname then
        local block, nexti = group_block(i)
        append(out, block)
        local sfx = gname:match(" 2$") and " 2" or ""
        -- the group's own lines, then its first pointer, changed
        local ind = l:match("^(%s*)")
        local pli = {}
        local k = 2
        pli[1] = ind .. "GROUP PLI" .. sfx
        while not block[k]:match("^%s*gen_pointer ") do pli[#pli + 1] = block[k]; k = k + 1 end
        local frames_done = false
        repeat
            local x = block[k]
            if x:match("^%s*gen_pointer ") then
                x = x:gsub("gen_pointer .*$", "gen_pointer PLI" .. sfx)
            elseif x:match("^%s*IMAGE ") then
                x = x:gsub("IMAGE .*$", "IMAGE CRT Displays/PFD/Artificial Horizon/HrznPLI")
            elseif x:match("^%s*DATAREF ") then
                x = x:gsub("DATAREF .*$", "DATAREF laminar/B747/pfd/pli")
            elseif x:match("^%s*SHOW_") then
                x = x:gsub("SHOW_.*$", "SHOW_GREATER 0.500000 laminar/B747/pfd/pli_show")
            elseif x:match("^%s*KEY_FRAME ") then
                if frames_done then x = nil else
                    frames_done = true
                    local fi = x:match("^(%s*)")
                    local px = HOLD_DEG * PX_PER_DEG
                    pli[#pli + 1] = string.format("%sKEY_FRAME %.6f %.6f 1.000000", fi, -999, -px)
                    pli[#pli + 1] = string.format("%sKEY_FRAME %.6f %.6f 1.000000", fi, -HOLD_DEG, -px)
                    pli[#pli + 1] = string.format("%sKEY_FRAME %.6f %.6f 1.000000", fi, HOLD_DEG, px)
                    x = string.format("%sKEY_FRAME %.6f %.6f", fi, 999, px)
                end
            end
            if x then pli[#pli + 1] = x end
            k = k + 1
        until block[k]:match("^%s*gen_pointer ") or block[k]:match("^%s*END_GROUP")
        pli[#pli + 1] = ind .. "END_GROUP"
        append(out, pli)
        print(string.format("after GROUP %s (near line %d): GROUP PLI%s, its pointer on laminar/B747/pfd/pli (%.2f px a degree, held at %d)",
            gname, i, sfx, PX_PER_DEG, HOLD_DEG))
        plis = plis + 1
        i = nexti
    elseif pname and (pname == "Vr" or pname == "Vr 2") then
        local block, nexti = item_block(i)
        local ind = l:match("^(%s*)")
        local sfx = pname == "Vr 2" and " 2" or ""
        local show
        for _, x in ipairs(block) do if x:match("^%s*SHOW_") then show = x:match("^%s*(.*)$") end end
        assert(show, "no condition on " .. pname .. " near line " .. i)
        out[#out + 1] = ind .. "GROUP Vr Bugs" .. sfx
        out[#out + 1] = ind .. "  " .. show
        local vr, r = {}, {}
        for _, x in ipairs(block) do
            if x:match("^%s*SHOW_") then
                vr[#vr + 1] = (x:gsub("SHOW_.*$", "SHOW_LESS 0.500000 laminar/B747/airspeed/vr_r"))
                r[#r + 1] = (x:gsub("SHOW_.*$", "SHOW_GREATER 0.500000 laminar/B747/airspeed/vr_r"))
            elseif x:match("^%s*gen_pointer ") then
                vr[#vr + 1] = x
                r[#r + 1] = (x:gsub("gen_pointer .*$", "gen_pointer Vr R" .. sfx))
            elseif x:match("^%s*IMAGE ") then
                vr[#vr + 1] = x
                r[#r + 1] = (x:gsub("IMAGE .*$", "IMAGE CRT Displays/PFD/Vspeeds/VrR"))
            else
                vr[#vr + 1] = x
                r[#r + 1] = x
            end
        end
        append(out, indent(vr, "  "))
        append(out, indent(r, "  "))
        out[#out + 1] = ind .. "END_GROUP"
        print(string.format("gen_pointer %s (near line %d): in GROUP Vr Bugs%s (%s), VR with vr_r 0, R with vr_r 1",
            pname, i, sfx, show))
        vrs = vrs + 1
        i = nexti
    else
        out[#out + 1] = l
        i = i + 1
    end
end
assert(plis == 4 and vrs == 4, string.format("changed %d PLI groups and %d VR bugs, expected 4 and 4", plis, vrs))

local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
