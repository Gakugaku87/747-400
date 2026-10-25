-- The custom acf's PFD flight path vector and the FPV, PITCH and ROLL flags
-- (5-2 step 4d; panel changes allowed anywhere since 2026-10-25). Run from
-- the repository root:
--   luajit docs/overhaul/tools/panel_pfd_fpv.lua <acf in> <acf out>
-- It prints every change. In each of the four PFD copies:
--  - after GROUP PLI (in the attitude display), a GROUP FPV shown with
--    laminar/B747/pfd/<side>/fpv_show, holding a GROUP FPV X (moved right
--    by pfd/<side>/fpv_x, panel pixels) holding a GROUP FPV Y (moved up by
--    fpv_y) holding the FPV's body (a needle turned with the bank like the
--    horizon, without its pitch deflection) and its feet (not turned: they
--    stay parallel to the airplane symbol, FCOM p.980);
--  - in the IRS OFF group (the ATT and HDG flags' group), the FPV flag
--    (pfd/<side>/fpv_flag) and the PITCH and ROLL flags (pfd/pitch_flag,
--    roll_flag; the stock images Failure Flags/pitch and roll, unused
--    before). Their places from FCOM p.999's and p.974's figures, scaled by
--    the ATT flag's and the airplane symbol's sizes (estimates).
-- The images come from make_pfd_fpv_images.ps1. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_fpv.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

-- the flags' places from the attitude display's centre (panel pixels)
local FPV_FLAG_DX, FPV_FLAG_DY = -99, 71
local PITCH_DX, ROLL_DX, PR_DY = -108, 113, -125

local function append(dstt, block) for _, l in ipairs(block) do dstt[#dstt + 1] = l end end
local function indent(block, by)
    local o = {}
    for k, l in ipairs(block) do o[k] = (l == "" and l) or (by .. l) end
    return o
end
local function item_block(i)
    local ind = lines[i]:match("^(%s*)")
    local j = i + 1
    while lines[j] and not lines[j]:match("^" .. ind .. "%S") do j = j + 1 end
    local b = {}
    for k = i, j - 1 do b[#b + 1] = lines[k] end
    return b
end
local function group_end(i)
    local ind = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. ind .. "END_GROUP%s*$") do j = j + 1 end
    return j
end
-- a copy of a block: renamed, its POS and IMAGE set, its SHOW and pitch
-- deflection lines dropped, and a SHOW line added when given
local function copy(block, kind_name, pos, image, show)
    local o = {}
    for k, l in ipairs(block) do
        local ind = l:match("^(%s*)")
        if k == 1 then
            o[#o + 1] = ind .. kind_name
        elseif l:match("^%s*POS ") then
            o[#o + 1] = ind .. string.format("POS %.6f %.6f", pos[1], pos[2])
        elseif l:match("^%s*IMAGE ") then
            o[#o + 1] = ind .. "IMAGE " .. image
        elseif l:match("^%s*SHOW_") or l:match("^%s*DEFLECT_") then
            -- dropped
        elseif l:match("^%s*DATAREF") and show then
            o[#o + 1] = l
            o[#o + 1] = ind .. show
        else
            o[#o + 1] = l
        end
    end
    return o
end

-- first pass: each copy's side, attitude centre, horizon needle and a static
-- rotary to copy (the IRS OFF group's airplane symbol)
local copies = {}
local cur
for i, l in ipairs(lines) do
    local top = l:match("^GROUP (.+)$")
    if top then
        cur = nil
        if top:match("^Captain PFD") or top:match("^First Officer PFD") then
            cur = {side = top:match("^Captain") and "capt" or "fo"}
            copies[#copies + 1] = cur
        end
    elseif cur then
        if l:match("^%s*gen_needle Artificial Horizon") then cur.horizon = item_block(i) end
        if l:match("^%s*GROUP PLI") then
            cur.pli = i
            local x, y = table.concat(item_block(i), "\n"):match("POS ([%d.%-]+) ([%d.%-]+)")
            cur.cx, cur.cy = tonumber(x), tonumber(y)
        end
        if l:match("^%s*GROUP %a+ IRS OFF PFD") then cur.off = i end
        if l:match("^%s*gen_rotary Airplane Symbol") and cur.off and not cur.static then cur.static = item_block(i) end
    end
end
assert(#copies == 4, "found " .. #copies .. " PFD copies")
for n, c in ipairs(copies) do
    assert(c.horizon and c.pli and c.cx and c.off and c.static, "copy " .. n .. ": missing pieces")
end

-- second pass: insert after each PLI group's END_GROUP and after each IRS
-- OFF group's header lines (before its first child)
local after = {}
for _, c in ipairs(copies) do
    local sfx = c.side == "fo" and " 2" or ""
    local e = group_end(c.pli)
    local ind = lines[c.pli]:match("^(%s*)")
    local b = {}
    local fpv = "laminar/B747/pfd/" .. c.side .. "/"
    b[#b + 1] = ind .. "GROUP FPV" .. sfx
    b[#b + 1] = ind .. "  SHOW_GREATER 0.500000 " .. fpv .. "fpv_show"
    local function tgroup(name, dref, vertical, pre)
        return {pre .. "GROUP " .. name .. sfx, pre .. "  GROUP_ANIMATE_MODE TRANSLATE", pre .. "  GROUP_WIDTH 100",
            pre .. "  GROUP_HEIGHT 100", pre .. "  DATAREF " .. dref,
            pre .. string.format("  POS %.6f %.6f", c.cx, c.cy),
            pre .. "  KEY_FRAME -300.000000 -300.000000 1.000000", pre .. "  KEY_FRAME 300.000000 300.000000",
            pre .. "  IS_VERTICAL " .. vertical, pre .. "  OFFSET 0.000000"}
    end
    append(b, tgroup("FPV X", fpv .. "fpv_x", 0, ind .. "  "))
    append(b, tgroup("FPV Y", fpv .. "fpv_y", 1, ind .. "    "))
    local hind = c.horizon[1]:match("^(%s*)")
    local body = copy(c.horizon, "gen_needle FPV Body" .. sfx, {c.cx, c.cy}, "CRT Displays/PFD/Artificial Horizon/HrznFPVbody")
    local sind = c.static[1]:match("^(%s*)")
    local feet = copy(c.static, "gen_rotary FPV Feet" .. sfx, {c.cx, c.cy}, "CRT Displays/PFD/Artificial Horizon/HrznFPVfeet")
    -- re-indent the copies to sit inside FPV Y
    local function reind(block, from, to)
        local o = {}
        for k, l in ipairs(block) do o[k] = (l == "" and l) or (to .. l:sub(#from + 1)) end
        return o
    end
    append(b, reind(body, hind, ind .. "      "))
    append(b, reind(feet, sind, ind .. "      "))
    b[#b + 1] = ind .. "    END_GROUP"
    b[#b + 1] = ind .. "  END_GROUP"
    b[#b + 1] = ind .. "END_GROUP"
    after[e] = b
    print(string.format("%s copy: GROUP FPV%s after GROUP PLI (centre %.1f %.1f), on %sfpv_show, fpv_x, fpv_y",
        c.side, sfx, c.cx, c.cy, fpv))

    -- the flags at the IRS OFF group's first child
    local j = c.off + 1
    local oind = lines[c.off]:match("^(%s*)") .. "  "
    while not lines[j]:match("^%s*gen_") do j = j + 1 end
    local flags = {}
    append(flags, reind(copy(c.static, "gen_rotary FPV X" .. sfx, {c.cx + FPV_FLAG_DX, c.cy + FPV_FLAG_DY},
        "CRT Displays/PFD/Failure Flags/fpvX", "SHOW_GREATER 0.500000 " .. fpv .. "fpv_flag"), sind, oind))
    append(flags, reind(copy(c.static, "gen_rotary PITCH X" .. sfx, {c.cx + PITCH_DX, c.cy + PR_DY},
        "CRT Displays/PFD/Failure Flags/pitch", "SHOW_GREATER 0.500000 laminar/B747/pfd/pitch_flag"), sind, oind))
    append(flags, reind(copy(c.static, "gen_rotary ROLL X" .. sfx, {c.cx + ROLL_DX, c.cy + PR_DY},
        "CRT Displays/PFD/Failure Flags/roll", "SHOW_GREATER 0.500000 laminar/B747/pfd/roll_flag"), sind, oind))
    after[j - 1] = flags
    print(string.format("%s copy: FPV, PITCH and ROLL flags in the IRS OFF group (FPV at %.1f %.1f, PITCH %.1f %.1f, ROLL %.1f %.1f)",
        c.side, c.cx + FPV_FLAG_DX, c.cy + FPV_FLAG_DY, c.cx + PITCH_DX, c.cy + PR_DY, c.cx + ROLL_DX, c.cy + PR_DY))
end

local out = {}
for i, l in ipairs(lines) do
    out[#out + 1] = l
    if after[i] then append(out, after[i]) end
end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
