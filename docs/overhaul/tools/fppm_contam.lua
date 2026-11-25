-- fppm_contam.lua: the data part of
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_contam_model.lua
-- (2026-11-25, the EFB's takeoff on contaminated runways) from the text runs
-- of the 747-400F/PW4056 FPPM's (D632U002-RZ043) ADVISORY INFORMATION
-- tables (_ref/1059530115-74F-FPPM.pdf):
--   TO   p.36-40 (1.2.12-16)   slush/standing water, slippery runway
--   TO1  p.48-53 (1.3.2-7)     the same at 8 % thrust reduction
--   TO2  p.60-65 (1.3.14-19)   the same at 20 % thrust reduction
-- each with 2 engine reverse thrust and no reverse thrust: 36 tables
-- (Weight Adjustment, VMCG Limit Weight, V1 Adjustment for each rating,
-- contaminant and reverse thrust). LuaJIT:
--
--   luajit docs/overhaul/tools/fppm_contam.lua <FPPM pdf> [model.lua] [dump dir]
--
-- writes the data between the model's "-- BEGIN GENERATED DATA" and
-- "-- END GENERATED DATA" lines (stdout without a model; the rest of the
-- model is kept), the tables as printed grids to <dump dir>/fppm_contam_grids.txt
-- (to lay beside the page images, _ref/text/img/FPPM), a summary to stderr.
-- [dump dir]: where pdf_paths.lua's page dumps go (default %TEMP%); with
-- FPPM_CONTAM_REUSE=1 the dumps already there are read again.
--
-- How the pages are read (pdf_paths.lua's text runs, page points):
--  - each page's title (12 pt), its thrust reduction and reverse thrust
--    lines and the tables' titles (10 pt) checked against the page list
--    below, the section number from the footer;
--  - a table: the region from its title down to the next title; its 9
--    columns the "S.L.", "4000", "8000" headings (3 times, in that order),
--    grouped under the 3 depth ("0.12 INCHES (3mm)" ...) or braking action
--    (GOOD, MEDIUM, POOR) headings, each group heading checked over its 3
--    columns; the rows the numbers in the left column (a uniform step
--    checked); every number of the 7 pt cell size placed in its row (same
--    baseline) and its column (the nearest heading centre, Times widths),
--    two numbers in one cell or one off every column an error; a blank
--    cell is no run there;
--  - checked: each column's printed cells one unbroken run; the VMCG limit
--    weights rising with the field length; the weight adjustment's
--    adjusted weight (limit weight + adjustment) rising with the limit
--    weight (the model holds the edge row past the table on that);
--  - the notes under the tables (8 pt runs, joined line by line: the runs
--    break inside words) checked for the method (the table entered with
--    the derate's field/obstacle limit weight, the lesser of the two
--    weights, V1 = VMCG when VMCG limited, not below VMCG) and read for the
--    flaps 10 changes, signed as printed.
local fmt = string.format

local pdf, model_path, dump_dir = arg[1], arg[2], arg[3]
if not pdf then
    io.stderr:write("usage: luajit fppm_contam.lua <FPPM pdf> [model.lua] [dump dir]\n")
    os.exit(2)
end
if model_path == "" then model_path = nil end
dump_dir = dump_dir or os.getenv("TEMP") or "."
local tool_dir = arg[0]:match("^(.*)[/\\]") or "."
local reuse = os.getenv("FPPM_CONTAM_REUSE") == "1"

local function check(cond, msg)
    if not cond then error("fppm_contam: " .. msg, 0) end
end
local function log(...) io.stderr:write(fmt(...), "\n") end

-- the pages: {page, rating %, kind, reverse thrust engines, tables on it}
local PAGES = {
    {36, 0, "SLUSH", 2, {"wa", "vmcg", "v1"}},
    {37, 0, "SLUSH", 0, {"wa", "vmcg", "v1"}},
    {38, 0, "SLIPPERY", 2, {"wa", "vmcg"}},
    {39, 0, "SLIPPERY", 2, {"v1"}},
    {40, 0, "SLIPPERY", 0, {"wa", "vmcg", "v1"}},
    {48, 8, "SLUSH", 2, {"wa", "vmcg", "v1"}},
    {49, 8, "SLUSH", 0, {"wa", "vmcg", "v1"}},
    {50, 8, "SLIPPERY", 2, {"wa", "vmcg"}},
    {51, 8, "SLIPPERY", 2, {"v1"}},
    {52, 8, "SLIPPERY", 0, {"wa", "vmcg"}},
    {53, 8, "SLIPPERY", 0, {"v1"}},
    {60, 20, "SLUSH", 2, {"wa", "vmcg", "v1"}},
    {61, 20, "SLUSH", 0, {"wa", "vmcg", "v1"}},
    {62, 20, "SLIPPERY", 2, {"wa", "vmcg"}},
    {63, 20, "SLIPPERY", 2, {"v1"}},
    {64, 20, "SLIPPERY", 0, {"wa", "vmcg"}},
    {65, 20, "SLIPPERY", 0, {"v1"}},
}
local PREFIX = {[0] = "", [8] = "TO1 ", [20] = "TO2 "}
local KIND_TITLE = {SLUSH = "Slush/Standing Water Takeoff", SLIPPERY = "Slippery Runway Takeoff"}
local REV_TITLE = {[2] = "2 Engine Reverse Thrust", [0] = "No Reverse Thrust"}
local TABLE_TITLE = {wa = "Weight Adjustment (1000 KG)", vmcg = "VMCG Limit Weight (1000 KG)",
    v1 = "V1 Adjustment (KIAS)"}
local ROW_STEP = {wa = -20, vmcg = 400, v1 = -20}
local ALT = {"S.L.", "4000", "8000"}
local ALT_FT = {0, 4000, 8000}
local BRAKING = {"GOOD", "MEDIUM", "POOR"}

------------------------------------------------------------------------
-- pdf_paths.lua's page dumps: the text runs
------------------------------------------------------------------------
local function dump_page(page)
    local out = dump_dir .. "/fppm_contam_p" .. page .. ".txt"
    local f = reuse and io.open(out, "rb")
    if f then
        f:close()
    else
        local chunk = assert(loadfile(tool_dir .. "/pdf_paths.lua"))
        local saved, saved_print = arg, print
        arg = {[0] = "pdf_paths.lua", pdf, tostring(page), out}
        print = function() end
        chunk()
        arg, print = saved, saved_print
    end
    local runs = {}
    for line in io.lines(out) do
        line = line:gsub("\r$", "")
        if line:sub(1, 2) == "T " then
            local x, y, size, ang, text = line:match("^T (%S+) (%S+) (%S+) (%S+) ?(.*)$")
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if text ~= "" then
                runs[#runs + 1] = {x = tonumber(x), y = tonumber(y), size = tonumber(size), ang = tonumber(ang),
                    text = text, raw = line:match("^T %S+ %S+ %S+ %S+ ?(.*)$")}
            end
        end
    end
    return runs
end

local function near(a, b, tol) return math.abs(a - b) <= tol end

-- a run's width (pt) by Times-Roman's widths (the tables' font), 1/1000 em
local TIMES = {["-"] = 333, ["."] = 250, [" "] = 250, S = 556, L = 611}
local function width(r)
    local w = 0
    for c in r.text:gmatch(".") do w = w + (TIMES[c] or 500) end
    return w * r.size / 1000
end
local function centre(r) return r.x + width(r) / 2 end

local function find_runs(runs, pred)
    local out = {}
    for _, r in ipairs(runs) do
        if pred(r) then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) return a.x < b.x end)
    return out
end

------------------------------------------------------------------------
-- a table in its region (y between lo and hi)
------------------------------------------------------------------------
local function read_table(runs, kind, name, lo, hi, where)
    local function inside(r) return r.y > lo and r.y < hi end
    local cell_size = 6.96
    local function small(r) return inside(r) and near(r.size, cell_size, 0.05) and r.ang == 0 end
    -- the altitude headings: S.L., 4000, 8000 three times on one line
    local sl = find_runs(runs, function(r) return small(r) and r.text == "S.L." end)
    check(#sl == 3, where .. ": " .. #sl .. " S.L. headings")
    local hy = sl[1].y
    local heads = find_runs(runs, function(r)
        return small(r) and near(r.y, hy, 0.3) and (r.text == "S.L." or r.text == "4000" or r.text == "8000")
    end)
    check(#heads == 9, where .. ": " .. #heads .. " altitude headings")
    local cols = {}
    for i, h in ipairs(heads) do
        check(h.text == ALT[(i - 1) % 3 + 1], where .. ": heading " .. i .. " " .. h.text)
        cols[i] = centre(h)
    end
    local pa = find_runs(runs, function(r) return small(r) and r.text == "PRESSURE ALTITUDE (FT)" end)
    check(#pa == 3, where .. ": " .. #pa .. " PRESSURE ALTITUDE headings")
    -- the groups: depth (mm) or braking action, each over its 3 columns
    local groups = {}
    local top = kind == "SLUSH" and "SLUSH/STANDING WATER DEPTH" or "REPORTED BRAKING ACTION"
    check(#find_runs(runs, function(r) return small(r) and r.text == top end) == 1, where .. ": no " .. top)
    local g = find_runs(runs, function(r)
        if not small(r) or r.y <= hy then return false end
        if kind == "SLUSH" then return r.text:match("^0%.%d%d INCHES %(%d+mm%)$") ~= nil end
        return r.text == "GOOD" or r.text == "MEDIUM" or r.text == "POOR"
    end)
    check(#g == 3, where .. ": " .. #g .. " group headings")
    for i, r in ipairs(g) do
        local c = centre(r)
        check(c > cols[3 * i - 2] and c < cols[3 * i], where .. ": group heading " .. r.text .. " not over its columns")
        if kind == "SLUSH" then
            local inch, mm = r.text:match("^(0%.%d%d) INCHES %((%d+)mm%)$")
            groups[i] = {mm = tonumber(mm), inch = tonumber(inch)}
        else
            check(r.text == BRAKING[i], where .. ": braking action " .. i .. " " .. r.text)
            groups[i] = {braking = r.text}
        end
    end
    -- the left column's headings
    local left = cols[1] - 30
    local lefts = {}
    local lr = find_runs(runs, function(r) return small(r) and r.x < left and r.y > hy - 1 end)
    table.sort(lr, function(a, b) return a.y > b.y end)
    for _, r in ipairs(lr) do lefts[#lefts + 1] = r.text end
    local left_text = table.concat(lefts, " ")
    -- the rows: the numbers in the left column below the headings
    local rows = find_runs(runs, function(r)
        return small(r) and r.y < hy - 2 and r.x < left and r.text:match("^%d+$") ~= nil
    end)
    table.sort(rows, function(a, b) return a.y > b.y end)
    check(#rows >= 2, where .. ": " .. #rows .. " rows")
    local t = {rows = {}, cells = {}, groups = groups, left = left_text}
    for i, r in ipairs(rows) do
        t.rows[i] = tonumber(r.text)
        t.cells[i] = {}
        if i > 1 then
            check(t.rows[i] - t.rows[i - 1] == ROW_STEP[name],
                fmt("%s: rows %d to %d not a %d step", where, t.rows[i - 1], t.rows[i], ROW_STEP[name]))
        end
    end
    -- the cells
    local n = 0
    t.split = {}
    local function row_of(r)
        local ri
        for i, rr in ipairs(rows) do
            if near(rr.y, r.y, 0.6) then ri = i end
        end
        check(ri, fmt("%s: %s at y %.2f in no row", where, r.text, r.y))
        return ri
    end
    for _, r in ipairs(runs) do
        if small(r) and r.y < hy - 2 and r.text:match("^%-%d+%-%d") then
            -- a whole row as one run: pdf_paths.lua splits a TJ run only at
            -- gaps below -300, and these rows are spaced by character
            -- spacing (Tc 5.569) with +5560 kerns pulling each number's
            -- digits together (p.49, p.53). Found by its text (two or more
            -- signed numbers run together; before pdf_paths.lua's TJ fix of
            -- 2026-11-25, by its x of about -534). Taken only as 9 signed
            -- numbers (every column printed), left to right; pdftotext's
            -- reading below checks them.
            local nums = {}
            for s in r.text:gmatch("%-%d+") do nums[#nums + 1] = tonumber(s) end
            check(#nums == 9 and table.concat(nums) == r.text,
                fmt("%s: a run off the columns that is not 9 signed numbers: %s", where, r.text))
            local ri = row_of(r)
            for j = 1, 9 do
                check(t.cells[ri][j] == nil, fmt("%s: two numbers in row %d column %d", where, t.rows[ri], j))
                t.cells[ri][j] = nums[j]
            end
            n = n + 9
            t.split[#t.split + 1] = t.rows[ri]
        elseif small(r) and r.y < hy - 2 and r.x >= left then
            check(r.text:match("^%-?%d+$") ~= nil, where .. ": not a number in the table: " .. r.text)
            local ri = row_of(r)
            local c, best = nil, 1e9
            local x = centre(r)
            for j = 1, 9 do
                local d = math.abs(x - cols[j])
                if d < best then c, best = j, d end
            end
            check(best < 10, fmt("%s: %s at x %.2f off the columns (%.1f pt)", where, r.text, r.x, best))
            check(t.cells[ri][c] == nil, fmt("%s: two numbers in row %d column %d", where, t.rows[ri], c))
            t.cells[ri][c] = tonumber(r.text)
            n = n + 1
        end
    end
    t.n = n
    -- each column's printed cells one unbroken run
    for j = 1, 9 do
        local first, last, count = nil, nil, 0
        for i = 1, #rows do
            if t.cells[i][j] then
                first = first or i
                last = i
                count = count + 1
            end
        end
        check(count == 0 or last - first + 1 == count, fmt("%s: column %d has a blank between printed cells", where, j))
        if name == "vmcg" then
            for i = (first or 1) + 1, last or 0 do
                check(t.cells[i][j] > t.cells[i - 1][j], fmt("%s: column %d not rising at %d ft", where, j, t.rows[i]))
            end
        elseif name == "wa" then
            for i = (first or 1) + 1, last or 0 do
                check(t.rows[i] + t.cells[i][j] < t.rows[i - 1] + t.cells[i - 1][j],
                    fmt("%s: column %d's adjusted weight not falling at %d t", where, j, t.rows[i]))
            end
        end
    end
    t.lowest_cell_y = rows[#rows].y
    return t
end

-- the notes under a table: 8 pt runs between lo and hi, joined line by line
local function read_notes(runs, lo, hi)
    local ls = {}
    for _, r in ipairs(runs) do
        if r.y > lo and r.y < hi and near(r.size, 7.98, 0.05) then
            local line
            for _, l in ipairs(ls) do
                if near(l.y, r.y, 0.5) then line = l end
            end
            if not line then
                line = {y = r.y, runs = {}}
                ls[#ls + 1] = line
            end
            line.runs[#line.runs + 1] = r
        end
    end
    table.sort(ls, function(a, b) return a.y > b.y end)
    local notes = {}
    for _, l in ipairs(ls) do
        table.sort(l.runs, function(a, b) return a.x < b.x end)
        local num = l.runs[1].text:match("^(%d)%.$")
        local parts = {}
        for i = num and 2 or 1, #l.runs do parts[#parts + 1] = l.runs[i].raw end
        local s = table.concat(parts)
        if num then
            check(tonumber(num) == #notes + 1, "note " .. num .. " out of order")
            notes[#notes + 1] = s
        else
            check(#notes > 0, "a note line before note 1: " .. s)
            notes[#notes] = notes[#notes] .. " " .. s
        end
    end
    for i, s in ipairs(notes) do notes[i] = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "") end
    return notes
end

-- the cross-check: pdftotext's (xpdf) own reading of the page ("-table"
-- keeps a row on one line), each row's numbers left to right against the
-- printed cells read from the positions
local PDFTOTEXT = os.getenv("PDFTOTEXT") or "pdftotext"
local function pdftext_lines(page)
    local h = assert(io.popen(fmt('%s -table -f %d -l %d "%s" -', PDFTOTEXT, page, page, pdf), "r"))
    local s = h:read("*a")
    h:close()
    check(s and #s > 200, "pdftotext gave nothing for page " .. page)
    local lines = {}
    for l in s:gmatch("[^\n]*") do lines[#lines + 1] = l:gsub("\r$", "") end
    return lines
end

local function cross_check(lines, title, t, where)
    local k
    for i, l in ipairs(lines) do
        if l:find(title, 1, true) then k = i end
    end
    check(k, where .. ": pdftotext has no " .. title)
    for ri, row in ipairs(t.rows) do
        local nums
        while not nums do
            k = k + 1
            check(lines[k], fmt("%s: pdftotext has no row %d", where, row))
            local label, rest = lines[k]:match("^%s*(%d+)(.*)$")
            if label == tostring(row) then
                nums = {}
                for tok in rest:gmatch("%S+") do
                    check(tok:match("^%-?%d+$"), fmt("%s: pdftotext row %d: %s", where, row, tok))
                    nums[#nums + 1] = tonumber(tok)
                end
            end
        end
        local mine = {}
        for j = 1, 9 do
            if t.cells[ri][j] then mine[#mine + 1] = t.cells[ri][j] end
        end
        check(table.concat(nums, " ") == table.concat(mine, " "),
            fmt("%s row %d: pdftotext %s, the runs %s", where, row, table.concat(nums, " "), table.concat(mine, " ")))
    end
end

local function flaps10(text, what, where)
    local l = text:lower()
    local cond, verb, n
    if what == "vmcg" then
        cond, verb, n = l:match("for flaps 10(.-), (%a+) vmcg limit%a* weight by (%d+) kg")
    else
        cond, verb, n = l:match("for flaps 10(.-), (%a+) v1 by [%a ]-(%d+) kts?%.")
    end
    check(verb, where .. ": no flaps 10 note: " .. text)
    check(verb == "decrease" or verb == "increase", where .. ": flaps 10 note's verb " .. verb)
    local c
    if cond ~= "" then
        c = cond:match("^ and (%a+) reported braking action$")
        check(c, where .. ": flaps 10 note's condition '" .. cond .. "'")
        c = c:upper()
    end
    return (verb == "decrease" and -1 or 1) * tonumber(n), c, verb
end

------------------------------------------------------------------------
-- the pages
------------------------------------------------------------------------
local DATA = {}            -- DATA[rating][kind][rev][name] = table
local grids = {}
local total_cells, total_tables = 0, 0
local misprints = {}
local suspects = {}

for _, p in ipairs(PAGES) do
    local page, rating, kind, rev, names = p[1], p[2], p[3], p[4], p[5]
    local runs = dump_page(page)
    local plines = pdftext_lines(page)
    local where = "p." .. page
    local function one(pred, what)
        local l = find_runs(runs, pred)
        check(#l == 1, where .. ": " .. #l .. " " .. what)
        return l[1]
    end
    -- the page's titles
    one(function(r) return r.text == "ADVISORY INFORMATION" end, "ADVISORY INFORMATION")
    local title = one(function(r) return near(r.size, 12, 0.05) end, "page titles")
    check(title.text == PREFIX[rating] .. KIND_TITLE[kind], where .. ": title " .. title.text)
    if rating > 0 then
        one(function(r) return r.text == rating .. "% Thrust Reduction" end, rating .. "% Thrust Reduction")
    end
    one(function(r) return r.text == REV_TITLE[rev] end, REV_TITLE[rev])
    local sec = one(function(r) return near(r.size, 10.98, 0.05) and r.text:match("^1%.%d+%.%d+$") end, "section numbers").text
    -- the tables' titles, top to bottom
    local titles = find_runs(runs, function(r)
        return near(r.size, 9.96, 0.05) and (r.text == TABLE_TITLE.wa or r.text == TABLE_TITLE.vmcg or r.text == TABLE_TITLE.v1)
    end)
    table.sort(titles, function(a, b) return a.y > b.y end)
    check(#titles == #names, where .. ": " .. #titles .. " tables")
    DATA[rating] = DATA[rating] or {}
    DATA[rating][kind] = DATA[rating][kind] or {}
    DATA[rating][kind][rev] = DATA[rating][kind][rev] or {}
    local D = DATA[rating][kind][rev]
    for i, name in ipairs(names) do
        check(titles[i].text == TABLE_TITLE[name], where .. ": table " .. i .. " " .. titles[i].text)
        local hi = titles[i].y
        local lo = titles[i + 1] and titles[i + 1].y or 60
        local w = where .. " " .. name
        local t = read_table(runs, kind, name, lo, hi, w)
        t.page, t.sec = page, sec
        cross_check(plines, TABLE_TITLE[name], t, w)
        if #t.split > 0 then
            log("%s: rows %s read from merged runs (pdf_paths.lua TJ), checked by pdftotext", w, table.concat(t.split, ", "))
        end
        if name ~= "vmcg" then
            for ri, row in ipairs(t.rows) do
                for j = 1, 9 do
                    if (t.cells[ri][j] or 0) > 0 then
                        suspects[#suspects + 1] = fmt("%s (%s) row %d column %d: %d printed positive", w, sec, row, j, t.cells[ri][j])
                    end
                end
            end
        end
        -- the left column's heading
        if name == "wa" then
            local want = (rating > 0 and (PREFIX[rating]:gsub(" ", "") .. " ") or "") .. "FIELD/OBSTACLE LIMIT WEIGHT (1000 KG)"
            check(t.left == want, w .. ": left heading '" .. t.left .. "'")
        elseif name == "vmcg" then
            check(t.left == "FIELD LENGTH AVAILABLE (FT)", w .. ": left heading '" .. t.left .. "'")
        else
            check(t.left == "WEIGHT (1000 KG)", w .. ": left heading '" .. t.left .. "'")
        end
        -- the notes
        local notes = read_notes(runs, lo, t.lowest_cell_y)
        if name == "vmcg" then
            check(#notes == 3, w .. ": " .. #notes .. " notes")
            local n1 = notes[1]:lower()
            local entered = (rating > 0 and PREFIX[rating]:lower() or "") .. "field/obstacle limit weight"
            check(n1:find("enter weight adjustment table with", 1, true) and n1:find(entered, 1, true),
                w .. ": note 1 " .. notes[1])
            check(notes[2]:lower():find("find vmcg limit%a* weight for available field length and pressure altitude"),
                w .. ": note 2 " .. notes[2])
            check(notes[3]:lower():find("limited weight is lesser of weights from 1 and 2", 1, true),
                w .. ": note 3 " .. notes[3])
            t.f10, t.f10_cond, t.f10_verb = flaps10(notes[2], "vmcg", w)
            check(t.f10_cond == nil or t.f10_cond == "POOR", w .. ": flaps 10 for " .. tostring(t.f10_cond))
            check((kind == "SLUSH") == (t.f10_cond == nil), w .. ": flaps 10 condition")
            t.f10 = t.f10 * 1           -- kg
            if t.f10 > 0 then misprints[#misprints + 1] = fmt("p.%d (%s): %s", page, sec, notes[2]) end
            t.notes = notes
        elseif name == "v1" then
            check(#notes == 2, w .. ": " .. #notes .. " notes")
            check(notes[1]:lower() == "obtain v1, vr and v2 for the actual weight.", w .. ": note 1 " .. notes[1])
            local n2 = notes[2]:lower():gsub("%s*=%s*", " = ")
            check(n2:find("if vmcg limited, set v1 = vmcg.", 1, true) == 1, w .. ": note 2 " .. notes[2])
            check(n2:find("if not vmcg limited, enter v1 adjustment table with the actual weight", 1, true),
                w .. ": note 2 " .. notes[2])
            check(n2:find("if adjusted v1 is less than vmcg, set v1 = vmcg.", 1, true), w .. ": note 2 " .. notes[2])
            t.f10, t.f10_cond, t.f10_verb = flaps10(notes[2], "v1", w)
            check((kind == "SLUSH") == (t.f10_cond == nil) and (t.f10_cond == nil or t.f10_cond == "GOOD"),
                w .. ": flaps 10 condition")
            t.notes = notes
        else
            check(#notes == 0, w .. ": notes between the weight adjustment and VMCG tables")
        end
        D[name] = t
        total_cells = total_cells + t.n
        total_tables = total_tables + 1
        -- the grid
        local gl = {fmt("p.%d (%s) %s%s, %s: %s, %d cells", page, sec, PREFIX[rating], KIND_TITLE[kind], REV_TITLE[rev],
            TABLE_TITLE[name], t.n)}
        local h = {"      "}
        for gi = 1, 3 do
            local gname = kind == "SLUSH" and (t.groups[gi].mm .. " mm") or t.groups[gi].braking
            h[#h + 1] = fmt("| %-17s", gname)
        end
        gl[#gl + 1] = table.concat(h)
        for ri, row in ipairs(t.rows) do
            local s = {fmt("%6d", row)}
            for j = 1, 9 do
                if (j - 1) % 3 == 0 then s[#s + 1] = " |" end
                s[#s + 1] = t.cells[ri][j] and fmt("%5d", t.cells[ri][j]) or "    ."
            end
            gl[#gl + 1] = table.concat(s)
        end
        for k, s in ipairs(t.notes or {}) do gl[#gl + 1] = "  " .. k .. ". " .. s end
        grids[#grids + 1] = table.concat(gl, "\n")
    end
end
check(total_tables == 36, total_tables .. " tables")

-- every page's columns the same: 3, 6, 13 mm; GOOD, MEDIUM, POOR
for _, rating in ipairs({0, 8, 20}) do
    for _, kind in ipairs({"SLUSH", "SLIPPERY"}) do
        for _, rev in ipairs({2, 0}) do
            for _, name in ipairs({"wa", "vmcg", "v1"}) do
                local t = DATA[rating][kind][rev][name]
                check(t, fmt("no %s table for %d %% %s %d", name, rating, kind, rev))
                for gi = 1, 3 do
                    if kind == "SLUSH" then
                        check(t.groups[gi].mm == ({3, 6, 13})[gi], fmt("p.%d: depth %d", t.page, t.groups[gi].mm))
                        check(t.groups[gi].inch == ({0.12, 0.25, 0.5})[gi], fmt("p.%d: inches", t.page))
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- the generated data
------------------------------------------------------------------------
local OUT = {}
local function out(s) OUT[#OUT + 1] = s end
out("-- BEGIN GENERATED DATA (docs/overhaul/tools/fppm_contam.lua from")
out("-- _ref/1059530115-74F-FPPM.pdf's text runs; do not edit by hand)")
out("--")
out("-- M.DATA[rating %][kind][reverse thrust engines] = {wa, vmcg, v1}, the")
out("-- FPPM's ADVISORY INFORMATION tables (747-400F/PW4056, D632U002-RZ043):")
out("--   wa    Weight Adjustment (1000 KG), rows the field/obstacle limit")
out("--         weight (1000 kg; the derate's own for TO1 and TO2)")
out("--   vmcg  VMCG Limit Weight (1000 KG), rows the field length available (ft)")
out("--   v1    V1 Adjustment (KIAS), rows the (actual) weight (1000 kg)")
out("-- A row as printed: {row, then 3 columns (S.L., 4000, 8000 ft pressure")
out("-- altitude) for each of 3 mm, 6 mm, 13 mm slush/standing water depth or")
out("-- GOOD, MEDIUM, POOR reported braking action}; false a blank cell.")
out("-- f10: the notes' flaps 10 change as printed (vmcg kg, v1 kt; + an")
out("-- increase), f10_cond the braking action it is for (nil: every column).")
out("-- n: the table's printed cells.")
out(fmt("M.TABLE_COUNT = %d", total_tables))
out(fmt("M.CELL_COUNT = %d", total_cells))
out("M.DEPTH_MM = {3, 6, 13}            -- 0.12, 0.25, 0.50 INCHES")
out("M.BRAKING_COLS = {GOOD = 1, MEDIUM = 2, POOR = 3}")
out("M.ALT_FT = {0, 4000, 8000}         -- S.L., 4000, 8000")
out("M.DATA = {")
for _, rating in ipairs({0, 8, 20}) do
    out(fmt("    [%d] = {", rating))
    for _, kind in ipairs({"SLUSH", "SLIPPERY"}) do
        out(fmt("        %s = {", kind))
        for _, rev in ipairs({2, 0}) do
            out(fmt("            [%d] = {", rev))
            for _, name in ipairs({"wa", "vmcg", "v1"}) do
                local t = DATA[rating][kind][rev][name]
                out(fmt("                -- FPPM p.%d (%s) %s%s, %s, %s", t.page, t.sec, PREFIX[rating], KIND_TITLE[kind],
                    REV_TITLE[rev], TABLE_TITLE[name]))
                local head = fmt("                %s = {page = %d, sec = \"%s\", n = %d,", name, t.page, t.sec, t.n)
                if t.f10 then
                    head = head .. fmt(" f10 = %d,", t.f10)
                    if t.f10_cond then head = head .. fmt(" f10_cond = \"%s\",", t.f10_cond) end
                end
                out(head)
                for ri, row in ipairs(t.rows) do
                    local s = {tostring(row)}
                    for j = 1, 9 do s[#s + 1] = t.cells[ri][j] and tostring(t.cells[ri][j]) or "false" end
                    out("                    {" .. table.concat(s, ", ") .. "},")
                end
                out("                },")
            end
            out("            },")
        end
        out("        },")
    end
    out("    },")
end
out("}")
out("-- END GENERATED DATA")

local gf = assert(io.open(dump_dir .. "/fppm_contam_grids.txt", "wb"))
gf:write(table.concat(grids, "\n\n"), "\n")
gf:close()
log("%d tables, %d cells; grids in %s/fppm_contam_grids.txt", total_tables, total_cells, dump_dir)
for _, m in ipairs(misprints) do log("flaps 10 VMCG note printed as an increase: %s", m) end
for _, m in ipairs(suspects) do log("suspect: %s", m) end

local data = table.concat(OUT, "\n") .. "\n"
if not model_path then
    io.write(data)
    return
end
local f = assert(io.open(model_path, "rb"))
local src = f:read("*a")
f:close()
local crlf = src:find("\r\n", 1, true) ~= nil
src = src:gsub("\r\n", "\n")
local a = src:find("%-%- BEGIN GENERATED DATA")
local _, b = src:find("%-%- END GENERATED DATA\n")
check(a and b, model_path .. ": no generated data markers")
src = src:sub(1, a - 1) .. data .. src:sub(b + 1)
if crlf then src = src:gsub("\n", "\r\n") end
f = assert(io.open(model_path, "wb"))
f:write(src)
f:close()
log("data written to %s", model_path)
