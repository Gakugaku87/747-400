-- The custom acf's ND route data (5-2 step 5c; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_data.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, each of the
-- first 20 map slots (the route waypoints take the first slots:
-- B747.61.xt.nd.lua) gets two lines under its identifier, the altitude and
-- the ETA (FCOM p.1148; FMSPG p.50: KILMR, 12000, 0835Z), from the ND
-- module's laminar/B747/nd/<side>/text/rdata1_<n> and rdata2_<n>: white
-- (the inactive waypoints' font) on rdata_color[n] 1, magenta (the active
-- waypoint's font, TXT.2.28.red) on 2. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_data.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local SLOTS = 20
local LINE_DY = 26                  -- the lines' spacing (the font is 24 pixels high)

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
-- the panel keeps 19 characters of a name ("ND Text10 backrotat")
local NAME_MAX = 19
local function short(nm)
    local kind, rest = nm:match("^(%S+) (.*)$")
    return kind .. " " .. rest:sub(1, NAME_MAX)
end
local function child(i, nm)
    for _, j in ipairs(children(i)) do
        if name(j):gsub("%s+", " ") == short(nm) then return j end
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
-- a copy of a gen_ block at depth with a new header, POS and DATAREF
local function copy(i, depth, header, x, y, dref)
    local n = ind(i)
    local pre = string.rep(" ", depth)
    local o = {pre .. header}
    for j = i + 1, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        local key = body:match("^  (%u[%u_]*)")
        if key == "POS" then
            o[#o + 1] = pre .. string.format("  POS %.6f %.6f", x, y)
        elseif key == "DATAREF" then
            o[#o + 1] = pre .. "  DATAREF " .. dref
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
local NDS = {{top = "Captain ND", side = "capt"}, {top = "First Officer ND", side = "fo"}}
for _, d in ipairs(NDS) do
    local top
    for i, l in ipairs(lines) do if l == "GROUP " .. d.top then top = i break end end
    assert(top, "no " .. d.top)
    local center
    for j = top + 1, group_end(top) - 1 do
        if name(j) == "GROUP ND Text Center" then assert(not center, "two ND Text Center"); center = j end
    end
    assert(center, "no ND Text Center in " .. d.top)
    print(string.format("%s (line %d), ND Text Center (line %d):", d.top, top, center))
    local T = "laminar/B747/nd/" .. d.side .. "/text/"
    for n = 0, SLOTS - 1 do
        local slot = child(center, "GROUP ND Text Icons" .. n)
        local back = child(child(slot, "GROUP ND Text" .. n .. " Y"), "GROUP ND Text" .. n .. " backrotate")
        local white = child(back, "gen_text Text" .. n .. " White")
        local red = child(back, "gen_text Text" .. n .. " Red")
        local x, y = pos(white)
        local depth = ind(white)
        local pre = string.rep(" ", depth)
        local block = {}
        for _, c in ipairs({{"White", white, 1}, {"Magenta", red, 2}}) do
            block[#block + 1] = pre .. short("GROUP T" .. n .. " Data " .. c[1])
            block[#block + 1] = pre .. string.format("  SHOW_EQUAL %.6f %srdata_color[%d]", c[3], T, n)
            for k = 1, 2 do
                for _, l in ipairs(copy(c[2], depth + 2, short(string.format("gen_text T%d Data%d %s", n, k, c[1])),
                        x, y - k * LINE_DY, string.format("%srdata%d_%d", T, k, n))) do
                    block[#block + 1] = l
                end
            end
            block[#block + 1] = pre .. "END_GROUP"
        end
        local last = children(back)
        local at = gen_end(last[#last])
        assert(not after[at], "two insertions after line " .. at)
        after[at] = block
        changes = changes + 1
        print(string.format("  slot %d: + Route Data White, Magenta at %.1f %.1f, %.1f", n, x, y - LINE_DY, y - 2 * LINE_DY))
    end
end
print(changes .. " changes")

local out = {}
for i, l in ipairs(lines) do
    out[#out + 1] = l
    if after[i] then for _, a in ipairs(after[i]) do out[#out + 1] = a end end
end
local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
