-- The custom acf's PFD ILS receiver (5-2 step 5b; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_pfd_ils_rx.lua <acf in> <acf out>
-- It prints every change. Each PFD follows the ILS receiver of the EIU in use
-- (FCOM p.1044; laminar/B747/pfd/<side>/ils_rx 1 L, 2 C, 3 R from the
-- display glue, ILS C on NAV1's data):
--  - the localizer pointers and the rising runway on pfd/<side>/loc_dots,
--    the glideslope pointers on pfd/<side>/gs_dots (before: X-Plane's HSI
--    deviations, NAV1 on the Captain's side and NAV2 on the F/O's whatever
--    the EIU);
--  - the approach reference's identifier on pfd/<side>/ils_ref, the
--    receiver's identifier or its frequency until the identification
--    (ATA34_1 p.466; before: NAV1's identifier on both sides, blank until
--    received), the F/O's second identifier item removed;
--  - the approach reference's DME and the approach course (FCOM p.986) on
--    ils_rx: NAV1's below 2.5, NAV2's above (before: the centre panel's FMC
--    master selector).
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_ils_rx.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local XP = "sim/cockpit2/radios/indicators/"

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
        local n = name(j)
        if n == nm or n == nm .. " 2" then return j end
    end
    error("no " .. nm .. " in " .. name(i))
end
local function props(i)
    local n, out, j = ind(i), {}, i + 1
    while lines[j] do
        local l = lines[j]
        if l:match("%S") then
            if ind(j) <= n then break end
            if ind(j) == n + 2 and (l:match("^%s*GROUP ") or l:match("^%s*gen_")) then break end
            if ind(j) == n + 2 then out[#out + 1] = j end
        end
        j = j + 1
    end
    return out
end

local replace, after = {}, {}
local changes = 0
local function prop_line(i, key)
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*" .. key .. " ") or lines[j]:match("^%s*" .. key .. "$") then return j end
    end
end
-- one SHOW line: the first replaced, the others dropped; an item without one
-- gets it after its DATAREF line
local function set_show(i, show)
    local first
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then
            if first then replace[j] = false else first = j; replace[j] = string.rep(" ", ind(i) + 2) .. show end
        end
    end
    if not first then
        local d = assert(prop_line(i, "DATAREF"), "no DATAREF in " .. name(i))
        after[d] = {string.rep(" ", ind(i) + 2) .. show}
    end
    changes = changes + 1
    print(string.format("  %s: %s", name(i), show))
end
local function set_dataref(i, dr)
    local d = assert(prop_line(i, "DATAREF"), "no DATAREF in " .. name(i))
    replace[d] = string.rep(" ", ind(i) + 2) .. "DATAREF " .. dr
    changes = changes + 1
    print(string.format("  %s: DATAREF %s", name(i), dr))
end
local function drop_show(i)
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then replace[j] = false end
    end
    changes = changes + 1
    print(string.format("  %s: no SHOW", name(i)))
end
local function delete(i)
    for j = i, gen_end(i) do replace[j] = false end
    changes = changes + 1
    print(string.format("  - %s", name(i)))
end

local copies = {}
for i, l in ipairs(lines) do
    local top = l:match("^GROUP (.+)$")
    if top and (top == "Captain PFD" or top == "First Officer PFD") then
        copies[#copies + 1] = {top = i, side = top:match("^Captain") and "capt" or "fo"}
    end
end
assert(#copies == 4, "found " .. #copies .. " PFD copies")

for _, c in ipairs(copies) do
    local p = "laminar/B747/pfd/" .. c.side .. "/"
    local L, R = "SHOW_LESS 2.500000 " .. p .. "ils_rx", "SHOW_GREATER 2.500000 " .. p .. "ils_rx"
    print(string.format("%s copy (line %d):", c.side, c.top))
    -- the deviations
    local nh, nv = 0, 0
    for j = c.top + 1, group_end(c.top) - 1 do
        local l = lines[j]
        local pre, which = l:match("^(%s*)DATAREF " .. XP .. "hsi_([hv])def_dots_c?o?pilot%s*$")
        if pre then
            if which == "h" then
                replace[j], nh = pre .. "DATAREF " .. p .. "loc_dots", nh + 1
            else
                replace[j], nv = pre .. "DATAREF " .. p .. "gs_dots", nv + 1
            end
        end
        assert(not l:match("SHOW_.*hsi_[hv]def"), "a SHOW on the HSI deviation at line " .. j)
    end
    assert(nh == 4 and nv == 2, string.format("%d localizer and %d glideslope DATAREFs", nh, nv))
    changes = changes + nh + nv
    print(string.format("  %d localizer DATAREFs (rising runway, 3 pointers) on %sloc_dots, %d glideslope on %sgs_dots",
        nh, p, nv, p))

    -- the approach reference and course
    local found = {}
    for j = c.top + 1, group_end(c.top) - 1 do
        local g = lines[j]:match("^%s*GROUP (.-)%s*$")
        if g then
            local base = g:gsub(" 2$", "")
            if base == "Approach Ref" or base == "Approach Course" then
                assert(not found[base], "two " .. g)
                found[base] = j
            end
        end
    end
    local ref, crs = assert(found["Approach Ref"]), assert(found["Approach Course"])
    if c.side == "capt" then
        set_dataref(child(ref, "gen_text ILS Label"), p .. "ils_ref[0]")
    else
        local id = child(ref, "gen_text ILS L")
        set_dataref(id, p .. "ils_ref[0]")
        drop_show(id)
        delete(child(ref, "gen_text ILS R"))
    end
    set_show(child(ref, "gen_LED ILS L DME LED"), L)
    set_show(child(ref, "gen_LED ILS R DME LED"), R)
    set_show(child(crs, "gen_LED LED ILS L"), L)
    set_show(child(crs, "gen_LED LED ILS R"), R)
end
print(changes .. " changes")

local out = {}
for i, l in ipairs(lines) do
    if replace[i] ~= false then out[#out + 1] = replace[i] or l end
    if after[i] then for _, a in ipairs(after[i]) do out[#out + 1] = a end end
end
local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
