-- The custom acf's ND bearing pointers and lower corner blocks (5-2 step 5b;
-- panel changes allowed anywhere since 2026-10-25). Run from the repository
-- root:
--   luajit docs/overhaul/tools/panel_nd_brg.lua <acf in> <acf out>
-- It prints every change. In the Captain's and the F/O's ND, from the display
-- glue's laminar/B747/nd/<side>/... and nd/... (B747.60.nd_model.lua):
--  - the VOR and ADF bearing pointers (centred and expanded): VOR L or
--    ADF L on ptr_l 1 and 2, VOR R or ADF R on ptr_r (before: X-Plane's EFIS
--    switch positions alone, so a pointer stayed without a station or with a
--    failed receiver), their direction brg_l and brg_r (with respect to the
--    display's top: before, X-Plane's relative bearings, off by the drift on
--    the track-up map, and the centred VOR pointers read NAV4 and NAV5, the
--    ADF ones a scalar's index 10: DSP-35); the centred group in all modes
--    but PLAN (before only APP and VOR: FCOM p.1040);
--  - the lower corner blocks (the group already APP, VOR and MAP): VOR or
--    ADF on rad_l and rad_r; the receiver's name, or its flag (new VORL,
--    VORR, ADFL, ADFR: FCOM p.1034) on rad_l_flag; one frequency or
--    identifier text on nd/vor_l_ref, vor_r_ref, adf_l_ref, adf_r_ref (before:
--    two items on SHOW lines of which the last hid both; the Freq LEDs
--    removed); the VOR block's DME distance, "DME ---" or the new DMEL and
--    DMER flags on rad_l_dme;
--  - the APP and VOR reference blocks' DME flag (panel_nd_app.lua,
--    panel_nd_vor.lua: the stock's boxed DME) as DMEL on the Captain's ND
--    and DMER on the F/O's (FCOM p.1034; each side's DME: notes/ATA-34.md),
--    over the DME line.
-- Images from make_nd_vor_images.ps1. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_nd_brg.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local DME_FLAG_DX = 25              -- the 70-pixel DME flag over the DME label and distance (the label's centre + 25)

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
local function drop_show(i)
    for _, j in ipairs(props(i)) do
        if lines[j]:match("^%s*SHOW_") then replace[j] = false end
    end
    note(i, "no SHOW")
end
local function set_prop(i, key, value)
    local j = assert(prop_line(i, key), "no " .. key .. " in " .. name(i))
    replace[j] = string.rep(" ", ind(i) + 2) .. key .. " " .. value
    note(i, key .. " " .. value)
end
local function delete(i)
    for j = i, gen_end(i) do replace[j] = false end
    note(i, "removed")
end
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
local function xy(x, y) return string.format("%.6f %.6f", x, y) end

local NDS = {{top = "Captain ND", side = "capt", dme = "dmeLX"}, {top = "First Officer ND", side = "fo", dme = "dmeRX"}}
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
            for _, k in ipairs({"Map:Centered", "Map:Expanded", "Radio Data", "APP/VOR/MAP Mode"}) do
                if base == k then assert(not found[k], "two " .. k); found[k] = j end
            end
        end
    end
    for _, k in ipairs({"Map:Centered", "Map:Expanded", "Radio Data", "APP/VOR/MAP Mode"}) do assert(found[k], "no " .. k) end

    -- the bearing pointers
    local function pointers(g)
        for _, v in ipairs({{"GROUP VOR L", "ptr_l", 1, "brg_l"}, {"GROUP ADF L", "ptr_l", 2, "brg_l"},
                {"GROUP VOR R", "ptr_r", 1, "brg_r"}, {"GROUP ADF R", "ptr_r", 2, "brg_r"}}) do
            local grp = child(g, v[1])
            set_show(grp, string.format("SHOW_EQUAL %.6f %s%s", v[3], N, v[2]))
            local needle = children(grp)[1]
            assert(lines[needle]:match("gen_needle"), "no needle in " .. name(grp))
            local frames = {}
            for j = needle + 1, gen_end(needle) do
                local a, b = lines[j]:match("^%s*KEY_FRAME ([%d.%-]+) ([%d.%-]+)")
                if a then assert(tonumber(a) == tonumber(b), "a keyframe not 1:1 in " .. name(needle)) end
            end
            set_prop(needle, "DATAREF", N .. v[4])
        end
    end
    local cb = child(found["Map:Centered"], "GROUP Bearing Pointers")
    set_show(cb, "SHOW_LESS 2.500000 laminar/B747/nd/mode/" .. s .. "/sel_dial_pos")
    pointers(cb)
    pointers(child(found["Map:Expanded"], "GROUP Bearing Pointers"))

    -- the lower corner blocks
    local corners = found["APP/VOR/MAP Mode"]
    for _, c in ipairs({{"L", "l"}, {"R", "r"}}) do
        local R = "rad_" .. c[2]
        -- VOR
        local g = child(corners, "GROUP VOR " .. c[1])
        set_show(g, "SHOW_EQUAL 1.000000 " .. N .. R)
        local label = child(g, "gen_rotary Background VOR " .. c[1])
        set_show(label, "SHOW_EQUAL 0.000000 " .. N .. R .. "_flag")
        after[gen_end(label)] = copy(label, ind(label), "gen_rotary VOR" .. c[1] .. " Flag" .. sfx,
            {IMAGE = "CRT Displays/ND/vor" .. c[1] .. "X"}, "SHOW_EQUAL 1.000000 " .. N .. R .. "_flag")
        changes = changes + 1
        print("  + gen_rotary VOR" .. c[1] .. " Flag" .. sfx)
        local id = child(g, "gen_text ID TEXT")
        set_prop(id, "DATAREF", "laminar/B747/nd/vor_" .. c[2] .. "_ref[0]")
        drop_show(id)
        delete(child(g, "gen_LED Freq LED"))
        local dme = child(g, "gen_rotary Background DME")
        set_show(dme, "SHOW_EQUAL 1.000000 " .. N .. R .. "_dme")
        set_show(child(g, "gen_LED DME LED"), "SHOW_EQUAL 1.000000 " .. N .. R .. "_dme")
        local dx = child(g, "gen_rotary Background DME X")
        set_show(dx, "SHOW_EQUAL 0.000000 " .. N .. R .. "_dme")
        local mx, my = pos(dme)
        after[gen_end(dx)] = copy(dme, ind(dme), "gen_rotary DME" .. c[1] .. " Flag" .. sfx,
            {IMAGE = "CRT Displays/ND/dme" .. c[1] .. "X", POS = xy(mx + DME_FLAG_DX, my)}, "SHOW_EQUAL 2.000000 " .. N .. R .. "_dme")
        changes = changes + 1
        print("  + gen_rotary DME" .. c[1] .. " Flag" .. sfx)
        -- ADF
        g = child(corners, "GROUP ADF " .. c[1])
        set_show(g, "SHOW_EQUAL 2.000000 " .. N .. R)
        label = child(g, "gen_rotary Background")
        set_show(label, "SHOW_EQUAL 0.000000 " .. N .. R .. "_flag")
        after[gen_end(label)] = copy(label, ind(label), "gen_rotary ADF" .. c[1] .. " Flag" .. sfx,
            {IMAGE = "CRT Displays/ND/adf" .. c[1] .. "X"}, "SHOW_EQUAL 1.000000 " .. N .. R .. "_flag")
        changes = changes + 1
        print("  + gen_rotary ADF" .. c[1] .. " Flag" .. sfx)
        id = child(g, "gen_text ID TEXT")
        set_prop(id, "DATAREF", "laminar/B747/nd/adf_" .. c[2] .. "_ref[0]")
        drop_show(id)
        delete(child(g, "gen_LED Freq LED"))
    end

    -- the APP and VOR reference blocks' DME flag
    for _, blk in ipairs({"GROUP Sel Rec ILS", "GROUP Sel Rec VOR"}) do
        local flag = child(child(found["Radio Data"], blk), "gen_rotary DME Flag")
        local fx, fy = pos(flag)
        set_prop(flag, "IMAGE", "CRT Displays/ND/" .. d.dme)
        set_prop(flag, "POS", xy(fx + DME_FLAG_DX, fy))
    end
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
