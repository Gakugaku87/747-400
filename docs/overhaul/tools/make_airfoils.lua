-- The custom acf's main wing airfoils with an earlier stall, so that the
-- X-Plane flight model stalls at the FCTM's stall speeds (FCTM p.261-262
-- (7.13-7.14), notes/FCTM.md section 1.14; the acf with the stock Boeing
-- airfoils stalled about 21 kt slower clean and not at all with flaps 30).
-- Run from the repository root:
--   luajit docs/overhaul/tools/make_airfoils.lua <shift deg>
-- For each of the stock "Boeing Root/Mid/Tip (high subsonic).afl" it writes
-- airfoils/B744_<root|mid|tip>_custom.afl (the stock files stay for the
-- stock acf). The linear part of the lift curve is kept; the rounding to
-- CL max, the stall and the drag rise move SHIFT degrees lower:
--   - from the end of the linear part to CL max: the stock shape moved down
--     by SHIFT degrees and by slope * SHIFT in CL (so CL max is lower);
--   - the drop after CL max: the stock drop, scaled by the CL max ratio;
--   - after the drop: the stock post-stall curve scaled by the ratio, the
--     shift fading out by 60 deg and the ratio by 90 deg (flat plate);
--   - the drag: the stock stall drag rise starts at the new CL max, fading
--     back to the stock drag by 60 deg.
-- The pitching moment and the negative side are the stock ones. The fit
-- parameters on the parameter line (stall alpha, end of the linear part,
-- CL max, stall drop) are updated to match. Line endings are kept.
local shift = tonumber(arg[1])
assert(shift and shift >= 0 and shift < 9, "usage: make_airfoils.lua <shift deg, 0-9>")

local FOILS = {
    {"Boeing Root (high subsonic).afl", "B744_root_custom.afl"},
    {"Boeing Mid (high subsonic).afl", "B744_mid_custom.afl"},
    {"Boeing Tip (high subsonic).afl", "B744_tip_custom.afl"},
}

local function read_lines(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    local lines = {}
    for l in text:gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
    return lines
end

local function fmt_param(v)
    return string.format("%.5f", v)
end

for _, pair in ipairs(FOILS) do
    local src, dst = "airfoils/" .. pair[1], "airfoils/" .. pair[2]
    local lines = read_lines(src)
    -- the parameter line follows the line "1" (one Reynolds number set)
    local pi
    for i, l in ipairs(lines) do
        if l:gsub("\r$", "") == "1" and lines[i + 2] and lines[i + 2]:match("^alpha cl cd cm") then pi = i + 1 end
    end
    assert(pi, "no parameter line in " .. src)
    local params = {}
    for x in lines[pi]:gmatch("%S+") do params[#params + 1] = tonumber(x) end
    assert(#params == 25, "parameter count in " .. src)
    local slope, a_stall, a_lin = params[2], params[5], params[6]

    -- the stock table
    local rows, first = {}, pi + 2
    for i = first, #lines do
        local a, cl, cd, cm = lines[i]:match("^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        assert(a, "bad row " .. i .. " in " .. src)
        rows[#rows + 1] = {a = tonumber(a), cl = tonumber(cl), cd = tonumber(cd), cm = tonumber(cm),
                           cr = lines[i]:sub(-1) == "\r"}
    end
    local function at(field, a)
        if a <= rows[1].a then return rows[1][field] end
        for i = 2, #rows do
            if rows[i].a >= a then
                local p, q = rows[i - 1], rows[i]
                return p[field] + (q[field] - p[field]) * (a - p.a) / (q.a - p.a)
            end
        end
        return rows[#rows][field]
    end
    local clmax = at("cl", a_stall)
    local new_lin, new_stall = a_lin - shift, a_stall - shift
    local new_clmax = clmax - slope * shift
    local ratio = new_clmax / clmax
    local drop_end = a_stall + 4                    -- the stock drop is 4 deg wide
    local c0 = at("cd", a_stall) - at("cd", new_stall)

    local function shift_at(a)                       -- the shift, fading out after the drop
        if a <= drop_end - shift then return shift end
        if a >= 60 then return 0 end
        return shift * (60 - a) / (60 - (drop_end - shift))
    end
    local function ratio_at(a)
        if a <= 45 then return ratio end
        if a >= 90 then return 1 end
        return ratio + (1 - ratio) * (a - 45) / 45
    end
    local function new_cl(a)
        if a <= new_lin or a > 90 then return at("cl", a) end
        if a <= new_stall then return at("cl", a + shift) - slope * shift end
        if a <= drop_end - shift then
            return new_clmax - (clmax - at("cl", a + shift)) * ratio
        end
        return ratio_at(a) * at("cl", a + shift_at(a))
    end
    local function new_cd(a)
        if a <= new_stall or a >= 60 then return at("cd", a) end
        local s = shift_at(a)
        return at("cd", a + s) - c0 * s / shift
    end

    local out = {}
    for i = 1, pi - 1 do out[#out + 1] = lines[i] end
    params[5], params[6], params[8] = new_stall, new_lin, new_clmax
    params[11] = params[11] * ratio
    local p = {}
    for k, v in ipairs(params) do p[k] = fmt_param(v) end
    out[#out + 1] = table.concat(p, " ") .. (lines[pi]:sub(-1) == "\r" and "\r" or "")
    out[#out + 1] = lines[pi + 1]
    for _, r in ipairs(rows) do
        local cl, cd = r.cl, r.cd
        if shift > 0 then cl, cd = new_cl(r.a), new_cd(r.a) end
        out[#out + 1] = string.format("%6.1f %8.5f %8.5f %8.5f", r.a, cl, cd, r.cm) .. (r.cr and "\r" or "")
    end
    local f = assert(io.open(dst, "wb"))
    f:write(table.concat(out, "\n"), "\n")
    f:close()
    print(string.format("%s: CL max %.3f at %.1f deg -> %.3f at %.1f deg (linear to %.1f deg), ratio %.3f",
        pair[2], clmax, a_stall, new_clmax, new_stall, new_lin, ratio))
end
