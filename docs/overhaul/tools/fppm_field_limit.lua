-- fppm_field_limit.lua: the FPPM's Takeoff Field Limit charts (747-400F/
-- PW4056, D632U002-RZ043: flaps 10 FPPM p.27 (1.2.3), flaps 20 FPPM p.28
-- (1.2.4)) read from the PDF's vector drawing into the data block of
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_field_model.lua
-- (2026-11-25, the EFB's takeoff performance). LuaJIT; runs
-- pdf_paths.lua (this folder) on the two pages.
--
--   luajit docs/overhaul/tools/fppm_field_limit.lua <FPPM pdf> <model.lua> [dump dir] [overlay file]
--
-- The model's text between "-- BEGIN GENERATED DATA" and "-- END GENERATED
-- DATA" is replaced; the rest (the hand-written functions) is kept. The
-- page dumps go to [dump dir] (default %TEMP%). [overlay file]: the data
-- drawn back on the pages in points (for checking it over the page images:
-- "<page> <r,g,b> : x,y x,y ...").
--
-- How the families are found (each checked against its label on the page):
--  - the frame: the thick (1.84 pt) lines: the OAT axis (the upper
--    horizontal), the field length axis (the lower), the weight axis (the
--    long vertical on the right), the slope axis (the short vertical on the
--    right), the wind axis (the vertical at the left part's right edge);
--  - the scales: the 1.5 pt ticks on those axes paired in order with the
--    numeric labels beside them, a straight line fitted (residuals printed);
--    the wind's tail side from its 0 and 10 kt ticks (the chart's bottom edge
--    is 15 kt on that scale);
--  - the pressure-altitude lines: the long 0.55 pt curves that start on the
--    left part's left edge, top to bottom -2 to 10 (1000 ft); each label's
--    nearest line checked;
--  - the ASSUMED TEMPERATURE LIMIT line: the short 0.55 pt line in the left
--    part through the altitude lines' right ends; the ENVIRONMENTAL LIMIT
--    line the other one; their labels' angles checked;
--  - the REF LINE: the full-height vertical in the right part; the MINIMUM
--    FIELD LENGTH REQUIRED line: the shorter vertical there (labels checked);
--  - the guide lines: the other 0.55 pt lines in the right part, the wind
--    chart and the slope chart; the wind and slope charts' REF LINEs the
--    horizontals across them;
--  - the printed example: the long-dashed lines, by where their segments
--    lie.
local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
local fmt = string.format

local PAGES = {
    {flaps = 10, page = 27, sec = "1.2.3"},
    {flaps = 20, page = 28, sec = "1.2.4"},
}

local pdf, model_path, dump_dir, overlay_path = arg[1], arg[2], arg[3], arg[4]
if not pdf or not model_path then
    io.stderr:write("usage: luajit fppm_field_limit.lua <FPPM pdf> <model.lua> [dump dir] [overlay file]\n")
    os.exit(2)
end
dump_dir = dump_dir or os.getenv("TEMP") or "."
local tool_dir = arg[0]:match("^(.*)[/\\]") or "."

local function check(cond, msg)
    if not cond then error("fppm_field_limit: " .. msg, 0) end
end

------------------------------------------------------------------------
-- the page dump (pdf_paths.lua run in this process)
------------------------------------------------------------------------
local function dump_page(page)
    local out = dump_dir .. "/fppm_p" .. page .. ".txt"
    local chunk = assert(loadfile(tool_dir .. "/pdf_paths.lua"))
    local saved = arg
    arg = {[0] = "pdf_paths.lua", pdf, tostring(page), out}
    chunk()
    arg = saved
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
            d.T[#d.T + 1] = {x = tonumber(x), y = tonumber(y), size = tonumber(size), ang = tonumber(ang), text = text}
        end
    end
    return d
end

------------------------------------------------------------------------
-- geometry helpers
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

local function inside(pts, x0, x1, y0, y1)
    local a, b, c, d = bbox(pts)
    return a >= x0 - 0.1 and b <= x1 + 0.1 and c >= y0 - 0.1 and d <= y1 + 0.1
end

-- v at u on a list of {u, v} sorted by u; the end segments carried on
local function at(pts, u, iu, iv)
    iu, iv = iu or 1, iv or 2
    local n = #pts
    local k = n
    for i = 2, n do
        if u <= pts[i][iu] then
            k = i
            break
        end
    end
    local a, b = pts[k - 1], pts[k]
    return a[iv] + (b[iv] - a[iv]) * (u - a[iu]) / (b[iu] - a[iu])
end

local function sorted_by(pts, i)
    local c = {}
    for k, p in ipairs(pts) do c[k] = {p[1], p[2]} end
    table.sort(c, function(a, b) return a[i] < b[i] end)
    return c
end

-- where two polylines cross (the first crossing), nil if not
local function crossing(a, b)
    for i = 2, #a do
        local p1, p2 = a[i - 1], a[i]
        for j = 2, #b do
            local q1, q2 = b[j - 1], b[j]
            local rx, ry = p2[1] - p1[1], p2[2] - p1[2]
            local sx, sy = q2[1] - q1[1], q2[2] - q1[2]
            local den = rx * sy - ry * sx
            if abs(den) > 1e-12 then
                local t = ((q1[1] - p1[1]) * sy - (q1[2] - p1[2]) * sx) / den
                local u = ((q1[1] - p1[1]) * ry - (q1[2] - p1[2]) * rx) / den
                if t >= -1e-9 and t <= 1 + 1e-9 and u >= -1e-9 and u <= 1 + 1e-9 then
                    return {p1[1] + t * rx, p1[2] + t * ry}
                end
            end
        end
    end
end

-- a polyline's end segments made longer by e points (for crossings at a vertex)
local function extended(pts, e)
    local c = {}
    for k, p in ipairs(pts) do c[k] = {p[1], p[2]} end
    local function push(i, j)
        local dx, dy = c[i][1] - c[j][1], c[i][2] - c[j][2]
        local l = sqrt(dx * dx + dy * dy)
        c[i] = {c[i][1] + dx / l * e, c[i][2] + dy / l * e}
    end
    push(1, 2)
    push(#c, #c - 1)
    return c
end

-- Douglas-Peucker in points
local function simplify(pts, tol)
    local keep = {[1] = true, [#pts] = true}
    local function rec(i, j)
        local ax, ay, bx, by = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        local dx, dy = bx - ax, by - ay
        local l = sqrt(dx * dx + dy * dy)
        local best, bi = -1, nil
        for k = i + 1, j - 1 do
            local d
            if l < 1e-9 then
                d = sqrt((pts[k][1] - ax) ^ 2 + (pts[k][2] - ay) ^ 2)
            else
                d = abs((pts[k][1] - ax) * dy - (pts[k][2] - ay) * dx) / l
            end
            if d > best then best, bi = d, k end
        end
        if bi and best > tol then
            keep[bi] = true
            rec(i, bi)
            rec(bi, j)
        end
    end
    rec(1, #pts)
    local out = {}
    for k = 1, #pts do if keep[k] then out[#out + 1] = pts[k] end end
    return out
end

-- least squares pos = a + b * v; the worst residual (pos units)
local function fit(pos, val)
    local n, sx, sy, sxx, sxy = #pos, 0, 0, 0, 0
    for i = 1, n do
        sx, sy = sx + val[i], sy + pos[i]
        sxx, sxy = sxx + val[i] * val[i], sxy + val[i] * pos[i]
    end
    local b = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    local a = (sy - b * sx) / n
    local worst = 0
    for i = 1, n do worst = max(worst, abs(pos[i] - (a + b * val[i]))) end
    return a, b, worst
end

local function numeric(t)
    return t.text:match("^%-?%d+%.?%d*$") and tonumber(t.text)
end

------------------------------------------------------------------------
-- one page
------------------------------------------------------------------------
local function read_page(pg)
    local d = dump_page(pg.page)
    local rep = {}
    local function say(...) rep[#rep + 1] = fmt(...) end
    say("FPPM p.%d (%s), flaps %d", pg.page, pg.sec, pg.flaps)

    -- the page is the flaps' chart
    local title, bleed_off, bleed_one
    for _, t in ipairs(d.T) do
        if t.text:match("^Flaps %d+$") then title = tonumber(t.text:match("%d+")) end
        bleed_off = bleed_off or tonumber(t.text:match("packs off, increase weight by (%d+) kg"))
        bleed_one = bleed_one or tonumber(t.text:match("1 pack on, increase weight by (%d+) kg"))
    end
    check(title == pg.flaps, "page " .. pg.page .. " is not flaps " .. pg.flaps)
    check(bleed_off and bleed_one, "page " .. pg.page .. ": no bleed notes")

    -- the frame
    local thick_h, thick_v = {}, {}
    for _, s in ipairs(d.S) do
        if s.lw > 1.5 and #s.pts == 2 then
            local x0, x1, y0, y1 = bbox(s.pts)
            if y1 - y0 < 0.01 then thick_h[#thick_h + 1] = {x0 = x0, x1 = x1, y = y0}
            elseif x1 - x0 < 0.01 then thick_v[#thick_v + 1] = {x = x0, y0 = y0, y1 = y1} end
        end
    end
    check(#thick_h == 2 and #thick_v == 3, "page " .. pg.page .. ": frame lines")
    table.sort(thick_h, function(a, b) return a.y > b.y end)
    local xL, xM, yB = thick_h[1].x0, thick_h[1].x1, thick_h[1].y
    local xR, yF = thick_h[2].x1, thick_h[2].y
    check(abs(thick_h[2].x0 - xM) < 0.5, "field length axis start")
    table.sort(thick_v, function(a, b) return (a.y1 - a.y0) > (b.y1 - b.y0) end)
    local wax = thick_v[1]
    check(abs(wax.x - xR) < 0.5 and abs(wax.y0 - yB) < 0.5, "weight axis")
    local yT = wax.y1
    local wind_ax, slope_ax
    for i = 2, 3 do
        local v = thick_v[i]
        if abs(v.x - xM) < 0.5 then wind_ax = v elseif abs(v.x - xR) < 0.5 then slope_ax = v end
    end
    check(wind_ax and slope_ax and wind_ax.y0 > slope_ax.y1, "wind and slope axes")
    say("  frame: left part x %.2f..%.2f, right part x %.2f..%.2f, y %.2f..%.2f; FLA axis y %.2f",
        xL, xM, xM, xR, yB, yT, yF)
    say("         wind chart y %.2f..%.2f, slope chart y %.2f..%.2f", wind_ax.y0, wind_ax.y1, slope_ax.y0, slope_ax.y1)

    -- ticks and labels
    local ticks = {}
    for _, s in ipairs(d.S) do
        if s.lw > 0.4 and s.lw < 1 and #s.pts == 2 and length(s.pts) < 2.5 then
            local x0, x1, y0, y1 = bbox(s.pts)
            ticks[#ticks + 1] = {x0 = x0, x1 = x1, y0 = y0, y1 = y1, v = x1 - x0 < 0.01}
        end
    end
    local function pick_ticks(f)
        local r = {}
        for _, t in ipairs(ticks) do if f(t) then r[#r + 1] = t end end
        return r
    end
    local function pick_labels(f)
        local r = {}
        for _, t in ipairs(d.T) do if abs(t.ang) < 0.5 and numeric(t) and f(t) then r[#r + 1] = t end end
        return r
    end
    -- pairs ticks with labels in order; fits pos = a + b * value
    local function scale(name, tk, lb, vertical_ticks, sign)
        check(#tk == #lb and #tk >= 2, fmt("%s: %d ticks, %d labels", name, #tk, #lb))
        local key = vertical_ticks and "x0" or "y0"
        table.sort(tk, function(a, b) return a[key] < b[key] end)
        table.sort(lb, function(a, b)
            if vertical_ticks then return a.x < b.x end
            return a.y < b.y
        end)
        local pos, val = {}, {}
        for i = 1, #tk do
            pos[i] = tk[i][key]
            val[i] = numeric(lb[i]) * (sign and sign(i, lb) or 1)
            local lpos = vertical_ticks and lb[i].x or lb[i].y
            check(abs(lpos - pos[i]) < 12, fmt("%s: label %s far from its tick", name, lb[i].text))
        end
        return pos, val
    end

    -- OAT (degrees C below the axis, F above it)
    local pc, vc = scale("OAT C",
        pick_ticks(function(t) return t.v and t.x0 >= xL - 0.5 and t.x0 <= xM + 0.5 and abs(t.y1 - yB) < 0.1 and t.y0 < yB - 0.5 end),
        pick_labels(function(t) return t.y > yB - 12 and t.y < yB - 4 and t.x > xL - 12 and t.x < xM + 5 end), true)
    local oa, ob, ores = fit(pc, vc)
    local pf, vf = scale("OAT F",
        pick_ticks(function(t) return t.v and t.x0 >= xL - 0.5 and t.x0 <= xM + 0.5 and abs(t.y0 - yB) < 0.1 and t.y1 > yB + 0.5 end),
        pick_labels(function(t) return t.y > yB and t.y < yB + 5 and t.x > xL - 5 and t.x < xM end), true)
    local fres = 0
    for i = 1, #pf do fres = max(fres, abs(pf[i] - (oa + ob * (vf[i] - 32) * 5 / 9))) end
    say("  OAT: x = %.4f + %.5f * C (%d ticks -50..80, worst %.3f pt = %.3f C; the F ticks on it: worst %.3f C);"
        .. " edges %.3f, %.3f C", oa, ob, #pc, ores, ores / ob, fres / ob, (xL - oa) / ob, (xM - oa) / ob)

    -- weight (1000 kg) on the right
    local pw, vw = scale("weight",
        pick_ticks(function(t) return not t.v and abs(t.x0 - xR) < 0.1 and t.y0 >= yB - 0.5 and t.y0 <= yT + 0.5 end),
        pick_labels(function(t) return t.x > xR + 1 and t.x < xR + 8 and t.y > yB - 5 and t.y < yT + 2 end), false)
    local wa, wb, wres = fit(pw, vw)
    say("  weight: y = %.4f + %.5f * t (%d ticks 200..460, worst %.3f pt = %.3f t); edges %.3f, %.3f t",
        wa, wb, #pw, wres, wres / wb, (yB - wa) / wb, (yT - wa) / wb)

    -- field length available (1000 ft below the axis, 100 m above)
    local pl, vl = scale("FLA ft",
        pick_ticks(function(t) return t.v and t.x0 >= xM - 0.5 and t.x0 <= xR + 0.5 and abs(t.y1 - yF) < 0.1 and t.y0 < yF - 0.5 end),
        pick_labels(function(t) return t.y > yF - 12 and t.y < yF - 4 and t.x > xM - 5 and t.x < xR + 5 end), true)
    local la, lb, lres = fit(pl, vl)
    local pm, vm = scale("FLA m",
        pick_ticks(function(t) return t.v and t.x0 >= xM - 0.5 and t.x0 <= xR + 0.5 and abs(t.y0 - yF) < 0.1 and t.y1 > yF + 0.5 end),
        pick_labels(function(t) return t.y > yF and t.y < yF + 5 and t.x > xM and t.x < xR + 5 end), true)
    local mres = 0
    for i = 1, #pm do mres = max(mres, abs(pm[i] - (la + lb * vm[i] * 100 / 0.3048 / 1000))) end
    say("  field length: x = %.4f + %.5f * kft (%d ticks 4..18, worst %.3f pt = %.1f ft; the 100 m ticks on it:"
        .. " worst %.1f ft); edges %.1f, %.1f ft", la, lb, #pl, lres, lres / lb * 1000, mres / lb * 1000,
        (xM - la) / lb * 1000, (xR - la) / lb * 1000)

    -- wind (head up from 0, tail down: unsigned labels, those below "0" tail)
    local wtk = pick_ticks(function(t) return not t.v and abs(t.x1 - xM) < 0.1 and t.y0 >= wind_ax.y0 - 0.5 and t.y0 <= wind_ax.y1 + 0.5 end)
    local wlb = pick_labels(function(t) return t.x > xM - 16 and t.x < xM - 2 and t.y > wind_ax.y0 - 5 and t.y < wind_ax.y1 + 2 end)
    local pk, vk = scale("wind", wtk, wlb, false, function(i, lbs)
        for j = 1, #lbs do if lbs[j].text == "0" then return i < j and -1 or 1 end end
        error("wind: no 0 label")
    end)
    local hp, hv, tp, tv = {}, {}, {}, {}
    for i = 1, #pk do
        if vk[i] >= 0 then hp[#hp + 1], hv[#hv + 1] = pk[i], vk[i] end
        if vk[i] <= 0 then tp[#tp + 1], tv[#tv + 1] = pk[i], vk[i] end
    end
    local ha, hb, hres = fit(hp, hv)
    local ta, tb = fit(tp, tv)
    local tail_bottom = (wind_ax.y0 - ha) / tb
    say("  wind: head y = %.4f + %.5f * kt (ticks 0, 20, 40, worst %.3f pt = %.2f kt); tail %.5f pt/kt (0, 10;"
        .. " zero %.3f pt from the head fit's); top %.2f kt head, bottom %.2f kt", ha, hb, hres, hres / hb, tb,
        ta - ha, (wind_ax.y1 - ha) / hb, tail_bottom)

    -- slope (% up +)
    local ps, vs = scale("slope",
        pick_ticks(function(t) return not t.v and abs(t.x0 - xR) < 0.1 and t.y0 >= slope_ax.y0 - 0.5 and t.y0 <= slope_ax.y1 + 0.5 end),
        pick_labels(function(t) return t.x > xR + 1 and t.x < xR + 8 and t.y > slope_ax.y0 - 5 and t.y < slope_ax.y1 + 2 end), false)
    local sa, sb, sres = fit(ps, vs)
    say("  slope: y = %.4f + %.5f * %% (ticks -2, 0, 2, worst %.3f pt = %.3f %%)", sa, sb, sres, sres / sb)

    local function oat(x) return (x - oa) / ob end
    local function wt(y) return (y - wa) / wb end
    local function ft(x) return (x - la) / lb * 1000 end
    local function kt(y)
        if y >= ha then return (y - ha) / hb end
        return (y - ha) / tb
    end
    local function pct(y) return (y - sa) / sb end
    local inv = {
        x_oat = function(v) return oa + ob * v end,
        y_wt = function(v) return wa + wb * v end,
        x_ft = function(v) return la + lb * v / 1000 end,
        y_kt = function(v) return v >= 0 and ha + hb * v or ha + tb * v end,
        y_pct = function(v) return sa + sb * v end,
    }

    -- the 0.55 pt lines (not ticks), by part
    local med = {}
    for _, s in ipairs(d.S) do
        if s.lw > 0.4 and s.lw < 1 and s.dash == "-" and not (#s.pts == 2 and length(s.pts) < 2.5) then
            med[#med + 1] = s
        end
    end
    local left, right, wind_l, slope_l = {}, {}, {}, {}
    for _, s in ipairs(med) do
        if inside(s.pts, xL, xM, yB, yT) then left[#left + 1] = s
        elseif inside(s.pts, xM, xR, yB, yT) then right[#right + 1] = s
        elseif inside(s.pts, xM, xR, wind_ax.y0, wind_ax.y1) then wind_l[#wind_l + 1] = s
        elseif inside(s.pts, xM, xR, slope_ax.y0, slope_ax.y1) then slope_l[#slope_l + 1] = s end
    end

    -- the pressure-altitude lines and the two limit lines
    local alts, lims = {}, {}
    for _, s in ipairs(left) do
        local x0 = bbox(s.pts)
        if #s.pts >= 20 and abs(x0 - xL) < 0.1 then alts[#alts + 1] = sorted_by(s.pts, 1)
        else lims[#lims + 1] = s.pts end
    end
    check(#alts == 13, "page " .. pg.page .. ": " .. #alts .. " pressure-altitude lines")
    check(#lims == 2, "page " .. pg.page .. ": " .. #lims .. " limit lines")
    table.sort(alts, function(a, b) return a[1][2] > b[1][2] end)
    local PA = {}
    for j = 1, 13 do PA[j] = (j - 3) * 1000 end
    -- each label's nearest line (vertical distance at the label's start)
    local lab_bad, lab_worst = {}, 0
    for _, t in ipairs(d.T) do
        local v = numeric(t)
        if v and t.ang < -5 and t.ang > -40 and t.x > xL and t.x < xM then
            local best, bj, bd = 1e9, nil, nil
            for j = 1, 13 do
                local dy = t.y - at(alts[j], t.x)
                if abs(dy) < best then best, bj, bd = abs(dy), j, dy end
            end
            lab_worst = max(lab_worst, abs(bd))
            if PA[bj] ~= v * 1000 then lab_bad[#lab_bad + 1] = t.text end
        end
    end
    check(#lab_bad == 0, "pressure-altitude labels off their lines: " .. table.concat(lab_bad, " "))
    say("  13 pressure-altitude lines, -2..10 top to bottom (each label on its line, within %.1f pt)", lab_worst)
    -- which limit line runs through the altitude lines' right ends
    local atm, env
    for _, l in ipairs(lims) do
        local worst = 0
        for j = 1, 13 do
            local e = alts[j][#alts[j]]
            local dmin = 1e9
            for k = 2, #l do
                local a, b = l[k - 1], l[k]
                local dx, dy = b[1] - a[1], b[2] - a[2]
                local t = max(0, min(1, ((e[1] - a[1]) * dx + (e[2] - a[2]) * dy) / (dx * dx + dy * dy)))
                dmin = min(dmin, sqrt((a[1] + t * dx - e[1]) ^ 2 + (a[2] + t * dy - e[2]) ^ 2))
            end
            worst = max(worst, dmin)
        end
        if worst < 0.1 then atm = l else env = l end
    end
    check(atm and env, "limit lines")
    -- the labels: ENVIRONMENTAL ... at the env line's angle, ASSUMED ... at the other's
    local function angle_of(l)
        local s = sorted_by(l, 2)
        return math.deg(math.atan2(s[#s][2] - s[1][2], s[#s][1] - s[1][1]))
    end
    for _, t in ipairs(d.T) do
        if t.text:match("^ENVIRONMENTAL") then
            check(abs(t.ang - angle_of(env)) < 10, fmt("ENVIRONMENTAL LIMIT label at %.1f deg", t.ang))
        elseif t.text:match("^ASSUMED") then
            check(abs(t.ang - angle_of(atm)) < 10, fmt("ASSUMED TEMPERATURE label at %.1f deg", t.ang))
        end
    end
    local env_c, atm_c, env_w = {}, {}, {}
    local env_x = extended(sorted_by(env, 2), 0.5)
    for j = 1, 13 do
        local p = crossing(alts[j], env_x)
        check(p, "no environmental limit crossing on line " .. j)
        env_c[j], env_w[j] = oat(p[1]), wt(p[2])
        atm_c[j] = oat(alts[j][#alts[j]][1])
    end
    say("  ENVIRONMENTAL LIMIT (C at -2..10): %s", table.concat((function()
        local r = {} for j = 1, 13 do r[j] = fmt("%.1f", env_c[j]) end return r end)(), " "))
    say("  ASSUMED TEMPERATURE LIMIT (C):     %s", table.concat((function()
        local r = {} for j = 1, 13 do r[j] = fmt("%.1f", atm_c[j]) end return r end)(), " "))

    -- the right part: REF LINE, MINIMUM FIELD LENGTH REQUIRED, guide lines
    local verts, guides = {}, {}
    for _, s in ipairs(right) do
        local x0, x1, y0, y1 = bbox(s.pts)
        if #s.pts == 2 and x1 - x0 < 0.01 then verts[#verts + 1] = {x = x0, y0 = y0, y1 = y1}
        else guides[#guides + 1] = sorted_by(s.pts, 1) end
    end
    check(#verts == 2, "right part verticals")
    table.sort(verts, function(a, b) return a.y1 > b.y1 end)
    local ref, mfl = verts[1], verts[2]
    check(abs(ref.y1 - yT) < 0.5 and abs(ref.y0 - yB) < 0.5 and abs(mfl.y0 - yB) < 0.5, "REF / minimum lines")
    for _, t in ipairs(d.T) do
        if t.text:match("^REF%s+LINE") and abs(t.ang - 90) < 1 then
            check(t.x < ref.x and ref.x - t.x < 6, "REF LINE label not at its line")
        elseif t.text:match("^MINIMUM") then
            check(abs(t.ang - 90) < 1 and t.x < mfl.x and mfl.x - t.x < 6, "MINIMUM FIELD LENGTH label not at its line")
        end
    end
    local ref_ft, min_ft, min_top = ft(ref.x), ft(mfl.x), wt(mfl.y1)
    say("  REF LINE %.1f ft; MINIMUM FIELD LENGTH REQUIRED %.1f ft (up to %.2f t)", ref_ft, min_ft, min_top)
    local G = {}
    for _, g in ipairs(guides) do
        local pts = {}
        for k, p in ipairs(simplify(g, 0.02)) do pts[k] = {ft(p[1]), wt(p[2])} end
        G[#G + 1] = {ref = at(pts, ref_ft), pts = pts, reaches = g[1][1] <= ref.x + 0.05 and g[#g][1] >= ref.x - 0.05}
    end
    table.sort(G, function(a, b) return a.ref < b.ref end)
    local gtxt, gdev = {}, 0
    for i, g in ipairs(G) do
        gtxt[i] = fmt("%.2f%s", g.ref, g.reaches and "" or "*")
        gdev = max(gdev, abs(g.ref - floor(g.ref / 20 + 0.5) * 20))
    end
    say("  %d guide lines, at the REF LINE (t; * carried on to it): %s; off the 20 t steps by %.2f t at most",
        #G, table.concat(gtxt, " "), gdev)

    -- the wind and slope charts: REF LINE and guide lines
    local function small_chart(name, lines, to_u, zero_y)
        local G2, refy = {}, nil
        for _, s in ipairs(lines) do
            local x0, x1, y0, y1 = bbox(s.pts)
            if #s.pts == 2 and y1 - y0 < 0.01 and x1 - x0 > (xR - xM) - 0.5 then
                refy = y0
            else
                local pts = {}
                for k, p in ipairs(s.pts) do pts[k] = {to_u(p[2]), ft(p[1])} end
                table.sort(pts, function(a, b) return a[1] < b[1] end)
                G2[#G2 + 1] = {pts = pts}
            end
        end
        check(refy, name .. ": no REF LINE")
        for _, g in ipairs(G2) do g.ref = at(g.pts, 0) end
        table.sort(G2, function(a, b) return a.ref < b.ref end)
        local r, dev = {}, 0
        for i, g in ipairs(G2) do
            r[i] = fmt("%.0f", g.ref)
            dev = max(dev, abs(g.ref - floor(g.ref / 1000 + 0.5) * 1000))
        end
        say("  %s: REF LINE at %.3f pt from the scale's zero; %d guide lines at it (ft): %s (off the 1000 ft steps"
            .. " by %.1f ft at most)", name, refy - zero_y, #G2, table.concat(r, " "), dev)
        return G2
    end
    local WG = small_chart("wind", wind_l, kt, ha)
    local SG = small_chart("slope", slope_l, pct, sa)

    -- the printed example (the long-dashed lines)
    local ex = {}
    for _, s in ipairs(d.S) do
        local first = tonumber(s.dash:match("^%[([%d%.]+)"))
        if first and first > 5 then
            for k = 2, #s.pts do
                local a, b = s.pts[k - 1], s.pts[k]
                local x0, x1, y0, y1 = min(a[1], b[1]), max(a[1], b[1]), min(a[2], b[2]), max(a[2], b[2])
                local vert, hor = x1 - x0 < 0.3, y1 - y0 < 0.3
                if vert and x0 < xM and y1 > yB + 5 then ex.oat = oat(x0)
                elseif hor and y0 > yB and abs(x1 - ref.x) < 0.5 then ex.wref = wt(y0)
                elseif hor and y0 > yB and abs(x1 - xR) < 0.5 then ex.w, ex.lc_x = wt(y0), x0
                elseif vert and y0 < slope_ax.y0 and y1 <= slope_ax.y1 + 0.5 then ex.fla = ft(x0)
                elseif vert and y0 >= slope_ax.y1 - 0.5 and y1 <= wind_ax.y1 + 0.5 then ex.l1 = ft(x0)
                elseif not vert and not hor and y1 <= slope_ax.y1 + 0.5 and y0 >= slope_ax.y0 - 0.5 then
                    local far = abs(a[2] - (sa)) > abs(b[2] - sa) and a or b
                    ex.slope = pct(far[2])
                elseif not vert and not hor and y1 <= wind_ax.y1 + 0.5 and y0 >= wind_ax.y0 - 0.5 then
                    local far = abs(a[2] - ha) > abs(b[2] - ha) and a or b
                    ex.wind = kt(far[2])
                elseif vert and x0 > xM and y1 > yB then ex.lc = ft(x0)
                end
            end
        end
    end
    check(ex.oat and ex.wref and ex.w and ex.fla and ex.slope and ex.wind and ex.lc and ex.l1,
        "page " .. pg.page .. ": example")
    -- its pressure altitude: where the lines at its OAT take its REF weight
    for j = 1, 12 do
        local w1, w2 = at(alts[j], oa + ob * ex.oat), at(alts[j + 1], oa + ob * ex.oat)
        w1, w2 = wt(w1), wt(w2)
        if ex.wref <= w1 and ex.wref >= w2 then ex.pa = PA[j] + (w1 - ex.wref) / (w1 - w2) * 1000 end
    end
    check(ex.pa, "page " .. pg.page .. ": the example's REF weight off the pressure-altitude lines")
    say("  example: OAT %.2f C, REF %.2f t (pressure altitude %.0f ft by the lines), field length %.0f ft, slope %+.2f %%"
        .. " (then %.0f ft), wind %+.2f kt, corrected %.0f ft, weight %.2f t", ex.oat, ex.wref, ex.pa, ex.fla, ex.slope,
        ex.l1, ex.wind, ex.lc, ex.w)

    -- the pressure-altitude lines in chart units (and the rounding's cost)
    -- (each kept vertex's OAT rounded to 0.1 C and its weight then read on the
    -- drawn line at that OAT, so that the rounding does not move it off the line)
    local P = {}
    for j = 1, 13 do
        local rawc = {}
        for k, p in ipairs(alts[j]) do rawc[k] = {oat(p[1]), wt(p[2])} end
        local pts = {}
        for k, p in ipairs(simplify(alts[j], 0.02)) do
            local u = floor(oat(p[1]) * 10 + 0.5) / 10
            pts[k] = {u, at(rawc, u)}
        end
        P[j] = pts
    end
    -- the limit lines top down (the environmental one has a vertical top part)
    local L = {}
    for _, l in ipairs({env, atm}) do
        local s = sorted_by(l, 2)
        local pts = {}
        for k = #s, 1, -1 do pts[#pts + 1] = {oat(s[k][1]), wt(s[k][2])} end
        L[#L + 1] = pts
    end

    return {
        pg = pg, report = rep, P = P, PA = PA, env = L[1], atm = L[2], env_c = env_c, atm_c = atm_c,
        ref_ft = ref_ft, min_ft = min_ft, min_top = min_top, G = G, WG = WG, SG = SG, ex = ex,
        bleed_off = bleed_off, bleed_one = bleed_one, raw_alts = alts, oat = oat, wt = wt, inv = inv,
        tail_bottom = tail_bottom, head_top = (wind_ax.y1 - ha) / hb,
        oat_lo = oat(xL), oat_hi = oat(xM), w_lo = wt(yB), w_hi = wt(yT), ft_lo = ft(xM), ft_hi = ft(xR),
    }
end

------------------------------------------------------------------------
-- the data block
------------------------------------------------------------------------
local function num(v, dec)
    local s = fmt("%." .. dec .. "f", v)
    if dec > 0 then s = s:gsub("0+$", ""):gsub("%.$", "") end
    if s == "-0" then s = "0" end
    return s
end

-- a curve as flat pairs, rounded, its u strictly rising after the rounding
-- (any_order: as given)
local function flat(pts, du, dv, any_order)
    local out, last = {}, nil
    local dropped = 0
    for _, p in ipairs(pts) do
        local u = tonumber(num(p[1], du))
        if any_order or last == nil or u > last then
            out[#out + 1] = num(p[1], du)
            out[#out + 1] = num(p[2], dv)
            last = u
        else
            dropped = dropped + 1
        end
    end
    return out, dropped
end

-- items after a first line's head, continued at the head's indentation + 4
local function wrap(items, head, width)
    local cont = head:match("^(%s*)") .. "    "
    local lines, cur, fresh = {}, head, true
    for i, it in ipairs(items) do
        local piece = it .. (i < #items and "," or "")
        if #cur + #piece + 1 > width and not fresh then
            lines[#lines + 1] = cur
            cur, fresh = cont .. piece, false
        else
            cur = fresh and cur .. piece or cur .. " " .. piece
            fresh = false
        end
    end
    lines[#lines + 1] = cur
    return table.concat(lines, "\n")
end

-- the worst difference between the rounded curve and the drawn one (t), at 0.05 C steps
local function rounding_cost(c, rounded)
    local pts = {}
    for i = 1, #rounded, 2 do pts[#pts + 1] = {tonumber(rounded[i]), tonumber(rounded[i + 1])} end
    local worst = 0
    local raw = {}
    for k, p in ipairs(c.raw) do raw[k] = {c.oat(p[1]), c.wt(p[2])} end
    local t = raw[1][1]
    while t <= raw[#raw][1] do
        worst = max(worst, abs(at(pts, t) - at(raw, t)))
        t = t + 0.05
    end
    return worst
end

local function block(res)
    local o = {}
    local function w(s) o[#o + 1] = s end
    w("-- BEGIN GENERATED DATA (docs/overhaul/tools/fppm_field_limit.lua from the FPPM's PDF; do not edit by hand)")
    w("-- By flaps: pa[j] the pressure-altitude line pa_ft[j] as {OAT C, weight 1000 kg, ...}, OAT rising, from")
    w("-- the chart's left edge to the ASSUMED TEMPERATURE LIMIT; env/atm the ENVIRONMENTAL and ASSUMED")
    w("-- TEMPERATURE LIMIT lines {OAT, t, ...}; env_c/atm_c where each pa line meets them (C); ref_ft the REF")
    w("-- LINE; min_ft the MINIMUM FIELD LENGTH REQUIRED line (min_top: its top, t); guide: the right part's guide")
    w("-- lines {ft, t, ...} (ref: t at the REF LINE); wind: {kt (head +), ft, ...} (ref: ft at 0 kt); slope:")
    w("-- {% (up +), ft, ...} (ref: ft at 0 %); bleed: the notes' kg (packs off, 1 pack on); scale: the charts'")
    w("-- edges; example: the printed example's dashed lines as read (pa_ft: where the lines put it).")
    w("local DATA = {")
    for _, c in ipairs(res) do
        local pg = c.pg
        w(fmt("    [%d] = {    -- FPPM p.%d (%s)", pg.flaps, pg.page, pg.sec))
        w(fmt("        pa_ft = {%s},", table.concat((function()
            local r = {} for j = 1, 13 do r[j] = tostring(c.PA[j]) end return r end)(), ", ")))
        w("        pa = {")
        local worst, drops = 0, 0
        for j = 1, 13 do
            local f, dr = flat(c.P[j], 1, 2)
            drops = drops + dr
            worst = max(worst, rounding_cost({raw = c.raw_alts[j], oat = c.oat, wt = c.wt}, f))
            w(wrap(f, "            {", 116) .. "},")
        end
        c.report[#c.report + 1] = fmt("  data: the pressure-altitude lines as stored differ from the drawn ones by %.3f t"
            .. " at most (simplified 0.02 pt, rounded 0.1 C and 0.01 t; %d points dropped by the rounding)", worst, drops)
        w("        },")
        w(wrap((flat(c.env, 1, 2, true)), "        env = {", 116) .. "},")
        w(wrap((flat(c.atm, 1, 2, true)), "        atm = {", 116) .. "},")
        local e, a = {}, {}
        for j = 1, 13 do e[j], a[j] = num(c.env_c[j], 1), num(c.atm_c[j], 1) end
        w("        env_c = {" .. table.concat(e, ", ") .. "},")
        w("        atm_c = {" .. table.concat(a, ", ") .. "},")
        w(fmt("        ref_ft = %s, min_ft = %s, min_top = %s,", num(c.ref_ft, 0), num(c.min_ft, 0), num(c.min_top, 2)))
        w("        guide = {")
        for _, g in ipairs(c.G) do
            local f = flat(g.pts, 0, 2)
            w(wrap(f, fmt("            {ref = %s, ", num(g.ref, 2)), 116) .. "},")
        end
        w("        },")
        for _, k in ipairs({"wind", "slope"}) do
            w("        " .. k .. " = {")
            for _, g in ipairs(k == "wind" and c.WG or c.SG) do
                local f = flat(g.pts, k == "wind" and 1 or 2, 0)
                w(wrap(f, fmt("            {ref = %s, ", num(g.ref, 0)), 116) .. "},")
            end
            w("        },")
        end
        w(fmt("        bleed = {%d, %d},", c.bleed_off, c.bleed_one))
        w(fmt("        scale = {oat_lo = %s, oat_hi = %s, w_lo = %s, w_hi = %s, ft_lo = %s, ft_hi = %s,",
            num(c.oat_lo, 1), num(c.oat_hi, 1), num(c.w_lo, 2), num(c.w_hi, 2), num(c.ft_lo, 0), num(c.ft_hi, 0)))
        w(fmt("            head = %s, tail = %s, slope = 2},", num(c.head_top, 1), num(-c.tail_bottom, 1)))
        local ex = c.ex
        w(fmt("        example = {oat_c = %s, pa_ft = %s, fla_ft = %s, slope_pct = %s, wind_kt = %s, ref_t = %s,",
            num(ex.oat, 1), num(ex.pa, 0), num(ex.fla, 0), num(ex.slope, 2), num(ex.wind, 1), num(ex.wref, 2)))
        w(fmt("            slope_ft = %s, lc_ft = %s, w_t = %s},", num(ex.l1, 0), num(ex.lc, 0), num(ex.w, 2)))
        w("    },")
    end
    w("}")
    w("-- END GENERATED DATA")
    return table.concat(o, "\n")
end

------------------------------------------------------------------------
local res = {}
for i, pg in ipairs(PAGES) do res[i] = read_page(pg) end
local data = block(res)
for _, c in ipairs(res) do print(table.concat(c.report, "\n")) end

local f = assert(io.open(model_path, "rb"))
local src = f:read("*a")
f:close()
local a = src:find("-- BEGIN GENERATED DATA", 1, true)
local _, b = src:find("-- END GENERATED DATA", 1, true)
check(a and b and a < b, "no data markers in " .. model_path)
check(not data:find("[\128-\255]"), "non-ASCII in the data")
src = src:sub(1, a - 1) .. data .. src:sub(b + 1)
f = assert(io.open(model_path, "wb"))
f:write(src)
f:close()
print("data written to " .. model_path)

-- the data drawn back in page points, for checking it over the page images
if overlay_path then
    local out = {}
    local function line(page, rgb, pts)
        local t = {}
        for _, p in ipairs(pts) do t[#t + 1] = fmt("%.2f,%.2f", p[1], p[2]) end
        out[#out + 1] = page .. " " .. rgb .. " : " .. table.concat(t, " ")
    end
    -- reads the data back from the written model, so the overlay shows what is stored
    local M = dofile(model_path)
    for _, c in ipairs(res) do
        local D, inv, pgn = M.DATA[c.pg.flaps], c.inv, c.pg.page
        local function back(p, fu, fv, swap)
            local t = {}
            for i = 1, #p, 2 do
                local u, v = fu(p[i]), fv(p[i + 1])
                t[#t + 1] = swap and {v, u} or {u, v}
            end
            return t
        end
        for _, p in ipairs(D.pa) do line(pgn, "255,0,0", back(p, inv.x_oat, inv.y_wt)) end
        line(pgn, "0,160,0", back(D.env, inv.x_oat, inv.y_wt))
        line(pgn, "0,0,255", back(D.atm, inv.x_oat, inv.y_wt))
        for _, g in ipairs(D.guide) do line(pgn, "255,0,255", back(g, inv.x_ft, inv.y_wt)) end
        for _, g in ipairs(D.wind) do line(pgn, "255,128,0", back(g, inv.y_kt, inv.x_ft, true)) end
        for _, g in ipairs(D.slope) do line(pgn, "0,160,160", back(g, inv.y_pct, inv.x_ft, true)) end
        local xr, xm = inv.x_ft(D.ref_ft), inv.x_ft(D.min_ft)
        line(pgn, "0,0,255", {{xr, inv.y_wt(200)}, {xr, inv.y_wt(460)}})
        line(pgn, "0,160,0", {{xm, inv.y_wt(200)}, {xm, inv.y_wt(D.min_top)}})
    end
    f = assert(io.open(overlay_path, "wb"))
    f:write(table.concat(out, "\n") .. "\n")
    f:close()
    print("overlay written to " .. overlay_path)
end
