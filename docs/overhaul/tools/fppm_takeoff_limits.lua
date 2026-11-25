-- fppm_takeoff_limits.lua: the data part of
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_limits_model.lua
-- (2026-11-25, the EFB's takeoff performance) from the vector drawings of
-- four charts of the 747-400F/PW4056 FPPM (_ref/1059530115-74F-FPPM.pdf):
--   p.29 (1.2.5)  Takeoff Climb Limit, flaps 10
--   p.30 (1.2.6)  Takeoff Climb Limit, flaps 20
--   p.33 (1.2.9)  Tire Speed Limit (235 mph tires), flaps 10
--   p.34 (1.2.10) Brake Energy Limit VMBE, flaps 10 and 20
-- Each page is first dumped by pdf_paths.lua (same folder):
--   luajit docs/overhaul/tools/pdf_paths.lua _ref/1059530115-74F-FPPM.pdf 29 <dir>/p29.txt
--   (and 30, 33, 34)
-- then
--   luajit docs/overhaul/tools/fppm_takeoff_limits.lua <dir> [model.lua]
-- writes the data between the model's "-- BEGIN GENERATED DATA" and
-- "-- END GENERATED DATA" lines (stdout without a model), and the
-- calibration, the curve identification and the printed examples to stderr.
--
-- How the drawings are read (see the stderr report for the numbers):
--   axes   each axis from its tick marks (short solid strokes on the thick
--          axis line) and the numbers printed by them (least squares,
--          residuals reported), checked against the long grid lines (each
--          should fall on a round value) and, on the climb and tire charts,
--          against the degF ticks (deg F = 32 + 1.8 deg C).
--   curves the solid strokes of the curves' width inside the plot; each
--          curve gets the rotated number printed on it (nearest stroke;
--          one number a curve, checked against the curves' order: lower
--          altitude heavier, colder OAT line further right, lighter weight
--          line higher). The VMBE chart's OAT labels sit in a row along
--          the lines' ends (50 C's nearer 60 C's line): paired in that row.
--   limits the climb charts' ENVIRONMENTAL LIMIT and ASSUMED TEMPERATURE
--          LIMIT lines by the labels printed along them; the VMBE chart's
--          shaded area is its grey fill; the VMBE chart's right part has
--          no scale across, so its unlabelled grid columns are the unit.
--   notes  the numbers of the notes under the charts and in the VMBE table,
--          from the page text.
-- Curves are thinned (Douglas-Peucker, 0.12 pt) and rounded to 0.01 deg C
-- and 0.1 t (VMBE chart: 0.01 of 1000 ft, 0.001 grid column, 0.1 kt): the
-- model stays within 0.15 t of the drawn climb and tire curves.
local DIR, MODEL = arg[1], arg[2]
if not DIR then
    io.stderr:write("usage: luajit fppm_takeoff_limits.lua <dump dir> [model.lua]\n")
    os.exit(2)
end
local abs, floor, sqrt, huge = math.abs, math.floor, math.sqrt, math.huge
local function log(fmt, ...) io.stderr:write(string.format(fmt, ...), "\n") end

------------------------------------------------------------------------
-- the dump
------------------------------------------------------------------------
local function parse_pts(s)
    local pts = {}
    for x, y in s:gmatch("([%-%d%.]+),([%-%d%.]+)") do pts[#pts + 1] = {tonumber(x), tonumber(y)} end
    return pts
end

local function load_page(n)
    local path = DIR .. "/p" .. n .. ".txt"
    local f = assert(io.open(path, "rb"), "no " .. path .. " (run pdf_paths.lua first)")
    local pg = {n = n, paths = {}, texts = {}}
    for line in f:lines() do
        line = line:gsub("\r$", "")
        local k = line:sub(1, 2)
        if k == "S " then
            local lw, col, dash, pts = line:match("^S (%S+) (%S+) (%S+) : (.*)$")
            pg.paths[#pg.paths + 1] = {kind = "S", lw = tonumber(lw), col = col, dash = dash, pts = parse_pts(pts)}
        elseif k == "F " then
            local col, pts = line:match("^F (%S+) : (.*)$")
            pg.paths[#pg.paths + 1] = {kind = "F", col = col, pts = parse_pts(pts)}
        elseif k == "T " then
            local x, y, size, ang, text = line:match("^T (%S+) (%S+) (%S+) (%S+) ?(.*)$")
            pg.texts[#pg.texts + 1] = {x = tonumber(x), y = tonumber(y), size = tonumber(size),
                ang = tonumber(ang), text = text}
        end
    end
    f:close()
    return pg
end

------------------------------------------------------------------------
-- geometry
------------------------------------------------------------------------
local function seg_dist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and ((px - ax) * dx + (py - ay) * dy) / l2 or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local qx, qy = ax + t * dx - px, ay + t * dy - py
    return sqrt(qx * qx + qy * qy)
end

local function poly_dist(px, py, pts)
    local d = huge
    for i = 1, #pts - 1 do
        local e = seg_dist(px, py, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
        if e < d then d = e end
    end
    return d
end

-- Douglas-Peucker on points (pt)
local function thin(pts, tol)
    local keep = {[1] = true, [#pts] = true}
    local function rec(i, j)
        local dmax, k = 0, nil
        for m = i + 1, j - 1 do
            local d = seg_dist(pts[m][1], pts[m][2], pts[i][1], pts[i][2], pts[j][1], pts[j][2])
            if d > dmax then dmax, k = d, m end
        end
        if k and dmax > tol then
            keep[k] = true
            rec(i, k)
            rec(k, j)
        end
    end
    rec(1, #pts)
    local out = {}
    for i = 1, #pts do if keep[i] then out[#out + 1] = pts[i] end end
    return out
end

-- drop repeated points (closer than eps)
local function dedup(pts, eps)
    local out = {pts[1]}
    for i = 2, #pts do
        local p, q = out[#out], pts[i]
        if abs(p[1] - q[1]) > eps or abs(p[2] - q[2]) > eps then out[#out + 1] = q end
    end
    return out
end

-- value of a polyline at u (k: the coordinate to enter with, 1 = x, 2 = y),
-- the end segments' lines beyond the ends; pts ordered by that coordinate
local function poly_at(pts, u, k)
    local o = 3 - k
    local n = #pts
    local i = 1
    if u >= pts[n][k] then i = n - 1
    elseif u > pts[1][k] then
        while pts[i + 1][k] < u do i = i + 1 end
    end
    local a, b = pts[i], pts[i + 1]
    if b[k] == a[k] then return b[o] end
    return a[o] + (u - a[k]) / (b[k] - a[k]) * (b[o] - a[o])
end

-- intersection of segment ab with polyline: the first one, or nil
local function seg_cross(a, b, poly)
    for i = 1, #poly - 1 do
        local c, d = poly[i], poly[i + 1]
        local rx, ry = b[1] - a[1], b[2] - a[2]
        local sx, sy = d[1] - c[1], d[2] - c[2]
        local den = rx * sy - ry * sx
        if abs(den) > 1e-12 then
            local t = ((c[1] - a[1]) * sy - (c[2] - a[2]) * sx) / den
            local u = ((c[1] - a[1]) * ry - (c[2] - a[2]) * rx) / den
            if t >= -1e-9 and t <= 1 + 1e-9 and u >= -1e-9 and u <= 1 + 1e-9 then
                return {a[1] + t * rx, a[2] + t * ry}
            end
        end
    end
end

local function poly_cross(p, q)
    for i = 1, #p - 1 do
        local x = seg_cross(p[i], p[i + 1], q)
        if x then return x end
    end
end

------------------------------------------------------------------------
-- axes
------------------------------------------------------------------------
local function is_solid(p) return p.kind == "S" and p.dash == "-" end

-- the thick axis lines: {dir = "h"|"v", at, lo, hi}
local function thick_lines(pg)
    local out = {}
    for _, p in ipairs(pg.paths) do
        if is_solid(p) and p.lw > 1.5 and #p.pts == 2 then
            local a, b = p.pts[1], p.pts[2]
            if abs(a[2] - b[2]) < 0.05 then
                out[#out + 1] = {dir = "h", at = a[2], lo = math.min(a[1], b[1]), hi = math.max(a[1], b[1])}
            elseif abs(a[1] - b[1]) < 0.05 then
                out[#out + 1] = {dir = "v", at = a[1], lo = math.min(a[2], b[2]), hi = math.max(a[2], b[2])}
            end
        end
    end
    return out
end

local function axis(pg, dir, near)
    local best
    for _, l in ipairs(thick_lines(pg)) do
        if l.dir == dir and abs(l.at - near) < 3 and (not best or abs(l.at - near) < abs(best.at - near)) then best = l end
    end
    return assert(best, "p." .. pg.n .. ": no thick " .. dir .. " line near " .. near)
end

-- tick marks on an axis: short solid two-point strokes perpendicular to it,
-- one end on it, on side (-1: below / left, +1: above / right)
local function ticks(pg, ax, side)
    local out = {}
    for _, p in ipairs(pg.paths) do
        if is_solid(p) and #p.pts == 2 then
            local a, b = p.pts[1], p.pts[2]
            -- drawn from either end: a on the axis
            local k = ax.dir == "h" and 2 or 1
            if abs(b[k] - ax.at) < abs(a[k] - ax.at) then a, b = b, a end
            if ax.dir == "h" and abs(a[1] - b[1]) < 0.05 then
                local len = b[2] - a[2]
                if abs(a[2] - ax.at) < 0.6 and abs(len) > 1.5 and abs(len) < 3.6 and len * side > 0
                    and a[1] >= ax.lo - 0.5 and a[1] <= ax.hi + 0.5 then
                    out[#out + 1] = a[1]
                end
            elseif ax.dir == "v" and abs(a[2] - b[2]) < 0.05 then
                local len = b[1] - a[1]
                if abs(a[1] - ax.at) < 0.6 and abs(len) > 1.5 and abs(len) < 3.6 and len * side > 0
                    and a[2] >= ax.lo - 0.5 and a[2] <= ax.hi + 0.5 then
                    out[#out + 1] = a[2]
                end
            end
        end
    end
    table.sort(out)
    local u = {}
    for _, v in ipairs(out) do if #u == 0 or v - u[#u] > 0.3 then u[#u + 1] = v end end
    return u
end

-- Helvetica widths (em) for the label centres
local CW = {["-"] = 0.333, [" "] = 0.278, ["("] = 0.333, [")"] = 0.333}
local function text_w(t, size)
    local w = 0
    for c in t:gmatch(".") do w = w + (CW[c] or 0.556) end
    return w * size
end

-- horizontal number labels whose anchor is inside the box
local function num_labels(pg, x0, y0, x1, y1)
    local out = {}
    for _, t in ipairs(pg.texts) do
        local s = t.text:match("^%s*(%-?%d+)%s*$")
        if s and abs(t.ang) < 1 and t.x >= x0 and t.x <= x1 and t.y >= y0 and t.y <= y1 then
            local lead = #t.text:match("^(%s*)")
            out[#out + 1] = {v = tonumber(s), cx = t.x + text_w(t.text:sub(1, lead), t.size) + text_w(s, t.size) / 2,
                cy = t.y + 0.36 * t.size}
        end
    end
    return out
end

-- value = a + b * coord from the ticks and their labels
-- (skip: a label without its own tick is left out, for the deg F checks:
-- p.33's -40 F shares the -40 C tick)
local function calibrate(name, tk, labs, dir, tol, skip)
    local pairs_, used, skipped = {}, {}, 0
    for _, l in ipairs(labs) do
        local c = dir == "h" and l.cx or l.cy
        local best, bd
        for _, t in ipairs(tk) do
            if not bd or abs(t - c) < bd then best, bd = t, abs(t - c) end
        end
        if skip and not (bd and bd <= tol) then
            skipped = skipped + 1
        else
            assert(bd and bd <= tol, string.format("%s: label %g has no tick (%.2f pt)", name, l.v, bd or -1))
            assert(not used[best], string.format("%s: two labels on the tick at %.2f", name, best))
            used[best] = true
            pairs_[#pairs_ + 1] = {best, l.v}
        end
    end
    if skipped > 0 then log("  %-28s %d label(s) without a tick of their own", name, skipped) end
    assert(#pairs_ >= 3, name .. ": fewer than 3 labelled ticks")
    local n, sx, sy, sxx, sxy = #pairs_, 0, 0, 0, 0
    for _, p in ipairs(pairs_) do
        sx, sy, sxx, sxy = sx + p[1], sy + p[2], sxx + p[1] * p[1], sxy + p[1] * p[2]
    end
    local b = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    local a = (sy - b * sx) / n
    local rms, mx = 0, 0
    for _, p in ipairs(pairs_) do
        local r = a + b * p[1] - p[2]
        rms = rms + r * r
        if abs(r) > mx then mx = abs(r) end
    end
    rms = sqrt(rms / n)
    log("  %-28s %2d labelled ticks, value = %.4f + %.6f * pt, residual rms %.4f max %.4f (units)", name, n, a, b, rms, mx)
    local cal = {a = a, b = b, name = name, max = mx}
    function cal.v(c) return a + b * c end
    function cal.c(v) return (v - a) / b end
    return cal
end

-- the long grid lines parallel to an axis should fall on multiples of step
local function grid_check(pg, cal, dir, span_lo, span_hi, step, win_lo, win_hi)
    local worst, n = 0, 0
    for _, p in ipairs(pg.paths) do
        if is_solid(p) and #p.pts == 2 then
            local a, b = p.pts[1], p.pts[2]
            local c, lo, hi
            if dir == "h" and abs(a[1] - b[1]) < 0.05 then c, lo, hi = a[1], math.min(a[2], b[2]), math.max(a[2], b[2])
            elseif dir == "v" and abs(a[2] - b[2]) < 0.05 then c, lo, hi = a[2], math.min(a[1], b[1]), math.max(a[1], b[1]) end
            if c and lo <= span_lo + 2 and hi >= span_hi - 2 and c >= (win_lo or -huge) - 0.5 and c <= (win_hi or huge) + 0.5 then
                local v = cal.v(c)
                local d = abs(v - floor(v / step + 0.5) * step)
                n = n + 1
                if d > worst then worst = d end
            end
        end
    end
    log("  %-28s %2d grid lines, worst %.4f units off a multiple of %g", cal.name .. " grid", n, worst, step)
    return worst
end

------------------------------------------------------------------------
-- curves and labels
------------------------------------------------------------------------
local function strokes(pg, lw_lo, lw_hi, box, min_pts)
    local out = {}
    for _, p in ipairs(pg.paths) do
        if is_solid(p) and p.lw >= lw_lo and p.lw <= lw_hi and #p.pts >= (min_pts or 3) then
            local inside = true
            for _, q in ipairs(p.pts) do
                if q[1] < box[1] - 1 or q[1] > box[3] + 1 or q[2] < box[2] - 1 or q[2] > box[4] + 1 then inside = false break end
            end
            if inside then out[#out + 1] = dedup(p.pts, 0.005) end
        end
    end
    return out
end

-- join strokes that continue one another (end on start)
local function join(list)
    local changed = true
    while changed do
        changed = false
        for i = 1, #list do
            for j = 1, #list do
                if i ~= j and list[i] and list[j] then
                    local a, b = list[i], list[j]
                    local e, s = a[#a], b[1]
                    if abs(e[1] - s[1]) < 0.02 and abs(e[2] - s[2]) < 0.02 then
                        for k = 2, #b do a[#a + 1] = b[k] end
                        list[j] = false
                        changed = true
                    end
                end
            end
        end
    end
    local out = {}
    for _, l in ipairs(list) do if l then out[#out + 1] = l end end
    return out
end

-- rotated labels: {v, x, y, text}
local function rot_labels(pg, pattern, ang_lo, ang_hi, box)
    local out = {}
    for _, t in ipairs(pg.texts) do
        local s = t.text:match(pattern)
        if s and t.ang >= ang_lo and t.ang <= ang_hi and t.x >= box[1] and t.x <= box[3] and t.y >= box[2] and t.y <= box[4] then
            out[#out + 1] = {v = tonumber(s), x = t.x, y = t.y, text = t.text}
        end
    end
    return out
end

-- each label to its nearest curve, one a curve; returns value by curve index
local function assign(name, curves, labs)
    local val, margin = {}, huge
    for _, l in ipairs(labs) do
        local d1, d2, k = huge, huge, nil
        for i, c in ipairs(curves) do
            local d = poly_dist(l.x, l.y, c)
            if d < d1 then d2, d1, k = d1, d, i elseif d < d2 then d2 = d end
        end
        assert(not val[k], string.format("%s: labels %s and %s on one curve", name, tostring(val[k]), l.v))
        val[k] = l.v
        if d2 - d1 < margin then margin = d2 - d1 end
        log("    label %-10s -> curve %2d  %.2f pt (next %.2f)", l.text:gsub("%s+", " "), k, d1, d2)
    end
    for i = 1, #curves do assert(val[i], string.format("%s: curve %d has no label", name, i)) end
    assert(#labs == #curves, name .. ": labels and curves differ in number")
    log("  %s: %d curves, %d labels, smallest margin to the next curve %.2f pt", name, #curves, #labs, margin)
    return val
end

-- labels set in a row along the curves' ends (the VMBE chart's OAT lines:
-- down the right edge, then left along the bottom, where 50 C's label sits
-- nearer 60 C's line): the n-th label in the row to the n-th curve end in
-- it, both ranked by x + y; the curves' order is checked by the caller
local function assign_row(name, curves, labs)
    local ends = {}
    for i, c in ipairs(curves) do
        local e = c[1][2] < c[#c][2] and c[1] or c[#c]
        ends[i] = {i = i, k = e[1] + e[2]}
    end
    table.sort(ends, function(a, b) return a.k > b.k end)
    local ls = {}
    for i, l in ipairs(labs) do ls[i] = l end
    table.sort(ls, function(a, b) return a.x + a.y > b.x + b.y end)
    assert(#ls == #ends, name .. ": labels and curves differ in number")
    local val = {}
    for n, e in ipairs(ends) do
        val[e.i] = ls[n].v
        local near, d1 = nil, huge
        for i, c in ipairs(curves) do
            local d = poly_dist(ls[n].x, ls[n].y, c)
            if d < d1 then near, d1 = i, d end
        end
        log("    label %-10s -> curve %2d (%.2f pt; nearest curve %d)", ls[n].text:gsub("%s+", " "), e.i,
            poly_dist(ls[n].x, ls[n].y, curves[e.i]), near)
    end
    log("  %s: %d curves by the row of labels at their ends", name, #curves)
    return val
end

------------------------------------------------------------------------
-- page text and the notes' numbers
------------------------------------------------------------------------
local function page_text(pg)
    local ts = {}
    -- the horizontal runs but the bare numbers (axis labels, subscripts),
    -- which would join the lines of the VMBE table beside the VMBE scale
    for _, t in ipairs(pg.texts) do
        if abs(t.ang) < 1 and not t.text:match("^%s*[%d%-%.]*%s*$") then ts[#ts + 1] = t end
    end
    table.sort(ts, function(a, b) return a.y > b.y end)
    local lines = {}
    for _, t in ipairs(ts) do
        local l = lines[#lines]
        -- one line: baselines within 4.2 pt (subscripts sit about 4.15 below)
        if l and l.y - t.y <= 4.2 then l[#l + 1] = t else lines[#lines + 1] = {y = t.y, t} end
    end
    local out = {}
    for _, l in ipairs(lines) do
        table.sort(l, function(a, b) return a.x < b.x end)
        local s = {}
        for _, t in ipairs(l) do s[#s + 1] = t.text end
        out[#out + 1] = table.concat(s, " ")
    end
    return (table.concat(out, " "):gsub("%s+", " "))
end

-- pattern without spaces: the text's spaces are dropped (runs split
-- inside words, "3 pa" + "cks on")
local function note(text, pattern, what)
    local a, b = text:gsub("%s", ""):match(pattern)
    assert(a, "note not found: " .. what .. " (" .. pattern .. ")")
    return tonumber(a), tonumber(b)
end

------------------------------------------------------------------------
-- output helpers
------------------------------------------------------------------------
local function num(v, dec)
    local s = string.format("%." .. dec .. "f", v)
    if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
    if s == "-0" then s = "0" end
    return s
end

-- a flat list {a1, b1, a2, b2, ...}, wrapped
local function flat(list, deca, decb, indent)
    local parts = {}
    for _, p in ipairs(list) do parts[#parts + 1] = num(p[1], deca) .. "," .. num(p[2], decb) end
    local lines, cur = {}, indent .. "{"
    for i, s in ipairs(parts) do
        local piece = s .. (i < #parts and ", " or "")
        if #cur + #piece > 104 then
            lines[#lines + 1] = cur:gsub("%s+$", "")
            cur = indent .. " " .. piece
        else
            cur = cur .. piece
        end
    end
    lines[#lines + 1] = cur .. "},"
    return table.concat(lines, "\n")
end

local OUT = {}
local function out(s) OUT[#OUT + 1] = s end

------------------------------------------------------------------------
-- Takeoff Climb Limit (p.29 flaps 10, p.30 flaps 20)
------------------------------------------------------------------------
local function climb(pn, flaps, section)
    log("Takeoff Climb Limit flaps %d, FPPM p.%d (%s)", flaps, pn, section)
    local pg = load_page(pn)
    local xa, ya
    for _, l in ipairs(thick_lines(pg)) do
        if l.dir == "h" and (not xa or l.at < xa.at) then xa = l end
        if l.dir == "v" and (not ya or l.at < ya.at) then ya = l end
    end
    local box = {ya.at, xa.at, xa.hi, ya.hi}
    -- deg C under the axis, deg F above it, weights left of the y axis
    local cx = calibrate("OAT C", ticks(pg, xa, -1), num_labels(pg, xa.lo - 5, xa.at - 12, xa.hi + 5, xa.at - 3), "h", 5)
    local fx = calibrate("OAT F (check)", ticks(pg, xa, 1), num_labels(pg, xa.lo, xa.at + 1, xa.hi, xa.at + 6), "h", 5, true)
    local wy = calibrate("weight 1000 kg", ticks(pg, ya, -1), num_labels(pg, ya.at - 25, ya.lo - 6, ya.at - 2, ya.hi + 2), "v", 5)
    grid_check(pg, cx, "h", box[2], box[4], 5)
    grid_check(pg, wy, "v", box[1], box[3], 10)
    local fmax = 0
    for f = 40, 170, 10 do
        local d = abs(cx.v(fx.c(f)) - (f - 32) / 1.8)
        if d > fmax then fmax = d end
    end
    log("  deg F ticks vs deg C scale: worst %.3f C", fmax)

    local all = strokes(pg, 0.45, 0.6, box)
    local curves, others = {}, {}
    for _, c in ipairs(all) do
        if abs(c[1][1] - ya.at) < 0.5 then curves[#curves + 1] = c else others[#others + 1] = c end
    end
    local labs = rot_labels(pg, "^(%-?%d+)$", -89, -5, box)
    local alt = assign("altitude curves", curves, labs)
    -- order by altitude
    local idx = {}
    for i = 1, #curves do idx[i] = i end
    table.sort(idx, function(a, b) return alt[a] < alt[b] end)
    local env_line, atl_line
    for _, t in ipairs(pg.texts) do
        local which = t.text:match("ENVIRONMENTAL") and "env" or t.text:match("ASSUMED") and "atl"
        if which then
            local best, bd
            for _, o in ipairs(others) do
                local d = poly_dist(t.x, t.y, o)
                if not bd or d < bd then best, bd = o, d end
            end
            log("  %s line: %d points, %.2f pt from its label", which, #best, bd)
            if which == "env" then env_line = best else atl_line = best end
        end
    end
    assert(env_line and atl_line and #others == 2, "climb: limit lines")
    -- the environmental limit line's ends stop on the outer curves, a hair
    -- short of them on p.30: lengthen its end segments by 1 pt
    local function lengthen(l)
        local e = {}
        for k, p in ipairs(l) do e[k] = {p[1], p[2]} end
        for _, ends in ipairs({{1, 2}, {#l, #l - 1}}) do
            local a, b = e[ends[1]], e[ends[2]]
            local dx, dy = a[1] - b[1], a[2] - b[2]
            local len = sqrt(dx * dx + dy * dy)
            a[1], a[2] = a[1] + dx / len, a[2] + dy / len
        end
        return e
    end
    env_line = lengthen(env_line)

    local res = {alt = {}, curve = {}, env = {}}
    local prev_w
    for n, i in ipairs(idx) do
        local c = curves[i]
        for k = 2, #c do assert(c[k][1] > c[k - 1][1] - 0.01, "climb curve not rising in OAT") end
        -- the ATL line passes through every curve's end
        local de = poly_dist(c[#c][1], c[#c][2], atl_line)
        -- the environmental limit's OAT on this curve
        local x = assert(poly_cross(c, env_line), "curve " .. alt[i] .. " misses the environmental limit")
        local th = thin(c, 0.12)
        local pts = {}
        for _, p in ipairs(th) do pts[#pts + 1] = {cx.v(p[1]), wy.v(p[2])} end
        res.alt[n] = alt[i]
        res.curve[n] = pts
        res.env[n] = cx.v(x[1])
        -- lower altitude, heavier at every OAT
        local w30 = wy.v(poly_at(c, cx.c(30), 1))
        if prev_w then assert(w30 < prev_w + 0.01, "climb curves out of altitude order") end
        prev_w = w30
        local brk = 1
        while pts[brk + 1] and pts[brk + 1][2] > pts[1][2] - 1.5 do brk = brk + 1 end
        log("  %3d000 ft: %2d -> %2d points, flat %.1f t to %.1f C, env %.2f C, ATL %.2f C (end %.2f pt off the ATL line)",
            alt[i], #c, #th, pts[1][2], pts[brk][1], res.env[n], pts[#pts][1], de)
    end
    local text = page_text(pg)
    res.notes = {
        packs_off = note(text, "packsoff,increaseweightby(%d+)kg", "packs off"),
        one_pack = note(text, "1packon,increaseweightby(%d+)kg", "1 pack on"),
        apu_one_pack = note(text, "enginebleedoffandAPUsupplying1A/Cpack,increase%a-weightby(%d+)kg", "APU 1 pack"),
        basis = assert(text:gsub("%s", ""):match("Basedonenginebleedfor3packsonandanti%-iceonoroff"), "basis"),
    }
    log("  notes: packs off +%d kg, 1 pack +%d kg, engine bleed off and APU 1 pack +%d kg",
        res.notes.packs_off, res.notes.one_pack, res.notes.apu_one_pack)
    -- the printed example (dashed, with arrows), if any
    for _, p in ipairs(pg.paths) do
        if p.kind == "S" and p.dash ~= "-" and p.dash:match("^%[1%d") then
            local t = cx.v(p.pts[1][1])
            local w = wy.v(p.pts[2][2])
            local by = {}
            for n2, i in ipairs(idx) do by[n2] = wy.v(poly_at(curves[i], p.pts[1][1], 1)) end
            local s = {}
            for n2 = 1, #by do s[#s + 1] = string.format("%d:%.1f", res.alt[n2], by[n2]) end
            log("  EXAMPLE: up from %.2f C to %.2f t, read left (curves at that OAT %s)", t, w, table.concat(s, " "))
        end
    end
    return res
end

local function write_climb(c, flaps, pn, section)
    out(string.format("    [%d] = {                                     -- FPPM p.%d (%s)", flaps, pn, section))
    out("        alt = {" .. table.concat(c.alt, ", ") .. "},")
    out("        curve = {")
    for n, pts in ipairs(c.curve) do
        out(string.format("            -- %d ft", c.alt[n] * 1000))
        out(flat(pts, 2, 1, "            "))
    end
    out("        },")
    local e = {}
    for n = 1, #c.env do e[n] = num(c.env[n], 1) end
    out("        env = {" .. table.concat(e, ", ") .. "},")
    out(string.format("        notes = {packs_off = %d, one_pack = %d, apu_one_pack = %d},",
        c.notes.packs_off, c.notes.one_pack, c.notes.apu_one_pack))
    out("    },")
end

------------------------------------------------------------------------
-- Tire Speed Limit (p.33)
------------------------------------------------------------------------
local function tire(pn, section)
    log("Tire Speed Limit flaps 10, FPPM p.%d (%s)", pn, section)
    local pg = load_page(pn)
    local xa, ya
    for _, l in ipairs(thick_lines(pg)) do
        if l.dir == "h" then xa = l end
        if l.dir == "v" then ya = l end
    end
    local box = {ya.at, xa.at, xa.hi, ya.hi}
    local cx = calibrate("OAT C", ticks(pg, xa, -1), num_labels(pg, xa.lo - 10, xa.at - 13, xa.hi + 5, xa.at - 3), "h", 5)
    local fx = calibrate("OAT F (check)", ticks(pg, xa, 1), num_labels(pg, xa.lo, xa.at + 1, xa.hi, xa.at + 9), "h", 5, true)
    local wy = calibrate("weight 1000 kg", ticks(pg, ya, -1), num_labels(pg, ya.at - 25, ya.lo - 6, ya.at - 2, ya.hi + 2), "v", 5)
    grid_check(pg, cx, "h", box[2], box[4], 10)
    grid_check(pg, wy, "v", box[1], box[3], 10)
    local fmax = 0
    for f = -40, 140, 20 do
        local d = abs(cx.v(fx.c(f)) - (f - 32) / 1.8)
        if d > fmax then fmax = d end
    end
    log("  deg F ticks vs deg C scale: worst %.3f C", fmax)
    local curves = strokes(pg, 0.55, 0.65, box)
    local labs = rot_labels(pg, "^(%-?%d+)$", -89, -5, box)
    local alt = assign("altitude curves", curves, labs)
    local idx = {}
    for i = 1, #curves do idx[i] = i end
    table.sort(idx, function(a, b) return alt[a] < alt[b] end)
    local res = {alt = {}, curve = {}}
    local prev
    for n, i in ipairs(idx) do
        local c = curves[i]
        -- drawn top left to bottom right or the other way: OAT rising
        if c[1][1] > c[#c][1] then
            local r = {}
            for k = #c, 1, -1 do r[#r + 1] = c[k] end
            c = r
        end
        for k = 2, #c do assert(c[k][1] > c[k - 1][1] - 0.01 and c[k][2] < c[k - 1][2] + 0.01, "tire curve not monotonic") end
        local pts = {}
        for _, p in ipairs(thin(c, 0.12)) do pts[#pts + 1] = {cx.v(p[1]), wy.v(p[2])} end
        res.alt[n], res.curve[n] = alt[i], pts
        local w = wy.v(poly_at(c, cx.c(40), 1))
        if prev then assert(w < prev + 0.01, "tire curves out of altitude order") end
        prev = w
        log("  %3d000 ft: %2d points, from %.1f C %.1f t to %.1f C %.1f t", alt[i], #pts, pts[1][1], pts[1][2], pts[#pts][1], pts[#pts][2])
    end
    res.top, res.bottom = wy.v(ya.hi), wy.v(xa.at)
    res.oat_min, res.oat_max = cx.v(ya.at), cx.v(xa.hi)
    local text = page_text(pg)
    res.notes = {
        flaps20 = note(text, "Increaseflaps10tirespeedlimitweightby(%d+)kgforflaps20", "flaps 20"),
        head = note(text, "Increasetirespeedlimitweightby(%d+)kgperknotheadwind", "headwind"),
        tail = note(text, "Decreasetirespeedlimitweightby(%d+)kgperknottailwind", "tailwind"),
    }
    assert(text:gsub("%s", ""):match("235MPHTIRES"), "235 mph")
    log("  notes: flaps 20 +%d kg, +%d kg a knot headwind, -%d kg a knot tailwind", res.notes.flaps20, res.notes.head, res.notes.tail)
    log("  chart: OAT %.2f to %.2f C, weight %.2f to %.2f t", res.oat_min, res.oat_max, res.bottom, res.top)
    return res
end

------------------------------------------------------------------------
-- Brake Energy Limit VMBE (p.34)
------------------------------------------------------------------------
local function vmbe(pn, section)
    log("Brake Energy Limit VMBE flaps 10 and 20, FPPM p.%d (%s)", pn, section)
    local pg = load_page(pn)
    local lines = thick_lines(pg)
    local pa_ax, w_ax, v_ax
    for _, l in ipairs(lines) do
        if l.dir == "h" then w_ax = l end
        if l.dir == "v" and (not pa_ax or l.at < pa_ax.at) then pa_ax = l end
        if l.dir == "v" and (not v_ax or l.at > v_ax.at) then v_ax = l end
    end
    local wx = calibrate("weight 1000 kg (upper left)", ticks(pg, w_ax, -1),
        num_labels(pg, w_ax.lo - 10, w_ax.at - 12, w_ax.hi + 5, w_ax.at - 3), "h", 5)
    local py = calibrate("pressure altitude 1000 ft", ticks(pg, pa_ax, -1),
        num_labels(pg, pa_ax.at - 18, pa_ax.lo - 6, pa_ax.at - 2, pa_ax.hi + 2), "v", 5)
    local vy = calibrate("VMBE KIAS", ticks(pg, v_ax, 1),
        num_labels(pg, v_ax.at + 2, v_ax.lo - 6, v_ax.at + 20, v_ax.hi + 2), "v", 5)
    grid_check(pg, wx, "h", w_ax.at, pa_ax.hi, 20)
    grid_check(pg, py, "v", pa_ax.at, w_ax.hi, 2)
    -- the right part's reference axis: grid columns from its left edge,
    -- from its long vertical grid lines (no numbers on it)
    local cols = {}
    for _, p in ipairs(pg.paths) do
        if is_solid(p) and #p.pts == 2 and abs(p.pts[1][1] - p.pts[2][1]) < 0.05
            and math.min(p.pts[1][2], p.pts[2][2]) < v_ax.lo + 1 and math.max(p.pts[1][2], p.pts[2][2]) > pa_ax.hi - 1 then
            cols[#cols + 1] = p.pts[1][1]
        end
    end
    table.sort(cols)
    local labs = {}
    for k, x in ipairs(cols) do labs[k] = {v = k - 1, cx = x, cy = 0} end
    local rx = calibrate("reference (grid columns)", cols, labs, "h", 0.5)
    -- the right part's horizontal grid lines continue the VMBE and altitude scales
    grid_check(pg, vy, "v", cols[1], cols[#cols], 10, v_ax.lo, w_ax.at - 1)
    grid_check(pg, py, "v", cols[1], cols[#cols], 2, w_ax.at, pa_ax.hi)

    -- the shaded area
    local shaded
    for _, p in ipairs(pg.paths) do
        if p.kind == "F" and p.col == "0.90,0.90,0.90" then shaded = dedup(p.pts, 0.005) end
    end
    assert(shaded, "no shaded area")
    if abs(shaded[1][1] - shaded[#shaded][1]) < 0.01 and abs(shaded[1][2] - shaded[#shaded][2]) < 0.01 then
        shaded[#shaded] = nil
    end
    local sh = {}
    -- the slanted edge is drawn as a series of short strokes: thin it
    for _, p in ipairs(thin(shaded, 0.12)) do sh[#sh + 1] = {wx.v(p[1]), py.v(p[2])} end
    log("  shaded area: %d -> %d vertices", #shaded, #sh)

    -- OAT lines (upper right) and weight lines (lower right)
    local top = {cols[1], w_ax.at, cols[#cols], pa_ax.hi}
    local low = {cols[1], v_ax.lo, cols[#cols], v_ax.hi}
    local oat_lines = join(strokes(pg, 0.5, 0.6, top, 2))
    local wt_lines = strokes(pg, 0.5, 0.6, low, 3)
    local oat = assign_row("OAT lines", oat_lines, rot_labels(pg, "^%s*(%-?%d+)%s*%(", -89, -20, {cols[1], w_ax.at - 10, cols[#cols], pa_ax.hi}))
    local wt = assign("weight lines", wt_lines, rot_labels(pg, "^(%d%d%d)$", 20, 70, {cols[1], v_ax.lo, cols[#cols], v_ax.hi + 10}))
    local res = {oat = {}, oat_line = {}, wt = {}, wt_line = {}}
    local idx = {}
    for i = 1, #oat_lines do idx[i] = i end
    table.sort(idx, function(a, b) return oat[a] < oat[b] end)
    local prev
    for n, i in ipairs(idx) do
        local c = oat_lines[i]
        -- altitude rising
        table.sort(c, function(a, b) return a[2] < b[2] end)
        local pts = {}
        for _, p in ipairs(thin(c, 0.12)) do pts[#pts + 1] = {py.v(p[2]), rx.v(p[1])} end
        res.oat[n], res.oat_line[n] = oat[i], pts
        local r10 = pts[#pts][2]
        if prev then assert(r10 < prev, "OAT lines out of order") end
        prev = r10
        log("  OAT %3d C: %2d points, %.2f kft col %.3f to %.2f kft col %.3f", oat[i], #pts, pts[1][1], pts[1][2], pts[#pts][1], pts[#pts][2])
    end
    idx = {}
    for i = 1, #wt_lines do idx[i] = i end
    table.sort(idx, function(a, b) return wt[a] < wt[b] end)
    prev = nil
    for n, i in ipairs(idx) do
        local c = wt_lines[i]
        table.sort(c, function(a, b) return a[1] < b[1] end)
        local pts = {}
        for _, p in ipairs(thin(c, 0.12)) do pts[#pts + 1] = {rx.v(p[1]), vy.v(p[2])} end
        res.wt[n], res.wt_line[n] = wt[i], pts
        local v = vy.v(poly_at(c, rx.c(4), 1))
        if prev then assert(v < prev, "weight lines out of order") end
        prev = v
        log("  %3d t: %2d points, col %.3f %.1f kt to col %.3f %.1f kt", wt[i], #pts, pts[1][1], pts[1][2], pts[#pts][1], pts[#pts][2])
    end
    res.shaded = sh
    -- the lines stop at one grid line on the right: the one nearest their
    -- right-most ends
    local xend = -huge
    for _, c in ipairs(oat_lines) do for _, p in ipairs(c) do if p[1] > xend then xend = p[1] end end end
    for _, c in ipairs(wt_lines) do for _, p in ipairs(c) do if p[1] > xend then xend = p[1] end end end
    local gl
    for _, x in ipairs(cols) do if not gl or abs(x - xend) < abs(gl - xend) then gl = x end end
    res.ref_max = rx.v(gl)
    res.vmax, res.vmin = vy.v(v_ax.hi), vy.v(v_ax.lo)
    log("  lines end at column %.3f (right-most end %.2f pt off it); VMBE scale %.1f to %.1f kt",
        res.ref_max, xend - gl, res.vmin, res.vmax)

    local text = page_text(pg)
    res.notes = {}
    res.notes.up = note(text, "INCREASEVMBEBY(%d+)KTSFOR1%%UPHILL", "uphill")
    res.notes.down = note(text, "DECREASEVMBEBY(%d+)KTSFOR1%%DOWNHILL", "downhill")
    res.notes.head, res.notes.head_per = note(text, "INCREASEVMBEBY(%d+)KTSFOR(%d+)KTSHEADWIND", "headwind")
    res.notes.tail, res.notes.tail_per = note(text, "DECREASEVMBEBY(%d+)KTSFOR(%d+)KTSTAILWIND", "tailwind")
    res.notes.brakes2 = note(text, "DECREASEVMBEBY(%d+)KTS%u-FORTWOBRAKESDEACTIVATED", "brakes")  -- the row header BRAKE between
    res.notes.per_kt = note(text, "NORMALTAKEOFF:DECREASEBRAKERELEASEWEIGHTBY(%d+)KGFOREACHKNOT", "normal")
    res.notes.per_kt_ic = note(text, "IMPROVEDCLIMBTAKEOFF:DECREASECLIMBWEIGHTIMPROVEMENTBY(%d+)KGFOREACHKNOT", "improved")
    local nt = res.notes
    log("  notes: +%d kt a 1%% uphill, -%d kt a 1%% downhill, +%d kt a %d kt headwind, -%d kt a %d kt tailwind,",
        nt.up, nt.down, nt.head, nt.head_per, nt.tail, nt.tail_per)
    log("         -%d kt two brakes deactivated; %d kg a knot V1 over VMBE (normal), %d kg (improved climb)",
        nt.brakes2, nt.per_kt, nt.per_kt_ic)

    -- the printed example
    local ex = {}
    for _, p in ipairs(pg.paths) do
        if p.kind == "S" and p.dash ~= "-" and p.dash:match("^%[1%d") then ex[#ex + 1] = p.pts end
    end
    if #ex == 2 then
        local h, path = ex[1], ex[2]
        if #h > #path then h, path = path, h end
        local pa = py.v(h[1][2])
        local wgt = wx.v(path[#path][1])
        local pa2 = py.v(path[#path - 1][2])
        local ref_up, ref_low = rx.v(path[#path - 2][1]), rx.v(path[2][1])
        local v = vy.v(path[1][2])
        -- the OAT the turn sits on: between the two OAT lines bracketing it
        local refs = {}
        for n = 1, #res.oat do refs[n] = poly_at(res.oat_line[n], pa2, 1) end
        local o
        for n = 1, #refs - 1 do
            if ref_up <= refs[n] and ref_up >= refs[n + 1] then
                o = res.oat[n] + (refs[n] - ref_up) / (refs[n] - refs[n + 1]) * (res.oat[n + 1] - res.oat[n])
            end
        end
        log("  EXAMPLE: %.1f t up to %.3f kft (entry line %.3f kft) right to col %.3f (OAT %.2f C) down (col %.3f) to %.2f kt",
            wgt, pa2, pa, ref_up, o or -999, ref_low, v)
        -- the weight the drawn turn to the VMBE scale sits on
        local vs = {}
        for n = 1, #res.wt do vs[n] = poly_at(res.wt_line[n], ref_low, 1) end
        for n = 1, #vs - 1 do
            if v <= vs[n] and v >= vs[n + 1] then
                log("  EXAMPLE: the turn at %.2f kt sits on %.1f t (lines %d t %.2f kt, %d t %.2f kt)", v,
                    res.wt[n] + (vs[n] - v) / (vs[n] - vs[n + 1]) * (res.wt[n + 1] - res.wt[n]),
                    res.wt[n], vs[n], res.wt[n + 1], vs[n + 1])
            end
        end
        local edge = {}
        for k = 1, #sh - 1 do
            local x = seg_cross({0, pa}, {1000, pa}, {sh[k], sh[k + 1]})
            if x and x[1] > 300.5 then edge[#edge + 1] = x[1] end
        end
        log("  EXAMPLE: the entry line ends at %.1f t, the shaded area's edge at that altitude %.1f t", wx.v(h[#h][1]), edge[1] or -1)
    end
    return res
end

------------------------------------------------------------------------
local c10 = climb(29, 10, "1.2.5")
local c20 = climb(30, 20, "1.2.6")
local tr = tire(33, "1.2.9")
local vm = vmbe(34, "1.2.10")

out("-- BEGIN GENERATED DATA (docs/overhaul/tools/fppm_takeoff_limits.lua from")
out("-- _ref/1059530115-74F-FPPM.pdf's vector drawings; do not edit by hand)")
out("")
out("-- Takeoff Climb Limit, FPPM p.29 (1.2.5) flaps 10, p.30 (1.2.6) flaps 20:")
out("-- 3 packs on, anti-ice on or off. A curve an airport pressure altitude")
out("-- (alt, 1000 ft): {OAT C, weight 1000 kg, ...} with the OAT rising from")
out("-- the chart's 0 C (\"0 AND BELOW\"); its last point is on the ASSUMED")
out("-- TEMPERATURE LIMIT line. env: the OAT where the curve crosses the")
out("-- ENVIRONMENTAL LIMIT line. notes: the kg to add for the bleed")
out("-- configurations under the chart.")
out("M.CLIMB = {")
write_climb(c10, 10, 29, "1.2.5")
write_climb(c20, 20, 30, "1.2.6")
out("}")
out("")
out("-- Tire Speed Limit, FPPM p.33 (1.2.9): 235 mph tires, flaps 10. A curve an")
out("-- airport pressure altitude: {OAT C, tire limit weight 1000 kg, ...}, OAT")
out("-- rising; the curves leave the chart at its top (top, 1000 kg) and end")
out("-- at the right at the highest OAT drawn. notes: kg to add for flaps 20,")
out("-- kg a knot headwind (added) and tailwind (taken off).")
out("M.TIRE = {")
out("    alt = {" .. table.concat(tr.alt, ", ") .. "},")
out("    curve = {")
for n, pts in ipairs(tr.curve) do
    out(string.format("        -- %d ft", tr.alt[n] * 1000))
    out(flat(pts, 2, 1, "        "))
end
out("    },")
out(string.format("    oat_min = %s, oat_max = %s, bottom = %s, top = %s,",
    num(tr.oat_min, 1), num(tr.oat_max, 1), num(tr.bottom, 1), num(tr.top, 1)))
out(string.format("    notes = {flaps20 = %d, head = %d, tail = %d},", tr.notes.flaps20, tr.notes.head, tr.notes.tail))
out("}")
out("")
out("-- Brake Energy Limit VMBE, FPPM p.34 (1.2.10), flaps 10 and 20. shaded:")
out("-- the shaded area (no check for a normal takeoff without tailwind),")
out("-- {brake release weight 1000 kg, pressure altitude 1000 ft, ...}. The")
out("-- right part has no scale across: ref counts its grid columns from its")
out("-- left edge. oat_line: an OAT's line (upper right), {pressure altitude")
out("-- 1000 ft, ref, ...} with the altitude rising; wt_line: a brake release")
out("-- weight's line (lower right), {ref, VMBE KIAS, ...} with ref rising.")
out("-- ref_max: the grid line where the lines stop; vmin, vmax: the VMBE")
out("-- scale. notes: kt a 1 % slope up (added) and down (taken off); kt for")
out("-- head_per kt headwind (added) and tail_per kt tailwind (taken off); kt")
out("-- for two brakes deactivated; kg of brake release weight (normal) and of")
out("-- climb weight improvement (improved climb) a knot V1 exceeds VMBE.")
out("M.VMBE = {")
out("    shaded =")
out(flat(vm.shaded, 1, 2, "        "))
out("    oat = {" .. table.concat(vm.oat, ", ") .. "},")
out("    oat_line = {")
for n, pts in ipairs(vm.oat_line) do
    out(string.format("        -- %d C", vm.oat[n]))
    out(flat(pts, 2, 3, "        "))
end
out("    },")
out("    wt = {" .. table.concat(vm.wt, ", ") .. "},")
out("    wt_line = {")
for n, pts in ipairs(vm.wt_line) do
    out(string.format("        -- %d t", vm.wt[n]))
    out(flat(pts, 3, 1, "        "))
end
out("    },")
out(string.format("    ref_max = %s, vmin = %s, vmax = %s,", num(vm.ref_max, 3), num(vm.vmin, 1), num(vm.vmax, 1)))
local nt = vm.notes
out(string.format("    notes = {up = %d, down = %d, head = %d, head_per = %d, tail = %d, tail_per = %d, brakes2 = %d,",
    nt.up, nt.down, nt.head, nt.head_per, nt.tail, nt.tail_per, nt.brakes2))
out(string.format("        per_kt = %d, per_kt_ic = %d},", nt.per_kt, nt.per_kt_ic))
out("}")
out("-- END GENERATED DATA")

local data = table.concat(OUT, "\n") .. "\n"
if not MODEL then
    io.write(data)
    return
end
local f = assert(io.open(MODEL, "rb"))
local src = f:read("*a")
f:close()
local crlf = src:find("\r\n", 1, true) ~= nil
src = src:gsub("\r\n", "\n")
local a = src:find("%-%- BEGIN GENERATED DATA")
local _, b = src:find("%-%- END GENERATED DATA\n")
assert(a and b, MODEL .. ": no generated data markers")
src = src:sub(1, a - 1) .. data .. src:sub(b + 1)
if crlf then src = src:gsub("\n", "\r\n") end
f = assert(io.open(MODEL, "wb"))
f:write(src)
f:close()
log("data written to %s", MODEL)
