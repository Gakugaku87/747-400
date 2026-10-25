-- The custom acf's ND weather radar annunciations in cyan and amber, with a
-- third line (5-1 step 5d, NAV-80, NAV-81; panel changes allowed anywhere
-- since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_wxr.lua <acf in> <acf out>
-- It prints every change. In each ND (the Captain's and the F/O's), from the
-- two cyan lines (gen_text with DATAREF laminar/B747/nd/<side>/text/wxr and
-- text/tilt, shown while that side's WXR was on):
--  - the cyan lines show while laminar/B747/nd/<side>/text/wxr_color[0], [1]
--    is 1 (B747.61.xt.nd.lua decides: WXR selected, a mode that shows it);
--  - an amber copy of each at the same place, shown while it is 2 (WXR FAIL,
--    the fault source in TEST: FCOM p.1155, p.1224; amber is CRT
--    Displays/TEXT/TXT.2.28.amber, as the TCAS data tags);
--  - a third line 20 px below the tilt (text/wxr3: WEAK or ATT in amber,
--    CAL or VAR in cyan), cyan and amber by wxr_color[2]; between the tilt
--    and TA ONLY.
-- X-Plane takes one condition for each instrument (ARCHITECTURE.md §5).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_wxr.lua <acf in> <acf out>")
local LINE_DY = 20
local AMBER = "CRT Displays/TEXT/TXT.2.28.amber"

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function block_end(s)
    local e = s
    while lines[e + 1] ~= "" do e = e + 1 end
    return e
end
-- the gen_text whose DATAREF is dref (exactly one in the file)
local function text_block(dref)
    local found
    for i = 1, #lines do
        if lines[i]:match("^%s*DATAREF " .. dref:gsub("%p", "%%%0") .. "$") then
            local s = i
            while not lines[s]:match("^%s*gen_text ") do s = s - 1 end
            assert(not found, "two instruments read " .. dref)
            found = s
        end
    end
    return assert(found, "no gen_text reads " .. dref)
end
local function field_line(s, key)
    for i = s, block_end(s) do
        if lines[i]:match("^%s*" .. key .. " ") then return i end
    end
    error("no " .. key .. " in the block at line " .. s)
end
local function copy_block(s, edits)
    local out = {}
    for i = s, block_end(s) do
        local l = lines[i]
        for key, v in pairs(edits) do
            if l:match("^%s*" .. key .. " ") or l:match("^%s*" .. key .. "$") then
                l = l:match("^(%s*)") .. key .. " " .. v
            end
        end
        out[#out + 1] = l
    end
    out[#out + 1] = ""
    return out
end
local function insert(at, block)
    for i = #block, 1, -1 do table.insert(lines, at, block[i]) end
end

for _, side in ipairs({"fo", "capt"}) do
    local T = "laminar/B747/nd/" .. side .. "/text/"
    local color = T .. "wxr_color"
    local l1 = text_block(T .. "wxr")
    local l2 = text_block(T .. "tilt")
    assert(l2 > l1 and block_end(l1) + 2 == l2, side .. ": the two lines are not next to each other")
    assert(not table.concat(lines, "\n", l1, block_end(l2)):find("wxr_color", 1, true), side .. ": already done")
    -- the cyan lines' conditions
    local c1, c2 = field_line(l1, "SHOW_EQUAL"), field_line(l2, "SHOW_EQUAL")
    print(string.format("%s: line %d %s -> wxr_color[0] == 1", side, c1, lines[c1]:match("SHOW_EQUAL (.*)$")))
    print(string.format("%s: line %d %s -> wxr_color[1] == 1", side, c2, lines[c2]:match("SHOW_EQUAL (.*)$")))
    lines[c1] = lines[c1]:match("^(%s*)") .. "SHOW_EQUAL 1.000000 " .. color .. "[0]"
    lines[c2] = lines[c2]:match("^(%s*)") .. "SHOW_EQUAL 1.000000 " .. color .. "[1]"
    local x, y = lines[field_line(l2, "POS")]:match("POS ([-%d.]+) ([-%d.]+)")
    local y3 = string.format("%.6f", tonumber(y) - LINE_DY)
    local name = lines[l1]:match("^%s*gen_text (.-)%s*$")
    local out = {}
    for _, b in ipairs(copy_block(l1, {gen_text = name .. " Amber", IMAGE = AMBER,
            SHOW_EQUAL = "2.000000 " .. color .. "[0]"})) do out[#out + 1] = b end
    for _, b in ipairs(copy_block(l2, {gen_text = name .. " TILT Amber", IMAGE = AMBER,
            SHOW_EQUAL = "2.000000 " .. color .. "[1]"})) do out[#out + 1] = b end
    for _, b in ipairs(copy_block(l2, {gen_text = name .. " 3", POS = x .. " " .. y3, DATAREF = T .. "wxr3",
            SHOW_EQUAL = "1.000000 " .. color .. "[2]"})) do out[#out + 1] = b end
    for _, b in ipairs(copy_block(l2, {gen_text = name .. " 3 Amber", POS = x .. " " .. y3, IMAGE = AMBER,
            DATAREF = T .. "wxr3", SHOW_EQUAL = "2.000000 " .. color .. "[2]"})) do out[#out + 1] = b end
    insert(block_end(l2) + 2, out)
    print(string.format("%s: amber lines 1 and 2, line 3 (cyan and amber) at (%s, %s), after line %d", side, x, y3, block_end(l2)))
end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print("written " .. dst)
