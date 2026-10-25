-- Make the custom acf's PFDs show each pilot's own radio altimeter, DH alert
-- and the GPWS's PULL UP and WINDSHEAR (5-1 step 4; the panel changes
-- approved 2026-10-23: GAP_ANALYSIS.md §4, DSP-02, DSP-04, DSP-10). Run from
-- the repository root:
--   luajit docs/overhaul/tools/panel_ra_gpws.lua <acf in> <acf out>
-- It prints every change. In each PFD group (the captain's and the first
-- officer's, each drawn twice: outboard and inboard):
--  - the radio altitude's digits and the rising runway show with that
--    pilot's radio altimeter working and below 2,500 ft
--    (laminar/B747/ra/capt/show, fo/show) instead of X-Plane's radio
--    altimeter below 2,500 ft; the rising runway moves with that pilot's
--    radio altitude (ra/capt/value, fo/value);
--  - the amber RA flag shows where the digits are when none of that pilot's
--    radio altimeters works (ra/capt/flag, fo/flag; ATA34_2 p.96; the image
--    by make_pfd_ra_images.ps1);
--  - the first officer's PFD reads its own radio altitude
--    (efis/radio_altitude_fo) and DH alert (dec_height/display_status_fo,
--    radio_alt/display_status_fo) instead of the captain's;
--  - DH set to 0 shows (FCOM p.981: not shown below 0 ft);
--  - PULL UP and WINDSHEAR are the GPWS's (laminar/B747/gpws/pull_up,
--    windshear) instead of X-Plane's annunciators.
-- X-Plane takes one condition (one dataref, a value or a range) for each
-- instrument or group (ARCHITECTURE.md §5); every condition changed here is
-- the only one of its block. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_ra_gpws.lua <acf in> <acf out>")
local RA, GP = "laminar/B747/ra/", "laminar/B747/gpws/"
local XP_RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_"
local XP_BUG = "sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_"
-- the RA flag's centre from the digits' POS: the digits are drawn round their POS
-- (checked in X-Plane, 2026-10-25: s43_gpws)
local FLAG_DX, FLAG_DY = 2, -3

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local changes = 0
local function note(what) changes = changes + 1; print(what) end
local function f6(v) return string.format("%.6f", v) end
local function plain(s) return (s:gsub("%p", "%%%0")) end
local function group_end(s)
    local ind = lines[s]:match("^(%s*)GROUP ")
    for i = s + 1, #lines do
        if lines[i] == ind .. "END_GROUP" then return i end
    end
    error("no END_GROUP for line " .. s)
end
local function find(a, b, pattern, what)
    for i = a, b do
        if lines[i]:match(pattern) then return i end
    end
    error("no " .. what .. " in lines " .. a .. "-" .. b)
end
local function block_end(s)
    local e = s
    while lines[e + 1] ~= "" do e = e + 1 end
    return e
end
local function pos_of(s)
    local x, y = lines[find(s, block_end(s), "^%s*POS ", "POS")]:match("POS ([-%d.]+) ([-%d.]+)")
    return tonumber(x), tonumber(y)
