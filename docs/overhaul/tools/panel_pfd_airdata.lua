-- Make the custom acf's PFDs show the selected ADC's air data (5-1 step 1b;
-- the panel changes approved 2026-10-23: GAP_ANALYSIS.md §4, DSP-02, DSP-04,
-- DSP-12). Run from the repository root:
--   luajit docs/overhaul/tools/panel_pfd_airdata.lua <acf in> <acf out>
-- It prints every change. In each PFD group (the captain's and the first
-- officer's, each drawn twice: outboard and inboard):
--  - the altitude (X-Plane's altitude_ft_pilot, _copilot) and the Mach
--    (X-Plane's true Mach, machno) become laminar/B747/airdata/alt_capt and
--    mach_capt (alt_fo, mach_fo): the selected ADC's, with that pilot's baro
--    setting (FCOM p.992: barometric altitude from the selected ADC). The
--    first officer's first altitude tape was shown by the captain's altitude.
--  - with that pilot's air data invalid (laminar/B747/airdata/valid_capt,
--    valid_fo 0) the speed display (its tape, bugs, V speeds and Mach), the
--    altitude tape with its background and bugs and the current altitude go,
--    and the amber SPD and ALT flags show on the tapes (FCOM p.1000; images
--    by make_pfd_airdata_images.ps1). The MACH flag is not drawn: the SPD flag
--    inhibits it and the ADCs fail whole.
--  - the altitude alert (FCOM p.992, p.1559): a highlighted white box round
--    the selected altitude and the current altitude from 900 to 300 ft before
--    the selected altitude (laminar/B747/airdata/alt_advise), an amber one
--    round the current altitude when departing it by 300 to 900 ft
--    (alt_alert).
-- X-Plane takes one condition (one dataref, a value or a range) for each
-- instrument or group: with two, the last one counts (tried 2026-10-25). So
-- the current altitude's boxes are in a group shown with the air data valid,
-- each box with its own condition. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_airdata.lua <acf in> <acf out>")
local AD = "laminar/B747/airdata/"
-- the selected altitude's box: centred over the tape, round the feet digits
local SEL_BOX_DY = 268            -- above the altitude tape's centre (its POS)

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

-- a group's END_GROUP: the next line with the group's indentation
local function group_end(s)
    local ind = lines[s]:match("^(%s*)GROUP ")
    for i = s + 1, #lines do
        if lines[i] == ind .. "END_GROUP" then return i end
    end
    error("no END_GROUP for line " .. s)
end
-- the first line in [a, b] matching a pattern
local function find(a, b, pattern, what)
    for i = a, b do
        if lines[i]:match(pattern) then return i end
    end
    error("no " .. what .. " in lines " .. a .. "-" .. b)
end
-- an instrument block: its first line to the line before the next blank
local function block_end(s)
    local e = s
    while lines[e + 1] ~= "" do e = e + 1 end
    return e
end
local function pos_of(s)
    local x, y = lines[find(s, block_end(s), "^%s*POS ", "POS")]:match("POS ([-%d.]+) ([-%d.]+)")
    return tonumber(x), tonumber(y)
end

-- the PFD groups, from the last so that the insertions keep the earlier lines
local pfds = {}
for i, l in ipairs(lines) do
    if l == "GROUP Captain PFD" then pfds[#pfds + 1] = {s = i, side = "capt"}
    elseif l == "GROUP First Officer PFD" then pfds[#pfds + 1] = {s = i, side = "fo"} end
end
assert(#pfds == 4, "expected four PFD groups, found " .. #pfds)
for k = 1, #lines do assert(not lines[k]:find(AD .. "alt_capt", 1, true), "the PFDs read the air data already") end

-- new lines are inserted after line i (from the bottom up within a PFD)
local function insert_after(i, new)
    for k = #new, 1, -1 do table.insert(lines, i + 1, new[k]) end
end
-- a gen_rotary copied from a template block, with a new name, position, image and conditions
local function rotary(t, ind, name, x, y, image, conds)
    local sub = ind .. "  "
    local out = {ind .. "gen_rotary " .. name}
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

for p = #pfds, 1, -1 do
    local s, side = pfds[p].s, pfds[p].side
    local e = group_end(s)
    local sfx = side == "capt" and "" or " 2"
    local valid = AD .. "valid_" .. side
    local who = side == "capt" and "captain" or "first officer"
    print(string.format("== the %s's PFD, lines %d-%d", who, s, e))

    -- the altitude and the Mach (in place: the lines do not move)
    local alt_from = side == "capt" and {"sim/cockpit2/gauges/indicators/altitude_ft_pilot"}
        or {"sim/cockpit2/gauges/indicators/altitude_ft_copilot", "sim/cockpit2/gauges/indicators/altitude_ft_pilot"}
    local n_alt, n_mach = 0, 0
    for i = s, e do
        local l = lines[i]
        local head, name = l:match("^(%s*DATAREF )(%S+)$")
        if not head then head, name = l:match("^(%s*SHOW_%u+ [-%d.]+ )(%S+)$") end
        if head then
            for _, from in ipairs(alt_from) do
                if name == from then
                    if side == "fo" and from:find("_pilot$") then
                        note(string.format("  line %d: %s -> alt_fo (a first officer's tape shown by the captain's altitude)", i, l:gsub("^%s*", "")))
                    end
                    lines[i] = head .. AD .. "alt_" .. side
                    n_alt = n_alt + 1
                end
            end
            if name == "sim/flightmodel/misc/machno" then
                lines[i] = head .. AD .. "mach_" .. side
                n_mach = n_mach + 1
            end
        end
    end
    for i = s, e do
        assert(not lines[i]:find("altitude_ft_", 1, true) and not lines[i]:find("machno", 1, true),
            "X-Plane's altitude or Mach left at line " .. i)
    end
    assert(n_alt == 54 and n_mach == 2, string.format("expected 54 altitudes and 2 Machs, found %d and %d", n_alt, n_mach))
    note(string.format("  %d altitudes -> %salt_%s, %d Machs -> %smach_%s", n_alt, AD, side, n_mach, AD, side))

    -- the places and the instruments to copy
    local asi = find(s, e, "^%s*GROUP Airspeed Display" .. plain(sfx) .. "$", "GROUP Airspeed Display")
    local asi_bg = find(asi, group_end(asi), "^%s*gen_rotary Tape Bkgnd", "the speed tape's background")
    local asi_x, asi_y = pos_of(asi_bg)
    local altd = find(s, e, "^%s*GROUP Altimeter Display" .. plain(sfx) .. "$", "GROUP Altimeter Display")
    local altd_e = group_end(altd)
    local alt_bg = find(altd, altd_e, "^%s*gen_rotary Altimeter Bkgnd", "the altitude tape's background")
    local alt_x, alt_y = pos_of(alt_bg)
    local tapes = find(altd, altd_e, "^%s*GROUP Tapes" .. plain(sfx) .. "$", "GROUP Tapes")
    local offset = find(altd, altd_e, "^%s*GROUP Altitude Offset" .. plain(sfx) .. "$", "GROUP Altitude Offset")
    local roll = find(altd, altd_e, "^%s*GROUP Rolling Display" .. plain(sfx) .. "$", "the altitude's GROUP Rolling Display")
    local roll_e = group_end(roll)
    local wnd = find(roll, roll_e, "^%s*gen_rotary Crnt Alt Window" .. plain(sfx) .. "$", "the current altitude window")
    local wnd_x, wnd_y = pos_of(wnd)
    local sel = find(altd, altd_e, "^%s*GROUP Selected Altitude" .. plain(sfx) .. "$", "GROUP Selected Altitude")
    local sel_e = group_end(sel)
    local irs = find(s, e, "^%s*GROUP %u+ IRS OFF PFD$", "the IRS OFF flags")
    local irs_e = group_end(irs)
    local att = find(irs, irs_e, "^%s*gen_rotary ATT X", "the ATT flag")
    local bg_d = find(alt_bg, block_end(alt_bg), "^%s*DATAREF", "the background's DATAREF")
    local function ind(i) return lines[i]:match("^(%s*)") end

    -- the insertions, each after a line of the unchanged group
    local ops = {}
    local function op(at, new, msg) ops[#ops + 1] = {at = at, new = new, msg = msg} end
    local function cat(...)
        local out = {}
        for _, t in ipairs({...}) do for _, l in ipairs(t) do out[#out + 1] = l end end
        return out
    end
    local tag = side == "capt" and "CAPT" or "FO"
    local gi = ind(irs)
    op(irs_e, cat({gi .. "GROUP " .. tag .. " AIR DATA FLAGS", gi .. "  SHOW_EQUAL 0.000000 " .. valid},
        rotary(att, gi .. "  ", "SPD X " .. tag .. " PFD", asi_x, asi_y, "CRT Displays/PFD/Failure Flags/spdX", {}),
        rotary(att, gi .. "  ", "ALT X " .. tag .. " PFD", alt_x, alt_y, "CRT Displays/PFD/Failure Flags/altX", {}),
        {gi .. "END_GROUP"}),
        string.format("GROUP %s AIR DATA FLAGS: SPD at %.1f, %.1f and ALT at %.1f, %.1f when %s is 0",
            tag, asi_x, asi_y, alt_x, alt_y, valid))
    local bi = ind(roll)
    op(roll_e, cat({bi .. "GROUP Crnt Alt Boxes" .. sfx, bi .. "  SHOW_EQUAL 1.000000 " .. valid},
        rotary(wnd, bi .. "  ", "Crnt Alt Box White" .. sfx, wnd_x, wnd_y,
            "CRT Displays/PFD/Altimeter/ALTrollingDigits/ALTcrntWndwHiW",
            {"SHOW_EQUAL 1.000000 " .. AD .. "alt_advise"}),
        rotary(wnd, bi .. "  ", "Crnt Alt Box Amber" .. sfx, wnd_x, wnd_y,
            "CRT Displays/PFD/Altimeter/ALTrollingDigits/ALTcrntWndwHiA",
            {"SHOW_EQUAL 1.000000 " .. AD .. "alt_alert"}),
        {bi .. "END_GROUP"}),
        string.format("GROUP Crnt Alt Boxes%s (when %s is 1): the current altitude's white box (alt_advise) and amber box (alt_alert) at %.1f, %.1f",
            sfx, valid, wnd_x, wnd_y))
    op(sel_e, rotary(wnd, ind(sel), "Sel Alt Box White" .. sfx, alt_x, alt_y + SEL_BOX_DY,
            "CRT Displays/PFD/Altimeter/SelAltBoxHiW", {"SHOW_EQUAL 1.000000 " .. AD .. "alt_advise"}),
        string.format("the selected altitude's white box (alt_advise) at %.1f, %.1f", alt_x, alt_y + SEL_BOX_DY))
    for _, g in ipairs({roll, offset, tapes, asi}) do
        op(g, {ind(g) .. "  SHOW_EQUAL 1.000000 " .. valid},
            string.format("%s shown when %s is 1", lines[g]:gsub("^%s*", ""), valid))
    end
    op(bg_d, {ind(bg_d) .. "SHOW_EQUAL 1.000000 " .. valid},
        string.format("the altitude tape's background shown when %s is 1", valid))

    table.sort(ops, function(a, b) return a.at > b.at end)
    for k = 2, #ops do assert(ops[k].at ~= ops[k - 1].at, "two insertions after line " .. ops[k].at) end
    for _, o in ipairs(ops) do
        insert_after(o.at, o.new)
        note(string.format("  after line %d (%d lines): %s", o.at, #o.new, o.msg))
    end
end

f = assert(io.open(dst, "wb"))
f:write(table.concat(lines, nl), nl)
f:close()
print(changes .. " changes")
