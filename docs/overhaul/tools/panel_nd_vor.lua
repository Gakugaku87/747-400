-- The custom acf's ND VOR mode (5-2 step 5b; panel changes allowed anywhere
-- since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_vor.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, VOR and VOR CTR
-- follow the display glue's reference VOR (laminar/B747/nd/<side>/vor_rx:
-- 1 VOR L, the Captain's; 2 VOR R, the F/O's) and its laminar/B747/nd/
-- <side>/... (B747.60.nd_model.lua):
--  - the course pointer, deviation bar and scale (centred and expanded):
--    VOR L's group or VOR R's on vor_rx (before: the NAV source selector's
--    CDU positions, DSP-03); the pointer on vor_crs 2 (gone while
--    autotuned), the bar (hollow: FCOM p.1144 fills only the ILS's) and the
--    scale on vor_dev (before: a SHOW line without a dataref, or none); the
--    bar's deflection 121.25 pixels at X-Plane's full 2.5 dots (before 115);
--  - the VOR CTR TO/FROM pointer (FCOM p.1144: an open triangle near the
--    airplane symbol), new, on the course line ahead (TO) or behind (FROM)
--    on to_from 1 and 2 (images from make_nd_vor_images.ps1);
--  - the VOR L and VOR R flags (FCOM p.1034), new, in a VOR-mode group of
--    the centred and the expanded map: above the airplane symbol (centred)
--    or below it (expanded) as ATA34_1 p.361 draws them, on vor_flag 1 and 2;
--  - the reference receiver block rebuilt as APP's (panel_nd_app.lua):
--    VOR L or R on vor_rx, the frequency or identifier on vor_ref (before:
--    two pairs of items on the wrong flags), the course on vor_crs_deg or
--    dashes (vor_crs), the DME in green, its dashes or flag (vor_dme), and
--    the TO/FROM words at the lower right (FCOM p.1024, p.1145; ATA34_1
--    p.357) on to_from.
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_vor.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local FULL_PX = 48.5 * 2.5          -- X-Plane's full deflection on the scale's dots (as panel_nd_app.lua)
local TRIANGLE_HALF_H = 26          -- the expanded airplane triangle (52 high)
local FLAG_H = 30
local GAP = 4
local FLAG_ABOVE = 62               -- the centred VOR flag above the airplane symbol (ATA34_1 p.361, scaled)
local TOFROM_DX, TOFROM_DY = -90, -542 -- the TO/FROM words from the CRS label (FCOM p.1024: 3/4 across, 6/7 down)

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
        local n = name(j):gsub("%s+", " ")
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
local function prop_line(i, key)
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*" .. key .. " ") or lines[j]:match("^%s*" .. key .. "$") then return j end
    end
end
local function pos(i)
    local x, y = lines[assert(prop_line(i, "POS"), "no POS in " .. name(i))]:match("^%s*POS ([%d.%-]+) ([%d.%-]+)")
    return tonumber(x), tonumber(y)
end

local replace, after = {}, {}
local changes = 0
local function note(i, what)
    changes = changes + 1
    print(string.format("  %s: %s", name(i), what))
end
local function set_show(i, show)
    local first
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then
            if first then replace[j] = false else first = j; replace[j] = string.rep(" ", ind(i) + 2) .. show end
        end
    end
    if not first then
        local d = prop_line(i, "DATAREF") or props(i)[1]
        assert(not after[d], "two insertions after line " .. d)
        after[d] = {string.rep(" ", ind(i) + 2) .. show}
    end
    note(i, show)
end
local function set_prop(i, key, value)
    local j = assert(prop_line(i, key), "no " .. key .. " in " .. name(i))
    replace[j] = string.rep(" ", ind(i) + 2) .. key .. " " .. value
    note(i, key .. " " .. value)
end
-- a copy of a gen_ item at a depth: header, properties replaced (mods by
-- key; false drops the line), its SHOW lines replaced by one (or none);
-- frames: replacement KEY_FRAME lines in order
local function copy(i, depth, header, mods, show, frames)
    local n = ind(i)
    local pre = string.rep(" ", depth)
    local o = {pre .. header}
    local k = 0
    for j = i + 1, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        local key = body:match("^  (%u[%u_]*)")
        if key == "SHOW_LESS" or key == "SHOW_EQUAL" or key == "SHOW_GREATER" then
            -- dropped
        elseif key == "KEY_FRAME" and frames then
            k = k + 1
            o[#o + 1] = pre .. "  " .. assert(frames[k], "more keyframes than given")
        elseif key and mods[key] == false then
            -- dropped
        elseif key and mods[key] then
            o[#o + 1] = pre .. "  " .. key .. " " .. mods[key]
            if key == "DATAREF" and show then o[#o + 1] = pre .. "  " .. show end
        elseif key == "DATAREF" then
            o[#o + 1] = pre .. body
            if show then o[#o + 1] = pre .. "  " .. show end
        else
            o[#o + 1] = body == "" and "" or pre .. body
        end
    end
    assert(not frames or k == #frames, "keyframes: " .. k)
    return o
end
local function xy(x, y) return string.format("%.6f %.6f", x, y) end

local NDS = {{top = "Captain ND", side = "capt"}, {top = "First Officer ND", side = "fo"}}
for _, d in ipairs(NDS) do
    local top
    for i, l in ipairs(lines) do if l == "GROUP " .. d.top then top = i break end end
    assert(top, "no " .. d.top)
    local s = d.side
    local N = "laminar/B747/nd/" .. s .. "/"
    local sfx = s == "capt" and " 2" or ""
    print(string.format("%s (line %d):", d.top, top))
    local found = {}
    for j = top + 1, group_end(top) - 1 do
        local g = lines[j]:match("^%s*GROUP (.-)%s*$")
        if g then
            local base = g:gsub(" 2$", "")
            for _, k in ipairs({"Map:Centered", "Map:Expanded", "Radio Data"}) do
                if base == k then assert(not found[k], "two " .. k); found[k] = j end
            end
        end
    end
    for _, k in ipairs({"Map:Centered", "Map:Expanded", "Radio Data"}) do assert(found[k], "no " .. k) end
    local cen, exp = found["Map:Centered"], found["Map:Expanded"]

    -- the course pointer, bar and scale; VOR CTR's TO/FROM pointer
    local function vor_groups(pointers, course, tofrom)
        local l, r = child(pointers, "GROUP VOR L"), child(pointers, "GROUP VOR R")
        set_show(l, "SHOW_EQUAL 1.000000 " .. N .. "vor_rx")
        set_show(r, "SHOW_EQUAL 2.000000 " .. N .. "vor_rx")
        for _, g in ipairs({l, r}) do
            local c = child(g, "gen_needle " .. course)
            set_show(c, "SHOW_EQUAL 2.000000 " .. N .. "vor_crs")
            local h = child(g, "gen_needle CDI:hollow 2")
            set_show(h, "SHOW_GREATER 0.500000 " .. N .. "vor_dev")
            set_prop(h, "DEFLECT_PIX", string.format("%.6f", FULL_PX))
            local sc = child(g, "gen_needle Scale 2")
            set_show(sc, "SHOW_GREATER 0.500000 " .. N .. "vor_dev")
            if tofrom then
                local img = {IMAGE = "EFIS/Maps/Centered/to_from_ptr", DEFLECT_SRC = false, DEFLECT_PIX = false}
                local block = copy(c, ind(c), "gen_needle TO Ptr" .. sfx, img, "SHOW_EQUAL 1.000000 " .. N .. "to_from")
                for _, x in ipairs(copy(c, ind(c), "gen_needle FROM Ptr" .. sfx, img, "SHOW_EQUAL 2.000000 " .. N .. "to_from",
                    {"KEY_FRAME 0.000000 180.000000 1.000000", "KEY_FRAME 90.000000 270.000000"})) do block[#block + 1] = x end
                after[gen_end(sc)] = block
                changes = changes + 2
                print("  + gen_needle TO Ptr" .. sfx .. ", FROM Ptr" .. sfx .. " (to_from_ptr, the course and the course + 180)")
            end
        end
        return l
    end
    local cl = vor_groups(child(child(cen, "GROUP Hdg Ofst:APP/VOR/MA"), "GROUP VOR Pointers"), "Course Ptr 2", true)
    vor_groups(child(child(exp, "GROUP Heading Offset"), "GROUP VOR Pointer"), "Course Pointer 2", false)
    local cx, cy = pos(child(cl, "gen_needle Scale 2"))
    local tx, ty = pos(child(exp, "gen_rotary Aircraft Triangle"))

    -- the VOR flags: a VOR-mode group after each map's glideslope group,
    -- its items copied from the G/S flag there (panel_nd_app.lua)
    local function flags(map, at)
        local gs
        for _, j in ipairs(children(map)) do
            if name(j):match("^GROUP Glideslope") then gs = j end
        end
        assert(gs, "no Glideslope in " .. name(map))
        local tmpl = child(gs, "gen_rotary GS X ND")
        local gi = ind(gs)
        local pre = string.rep(" ", gi)
        local block = {pre .. "GROUP VOR Flags" .. sfx, pre .. "  SHOW_EQUAL 1.000000 laminar/B747/nd/mode/" .. s .. "/sel_dial_pos",
            pre .. "  HIDE"}
        for k, v in ipairs({{"vorLX", 1}, {"vorRX", 2}}) do
            for _, x in ipairs(copy(tmpl, gi + 2, "gen_rotary VOR" .. (k == 1 and "L" or "R") .. " X ND" .. sfx,
                {POS = xy(at[1], at[2]), IMAGE = "CRT Displays/ND/" .. v[1]},
                string.format("SHOW_EQUAL %.6f %svor_flag", v[2], N))) do block[#block + 1] = x end
        end
        block[#block + 1] = pre .. "END_GROUP"
        after[group_end(gs)] = block
        changes = changes + 1
        print(string.format("  + GROUP VOR Flags%s: VORL X, VORR X at %.1f %.1f", sfx, at[1], at[2]))
    end
    flags(cen, {cx, cy + FLAG_ABOVE})
    flags(exp, {tx, ty - TRIANGLE_HALF_H - GAP - FLAG_H / 2})

    -- the reference receiver block, rebuilt
    local rec = child(found["Radio Data"], "GROUP Sel Rec VOR")
    local crs = child(rec, "gen_rotary Background CRS")
    set_show(crs, "SHOW_GREATER 0.500000 " .. N .. "vor_crs")
    local gl, gr = child(rec, "GROUP VOR L"), child(rec, "GROUP VOR R")
    local depth = ind(crs)
    local label_l, label_r = child(gl, "gen_rotary Background VOR L"), child(gr, "gen_rotary Background VOR R")
    local id, crs_led = child(gl, "gen_text ID TEXT"), child(gl, "gen_LED CRS LED")
    local dme, dme_x, dme_led = child(gl, "gen_rotary Background DME"), child(gl, "gen_rotary Background DME x"),
        child(gl, "gen_LED DME LED")
    local lx, ly = pos(crs_led)
    local kx, ky = pos(crs)
    local block = {}
    local function add(t) for _, x in ipairs(t) do block[#block + 1] = x end end
    add(copy(label_l, depth, "gen_rotary Background  VOR L" .. sfx, {}, "SHOW_EQUAL 1.000000 " .. N .. "vor_rx"))
    add(copy(label_r, depth, "gen_rotary Background  VOR R" .. sfx, {}, "SHOW_EQUAL 2.000000 " .. N .. "vor_rx"))
    add(copy(id, depth, "gen_text ID TEXT" .. sfx, {DATAREF = N .. "vor_ref[0]"}, nil))
    add(copy(crs_led, depth, "gen_LED CRS LED" .. sfx, {DATAREF = N .. "vor_crs_deg"}, "SHOW_EQUAL 2.000000 " .. N .. "vor_crs"))
    add(copy(id, depth, "gen_text CRS Dashes" .. sfx,
        {DATAREF = "laminar/B747/nd/dashes[0]", IMAGE = "CRT Displays/TEXT/TXT.1.24.white", POS = xy(lx - 8, ly)},
        "SHOW_EQUAL 1.000000 " .. N .. "vor_crs"))
    add(copy(dme, depth, "gen_rotary Background  DME" .. sfx, {IMAGE = "CRT Displays/ND/dme_bkgnd"},
        "SHOW_EQUAL 1.000000 " .. N .. "vor_dme"))
    add(copy(dme_led, depth, "gen_LED DME LED" .. sfx, {DATAREF = N .. "vor_dme_nm", IMAGE = "CRT Displays/LED/LED_8.21R.xxx#00.green"},
        "SHOW_EQUAL 1.000000 " .. N .. "vor_dme"))
    add(copy(dme_x, depth, "gen_rotary Background  DME X" .. sfx, {}, "SHOW_EQUAL 0.000000 " .. N .. "vor_dme"))
    add(copy(dme, depth, "gen_rotary DME Flag" .. sfx, {IMAGE = "CRT Displays/ND/dmeX_bkgnd"}, "SHOW_EQUAL 2.000000 " .. N .. "vor_dme"))
    add(copy(crs, depth, "gen_rotary TO Label" .. sfx, {IMAGE = "CRT Displays/ND/Ref Rcvr/to_lbl", POS = xy(kx + TOFROM_DX, ky + TOFROM_DY)},
        "SHOW_EQUAL 1.000000 " .. N .. "to_from"))
    add(copy(crs, depth, "gen_rotary FROM Label" .. sfx, {IMAGE = "CRT Displays/ND/Ref Rcvr/from_lbl", POS = xy(kx + TOFROM_DX, ky + TOFROM_DY)},
        "SHOW_EQUAL 2.000000 " .. N .. "to_from"))
    after[gen_end(crs)] = block
    for _, g in ipairs({gl, gr}) do
        for j = g, group_end(g) do replace[j] = false end
    end
    changes = changes + 1
    print(string.format("  Sel Rec VOR%s rebuilt: VOR L, R labels, the text on %svor_ref, the course or dashes, the DME, TO/FROM at %.1f %.1f",
        sfx, N, kx + TOFROM_DX, ky + TOFROM_DY))
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
