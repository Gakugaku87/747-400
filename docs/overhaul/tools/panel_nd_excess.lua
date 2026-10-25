-- The custom acf's ND EXCESS DATA message (5-2 step 5c; panel changes
-- allowed anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_excess.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, the message
-- (image from make_nd_excess_image.ps1) on the ND module's
-- laminar/B747/nd/<side>/excess_data (B747.61.xt.nd.lua: more map symbols
-- than its 60 slots), at the upper left as FCOM p.1030's figure: its left
-- edge an eighth of the display's width from the left, its middle a quarter
-- of the height from the top (the display: the CRT background's image, 677
-- x 682, centred on its POS). As the last item of the ND's group that
-- follows the display it is shown on (GROUP Lower EICAS Vertica). The line
-- endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_excess.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local SCREEN_W, SCREEN_H = 677, 682
local IMAGE_W = 160
local LEFT, MIDDLE = 0.125, 0.247       -- FCOM p.1030's figure

local function ind(i) return #lines[i]:match("^(%s*)") end
local function name(i) return lines[i]:match("^%s*(.-)%s*$") end
local function group_end(i)
    local s = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. s .. "END_GROUP%s*$") do j = j + 1 end
    return j
end
local function gen_end(i)
    local n, j = ind(i), i + 1
    while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do j = j + 1 end
    return j - 1
end
local function children(i)
    local n, out = ind(i), {}
    for j = i + 1, group_end(i) - 1 do
        if ind(j) == n + 2 and (lines[j]:match("^%s*GROUP ") or lines[j]:match("^%s*gen_")) then out[#out + 1] = j end
    end
    return out
end
local function child(i, nm)
    for _, j in ipairs(children(i)) do
        if name(j):gsub("%s+", " ") == nm then return j end
    end
    error("no " .. nm .. " in " .. name(i))
end
local function pos(i)
    for j = i + 1, gen_end(i) do
        local x, y = lines[j]:match("^%s*POS ([%d.%-]+) ([%d.%-]+)")
        if x then return tonumber(x), tonumber(y) end
    end
    error("no POS in " .. name(i))
end
local function copy(i, depth, header, x, y, image, show)
    local n = ind(i)
    local pre = string.rep(" ", depth)
    local o = {pre .. header}
    for j = i + 1, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        local key = body:match("^  (%u[%u_]*)")
        if key == "POS" then
            o[#o + 1] = pre .. string.format("  POS %.6f %.6f", x, y)
        elseif key == "IMAGE" then
            o[#o + 1] = pre .. "  IMAGE " .. image
        elseif key == "DATAREF" then
            o[#o + 1] = pre .. "  DATAREF "
            o[#o + 1] = pre .. "  " .. show
        elseif key == "SHOW_LESS" or key == "SHOW_EQUAL" or key == "SHOW_GREATER" then
            -- dropped
        else
            o[#o + 1] = body == "" and "" or pre .. body
        end
    end
    return o
end

local after = {}
local changes = 0
local NDS = {{top = "Captain ND", side = "capt", banana = "GROUP ND CAPT BANANA Y", arc = "gen_rotary CAPT BANANA"},
    {top = "First Officer ND", side = "fo", banana = "GROUP ND FO BANANA Y", arc = "gen_rotary FO BANANA"}}
for _, d in ipairs(NDS) do
    local top
    for i, l in ipairs(lines) do if l == "GROUP " .. d.top then top = i break end end
    assert(top, "no " .. d.top)
    local horizon = children(top)[1]
    assert(name(horizon) == "GROUP Lower EICAS Horizon", "no Lower EICAS Horizon in " .. d.top)
    local bx, by = pos(child(child(horizon, "GROUP ndclip"), "gen_rotary CRT Background"))
    local vertical = child(horizon, "GROUP Lower EICAS Vertica")
    local arc = child(child(child(vertical, "GROUP ND Text Center"), d.banana), d.arc)
    local x = bx - SCREEN_W / 2 + LEFT * SCREEN_W + IMAGE_W / 2
    local y = by + SCREEN_H / 2 - MIDDLE * SCREEN_H
    local at = group_end(vertical) - 1
    assert(not after[at], "two insertions after line " .. at)
    after[at] = copy(arc, ind(vertical) + 2, "gen_rotary EXCESS DATA", x, y, "CRT Displays/ND/excess_data",
        "SHOW_GREATER 0.500000 laminar/B747/nd/" .. d.side .. "/excess_data")
    changes = changes + 1
    print(string.format("%s (line %d): + gen_rotary EXCESS DATA at %.1f %.1f (the display centred at %.1f %.1f)",
        d.top, top, x, y, bx, by))
end
print(changes .. " changes")

local out = {}
for i, l in ipairs(lines) do
    out[#out + 1] = l
    if after[i] then for _, a in ipairs(after[i]) do out[#out + 1] = a end end
end
local w = assert(io.open(dst, "wb"))
w:write(table.concat(out, nl), nl)
w:close()
print("written " .. dst)
