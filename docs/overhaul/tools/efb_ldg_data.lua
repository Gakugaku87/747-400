-- efb_ldg_data.lua: the landing performance data of
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_ldg_model.lua
-- (2026-11-25, the EFB's PERFORMANCE - LANDING page, FCOM p.1183
-- (10.45.25)) read from the PDFs. LuaJIT.
--
--   luajit docs/overhaul/tools/efb_ldg_data.lua <FCOM pdf> <FPPM pdf> <model.lua> [dump dir] [overlay file]
--
-- The model's text between "-- BEGIN GENERATED DATA" and "-- END GENERATED
-- DATA" is replaced; the rest (the hand-written functions) is kept.
-- [dump dir]: where pdf_paths.lua's page dumps go (default %TEMP%).
-- [overlay file]: the charts' data drawn back in page points, one
-- polyline a line ("<page> <r,g,b> : x,y x,y ..."), to lay over the page
-- images (_ref/text/img/FPPM) and check by eye.
--
-- What is read, and how:
--  - the FCOM's Normal Configuration Landing Distance tables (747-400/
--    PW4056: flaps 30 FCOM p.275 (PI.12.1), flaps 25 p.276 (PI.12.2);
--    747-400F/CF6-80C2B1F: flaps 30 p.371 (PI.22.1), flaps 25 p.372
--    (PI.22.2)) and the FPPM's (747-400F/PW4056, D632U002-RZ043: flaps 30
--    p.78 (1.4.8), flaps 25 p.79 (1.4.9)) with "pdftotext -table" (xpdf
--    4.06, Git for Windows' /ucrt64/bin; set PDFTOTEXT to another one): its
--    table mode keeps each row's 13 cells on one line in the printed order
--    (the plain text, _ref/text/FCOM/p0275.txt, puts the temperature and
--    approach speed columns in blocks of their own). pdf_paths.lua cannot
--    read the FCOM's PDF (inflate: "distance too far" on p.275's streams);
--    the FPPM's tables are read the same way for the comparison. Every
--    section's rows checked by name and order, every row's 13 cells
--    numbers; the units, the reference weight and its step, the slippery
--    runway factor, the manual spoiler addition and the flare distance from
--    the pages' headers and notes;
--  - the FPPM's Quick Turnaround Limit tables (p.76 (1.4.6)): the text runs
--    of pdf_paths.lua, each cell to the nearest column heading (the blank
--    cells kept blank), the deg F column checked against the deg C; the
--    notes' adjustments and the time to wait from pdftotext (the runs break
--    inside words);
--  - the FPPM's Landing Field & Climb Limit charts (p.71-74 (1.4.1-4):
--    flaps 25 and 30, anti-skid operative and inoperative) from the vector
--    drawing (pdf_paths.lua; the left-hand pages p.72 and p.74 are drawn
--    at 92 %: 1.38 and 0.41 pt lines, their guide lines' ends up to 0.35 pt
--    off the edges, p.72's 6,000 ft line drawn twice):
--     - the scales: the thick axes' ends paired with the first and last
--       tick labels, every label checked on that scale (one common offset
--       of the labels from their ticks under 2.5 pt, each within 0.6 pt of
--       it); the field length's 100 M row checked against its ticks;
--     - the field chart's correction sections: the wind the lowest thick
--       axis piece on the right (15 kt tail to 40 kt head, its labels
--       checked), its REF LINE the horizontal across it; the brakes (NORMAL
--       to TWO INOP) and the runway (DRY to WET) between the full-width
--       horizontals by those labels, the REF LINE the lower edge (its label
--       checked); the guide lines the thin straight lines in the section,
--       each from the REF LINE, carried on to the section's far edge where
--       the chart clips them, checked to fan out in order;
--     - the pressure altitude lines: the thin lines in the weight part,
--       joined end to end, left to right -2 to 10 (1000 ft) where they all
--       are, each checked against its label;
--     - the climb limit chart: its 13 curves, top to bottom -2 to 10 (1000
--       ft), each checked against its label, thinned (Douglas-Peucker,
--       0.1 pt);
--     - the notes (packs, ice, manual spoilers, the flaps 30 approach speed
--       box) from the text runs;
--     - the printed examples (the long-dashed lines) printed in the charts'
--       units, for the test.
local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
local fmt = string.format

local fcom_pdf, fppm_pdf, model_path, dump_dir, overlay_path = arg[1], arg[2], arg[3], arg[4], arg[5]
if not fcom_pdf or not fppm_pdf or not model_path then
    io.stderr:write("usage: luajit efb_ldg_data.lua <FCOM pdf> <FPPM pdf> <model.lua> [dump dir] [overlay file]\n")
    os.exit(2)
end
dump_dir = dump_dir or os.getenv("TEMP") or "."
local tool_dir = arg[0]:match("^(.*)[/\\]") or "."
local PDFTOTEXT = os.getenv("PDFTOTEXT") or "pdftotext"

local function check(cond, msg)
    if not cond then error("efb_ldg_data: " .. msg, 0) end
end

local overlay = {}
local function draw(page, rgb, pts)
    local s = {}
    for i, p in ipairs(pts) do s[i] = fmt("%.2f,%.2f", p[1], p[2]) end
    overlay[#overlay + 1] = fmt("%d %s : %s", page, rgb, table.concat(s, " "))
end

------------------------------------------------------------------------
-- the distance tables (pdftotext -table)
------------------------------------------------------------------------
local function pdftext(pdf, page)
    local h = assert(io.popen(fmt('%s -table -f %d -l %d "%s" -', PDFTOTEXT, page, page, pdf), "r"))
    local s = h:read("*a")
    h:close()
    check(s and #s > 200, "pdftotext gave nothing for page " .. page .. " of " .. pdf)
    return s
end

local COND_ORDER = {"DRY", "GOOD", "MEDIUM", "POOR"}
local ROWS = {
    DRY = {"MAX MANUAL", "MAX AUTO", "4", "3", "2", "1"},
    GOOD = {"MAX MANUAL", "MAX AUTO", "4", "3"},
}
ROWS.MEDIUM, ROWS.POOR = ROWS.GOOD, ROWS.GOOD

-- one page's table: t.unit ("M"/"FT"), t.wt_unit ("KG"/"LB"), t.ref_wt,
-- t.wt_step, t.factor (the slippery runways' factor in the figures, 1
-- none), t.manual_spoilers (in t.unit), t.flare (approximately, t.unit),
-- t.rows[cond][brake] = {13 numbers}
local function parse_dist(text, flaps, where)
    local flat = text:gsub("%s+", " ")
    local t = {rows = {}}
    t.unit = flat:match("LANDING DISTANCE AND ADJUSTMENTS? %((%u+)%)")
    check(t.unit == "M" or t.unit == "FT", where .. ": the distance unit")
    local head = flat:match("LANDING DISTANCE AND ADJUSTMENTS? %(%u+%)(.-)MAX MANUAL")
    check(head, where .. ": the table's heading")
    t.wt_unit = head:find(" LB") and "LB" or "KG"
    for n in head:gmatch("%d+") do
        n = tonumber(n)
        if not t.ref_wt and n >= 100000 then t.ref_wt = n end
        if not t.wt_step and n >= 2000 and n < 100000 then t.wt_step = n end
    end
    check((t.wt_unit == "KG" and t.ref_wt == 250000 and t.wt_step == 5000)
        or (t.wt_unit == "LB" and t.ref_wt == 550000 and t.wt_step == 10000),
        where .. ": the reference weight and its step " .. tostring(t.ref_wt) .. " " .. tostring(t.wt_step) .. " " .. t.wt_unit)
    check(head:find("VREF ?" .. flaps) or head:find("VREF ?30"), where .. ": the approach speed column's VREF")
    local f = flat:match("factored by (%d%.%d+)")
    if f then
        t.factor = tonumber(f)
        check(flat:find("Good, Medium, and Poor Reported Braking Action distances and adjustments have been factored by"),
            where .. ": what the factor is on")
    else
        t.factor = 1
        check(flat:find("Actual %(unfactored%) distances are shown"), where .. ": neither factored nor actual")
    end
    local add, au = flat:match("For manual spoilers,? add (%d+) (%a+)")
    check(add and au:upper() == t.unit, where .. ": the manual spoilers' addition")
    t.manual_spoilers = tonumber(add)
    local fl, fu = flat:match("approximately (%d+) (%a+) flare distance")
    check(fl and fu:upper() == t.unit, where .. ": the flare distance")
    t.flare = tonumber(fl)
    check(flat:find("Reference distance is for sea level, standard day, no wind or slope, and four engine"), where .. ": the reference note")
    check(flat:find("Assumes VREF" .. flaps .. " approach speed"), where .. ": not VREF" .. flaps)
    check(flat:find("Max manual braking reference distance assumes use of auto spoilers"), where .. ": the spoiler note")
    t.vref_note = "VREF" .. flaps

    local cond
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        if line:find("^%s*Dry Runway") then cond = "DRY"
        elseif line:find("^%s*Good Reported") then cond = "GOOD"
        elseif line:find("^%s*Medium Reported") then cond = "MEDIUM"
        elseif line:find("^%s*Poor Reported") then cond = "POOR" end
        local name, rest = line:match("^%s*(MAX MANUAL)%s+(.*)$")
        if not name then name, rest = line:match("^%s*(MAX AUTO)%s+(.*)$") end
        if not name then
            name, rest = line:match("^%s*AUTOBRAKES?%s+(%d)%s+(.*)$")
        end
        if name then
            check(cond, where .. ": a row before its section: " .. line)
            local cells = {}
            for tok in rest:gmatch("%S+") do cells[#cells + 1] = tok end
            check(#cells == 12, where .. ": " .. cond .. " " .. name .. ": " .. #cells .. " cells")
            local a, b = cells[2]:match("^(%-?%d+)/(%-?%d+)$")
            check(a, where .. ": " .. cond .. " " .. name .. ": the weight cell " .. cells[2])
            local row = {tonumber(cells[1]), tonumber(a), tonumber(b)}
            for i = 3, 12 do
                local v = tonumber(cells[i])
                check(v and cells[i]:match("^%-?%d+$"), where .. ": " .. cond .. " " .. name .. ": cell " .. cells[i])
                row[#row + 1] = v
            end
            t.rows[cond] = t.rows[cond] or {order = {}}
            local r = t.rows[cond]
            check(not r[name], where .. ": " .. cond .. " " .. name .. " twice")
            r[name] = row
            r.order[#r.order + 1] = name
        end
    end
    for _, c in ipairs(COND_ORDER) do
        local r = t.rows[c]
        check(r and table.concat(r.order, ",") == table.concat(ROWS[c], ","),
            where .. ": " .. c .. "'s rows " .. (r and table.concat(r.order, ",") or "none"))
        for _, name in ipairs(ROWS[c]) do
            local v = r[name]
            -- the signs as the columns mean them: ref > 0, above >= 0 >= below,
            -- alt >= 0, head <= 0 <= tail, down >= 0 >= up, abv >= 0 >= blw,
            -- app >= 0, rev >= 0
            check(v[1] > 0 and v[2] >= 0 and v[3] <= 0 and v[4] >= 0 and v[5] <= 0 and v[6] >= 0
                and v[7] >= 0 and v[8] <= 0 and v[9] >= 0 and v[10] <= 0 and v[11] >= 0
                and v[12] >= 0 and v[13] >= v[12], where .. ": " .. c .. " " .. name .. ": a sign")
        end
    end
    return t
end

local FCOM_DIST = {
    {engine = 0, flaps = 30, page = 275, sec = "PI.12.1", model = "747-400/PW4056"},
    {engine = 0, flaps = 25, page = 276, sec = "PI.12.2", model = "747-400/PW4056"},
    {engine = 1, flaps = 30, page = 371, sec = "PI.22.1", model = "747-400F/CF6-80C2B1F"},
    {engine = 1, flaps = 25, page = 372, sec = "PI.22.2", model = "747-400F/CF6-80C2B1F"},
}
local FPPM_DIST = {
    {flaps = 30, page = 78, sec = "1.4.8"},
    {flaps = 25, page = 79, sec = "1.4.9"},
}

local dist = {}
for _, p in ipairs(FCOM_DIST) do
    local text = pdftext(fcom_pdf, p.page)
    check(text:find(p.model, 1, true), "FCOM p." .. p.page .. ": not " .. p.model)
    check(text:find("Normal Configuration Landing Distance", 1, true) and text:find("Flaps " .. p.flaps, 1, true),
        "FCOM p." .. p.page .. ": not the flaps " .. p.flaps .. " landing distance")
    local t = parse_dist(text, p.flaps, "FCOM p." .. p.page)
    t.page, t.sec = p.page, p.sec
    dist[p.engine] = dist[p.engine] or {model = p.model}
    dist[p.engine][p.flaps] = t
end
local fppm_dist = {model = "747-400F/PW4056"}
for _, p in ipairs(FPPM_DIST) do
    local text = pdftext(fppm_pdf, p.page)
    check(text:find("747-400F/PW4056", 1, true) and text:find("Flaps " .. p.flaps, 1, true),
        "FPPM p." .. p.page .. ": not the 747-400F/PW4056 flaps " .. p.flaps)
    local t = parse_dist(text, p.flaps, "FPPM p." .. p.page)
    t.page, t.sec = p.page, p.sec
    fppm_dist[p.flaps] = t
end
-- the two flaps' pages of a table agree on what is not per row
for _, d in pairs({dist[0], dist[1], fppm_dist}) do
    for _, k in ipairs({"unit", "wt_unit", "ref_wt", "wt_step", "factor", "manual_spoilers", "flare"}) do
        check(d[30][k] == d[25][k], d.model .. ": flaps 30 and 25 differ in " .. k)
    end
end

------------------------------------------------------------------------
-- pdf_paths.lua's page dumps
------------------------------------------------------------------------
local function dump_page(page)
    local out = dump_dir .. "/efb_ldg_fppm_p" .. page .. ".txt"
    local chunk = assert(loadfile(tool_dir .. "/pdf_paths.lua"))
    local saved, saved_print = arg, print
    arg = {[0] = "pdf_paths.lua", fppm_pdf, tostring(page), out}
    print = function() end
    chunk()
    arg, print = saved, saved_print
    local d = {S = {}, T = {}}
    for line in io.lines(out) do
        line = line:gsub("\r$", "")
        local k = line:sub(1, 1)
        if k == "S" then
            local lw, dash, pts = line:match("^S (%S+) %S+ (%S+) : (.*)$")
            local p = {}
            for x, y in pts:gmatch("([%-%d%.]+),([%-%d%.]+)") do p[#p + 1] = {tonumber(x), tonumber(y)} end
            d.S[#d.S + 1] = {lw = tonumber(lw), dash = dash, pts = p}
        elseif k == "T" then
            local x, y, size, ang, text = line:match("^T (%S+) (%S+) (%S+) (%S+) (.*)$")
            d.T[#d.T + 1] = {x = tonumber(x), y = tonumber(y), size = tonumber(size), ang = tonumber(ang),
                text = text:gsub("%s+$", "")}
        end
    end
    return d
end

------------------------------------------------------------------------
-- geometry
------------------------------------------------------------------------
local function bbox(pts)
    local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9
    for _, p in ipairs(pts) do
        x0, x1, y0, y1 = min(x0, p[1]), max(x1, p[1]), min(y0, p[2]), max(y1, p[2])
    end
    return x0, x1, y0, y1
end

local function length(pts)
    local s = 0
    for i = 2, #pts do s = s + sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
    return s
end

-- an arrowhead: a closed outline
local function closed(pts)
    return #pts > 2 and abs(pts[1][1] - pts[#pts][1]) < 0.05 and abs(pts[1][2] - pts[#pts][2]) < 0.05
end

local function inside(pts, x0, x1, y0, y1, tol)
    tol = tol or 0.15
    local a, b, c, d = bbox(pts)
    return a >= x0 - tol and b <= x1 + tol and c >= y0 - tol and d <= y1 + tol
end

local function seg_dist(px, py, a, b)
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and max(0, min(1, ((px - a[1]) * dx + (py - a[2]) * dy) / l2)) or 0
    local qx, qy = a[1] + t * dx, a[2] + t * dy
    return sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
end

local function poly_dist(px, py, pts)
    local d = 1e9
    for i = 2, #pts do d = min(d, seg_dist(px, py, pts[i - 1], pts[i])) end
    return d
end

-- polylines joined end to end (the charts draw a curve as pieces, some
-- backwards; p.72 draws its 6 line twice: a piece whose ends another's
-- match is dropped); each chain left to right
local function chains(all)
    local pieces = {}
    for _, pc in ipairs(all) do
        local dup = false
        for _, q in ipairs(pieces) do
            local function same(u, v) return abs(u[1] - v[1]) < 0.1 and abs(u[2] - v[2]) < 0.1 end
            if #q == #pc and ((same(q[1], pc[1]) and same(q[#q], pc[#pc])) or (same(q[1], pc[#pc]) and same(q[#q], pc[1]))) then
                dup = true
            end
        end
        if not dup then pieces[#pieces + 1] = pc end
    end
    local used, out = {}, {}
    local function near(p, q) return abs(p[1] - q[1]) < 0.06 and abs(p[2] - q[2]) < 0.06 end
    for i, pc in ipairs(pieces) do
        if not used[i] then
            used[i] = true
            local c = {}
            for _, p in ipairs(pc) do c[#c + 1] = {p[1], p[2]} end
            local grown = true
            while grown do
                grown = false
                for j, q in ipairs(pieces) do
                    if not used[j] then
                        local qf, ql = q[1], q[#q]
                        if near(c[#c], qf) then
                            for k = 2, #q do c[#c + 1] = {q[k][1], q[k][2]} end
                        elseif near(c[#c], ql) then
                            for k = #q - 1, 1, -1 do c[#c + 1] = {q[k][1], q[k][2]} end
                        elseif near(c[1], ql) then
                            for k = #q - 1, 1, -1 do table.insert(c, 1, {q[k][1], q[k][2]}) end
                        elseif near(c[1], qf) then
                            for k = 2, #q do table.insert(c, 1, {q[k][1], q[k][2]}) end
                        end
                        if near(c[#c], qf) or near(c[#c], ql) or near(c[1], qf) or near(c[1], ql) then
                            used[j], grown = true, true
                        end
                    end
                end
            end
            if c[1][1] > c[#c][1] then
                local r = {}
                for k = #c, 1, -1 do r[#r + 1] = c[k] end
                c = r
            end
            out[#out + 1] = c
        end
    end
    return out
end

-- Douglas-Peucker
local function thin(pts, tol)
    local keep = {[1] = true, [#pts] = true}
    local function rec(i, j)
        local dm, k = 0, nil
        for m = i + 1, j - 1 do
            local d = seg_dist(pts[m][1], pts[m][2], pts[i], pts[j])
            if d > dm then dm, k = d, m end
        end
        if k and dm > tol then
            keep[k] = true
            rec(i, k)
            rec(k, j)
        end
    end
    rec(1, #pts)
    local out = {}
    for i, p in ipairs(pts) do if keep[i] then out[#out + 1] = p end end
    return out
end

-- a text run's center (Helvetica's digits 0.556 em, the minus 0.333; the
-- height of a digit 0.716 em)
local function text_center(t)
    local w = 0
    for c in t.text:gmatch(".") do w = w + ((c == "-") and 0.333 or (c == " ") and 0.278 or 0.556) end
    w = w * t.size
    local h = 0.716 * t.size
    local a = math.rad(t.ang)
    return t.x + math.cos(a) * w / 2 - math.sin(a) * h / 2, t.y + math.sin(a) * w / 2 + math.cos(a) * h / 2
end

-- a scale from an axis' two ends and the labels along it: v(u) linear,
-- the first and last labels at the ends; every label checked (after the
-- labels' common offset from their ticks, the type's placing: under 2.5 pt)
local function scale(u0, u1, labels, what)
    table.sort(labels, function(a, b) return a.u < b.u end)
    check(#labels >= 3, what .. ": " .. #labels .. " labels")
    local v0, v1 = labels[1].v, labels[#labels].v
    local function v(u) return v0 + (u - u0) * (v1 - v0) / (u1 - u0) end
    local function u(val) return u0 + (val - v0) * (u1 - u0) / (v1 - v0) end
    local off = 0
    for _, l in ipairs(labels) do off = off + (l.u - u(l.v)) / #labels end
    local worst = 0
    for _, l in ipairs(labels) do worst = max(worst, abs(l.u - u(l.v) - off)) end
    check(abs(off) < 2.5 and worst < 0.6, fmt("%s: the labels %.2f pt off the axis' scale, one %.2f pt more", what, off, worst))
    return v, u, worst
end

-- labels against where they should be: one common offset (the type's
-- placing, under 2.5 pt), each within 0.6 pt of it
local function labels_agree(list, what)
    local off = 0
    for _, l in ipairs(list) do off = off + (l.got - l.want) / #list end
    for _, l in ipairs(list) do
        check(abs(off) < 2.5 and abs(l.got - l.want - off) < 0.6,
            fmt("%s: %s at %.2f, %.2f wanted (the labels' offset %.2f)", what, l.what, l.got, l.want, off))
    end
end

local function notes_text(d, x0, x1, y0, y1)
    local runs = {}
    for _, t in ipairs(d.T) do
        if t.size >= 7 and t.size <= 8.5 and t.x >= x0 and t.x <= x1 and t.y >= y0 and t.y <= y1 then runs[#runs + 1] = t end
    end
    table.sort(runs, function(a, b)
        if abs(a.y - b.y) > 2 then return a.y > b.y end
        return a.x < b.x
    end)
    local s = {}
    for _, t in ipairs(runs) do s[#s + 1] = t.text end
    return (table.concat(s, " "):gsub("%s+", " "))
end

local function is_long_dash(dash)
    local first = tonumber(dash:match("^%[([%d%.]+)"))
    return first and first >= 3
end

------------------------------------------------------------------------
-- the Landing Field & Climb Limit charts (FPPM p.71-74)
------------------------------------------------------------------------
local CHARTS = {
    {flaps = 25, page = 71, sec = "1.4.1", askid = true},
    {flaps = 30, page = 72, sec = "1.4.2", askid = true},
    {flaps = 25, page = 73, sec = "1.4.3", askid = false},
    {flaps = 30, page = 74, sec = "1.4.4", askid = false},
}

local examples = {}

local function read_chart(c)
    local d = dump_page(c.page)
    local where = "FPPM p." .. c.page
    local alltext = {}
    for _, t in ipairs(d.T) do alltext[#alltext + 1] = t.text end
    alltext = table.concat(alltext, " "):gsub("%s+", " ")
    check(alltext:find("Landing Field & Climb Limit", 1, true) and alltext:find("Flaps " .. c.flaps, 1, true),
        where .. ": not the flaps " .. c.flaps .. " landing field & climb limit")
    check(alltext:find(c.askid and "ANTI-SKID OPERATIVE" or "ANTI-SKID INOPERATIVE", 1, true), where .. ": the anti-skid title")

    -- the thick lines (1.5 pt; 1.38 on the left-hand pages, drawn at 92 %)
    local thick = {}
    for _, s in ipairs(d.S) do if s.lw >= 1.2 and #s.pts == 2 then thick[#thick + 1] = s.pts end end
    -- the field chart's field length axis: the longest horizontal; the
    -- climb chart's: the horizontal right of it, its weight axis the long
    -- vertical there
    local fla_axis, climb_oat_axis, climb_wt_axis
    for _, p in ipairs(thick) do
        local x0, x1, y0, y1 = bbox(p)
        if y1 - y0 < 0.05 and (not fla_axis or x1 - x0 > fla_axis[2] - fla_axis[1]) then fla_axis = {x0, x1, y0} end
    end
    check(fla_axis, where .. ": the field length axis")
    for _, p in ipairs(thick) do
        local x0, x1, y0, y1 = bbox(p)
        if y1 - y0 < 0.05 and x1 - x0 > 80 and x0 > fla_axis[2] + 30 then climb_oat_axis = {x0, x1, y0} end
        if x1 - x0 < 0.05 and y1 - y0 > 250 and x0 > fla_axis[2] + 30 then climb_wt_axis = {x0, y0, y1} end
    end
    check(fla_axis and climb_oat_axis and climb_wt_axis, where .. ": the axes")
    local xl, xr, yfla = fla_axis[1], fla_axis[2], fla_axis[3]
    -- the vertical axis pieces at the field chart's right edge
    local pieces = {}
    for _, p in ipairs(thick) do
        local x0, x1, y0, y1 = bbox(p)
        if x1 - x0 < 0.05 and abs(x0 - xr) < 0.3 then pieces[#pieces + 1] = {y0, y1} end
    end
    table.sort(pieces, function(a, b) return a[1] < b[1] end)
    local spans = {}
    for _, p in ipairs(pieces) do
        local last = spans[#spans]
        if last and abs(p[1] - last[2]) < 0.1 then last[2] = max(last[2], p[2]) else spans[#spans + 1] = {p[1], p[2]} end
    end
    -- the weight part: the longest span
    local wspan
    for _, s in ipairs(spans) do if not wspan or s[2] - s[1] > wspan[2] - wspan[1] then wspan = s end end
    -- labels right of the axis
    local right = {}
    for _, t in ipairs(d.T) do
        if t.ang == 0 and t.x > xr and t.x < xr + 8 then right[#right + 1] = t end
    end
    local function labels_in(y0, y1)
        local out = {}
        for _, t in ipairs(right) do
            local cx, cy = text_center(t)
            if cy >= y0 - 2.5 and cy <= y1 + 2.5 then out[#out + 1] = {t = t, cy = cy} end
        end
        return out
    end
    -- the weight scale
    local wl = {}
    for _, l in ipairs(labels_in(wspan[1], wspan[2])) do
        local v = tonumber(l.t.text)
        if v then wl[#wl + 1] = {u = l.cy, v = v} end
    end
    local wt_of, y_of_wt = scale(wspan[1], wspan[2], wl, where .. " field weight")
    local wt_lo, wt_hi = wt_of(wspan[1]), wt_of(wspan[2])
    -- the field length scale (1000 FT labels below the axis) and its 100 M row
    local fl, ml = {}, {}
    for _, t in ipairs(d.T) do
        local v = tonumber(t.text)
        if v and t.ang == 0 and t.x > xl - 5 and t.x < xr + 3 then
            local cx, cy = text_center(t)
            if cy < yfla - 4 and cy > yfla - 12 then fl[#fl + 1] = {u = cx, v = v * 1000} end
            if cy > yfla + 1 and cy < yfla + 8 then ml[#ml + 1] = {u = cx, v = v * 100} end
        end
    end
    local ft_of, x_of_ft, fworst = scale(xl, xr, fl, where .. " field length (ft)")
    -- the meter ticks: short verticals on the axis, one a 100 M label
    local mworst = 0
    for _, l in ipairs(ml) do
        local best = 1e9
        for _, s in ipairs(d.S) do
            if #s.pts == 2 and s.lw > 0.3 then
                local x0, x1, y0, y1 = bbox(s.pts)
                if x1 - x0 < 0.05 and y1 - y0 < 3 and abs(y0 - yfla) < 0.3 and abs(x0 - l.u) < abs(best - l.u) then best = x0 end
            end
        end
        check(best < 1e8, where .. ": no tick for " .. l.v .. " m")
        mworst = max(mworst, abs(ft_of(best) * 0.3048 - l.v))
    end
    check(#ml >= 5 and mworst < 3, fmt("%s: the meter ticks %.1f m off the feet", where, mworst))

    -- the correction sections: the wind the lowest thick axis piece on the
    -- right (its 15 kt tail at the bottom, 40 kt head at the top); the
    -- brakes (NORMAL to TWO INOP) and the runway (DRY to WET) between the
    -- full-width horizontals by their labels (the left-hand pages draw no
    -- thick axis there)
    local sections = {}
    local lowest
    for _, s in ipairs(spans) do
        if s ~= wspan and (not lowest or s[1] < lowest[1]) then lowest = s end
    end
    check(lowest and lowest[2] < wspan[1], where .. ": the wind's axis")
    sections.wind = {y0 = lowest[1], y1 = lowest[2], labels = labels_in(lowest[1], lowest[2])}
    local horiz = {}
    for _, s in ipairs(d.S) do
        if #s.pts == 2 and s.lw > 0.3 and s.lw < 1 then
            local x0, x1, y0, y1 = bbox(s.pts)
            if y1 - y0 < 0.05 and x0 < xl + 0.5 and x1 > xr - 0.5 and y0 > lowest[2] + 1 and y0 < wspan[1] - 1 then horiz[#horiz + 1] = y0 end
        end
    end
    local function labelled(lo_name, hi_name, kind)
        local lo, hi
        for _, l in ipairs(right) do
            local name = l.text:gsub("%s+", " ")
            if name == lo_name or name == hi_name then
                local _, cy = text_center(l)
                local best, by = 1e9, nil
                for _, y in ipairs(horiz) do
                    if abs(y - cy) < best then best, by = abs(y - cy), y end
                end
                check(best < 3, where .. ": no horizontal by " .. name)
                if name == lo_name then lo = {y = by, cy = cy} else hi = {y = by, cy = cy} end
            end
        end
        if not lo and not hi then return nil end
        check(lo and hi and hi.y > lo.y, where .. ": the " .. kind .. " section's edges")
        return {y0 = lo.y, y1 = hi.y, labels = {{t = {text = lo_name}, cy = lo.cy}, {t = {text = hi_name}, cy = hi.cy}}}
    end
    sections.brakes = labelled("NORMAL", "TWO INOP", "brakes")
    sections.wet = labelled("DRY", "WET", "runway condition")
    check(sections.wet and (sections.brakes ~= nil) == c.askid and sections.wet.y0 > sections.wind.y1
        and (not sections.brakes or (sections.brakes.y0 > sections.wind.y1 and sections.wet.y0 > sections.brakes.y1)),
        where .. ": the sections")
    -- each section's REF LINE: the full-width horizontal inside it (the wind),
    -- its lower edge (the brakes: NORMAL, the runway: DRY)
    local function ref_line(sec)
        for _, s in ipairs(d.S) do
            if #s.pts == 2 and s.lw > 0.3 then
                local x0, x1, y0, y1 = bbox(s.pts)
                if y1 - y0 < 0.05 and x0 < xl + 0.5 and x1 > xr - 0.5 and y0 > sec.y0 + 1 and y0 < sec.y1 - 1 then return y0 end
            end
        end
    end
    local sw = sections.wind
    sw.ref = ref_line(sw)
    check(sw.ref, where .. ": the wind's REF LINE")
    -- the wind scale: 0 at the REF LINE, 40 kt head at the top, 15 kt tail at the bottom
    local wl3 = {}
    for _, l in ipairs(sw.labels) do
        local v = tonumber(l.t.text)
        check(v, where .. ": a wind label " .. l.t.text)
        -- the head side's labels above the REF LINE (the 0's center a little above it)
        local want = l.cy >= sw.ref + 3 and sw.ref + (sw.y1 - sw.ref) * v / 40 or sw.ref - (sw.ref - sw.y0) * v / 15
        wl3[#wl3 + 1] = {got = l.cy, want = want, what = l.t.text}
    end
    labels_agree(wl3, where .. " wind labels")
    sw.up_max, sw.down_max = 40, 15
    for _, k in ipairs({"brakes", "wet"}) do
        local s = sections[k]
        if s then
            s.ref = s.y0
            local el = {}
            for _, l in ipairs(s.labels) do
                local at_ref = l.t.text == "DRY" or l.t.text == "NORMAL"
                el[#el + 1] = {got = l.cy, want = at_ref and s.y0 or s.y1, what = l.t.text}
            end
            labels_agree(el, where .. " " .. k .. " labels")
            -- the REF LINE label on its lower edge
            local found
            for _, t in ipairs(d.T) do
                if t.text:gsub("%s+", " ") == "REF LINE" and abs(t.y - s.y0) < 2 then found = true end
            end
            check(found, where .. ": no REF LINE label on the " .. k .. " section's lower edge")
        end
    end
    do
        local found
        for _, t in ipairs(d.T) do
            if t.text:gsub("%s+", " ") == "REF LINE" and abs(t.y - sw.ref) < 2 then found = true end
        end
        check(found, where .. ": no REF LINE label on the wind's REF LINE")
    end

    -- the guide lines
    local function guide(sec, kind)
        local up, down = {}, {}
        for _, s in ipairs(d.S) do
            -- (the left-hand pages' lines end up to 0.35 pt off the edges)
            if #s.pts == 2 and s.lw > 0.3 and s.lw < 1 and s.dash == "-" and inside(s.pts, xl, xr, sec.y0, sec.y1, 0.4) then
                local a, b = s.pts[1], s.pts[2]
                if abs(a[2] - b[2]) > 1 then
                    if abs(b[2] - sec.ref) < abs(a[2] - sec.ref) then a, b = b, a end
                    check(abs(a[2] - sec.ref) < 0.4, fmt("%s: a %s guide line off the REF LINE: %.2f,%.2f %.2f,%.2f", where, kind, a[1], a[2], b[1], b[2]))
                    local function x_at(y) return a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) end
                    local edge = b[2] > a[2] and sec.y1 or sec.y0
                    local xref, xfar = x_at(sec.ref), x_at(edge)
                    local g = {ft_of(xref), ft_of(xfar)}
                    if b[2] > a[2] then up[#up + 1] = g else down[#down + 1] = g end
                    draw(c.page, "255,0,0", {{xref, sec.ref}, {xfar, edge}})
                end
            end
        end
        for _, fam in ipairs({up, down}) do
            table.sort(fam, function(p, q) return p[1] < q[1] end)
            for i = 2, #fam do
                check(fam[i][1] - fam[i - 1][1] > 100 and fam[i][2] > fam[i - 1][2],
                    fmt("%s: %s guide lines %d and %d out of order", where, kind, i - 1, i))
            end
        end
        return up, down
    end
    local out = {flaps = c.flaps, page = c.page, sec = c.sec}
    out.fla = {ft_of(xl), ft_of(xr)}
    out.wt = {wt_lo, wt_hi}
    local head, tail = guide(sw, "wind")
    check(#head >= 10 and #tail >= 10, where .. ": the wind guide lines " .. #head .. " " .. #tail)
    out.wind = {head = 40, tail = 15, head_lines = head, tail_lines = tail}
    if sections.brakes then
        local up, down = guide(sections.brakes, "brakes")
        check(#up >= 10 and #down == 0, where .. ": the brakes guide lines")
        out.brakes = up
    end
    local wet, dn = guide(sections.wet, "runway")
    check(#wet >= 10 and #dn == 0, where .. ": the runway condition guide lines")
    out.wet = wet

    -- the pressure altitude lines
    local pcs = {}
    for _, s in ipairs(d.S) do
        if s.lw > 0.3 and s.lw < 1 and s.dash == "-" and inside(s.pts, xl, xr, wspan[1], wspan[2], 0.4) and not closed(s.pts) then
            local x0, x1, y0, y1 = bbox(s.pts)
            if x1 - x0 > 0.5 and y1 - y0 > 0.5 then pcs[#pcs + 1] = s.pts end
        end
    end
    local alts = chains(pcs)
    check(#alts == 7, where .. ": " .. #alts .. " altitude lines")
    -- left to right where they all are (some start on the left edge above
    -- the chart's bottom)
    local ykey = -1e9
    for _, a in ipairs(alts) do ykey = max(ykey, a[1][2] + 1) end
    local function x_at_y(a, y)
        for k = 2, #a do
            if y <= a[k][2] then return a[k - 1][1] + (y - a[k - 1][2]) / (a[k][2] - a[k - 1][2]) * (a[k][1] - a[k - 1][1]) end
        end
        return 1e9
    end
    table.sort(alts, function(a, b) return x_at_y(a, ykey) < x_at_y(b, ykey) end)
    local ALT = {-2000, 0, 2000, 4000, 6000, 8000, 10000}
    -- each label nearest its line
    local nl = 0
    for _, t in ipairs(d.T) do
        local v = tonumber(t.text)
        if v and t.ang > 30 and t.ang < 80 then
            local cx, cy = text_center(t)
            local best, bi = 1e9, nil
            for i, a in ipairs(alts) do
                local dd = poly_dist(cx, cy, a)
                if dd < best then best, bi = dd, i end
            end
            check(ALT[bi] == v * 1000, fmt("%s: the altitude label %s nearest the line %d", where, t.text, ALT[bi]))
            nl = nl + 1
        end
    end
    check(nl == 7, where .. ": " .. nl .. " altitude labels")
    out.alt = ALT
    out.lines = {}
    for i, a in ipairs(alts) do
        local x0, x1, y0, y1 = bbox(a)
        check(abs(a[1][2] - wspan[1]) < 0.2 or abs(a[1][1] - xl) < 0.2, where .. ": an altitude line starts inside the chart")
        local l = {}
        for k, p in ipairs(a) do
            l[k] = {ft_of(p[1]), wt_of(p[2])}
            if k > 1 then
                check(p[1] > a[k - 1][1] and p[2] > a[k - 1][2], where .. ": the altitude line " .. ALT[i] .. " not rising")
            end
        end
        out.lines[i] = l
        draw(c.page, "0,90,255", a)
    end
    -- lower altitudes reach a weight with less field length
    for i = 2, #alts do
        check(x_at_y(alts[i], ykey) > x_at_y(alts[i - 1], ykey) + 1, where .. ": the altitude lines out of order")
    end

    -- the climb limit chart
    local cx0, cx1, cy0 = climb_oat_axis[1], climb_oat_axis[2], climb_oat_axis[3]
    local cwy0, cwy1 = climb_wt_axis[2], climb_wt_axis[3]
    check(abs(climb_wt_axis[1] - cx0) < 0.2 and abs(cwy0 - cy0) < 0.2, where .. ": the climb chart's corner")
    local ol, wl2 = {}, {}
    for _, t in ipairs(d.T) do
        local v = tonumber(t.text)
        if v and t.ang == 0 then
            local tx, ty = text_center(t)
            if tx > cx0 - 4 and tx < cx1 + 4 and ty < cy0 - 3 and ty > cy0 - 12 then ol[#ol + 1] = {u = tx, v = v} end
            if tx < cx0 - 2 and tx > cx0 - 20 and ty > cwy0 - 3 and ty < cwy1 + 3 then wl2[#wl2 + 1] = {u = ty, v = v} end
        end
    end
    local oat_of, x_of_oat = scale(cx0, cx1, ol, where .. " climb OAT (C)")
    local cwt_of, y_of_cwt = scale(cwy0, cwy1, wl2, where .. " climb weight")
    local cpcs = {}
    for _, s in ipairs(d.S) do
        if s.lw > 0.3 and s.lw < 1 and s.dash == "-" and inside(s.pts, cx0, cx1, cwy0, cwy1, 0.4) and length(s.pts) > 20
            and not closed(s.pts) then
            cpcs[#cpcs + 1] = s.pts
        end
    end
    local curves = chains(cpcs)
    check(#curves == 13, where .. ": " .. #curves .. " climb curves")
    for _, cv in ipairs(curves) do check(abs(cv[1][1] - cx0) < 0.2, where .. ": a climb curve not from 0 C") end
    table.sort(curves, function(a, b) return a[1][2] > b[1][2] end)
    local CALT = {}
    for i = 1, 13 do CALT[i] = (i - 3) * 1000 end
    local ncl = 0
    for _, t in ipairs(d.T) do
        local v = tonumber(t.text)
        if v and t.ang < -50 and t.ang > -85 then
            local tx, ty = text_center(t)
            if tx > cx0 and tx < cx1 then
                -- the label sits right of its curve's falling part: the nearest
                -- curve to its left at its height
                local best, bi = 1e9, nil
                for i, cv in ipairs(curves) do
                    for k = 2, #cv do
                        local a, b = cv[k - 1], cv[k]
                        if (a[2] - ty) * (b[2] - ty) <= 0 and a[2] ~= b[2] then
                            local xc = a[1] + (ty - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
                            if xc <= tx and tx - xc < best then best, bi = tx - xc, i end
                        end
                    end
                end
                check(bi and CALT[bi] == v * 1000, fmt("%s: the climb label %s by the curve %s", where, t.text, bi and CALT[bi] or "none"))
                ncl = ncl + 1
            end
        end
    end
    check(ncl == 13, where .. ": " .. ncl .. " climb labels")
    out.climb = {alt = CALT, lines = {}}
    for i, cv in ipairs(curves) do
        local th = thin(cv, 0.1)
        local l = {}
        for k, p in ipairs(th) do
            l[k] = {oat_of(p[1]), cwt_of(p[2])}
            if k > 1 then
                check(p[1] > th[k - 1][1] and p[2] <= th[k - 1][2] + 0.5, where .. ": the climb curve " .. CALT[i] .. " not falling")
            end
        end
        out.climb.lines[i] = l
        draw(c.page, "0,170,0", th)
    end
    for i = 2, #curves do
        check(out.climb.lines[i][1][2] <= out.climb.lines[i - 1][1][2] + 0.05, where .. ": the climb curves out of order")
    end

    -- the notes
    local left = notes_text(d, xl - 30, xr, 60, yfla - 15)
    local rightn = notes_text(d, xr + 15, 612, 60, cy0 - 15)
    out.climb.pack1 = tonumber(rightn:match("FOR 1 A/C PACK OPERATION, INCREASE CLIMB WEIGHT (%d+) KG"))
    out.climb.pack0 = tonumber(rightn:match("FOR OPERATION WITH NO PACKS, INCREASE CLIMB WEIGHT (%d+) KG"))
    out.climb.ice = tonumber(rightn:match("REDUCE LANDING CLIMB LIMIT WEIGHT BY (%d+) KG FOR ICE ACCUMULATION"))
    out.climb.ice_below_c = tonumber(rightn:match("FORECAST LANDING TEMPERA%- TURE BELOW (%d+)"))
    check(rightn:find("CLIMB LIMIT BASED ON 3 PACKS", 1, true) and out.climb.pack1 and out.climb.pack0
        and out.climb.ice and out.climb.ice_below_c, where .. ": the climb notes: " .. rightn)
    if left:find("VALID FOR AUTOMATIC OR MANUAL SPOILERS", 1, true) then
        out.manual_spoilers = 0
    else
        check(left:find("VALID FOR AUTOMATIC SPOILERS", 1, true), where .. ": the spoiler note: " .. left)
        out.manual_spoilers = tonumber(left:match("FOR MANUAL SPOILERS REDUCE FIELD LENGTH AVAILABLE BY (%d+) FT"))
        check(out.manual_spoilers, where .. ": the manual spoilers' reduction: " .. left)
    end
    check(left:find("ANTI-SKID MUST BE OPERATIVE FOR TWO BRAKES INOPERATIVE", 1, true), where .. ": the two brakes note")
    out.f30_vapp_max = tonumber(left:match("GREATER THAN (%d+) KIAS, SCHEDULE FLAPS 25"))
    check((out.f30_vapp_max ~= nil) == (c.flaps == 30), where .. ": the flaps 30 approach speed box")

    -- the printed examples (long dashes)
    for _, s in ipairs(d.S) do
        if is_long_dash(s.dash) then
            local x0, x1, y0, y1 = bbox(s.pts)
            local e = {page = c.page}
            if x0 >= xl - 0.5 and x1 <= xr + 0.5 then
                e.kind = "field"
                local p = s.pts
                -- up from the field length, along the wind, the brakes and the
                -- runway's guide lines, up to an altitude line, across
                e.fla_ft = ft_of(p[1][1])
                local path = {}
                for k, q in ipairs(p) do path[k] = fmt("(%.0f ft, y %.2f)", ft_of(q[1]), q[2]) end
                e.path = path
                e.wt_t = wt_of(p[#p][2])
                -- the wind at the end of its slanted step
                for k = 2, #p do
                    if abs(p[k][2] - sw.ref) > 1 and p[k - 1][2] <= sw.ref + 0.2 and p[k][1] ~= p[k - 1][1] and p[k][2] <= sw.y1 + 0.2 and p[k][2] >= sw.y0 - 0.2 then
                        e.wind_kt = p[k][2] > sw.ref and (p[k][2] - sw.ref) / (sw.y1 - sw.ref) * 40 or -(sw.ref - p[k][2]) / (sw.ref - sw.y0) * 15
                        e.wind_ft = ft_of(p[k][1])
                    end
                end
                -- the line it meets: the altitude whose line passes nearest the
                -- corner where it turns across
                local corner = p[#p - 1]
                local best, bi = 1e9, nil
                for i, a in ipairs(alts) do
                    local dd = poly_dist(corner[1], corner[2], a)
                    if dd < best then best, bi = dd, i end
                end
                e.alt_ft, e.alt_off_pt, e.corner_ft = ALT[bi], best, ft_of(corner[1])
            elseif x0 >= cx0 - 0.5 and x1 <= cx1 + 0.5 then
                e.kind = "climb"
                local p = s.pts
                e.oat_c = oat_of(p[1][1])
                e.wt_t = cwt_of(p[#p][2])
                local corner = p[2]
                local best, bi = 1e9, nil
                for i, cv in ipairs(curves) do
                    local dd = poly_dist(corner[1], corner[2], cv)
                    if dd < best then best, bi = dd, i end
                end
                e.alt_ft, e.alt_off_pt = CALT[bi], best
            end
            if e.kind then examples[#examples + 1] = e end
        end
    end
    out.scale_worst = {fworst, mworst}
    return out
end

local field, field_inop, climb = {}, {}, {}
for _, c in ipairs(CHARTS) do
    local r = read_chart(c)
    if c.askid then
        field[c.flaps] = r
        climb[c.flaps] = r.climb
        climb[c.flaps].page, climb[c.flaps].sec = c.page, c.sec
    else
        field_inop[c.flaps] = r
        -- the anti-skid inoperative pages repeat the climb chart: the same?
        local a, b = climb[c.flaps], r.climb
        local worst = 0
        for i = 1, 13 do
            for _, p in ipairs(b.lines[i]) do
                -- a's weight at p's OAT
                local l = a.lines[i]
                local w
                for k = 2, #l do
                    if p[1] <= l[k][1] + 1e-9 then
                        w = l[k - 1][2] + (p[1] - l[k - 1][1]) / (l[k][1] - l[k - 1][1]) * (l[k][2] - l[k - 1][2])
                        break
                    end
                end
                if w then worst = max(worst, abs(w - p[2])) end
            end
        end
        check(worst < 0.3 and a.pack1 == b.pack1 and a.pack0 == b.pack0 and a.ice == b.ice,
            fmt("FPPM p.%d: the climb chart differs from the anti-skid operative page's by %.2f t", c.page, worst))
        io.write(fmt("FPPM p.%d's climb chart = p.%d's within %.2f (1000 kg)\n", c.page, a.page, worst))
    end
end

------------------------------------------------------------------------
-- the Quick Turnaround Limit (FPPM p.76)
------------------------------------------------------------------------
local qt = {}
do
    local d = dump_page(76)
    local titles = {}
    for _, t in ipairs(d.T) do
        local f = t.text:match("^Flaps (%d+)$")
        if f and t.size > 9 then titles[#titles + 1] = {flaps = tonumber(f), y = t.y} end
    end
    table.sort(titles, function(a, b) return a.y > b.y end)
    check(#titles == 2 and titles[1].flaps == 30 and titles[2].flaps == 25, "FPPM p.76: the two tables' titles")
    local alltext = {}
    for _, t in ipairs(d.T) do alltext[#alltext + 1] = t.text end
    alltext = table.concat(alltext, " "):gsub("%s+", " ")
    check(alltext:find("Quick Turnaround Limit", 1, true), "FPPM p.76: not the quick turnaround limit")
    local function width(t) return #t.text * 0.5 * t.size end
    for n, ti in ipairs(titles) do
        local ybot = titles[n + 1] and titles[n + 1].y or 0
        local runs = {}
        for _, t in ipairs(d.T) do if t.y < ti.y and t.y > ybot then runs[#runs + 1] = t end end
        -- the heading row: -2000 ... 10000
        local cols, hy = {}, nil
        for _, t in ipairs(runs) do
            if t.text == "-2000" then hy = t.y end
        end
        check(hy, "FPPM p.76: flaps " .. ti.flaps .. ": no heading row")
        for _, t in ipairs(runs) do
            if abs(t.y - hy) < 0.5 and tonumber(t.text) then cols[#cols + 1] = {pa = tonumber(t.text), x = t.x + width(t) / 2} end
        end
        table.sort(cols, function(a, b) return a.x < b.x end)
        local pa = {}
        for i, cl in ipairs(cols) do pa[i] = cl.pa end
        check(table.concat(pa, ",") == "-2000,-1000,0,1000,2000,3000,4000,5000,6000,7000,8000,9000,10000",
            "FPPM p.76: flaps " .. ti.flaps .. ": the columns " .. table.concat(pa, ","))
        local xc_c, xc_f
        for _, t in ipairs(runs) do
            if abs(t.y - hy) < 0.5 and t.text:find("C$") then xc_c = t.x end
            if abs(t.y - hy) < 0.5 and t.text:find("F$") then xc_f = t.x end
        end
        check(xc_c and xc_f, "FPPM p.76: the OAT columns")
        -- the rows
        local rowy = {}
        for _, t in ipairs(runs) do
            if t.y < hy - 1 and abs(t.x - xc_c) < 6 and tonumber(t.text) then rowy[#rowy + 1] = {y = t.y, c = tonumber(t.text)} end
        end
        table.sort(rowy, function(a, b) return a.y > b.y end)
        local oat, rows = {}, {}
        for i, r in ipairs(rowy) do
            oat[i] = r.c
            local row = {}
            for k = 1, 13 do row[k] = false end
            local fcell
            for _, t in ipairs(runs) do
                if abs(t.y - r.y) < 0.5 and tonumber(t.text) and t.x > xc_c + 10 then
                    local cx = t.x + width(t) / 2
                    if abs(t.x - xc_f) < 8 then
                        fcell = tonumber(t.text)
                    else
                        local best, bk = 1e9, nil
                        for k, cl in ipairs(cols) do
                            if abs(cl.x - cx) < best then best, bk = abs(cl.x - cx), k end
                        end
                        check(best < 6 and row[bk] == false, fmt("FPPM p.76: flaps %d %d C: the cell %s", ti.flaps, r.c, t.text))
                        row[bk] = tonumber(t.text)
                    end
                end
            end
            check(fcell and abs(fcell - (r.c * 1.8 + 32)) < 0.6, fmt("FPPM p.76: flaps %d %d C: the F column %s", ti.flaps, r.c, tostring(fcell)))
            -- the blanks only at a row's high altitude end
            local seen_blank = false
            for k = 1, 13 do
                if row[k] == false then seen_blank = true else check(not seen_blank, "FPPM p.76: a blank inside a row") end
            end
            rows[i] = row
        end
        check(table.concat(oat, ",") == "50,40,30,20,10,0,-10,-20,-30,-40,-50", "FPPM p.76: the OAT rows " .. table.concat(oat, ","))
        qt.oat, qt.pa = oat, pa
        qt[ti.flaps] = rows
    end
    -- (the notes from pdftotext: the text runs break inside words, "Dec" "rease")
    local notes = pdftext(fppm_pdf, 76):gsub("%s+", " ")
    qt.up = tonumber(notes:match("Increase weight by (%d+) kg per 1%% uphill slope"))
    qt.down = tonumber(notes:match("Decrease weight by (%d+) kg per 1%% downhill slope"))
    qt.head = tonumber(notes:match("Increase weight by (%d+) kg per 10 knots headwind"))
    qt.tail = tonumber(notes:match("Decrease weight by (%d+) kg per 10 knots tailwind"))
    qt.brakes = tonumber(notes:match("Decrease weight by (%d+) kg when two brakes are deactivated"))
    qt.wait_min = tonumber(notes:match("wait at least (%d+) minutes"))
    check(qt.up and qt.down and qt.head and qt.tail and qt.brakes and qt.wait_min, "FPPM p.76: the notes")
end

------------------------------------------------------------------------
-- the data block
------------------------------------------------------------------------
local L = {}
local function w(s) L[#L + 1] = s end
local function num(v, dec)
    if v == false then return "false" end
    local s = fmt("%." .. (dec or 0) .. "f", v)
    if dec and dec > 0 then s = s:gsub("0+$", ""):gsub("%.$", "") end
    if s == "-0" then s = "0" end
    return s
end
local function pairs_list(list, d1, d2)
    local s = {}
    for i, p in ipairs(list) do s[i] = "{" .. num(p[1], d1) .. ", " .. num(p[2], d2) .. "}" end
    return s
end
local function wrap(items, indent, width)
    local lines, cur = {}, indent
    for i, it in ipairs(items) do
        local piece = it .. (i < #items and "," or "")
        if #cur + #piece + 1 > width and cur ~= indent then
            lines[#lines + 1] = cur:gsub("%s+$", "")
            cur = indent
        end
        cur = cur .. piece .. " "
    end
    lines[#lines + 1] = cur:gsub("%s+$", "")
    return lines
end

local function write_dist(d, indent)
    for _, flaps in ipairs({30, 25}) do
        local t = d[flaps]
        w(fmt("%s[%d] = {   -- %s p.%d (%s)", indent, flaps, d.src, t.page, t.sec))
        for _, cname in ipairs(COND_ORDER) do
            w(fmt("%s    %s = {", indent, cname))
            for _, b in ipairs(ROWS[cname]) do
                local r = t.rows[cname][b]
                local s = {}
                for i = 1, 13 do s[i] = num(r[i]) end
                w(fmt('%s        ["%s"] = {%s},', indent, b, table.concat(s, ", ")))
            end
            w(indent .. "    },")
        end
        w(indent .. "},")
    end
end

w("-- BEGIN GENERATED DATA (docs/overhaul/tools/efb_ldg_data.lua: do not edit by hand)")
w("-- Normal Configuration Landing Distance, a row a braking configuration:")
w("-- " .. table.concat({"ref", "wt_above", "wt_below", "alt", "head", "tail", "down", "up",
    "isa_above", "isa_below", "app", "rev2", "norev"}, ", "))
w("-- (M.COL), in the table's units: the distance and its adjustments in")
w("-- unit, the weight's in wt_unit per wt_step from ref_wt; factor: the")
w("-- slippery runways' (GOOD, MEDIUM, POOR) figures already times it;")
w("-- manual_spoilers: added to MAX MANUAL with manual spoilers; flare: the")
w("-- distance from 50 ft included (approximately).")
w("M.DIST = {")
for _, e in ipairs({0, 1}) do
    local d = dist[e]
    d.src = "FCOM"
    local t = d[30]
    w(fmt("    [%d] = {   -- %s", e, d.model))
    w(fmt('        unit = "%s", wt_unit = "%s", ref_wt = %d, wt_step = %d, factor = %s,', t.unit, t.wt_unit, t.ref_wt, t.wt_step, num(t.factor, 2)))
    w(fmt("        manual_spoilers = %d, flare = %d,", t.manual_spoilers, t.flare))
    write_dist(d, "        ")
    w("    },")
end
w("}")
w("-- the FPPM's tables (747-400F/PW4056, actual distances): not used by the")
w("-- functions; the test holds the FCOM's PW4056 tables against them")
do
    local t = fppm_dist[30]
    fppm_dist.src = "FPPM"
    w("M.FPPM_DIST = {")
    w(fmt('    unit = "%s", wt_unit = "%s", ref_wt = %d, wt_step = %d, factor = %s,', t.unit, t.wt_unit, t.ref_wt, t.wt_step, num(t.factor, 2)))
    w(fmt("    manual_spoilers = %d, flare = %d,", t.manual_spoilers, t.flare))
    write_dist(fppm_dist, "    ")
    w("}")
end

local function write_field(name, tbl, what)
    w(fmt("%s = {   -- %s", name, what))
    for _, flaps in ipairs({25, 30}) do
        local f = tbl[flaps]
        w(fmt("    [%d] = {   -- FPPM p.%d (%s)", flaps, f.page, f.sec))
        w(fmt("        fla = {%s, %s}, wt = {%s, %s}, manual_spoilers = %d,%s", num(f.fla[1]), num(f.fla[2]),
            num(f.wt[1], 2), num(f.wt[2], 2), f.manual_spoilers, f.f30_vapp_max and fmt(" f30_vapp_max = %d,", f.f30_vapp_max) or ""))
        w("        -- the guide lines: {ft at the REF LINE, ft at the far edge}")
        w(fmt("        wind = {head = %d, tail = %d,", f.wind.head, f.wind.tail))
        w("            head_lines = {")
        for _, l in ipairs(wrap(pairs_list(f.wind.head_lines, 0, 0), "                ", 100)) do w(l) end
        w("            },")
        w("            tail_lines = {")
        for _, l in ipairs(wrap(pairs_list(f.wind.tail_lines, 0, 0), "                ", 100)) do w(l) end
        w("            },")
        w("        },")
        if f.brakes then
            w("        brakes = {   -- NORMAL to TWO INOP")
            for _, l in ipairs(wrap(pairs_list(f.brakes, 0, 0), "            ", 100)) do w(l) end
            w("        },")
        end
        w("        wet = {   -- DRY to WET")
        for _, l in ipairs(wrap(pairs_list(f.wet, 0, 0), "            ", 100)) do w(l) end
        w("        },")
        w("        -- the pressure altitude lines: {ft, 1000 kg}")
        w("        alt = {" .. table.concat(f.alt, ", ") .. "},")
        w("        lines = {")
        for i, l in ipairs(f.lines) do
            w(fmt("            {   -- %d ft", f.alt[i]))
            for _, s in ipairs(wrap(pairs_list(l, 0, 2), "                ", 100)) do w(s) end
            w("            },")
        end
        w("        },")
        w("    },")
    end
    w("}")
end
write_field("M.FIELD", field, "Landing Field Limit, anti-skid operative")
write_field("M.FIELD_ASKID_INOP", field_inop, "Landing Field Limit, anti-skid inoperative")

w("M.CLIMB = {   -- Landing Climb Limit (the anti-skid inoperative pages repeat it)")
for _, flaps in ipairs({25, 30}) do
    local cl = climb[flaps]
    w(fmt("    [%d] = {   -- FPPM p.%d (%s)", flaps, cl.page, cl.sec))
    w(fmt("        pack1 = %d, pack0 = %d, ice = %d, ice_below_c = %d,", cl.pack1, cl.pack0, cl.ice, cl.ice_below_c))
    w("        alt = {" .. table.concat(cl.alt, ", ") .. "},")
    w("        lines = {   -- {OAT C, 1000 kg}")
    for i, l in ipairs(cl.lines) do
        w(fmt("            {   -- %d ft", cl.alt[i]))
        for _, s in ipairs(wrap(pairs_list(l, 2, 2), "                ", 100)) do w(s) end
        w("            },")
    end
    w("        },")
    w("    },")
end
w("}")

w("M.QT = {   -- Quick Turnaround Limit, FPPM p.76 (1.4.6): 1000 kg, false blank")
w("    oat = {" .. table.concat(qt.oat, ", ") .. "},")
w("    pa = {" .. table.concat(qt.pa, ", ") .. "},")
for _, flaps in ipairs({30, 25}) do
    w(fmt("    [%d] = {", flaps))
    for i, r in ipairs(qt[flaps]) do
        local s = {}
        for k = 1, 13 do s[k] = num(r[k]) end
        w(fmt("        {%s},   -- %d C", table.concat(s, ", "), qt.oat[i]))
    end
    w("    },")
end
w(fmt("    up = %d, down = %d, head = %d, tail = %d, brakes = %d, wait_min = %d,", qt.up, qt.down, qt.head, qt.tail, qt.brakes, qt.wait_min))
w("}")
w("-- END GENERATED DATA")

local block = table.concat(L, "\n")
local f = assert(io.open(model_path, "rb"))
local src = f:read("*a")
f:close()
local a = src:find("-- BEGIN GENERATED DATA", 1, true)
local b0, b1 = src:find("-- END GENERATED DATA", 1, true)
check(a and b1 and b1 > a, model_path .. ": no generated data markers")
local nl = src:find("\r\n", 1, true) and "\r\n" or "\n"
local new = src:sub(1, a - 1) .. block:gsub("\n", nl) .. src:sub(b1 + 1)
f = assert(io.open(model_path, "wb"))
f:write(new)
f:close()
io.write(fmt("wrote %s (%d lines of data)\n", model_path, #L))

------------------------------------------------------------------------
-- the record: scales, examples, the FCOM against the FPPM
------------------------------------------------------------------------
for _, c in ipairs(CHARTS) do
    local r = c.askid and field[c.flaps] or field_inop[c.flaps]
    io.write(fmt("FPPM p.%d flaps %d %s: field length %d-%d ft, weight %.1f-%.1f t, labels within %.2f pt, meter ticks within %.1f m;"
        .. " guide lines head %d tail %d brakes %d wet %d\n", c.page, c.flaps, c.askid and "anti-skid op" or "anti-skid inop",
        r.fla[1], r.fla[2], r.wt[1], r.wt[2], r.scale_worst[1], r.scale_worst[2], #r.wind.head_lines, #r.wind.tail_lines,
        r.brakes and #r.brakes or 0, #r.wet))
end
for _, e in ipairs(examples) do
    if e.kind == "field" then
        io.write(fmt("FPPM p.%d field example: %.0f ft, wind %.1f kt (to %.0f ft), meets the %d ft line (%.2f pt off) at %.0f ft, %.2f t; path %s\n",
            e.page, e.fla_ft, e.wind_kt or 0, e.wind_ft or 0, e.alt_ft, e.alt_off_pt, e.corner_ft, e.wt_t, table.concat(e.path, " ")))
    else
        io.write(fmt("FPPM p.%d climb example: %.2f C, the %d ft curve (%.2f pt off), %.2f t\n", e.page, e.oat_c, e.alt_ft, e.alt_off_pt, e.wt_t))
    end
end
do
    -- the FCOM's PW4056 (747-400, m) against the FPPM's (747-400F, ft)
    local worst = {}
    for _, flaps in ipairs({30, 25}) do
        for _, cname in ipairs(COND_ORDER) do
            for _, b in ipairs(ROWS[cname]) do
                local a = dist[0][flaps].rows[cname][b]
                local p = fppm_dist[flaps].rows[cname][b]
                local fac = cname == "DRY" and 1 or dist[0][flaps].factor
                for i = 1, 13 do
                    local am = a[i] / fac
                    local pm = p[i] * 0.3048
                    if i == 2 or i == 3 then pm = p[i] * 0.3048 end
                    local dd = am - pm
                    local k = i == 1 and "ref" or "adj"
                    if not worst[k] or abs(dd) > abs(worst[k].d) then
                        worst[k] = {d = dd, at = fmt("flaps %d %s %s col %d: FCOM %d m%s, FPPM %d ft = %.0f m", flaps, cname, b, i, a[i],
                            fac ~= 1 and fmt(" / %.2f = %.0f m", fac, am) or "", p[i], pm)}
                    end
                end
            end
        end
    end
    io.write(fmt("FCOM PW4056 - FPPM: reference distances at most %.0f m (%s); adjustments at most %.0f m (%s)\n",
        worst.ref.d, worst.ref.at, worst.adj.d, worst.adj.at))
end

if overlay_path then
    local o = assert(io.open(overlay_path, "wb"))
    o:write(table.concat(overlay, "\n"), "\n")
    o:close()
    io.write(fmt("overlay: %s (%d polylines)\n", overlay_path, #overlay))
end
