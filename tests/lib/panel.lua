-- Reading the custom acf's 3D panel for the panel tests (2026-11-24, the
-- stage 4 review's PNL items): every GROUP and generic instrument between
-- PANEL_3D_BEGIN and PANEL_3D_END with its line, kind, name, parent, POS,
-- IMAGE, DATAREF, KEY_FRAMEs and SHOW conditions.
--   local P = dofile("tests/lib/panel.lua")
--   local panel = P.load("747-400_custom.acf")
--   local e = P.find(panel, {kind = "gen_pointer", name = "FD Bar - Pitch"})   -- the first
--   local all = P.find_all(panel, {dref = "laminar/B747/engines/TRA[0]"})
--   P.at(e, v)                 -- the key frames' output for the input v
--   P.shown(e, values)         -- with its groups, for dataref values (missing: 0)
-- X-Plane's rules as the aircraft's notes found them:
--   * KEY_FRAME: linear between the frames; outside the frames the end
--     segment's line goes on (notes/ATA-70-80.md §22: an EPR mark without a
--     flat end went on past the scale). Descending lists are not modelled
--     (the stage 4 review saw X-Plane carry the other end's line on): the
--     tests check that the frames they read ascend.
--   * SHOW: one dataref per element; SHOW_GREATER and SHOW_LESS on it make a
--     range and include their bound; lines on two datarefs: the last one
--     counts (ARCHITECTURE.md §5, 2026-10-25/27).
--   * a GROUP with GROUP_ANIMATE_MODE TRANSLATE moves what it holds by its
--     key frames' output (P.offset: the sum over an element's groups).
local M = {}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function M.load(path)
    local elems = {}
    local stack, cur = {}, nil
    local in_panel = false
    local ln = 0
    for line in io.lines(path) do
        ln = ln + 1
        line = line:gsub("\r$", "")
        if line == "PANEL_3D_BEGIN" then in_panel = true
        elseif line == "PANEL_3D_END" then in_panel = false
        elseif in_panel then
            local kw, rest = trim(line):match("^(%S+)%s*(.*)$")
            if kw == "GROUP" then
                local g = {kind = "GROUP", name = rest, line = ln, kf = {}, show = {}, parent = stack[#stack]}
                elems[#elems + 1] = g
                stack[#stack + 1] = g
                cur = g
            elseif kw == "END_GROUP" then
                stack[#stack] = nil
                cur = nil
            elseif kw and kw:match("^gen_") then
                local e = {kind = kw, name = rest, line = ln, kf = {}, show = {}, parent = stack[#stack]}
                elems[#elems + 1] = e
                cur = e
            elseif kw == nil then
                cur = nil                           -- a blank line ends an instrument
            elseif cur then
                if kw == "KEY_FRAME" then
                    local a, b, c = rest:match("^(%S+)%s+(%S+)%s*(%S*)")
                    cur.kf[#cur.kf + 1] = {tonumber(a), tonumber(b), tonumber(c), line = ln}
                elseif kw == "SHOW_EQUAL" or kw == "SHOW_GREATER" or kw == "SHOW_LESS" then
                    local v, d = rest:match("^(%S+)%s+(%S+)")
                    cur.show[#cur.show + 1] = {op = kw:sub(6), v = tonumber(v), dref = d, line = ln}
                elseif kw == "POS" then
                    local x, y = rest:match("^(%S+)%s+(%S+)")
                    cur.x, cur.y = tonumber(x), tonumber(y)
                elseif kw == "DATAREF" then
                    cur.dref = rest
                elseif kw == "IMAGE" then
                    cur.image = rest
                elseif kw == "GROUP_ANIMATE_MODE" then
                    cur.mode = rest
                else
                    cur[kw] = rest == "" and true or rest
                end
            end
        end
    end
    return elems
end

-- the element's groups, outermost first, joined with " / "
function M.path(e)
    local t = {}
    local p = e.parent
    while p do table.insert(t, 1, p.name); p = p.parent end
    return table.concat(t, " / ")
end

-- does e match the filter: kind, name, dref, image (exact), path (a Lua
-- pattern on M.path), under (a group element it must sit in)
local function matches(e, f)
    if f.kind and e.kind ~= f.kind then return false end
    if f.name and e.name ~= f.name then return false end
    if f.dref and e.dref ~= f.dref then return false end
    if f.image and e.image ~= f.image then return false end
    if f.path and not M.path(e):find(f.path) then return false end
    if f.under then
        local p = e.parent
        while p and p ~= f.under do p = p.parent end
        if p == nil then return false end
    end
    return true
end

function M.find_all(elems, f)
    local out = {}
    for _, e in ipairs(elems) do if matches(e, f) then out[#out + 1] = e end end
    return out
end

function M.find(elems, f)
    for _, e in ipairs(elems) do if matches(e, f) then return e end end
    return nil
end

-- the key frames' inputs ascend (strictly or with a repeated end point)
function M.ascending(e)
    for i = 2, #e.kf do
        if e.kf[i][1] < e.kf[i - 1][1] then return false end
    end
    return #e.kf >= 2
end

-- the output for input v: linear inside, the end segment's line outside
function M.at(e, v)
    local kf = e.kf
    local n = #kf
    if n == 1 then return kf[1][2] end
    local function seg(i)
        local a, b = kf[i], kf[i + 1]
        if b[1] == a[1] then return b[2] end
        return a[2] + (b[2] - a[2]) * (v - a[1]) / (b[1] - a[1])
    end
    if v <= kf[1][1] then return seg(1) end
    for i = 1, n - 1 do
        if v <= kf[i + 1][1] then return seg(i) end
    end
    return seg(n - 1)
end

-- the sum of the TRANSLATE groups' offsets above e (values: dataref -> value)
function M.offset(e, values)
    local sum = 0
    local p = e.parent
    while p do
        if p.mode == "TRANSLATE" and p.dref and #p.kf > 0 then
            sum = sum + M.at(p, values[p.dref] or 0)
        end
        p = p.parent
    end
    return sum
end

-- one element's own condition (see the head of the file)
function M.own_shown(e, values)
    if #e.show == 0 then return true end
    local last = e.show[#e.show].dref
    local v = values[last] or 0
    for _, s in ipairs(e.show) do
        if s.dref == last then
            if s.op == "EQUAL" and v ~= s.v then return false end
            if s.op == "GREATER" and v < s.v then return false end
            if s.op == "LESS" and v > s.v then return false end
        end
    end
    return true
end

-- shown with all its groups
function M.shown(e, values)
    local p = e
    while p do
        if not M.own_shown(p, values) then return false end
        p = p.parent
    end
    return true
end

return M
