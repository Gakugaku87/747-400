-- docs/overhaul/tools/panel_nd_plan_circles.lua (2026-11-05, notes/ATA-31.md §46,
-- ACF_DIFF.md §5): the ND's PLAN pictures (FCOM p.1027-1029) in the custom
-- acf, run once from the repository root on the acf before the change
-- (D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261105_before_nd_plan):
--   luajit docs/overhaul/tools/panel_nd_plan_circles.lua 747-400_custom.acf
local path = arg[1]
local lines = {}
for l in io.lines(path) do lines[#lines + 1] = l end
local changes = {}
local function note(n, old, new) changes[#changes + 1] = string.format("%d: %s  ->  %s", n, old:gsub("^%s+", ""), new:gsub("^%s+", "")) end

local SIDES = {
    {side = "capt", sfx = " 2", x = 335.25, north_x = 635, rheo = 0, bus = 2,
     expa = "GROUP Waypoints CAPT EXPA", north = "gen_rotary North Pointer 2"},
    {side = "fo", sfx = "", x = 1022.25, north_x = 1322, rheo = 3, bus = 4,
     expa = "GROUP Waypoints FO EXPAND", north = "gen_rotary North Pointer"},
}

-- 1. the map's geometry groups follow laminar/B747/nd/<side>/centred
local GEOM = {"GROUP Map:Centered", "GROUP Map:Expanded", "GROUP ND Text Center", "GROUP TCAS Alerts"}
for n, l in ipairs(lines) do
    local side = l:match("laminar/B747/nd/map_center/(%a+)$")
    if side then
        local geom = false
        for k = math.max(1, n - 5), n - 1 do
            for _, g in ipairs(GEOM) do
                if lines[k]:match("^%s*" .. g:gsub("%p", "%%%0")) then geom = true end
            end
        end
        if geom then
            local new = l:gsub("laminar/B747/nd/map_center/" .. side, "laminar/B747/nd/" .. side .. "/centred")
            note(n, l, new)
            lines[n] = new
        end
    end
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function find(text, from, to)
    for n = from or 1, to or #lines do
        if trim(lines[n]) == text then return n end
    end
end

local inserts = {}
for _, s in ipairs(SIDES) do
    -- 2. the expanded active waypoint block in PLAN too (the CRT's PLAN is
    -- expanded: FCOM p.1029's GRH, 0838.4z, 32.5 NM)
    local e = assert(find(s.expa), s.expa)
    local want = "SHOW_EQUAL 2.000000 laminar/B747/nd/mode/" .. s.side .. "/sel_dial_pos"
    assert(trim(lines[e + 1]) == want, "expa show: " .. lines[e + 1])
    local new = lines[e + 1]:gsub("SHOW_EQUAL 2%.000000", "SHOW_GREATER 1.500000")
    note(e + 1, lines[e + 1], new)
    lines[e + 1] = new
    -- 3. the stock's PLN north arrow in the centred group: none (the circles
    -- draw theirs at the top, the CRT's its own on the right)
    local p = assert(find(s.north), s.north)
    local q = p + 4
    assert(trim(lines[q]) == "SHOW_EQUAL 3.000000 laminar/B747/nd/mode/" .. s.side .. "/sel_dial_pos", "north show: " .. lines[q])
    new = lines[q]:gsub("SHOW_EQUAL 3%.000000 laminar/B747/nd/mode/" .. s.side .. "/sel_dial_pos",
        "SHOW_EQUAL 9.000000 laminar/B747/nd/" .. s.side .. "/pln_style")
    note(q, lines[q], new)
    lines[q] = new
    -- 4. the new group before ND Text Center (the symbols over it)
    local t = assert(find("GROUP ND Text Center", e), "ND Text Center")
    inserts[#inserts + 1] = {at = t, side = s}
end

local function rotary(ind, name, x, y, image, show, s)
    local o = {
        ind .. "gen_rotary " .. name,
        ind .. string.format("  POS %.6f %.6f", x, y),
        ind .. "  IMAGE " .. image,
        ind .. "  DATAREF ",
    }
    if show then o[#o + 1] = ind .. "  " .. show end
    for _, l in ipairs({"HIDE", "LIGHT_MODE GLASS_AUTO", "LIGHT_RHEOSTAT " .. s.rheo, "BUS_SRC " .. s.bus,
        "KEY_FRAME 0.000000 0.000000 1.000000", "KEY_FRAME 1.000000 6.000000", "DIGITS 1",
        "ROTARY_TYPE NO_CLICK", "CLICK_RADIUS 0.000000", "CLICK_RADIUS_DY 0.000000", "OFFSET 0.000000",
        "STEP1 1.000000", "STEP2 1.000000", "CURSOR DEFAULT", "CLICK_DX 0", "CLICK_DY 0"}) do
        o[#o + 1] = ind .. "  " .. l
    end
    o[#o + 1] = ""
    return o
end
local function led(ind, name, x, y, scale, s)
    local o = {ind .. "gen_LED " .. name}
    for _, l in ipairs({string.format("POS %.6f %.6f", x, y), "IMAGE CRT Displays/LED/LED_2.18R.xx###0.white",
        "DATAREF laminar/B747/nd/range_display_" .. s.side, "HIDE", "LIGHT_MODE GLASS_AUTO",
        "LIGHT_RHEOSTAT " .. s.rheo, "BUS_SRC " .. s.bus, "KEY_FRAME 0.000000 0.000000 1.000000",
        string.format("KEY_FRAME 999.000000 %.6f", 999 * scale), "DIGITS 3", "DECIMALS 0", "PERIOD_WIDTH 0",
        "LED_ROWS 4", "ROUNDING ROUND_ROUND"}) do
        o[#o + 1] = ind .. "  " .. l
    end
    return o
end
local function group(s)
    local cx, cy = s.x, 78.5
    local lx = cx - 18
    local o = {
        "      GROUP PLN Plan" .. s.sfx,
        "        SHOW_GREATER 0.500000 laminar/B747/nd/" .. s.side .. "/pln_style",
        "        HIDE",
        "        GROUP PLN Circles" .. s.sfx,
        "          SHOW_EQUAL 1.000000 laminar/B747/nd/" .. s.side .. "/pln_style",
        "          HIDE",
    }
    local function add(t) for _, l in ipairs(t) do o[#o + 1] = l end end
    -- the circles: the selected range (232.5 px, MAP CTR's rose) and half
    add(rotary("          ", "PLN Circles" .. s.sfx, cx, cy, "EFIS/Maps/plan_circles", nil, s))
    -- their numbers on them (FCOM p.1028's 320 and 160): range_display is
    -- half the selected range
    add(led("          ", "PLN Range Out Up" .. s.sfx, lx, cy + 232.5 - 9, 2, s))
    add(led("          ", "PLN Range Out Dn" .. s.sfx, lx, cy - 232.5 - 9, 2, s))
    add(led("          ", "PLN Range In Up" .. s.sfx, lx, cy + 116.25 - 9, 1, s))
    add(led("          ", "PLN Range In Dn" .. s.sfx, lx, cy - 116.25 - 9, 1, s))
    o[#o + 1] = "        END_GROUP"
    -- the CRT's north arrow on the right (FCOM p.1029; the stock's place)
    add(rotary("        ", "PLN North CRT" .. s.sfx, s.north_x, 9, "EFIS/Maps/NorthArrow",
        "SHOW_EQUAL 2.000000 laminar/B747/nd/" .. s.side .. "/pln_style", s))
    o[#o + 1] = "      END_GROUP"
    return o
end
table.sort(inserts, function(a, b) return a.at > b.at end)
for _, ins in ipairs(inserts) do
    local g = group(ins.side)
    for k = #g, 1, -1 do table.insert(lines, ins.at, g[k]) end
    changes[#changes + 1] = string.format("%d: inserted GROUP PLN Plan%s (%d lines)", ins.at, ins.side.sfx, #g)
end

local f = assert(io.open(path, "wb"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
for _, c in ipairs(changes) do print(c) end
