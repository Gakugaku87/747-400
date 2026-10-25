-- The custom acf's ND APP mode (5-2 step 5b; panel changes allowed anywhere
-- since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_nd_app.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, APP and APP CTR
-- follow the ILS receiver of the EIU in use (FCOM p.1044: the PFD's
-- laminar/B747/pfd/<side>/ils_rx, 1 L, 2 C, 3 R) and the display glue's
-- laminar/B747/nd/<side>/... (B747.60.pfd_ils_model.lua):
--  - the course pointer, deviation bar and scale (centred and expanded):
--    NAV1's group for ILS L and C, NAV2's for ILS R (before: the NAV source
--    selector's FMC L and FMC R positions, DSP-03); the pointer on nd/<side>/
--    crs 2 (gone without a runway course), the bars filled and hollow on
--    loc_ptr 1 and 2 (filled within 2 1/2 dots: FCOM p.1144; before X-Plane's
--    signal and 2.3 dots), the scale on loc_scale; the bars' deflection
--    121.25 pixels for X-Plane's full 2.5 dots, the scale's 48.5 pixels a dot
--    (before 115);
--  - the glideslope (centred and expanded): the pointers on nd/<side>/gs_ptr
--    and that side's deviation pfd/<side>/gs_dots (before: the HSI's, the
--    Captain's expanded one the copilot's), 48.5 pixels a dot like the scale
--    (before 97 pixels at 2.5 dots: the 2-dot mark) without CLIP, the scale
--    on gs_scale; the G/S flag where the scale is and the LOC flag left of
--    the airplane symbol (centred) or below it (expanded: estimate), from
--    ATA31 p.21, ATA34_1 p.477 and FCOM p.1034, on gs_flag and loc_flag;
--  - the reference receiver block: ILS L, C (new) or R on ils_rx; one
--    frequency or identifier text on nd/<side>/ils_ref (before: two pairs of
--    items on the wrong flags, ILS R's frequency from VOR L); the course on
--    crs_deg (the CDU's) or dashes (nd/dashes), both on crs; the DME in
--    green (FCOM p.1144) on dme_nm, "DME ---" or the DME flag on dme.
-- The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_app.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local DOT_PX = 48.5                 -- the localizer and glideslope scales' dots (EFIS/Maps/Expanded/LOCscale, HrznGSscale)
local FULL_PX = DOT_PX * 2.5        -- X-Plane's full deflection, 2.5 dots
local SYMBOL_HALF_W = 39            -- the centred airplane symbol (78 wide)
local TRIANGLE_HALF_H = 26          -- the expanded airplane triangle (52 high)
local FLAG_W, FLAG_H = 70, 30       -- the LOC flag
local GAP = 4
local IMG_FLAGS = "CRT Displays/PFD/Failure Flags/"

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
-- a direct child by name, with or without the Captain's " 2" (and the
-- stock's stray spaces)
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
-- one SHOW line: the first replaced, the others dropped; an item without one
-- gets it after its DATAREF line (a group after its first property line)
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
-- a copy of a gen_ item at a depth: header, and properties replaced
-- (POS, IMAGE, DATAREF as given), its SHOW lines replaced by one (or none)
local function copy(i, depth, header, mods, show)
    local n = ind(i)
    local pre = string.rep(" ", depth)
    local o = {pre .. header}
    for j = i + 1, gen_end(i) do
        local l = lines[j]
        local body = l:match("%S") and l:sub(n + 1) or ""
        local key = body:match("^  (%u[%u_]*)")
        if key == "SHOW_LESS" or key == "SHOW_EQUAL" or key == "SHOW_GREATER" then
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
    return o
end

local NDS = {{top = "Captain ND", side = "capt"}, {top = "First Officer ND", side = "fo"}}
for _, d in ipairs(NDS) do
    local top
    for i, l in ipairs(lines) do if l == "GROUP " .. d.top then top = i break end end
    assert(top, "no " .. d.top)
    local s = d.side
    local P, N = "laminar/B747/pfd/" .. s .. "/", "laminar/B747/nd/" .. s .. "/"
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

    -- the localizer: course pointer, bars and scale, centred and expanded
    local function ils_groups(pointers, course, filled)
        local l, r = child(pointers, "GROUP ILS L"), child(pointers, "GROUP ILS R")
        set_show(l, "SHOW_LESS 2.500000 " .. P .. "ils_rx")
        set_show(r, "SHOW_GREATER 2.500000 " .. P .. "ils_rx")
        for _, g in ipairs({l, r}) do
            set_show(child(g, "gen_needle " .. course), "SHOW_EQUAL 2.000000 " .. N .. "crs")
            local h, fl = child(g, "gen_needle CDI:hollow"), child(g, "gen_needle " .. filled)
            set_show(h, "SHOW_EQUAL 2.000000 " .. N .. "loc_ptr")
            set_prop(h, "DEFLECT_PIX", string.format("%.6f", FULL_PX))
            set_show(fl, "SHOW_EQUAL 1.000000 " .. N .. "loc_ptr")
            set_prop(fl, "DEFLECT_PIX", string.format("%.6f", FULL_PX))
            set_show(child(g, "gen_needle Scale"), "SHOW_GREATER 0.500000 " .. N .. "loc_scale")
        end
        return l
    end
    local cen, exp = found["Map:Centered"], found["Map:Expanded"]
    local cl = ils_groups(child(child(cen, "GROUP Hdg Ofst:APP/VOR/MA"), "GROUP ILS Pointers"), "Course Ptr", "CDI:filled")
    ils_groups(child(child(exp, "GROUP Heading Offset"), "GROUP ILS Pointer"), "Course Pointer", "CDI_filled")
    local cx, cy = pos(child(cl, "gen_needle Scale"))
    local tx, ty = pos(child(exp, "gen_rotary Aircraft Triangle"))

    -- the glideslope, and the flags in its group (APP only, not turning)
    local function glideslope(gs, loc_at)
        local p = child(gs, "GROUP Pointer")
        set_show(p, "SHOW_GREATER 0.500000 " .. N .. "gs_ptr")
        for _, v in ipairs({{"GROUP Pointer VDEF > 2.3", 2}, {"GROUP Pointer VDEF <= 2.3", 1}}) do
            local g = child(p, v[1])
            set_show(g, string.format("SHOW_EQUAL %.6f %sgs_ptr", v[2], N))
            local ptr = children(g)[1]
            assert(lines[ptr]:match("gen_pointer"), "no pointer in " .. name(g))
            set_prop(ptr, "DATAREF", P .. "gs_dots")
            local frames = 0
            for j = ptr + 1, gen_end(ptr) do
                local a, b, rest = lines[j]:match("^(%s*KEY_FRAME [%d.%-]+ )([%d.%-]+)(.*)$")
                if a and math.abs(math.abs(tonumber(b)) - 97) < 0.01 then
                    replace[j] = a .. string.format("%.6f", (tonumber(b) > 0 and 1 or -1) * FULL_PX) .. rest
                    frames = frames + 1
                elseif lines[j]:match("^%s*CLIP%s*$") then
                    replace[j] = false
                end
            end
            assert(frames == 4, frames .. " keyframes at 97 in " .. name(ptr))
            note(ptr, string.format("travel %.2f px at 2.5 dots, no CLIP", FULL_PX))
        end
        local scale = child(gs, "gen_rotary Scale")
        set_show(scale, "SHOW_GREATER 0.500000 " .. N .. "gs_scale")
        local gx, gy = pos(scale)
        local block = copy(scale, ind(scale), "gen_rotary GS X ND" .. sfx,
            {POS = string.format("%.6f %.6f", gx, gy), IMAGE = IMG_FLAGS .. "gsX"}, "SHOW_GREATER 0.500000 " .. N .. "gs_flag")
        for _, l in ipairs(copy(scale, ind(scale), "gen_rotary LOC X ND" .. sfx,
            {POS = string.format("%.6f %.6f", loc_at[1], loc_at[2]), IMAGE = IMG_FLAGS .. "locX"},
            "SHOW_GREATER 0.500000 " .. N .. "loc_flag")) do block[#block + 1] = l end
        after[gen_end(scale)] = block
        changes = changes + 2
        print(string.format("  + GS X ND%s at %.1f %.1f, LOC X ND%s at %.1f %.1f", sfx, gx, gy, sfx, loc_at[1], loc_at[2]))
    end
    local function gs_child(map)
        for _, j in ipairs(children(map)) do
            if name(j):match("^GROUP Glideslope") then return j end
        end
        error("no Glideslope in " .. name(map))
    end
    glideslope(gs_child(cen), {cx - SYMBOL_HALF_W - GAP - FLAG_W / 2, cy})
    glideslope(gs_child(exp), {tx, ty - TRIANGLE_HALF_H - GAP - FLAG_H / 2})

    -- the reference receiver block, rebuilt from the stock items
    local rec = child(found["Radio Data"], "GROUP Sel Rec ILS")
    local crs = child(rec, "gen_rotary Background CRS")
    set_show(crs, "SHOW_GREATER 0.500000 " .. N .. "crs")
    local gl, gr = child(rec, "GROUP ILS L"), child(rec, "GROUP ILS R")
    local depth = ind(crs)
    local label_l, label_r = child(gl, "gen_rotary Background ILS L"), child(gr, "gen_rotary Background ILS R")
    local id, crs_led = child(gl, "gen_text ID TEXT"), child(gl, "gen_LED CRS LED")
    local dme, dme_x, dme_led = child(gl, "gen_rotary Background DME"), child(gl, "gen_rotary Background DME X"),
        child(gl, "gen_LED DME LED")
    local lx, ly = pos(crs_led)
    local block = {}
    local function add(t) for _, l in ipairs(t) do block[#block + 1] = l end end
    add(copy(label_l, depth, "gen_rotary Background  ILS L" .. sfx, {}, "SHOW_EQUAL 1.000000 " .. P .. "ils_rx"))
    add(copy(label_l, depth, "gen_rotary Background  ILS C" .. sfx, {IMAGE = "CRT Displays/ND/Ref Rcvr/ils_C_bkgnd"},
        "SHOW_EQUAL 2.000000 " .. P .. "ils_rx"))
    add(copy(label_r, depth, "gen_rotary Background  ILS R" .. sfx, {}, "SHOW_EQUAL 3.000000 " .. P .. "ils_rx"))
    add(copy(id, depth, "gen_text ID TEXT" .. sfx, {DATAREF = N .. "ils_ref[0]"}, nil))
    add(copy(crs_led, depth, "gen_LED CRS LED" .. sfx, {DATAREF = N .. "crs_deg"}, "SHOW_EQUAL 2.000000 " .. N .. "crs"))
    -- the course dashes: the white text where the LED's three digits are
    -- (their left edge 8 pixels left of the LED's position: from a photo)
    add(copy(id, depth, "gen_text CRS Dashes" .. sfx,
        {DATAREF = "laminar/B747/nd/dashes[0]", IMAGE = "CRT Displays/TEXT/TXT.1.24.white",
         POS = string.format("%.6f %.6f", lx - 8, ly)}, "SHOW_EQUAL 1.000000 " .. N .. "crs"))
    add(copy(dme, depth, "gen_rotary Background  DME" .. sfx, {IMAGE = "CRT Displays/ND/dme_bkgnd"},
        "SHOW_EQUAL 1.000000 " .. N .. "dme"))
    add(copy(dme_led, depth, "gen_LED DME LED" .. sfx, {DATAREF = N .. "dme_nm", IMAGE = "CRT Displays/LED/LED_8.21R.xxx#00.green"},
        "SHOW_EQUAL 1.000000 " .. N .. "dme"))
    add(copy(dme_x, depth, "gen_rotary Background  DME X" .. sfx, {}, "SHOW_EQUAL 0.000000 " .. N .. "dme"))
    add(copy(dme, depth, "gen_rotary DME Flag" .. sfx, {IMAGE = "CRT Displays/ND/dmeX_bkgnd"}, "SHOW_EQUAL 2.000000 " .. N .. "dme"))
    after[gen_end(crs)] = block
    for _, g in ipairs({gl, gr}) do
        for j = g, group_end(g) do replace[j] = false end
    end
    changes = changes + 1
    print(string.format("  Sel Rec ILS%s rebuilt: ILS L, C, R labels, the text on %sils_ref, the course on crs_deg or dashes, the DME on dme_nm, dashes or flag",
        sfx, N))
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