end
local function ind(i) return lines[i]:match("^(%s*)") end
-- a gen_rotary copied from a template block, with a new name, position, image and conditions
local function rotary(t, indent, name, x, y, image, conds)
    local sub = indent .. "  "
    local out = {indent .. "gen_rotary " .. name}
    for k = t + 1, block_end(t) do
        local l = lines[k]:gsub("^%s*", "")
        if l:match("^POS ") then out[#out + 1] = sub .. "POS " .. f6(x) .. " " .. f6(y)
        elseif l:match("^IMAGE ") then out[#out + 1] = sub .. "IMAGE " .. image
        elseif l:match("^DATAREF") then
            out[#out + 1] = sub .. "DATAREF "
            for _, c in ipairs(conds) do out[#out + 1] = sub .. c end
        elseif not l:match("^SHOW_") then out[#out + 1] = sub .. l end
    end
    out[#out + 1] = ""
    return out
end
-- replace a line's dataref (the whole name at the end of the line); count it
local function swap(i, from, to)
    local head = lines[i]:match("^(.- )" .. plain(from) .. "$")
    assert(head, "line " .. i .. " does not end with " .. from)
    lines[i] = head .. to
end

local pfds = {}
for i, l in ipairs(lines) do
    if l == "GROUP Captain PFD" then pfds[#pfds + 1] = {s = i, side = "capt"}
    elseif l == "GROUP First Officer PFD" then pfds[#pfds + 1] = {s = i, side = "fo"} end
end
assert(#pfds == 4, "expected four PFD groups, found " .. #pfds)
for k = 1, #lines do assert(not lines[k]:find(RA .. "capt/show", 1, true), "the PFDs read the radio altimeters already") end

for p = #pfds, 1, -1 do
    local s, side = pfds[p].s, pfds[p].side
    local e = group_end(s)
    local sfx = side == "capt" and "" or " 2"
    local xp = side == "capt" and "pilot" or "copilot"
    local who = side == "capt" and "captain" or "first officer"
    print(string.format("== the %s's PFD, lines %d-%d", who, s, e))

    -- the rising runway: shown and moved by that pilot's radio altimeter
    local rwy = find(s, e, "^%s*GROUP Rsng Rwy Offset" .. plain(sfx) .. "$", "GROUP Rsng Rwy Offset")
    local rwy_show = find(rwy + 1, rwy + 1, "^%s*SHOW_LESS 2500%.000000 " .. plain(XP_RA .. xp) .. "$", "its RA condition")
    lines[rwy_show] = ind(rwy_show) .. "SHOW_EQUAL 1.000000 " .. RA .. side .. "/show"
    local rwy_d = find(rwy, group_end(rwy), "^%s*DATAREF " .. plain(XP_RA .. xp) .. "$", "the rising runway's DATAREF")
    swap(rwy_d, XP_RA .. xp, RA .. side .. "/value")
    note(string.format("  lines %d, %d: the rising runway shown by %s/show, moved by %s/value", rwy_show, rwy_d, RA .. side, RA .. side))

    -- DH 0 shown
    local dh = find(s, e, "^%s*GROUP Decision Height" .. plain(sfx) .. "$", "GROUP Decision Height")
    local dh_low = find(dh + 1, dh + 2, "^%s*SHOW_GREATER 0%.000000 " .. plain(XP_BUG .. xp) .. "$", "its low limit")
    lines[dh_low] = ind(dh_low) .. "SHOW_GREATER -0.500000 " .. XP_BUG .. xp
    note(string.format("  line %d: DH shown from 0 ft (was above 0)", dh_low))

    -- the radio altitude's digits
    local rag = find(s, e, "^%s*GROUP Radio Altitude" .. plain(sfx) .. "$", "GROUP Radio Altitude")
    local rag_e = group_end(rag)
    local rag_show = find(rag + 1, rag + 1, "^%s*SHOW_LESS 2500%.000000 " .. plain(XP_RA .. xp) .. "$", "its RA condition")
    lines[rag_show] = ind(rag_show) .. "SHOW_EQUAL 1.000000 " .. RA .. side .. "/show"
    note(string.format("  line %d: the radio altitude shown by %s/show", rag_show, RA .. side))

    -- the first officer's own radio altitude and DH alert
    if side == "fo" then
        local n = {0, 0, 0}
        for i = s, e do
            local l = lines[i]
            if l:match(" laminar/B747/efis/radio_altitude$") then
                swap(i, "laminar/B747/efis/radio_altitude", "laminar/B747/efis/radio_altitude_fo"); n[1] = n[1] + 1
            elseif l:match(" laminar/B747/dec_height/display_status$") then
                swap(i, "laminar/B747/dec_height/display_status", "laminar/B747/dec_height/display_status_fo"); n[2] = n[2] + 1
            elseif l:match(" laminar/B747/radio_alt/display_status$") then
                swap(i, "laminar/B747/radio_alt/display_status", "laminar/B747/radio_alt/display_status_fo"); n[3] = n[3] + 1
            end
        end
        assert(n[1] == 2 and n[2] == 2 and n[3] == 3,
            string.format("expected 2, 2, 3 of the captain's radio altitude and DH alert, found %d, %d, %d", n[1], n[2], n[3]))
        note(string.format("  %d radio altitudes -> efis/radio_altitude_fo, %d + %d DH alerts -> display_status_fo", n[1], n[2], n[3]))
    end

    -- PULL UP and WINDSHEAR
    local np, nw = 0, 0
    for i = s, e do
        if lines[i]:match("^%s*SHOW_EQUAL 1%.000000 sim/cockpit/warnings/annunciators/GPWS$") then
            swap(i, "sim/cockpit/warnings/annunciators/GPWS", GP .. "pull_up"); np = np + 1
        elseif lines[i]:match("^%s*SHOW_EQUAL 1%.000000 sim/cockpit2/annunciators/windshear_warning$") then
            swap(i, "sim/cockpit2/annunciators/windshear_warning", GP .. "windshear"); nw = nw + 1
        end
    end
    assert(np == 1 and nw == 1, string.format("expected one PULL UP and one WINDSHEAR, found %d and %d", np, nw))
    note("  PULL UP -> " .. GP .. "pull_up, WINDSHEAR -> " .. GP .. "windshear")

    -- the RA flag after the radio altitude's group (the lines below move)
    local led = find(rag, rag_e, "^%s*gen_LED LED", "the radio altitude's digits")
    local lx, ly = pos_of(led)
    local irs = find(s, e, "^%s*GROUP %u+ IRS OFF PFD$", "the IRS OFF flags")
    local att = find(irs, group_end(irs), "^%s*gen_rotary ATT X", "the ATT flag")
    local tag = side == "capt" and "CAPT" or "FO"
    local gi = ind(rag)
    local new = {gi .. "GROUP " .. tag .. " RA FLAG" .. sfx, gi .. "  SHOW_EQUAL 1.000000 " .. RA .. side .. "/flag"}
    for _, l in ipairs(rotary(att, gi .. "  ", "RA X " .. tag .. " PFD", lx + FLAG_DX, ly + FLAG_DY,
            "CRT Displays/PFD/Failure Flags/raX", {})) do new[#new + 1] = l end
    new[#new + 1] = gi .. "END_GROUP"
    for k = #new, 1, -1 do table.insert(lines, rag_e + 1, new[k]) end
    note(string.format("  after line %d (%d lines): GROUP %s RA FLAG%s at %.1f, %.1f when %s/flag is 1",
        rag_e, #new, tag, sfx, lx + FLAG_DX, ly + FLAG_DY, RA .. side))
end

f = assert(io.open(dst, "wb"))
f:write(table.concat(lines, nl), nl)
f:close()
print(changes .. " changes")
