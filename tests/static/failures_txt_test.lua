-- Run from the repository root with LuaJIT: luajit tests/static/failures_txt_test.lua
-- (2026-11-13; the 2026-11-12 review, 案 21) The failure window's list,
-- plugins/b747_fms_bridge/failures.txt (its format: the file's head;
-- docs/overhaul/notes/FAILURES.md), against what exists, without X-Plane:
--   - each failure's dataref made by an init script (run as XLua runs them:
--     tests/lib/xtlua.lua) or in X-Plane's Resources/plugins/DataRefs.txt,
--     writable, an array's element named and within it, a scalar not
--     indexed; kind "on" one of ours, "xp" one of X-Plane's, else a number;
--   - one of ours looked up by an xt module (a failure nothing reads fails
--     nothing);
--   - its label ASCII (X-Plane's font) and at most 40 letters; the same
--     failure not twice;
--   - a diagram after its chapter's failures, its lines horizontal or
--     vertical and on the canvas (1000 x 700), its texts at most 63
--     letters, each box a failure of the chapter's list.
-- The window reads the file when it opens (no rebuild): a line it cannot
-- use is left out without a word. On 2026-11-12 the review's check found
-- nothing wrong; this test keeps it so. Small broken samples run too, so the
-- test fails if the checker stops seeing them. Without X-Plane's
-- DataRefs.txt (set XPLANE_ROOT) the test fails, as sim_datarefs_test does.
local T = dofile("tests/lib/check.lua")("failures_txt")
local xtlua = dofile("tests/lib/xtlua.lua")
local source = dofile("tests/lib/source.lua")

local FILE = "plugins/b747_fms_bridge/failures.txt"

local types, _, init_writable = xtlua.created()
T.check(xtlua.datarefs_txt_found, "X-Plane's Resources/plugins/DataRefs.txt not found (set XPLANE_ROOT)")
-- X-Plane's datarefs: name -> writable
local xp = {}
local f = io.open(xtlua.xplane_root .. "/Resources/plugins/DataRefs.txt", "rb")
if f then
    for line in f:lines() do
        local name, _, w = line:match("^(%S+)\t(%S+)\t(%S+)")
        if name then xp[name] = w == "y" end
    end
    f:close()
end

-- the datarefs the xt modules look up
local looked = {}
for _, path in ipairs(source.lua_files()) do
    local instance, mod = path:match("^(plugins/[^/]+)/scripts/([^/]+)/[^/]+%.lua$")
    if instance and path == instance .. "/scripts/" .. mod .. "/" .. mod .. ".lua" then
        math.randomseed(1)
        local rt = xtlua.new()
        local ok, err = pcall(function() rt:load(path) end)
        T.check(ok, path .. " does not load: " .. tostring(err))
        for name in pairs(rt.bound) do looked[name] = true end
    end
end

-- the problems of a failures.txt's text (a list of "line n: ...")
local function check_text(text)
    local problems = {}
    local n, chapter, list, in_diagram, seen = 0, nil, {}, false, {}
    local function bad(what) problems[#problems + 1] = ("line %d: %s"):format(n, what) end
    local function check_ref(full, kind, label, what)
        local base, idx = full:match("^(.-)%[(%d+)%]$")
        base = base or full
        local t = types[base]
        if not t then bad(what .. ": no such dataref: " .. full) return end
        local size = tonumber((t.type or ""):match("^array%[(%d+)%]$"))
        local ours = init_writable[base] ~= nil
        local writable = ours and init_writable[base] == "yes" or (not ours and xp[base])
        if idx then
            if not size then bad(what .. ": an element of a " .. t.type .. " dataref: " .. full)
            elseif tonumber(idx) >= size then bad(what .. ": the element beyond " .. t.type .. ": " .. full) end
        elseif size then
            bad(what .. ": a " .. t.type .. " dataref without an element: " .. full)
        end
        if not writable then bad(what .. ": not writable: " .. full) end
        if kind == "xp" and ours then bad(what .. ": kind xp on one of our datarefs: " .. full) end
        if kind == "on" and not ours then bad(what .. ": kind on with X-Plane's dataref: " .. full) end
        if kind ~= "on" and kind ~= "xp" and not tonumber(kind) then bad(what .. ": kind \"" .. kind .. "\"") end
        if #label > 40 then bad(what .. ": label over 40 letters: " .. label) end
        if label:find("[\128-\255]") then bad(what .. ": label not ASCII: " .. label) end
        if ours and not looked[base] then bad(what .. ": no xt module looks it up (a failure nothing reads): " .. full) end
    end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        line = line:gsub("\r$", "")
        local tag, rest = line:match("^(%u)%s+(.*)$")
        if line:match("^D%s*$") then tag, rest = "D", "" end
        if line:sub(1, 1) == "#" or line:match("^%s*$") then
            -- a comment or a blank line
        elseif tag == "C" then
            chapter, list, in_diagram = rest, {}, false
        elseif tag == "G" then
            if in_diagram then bad("G after the chapter's diagram began") end
        elseif tag == "F" then
            local full, kind, label = rest:match("^(%S+)%s+(%S+)%s+(.+)$")
            if not full then bad("F line not read: " .. line)
            else
                if not chapter then bad("F before a chapter") end
                if in_diagram then bad("F after the chapter's diagram began: " .. full) end
                check_ref(full, kind, label, "F")
                local key = full .. " " .. kind
                if seen[key] then bad("the same failure twice: " .. key .. " (line " .. seen[key] .. ")") end
                seen[key] = n
                list[key] = true
            end
        elseif tag == "D" then
            in_diagram = true
        elseif tag == "L" then
            local x1, y1, x2, y2 = rest:match("^(%-?[%d.]+)%s+(%-?[%d.]+)%s+(%-?[%d.]+)%s+(%-?[%d.]+)%s*$")
            if not x1 then bad("L line not read: " .. line)
            else
                x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
                if x1 ~= x2 and y1 ~= y2 then bad("L neither horizontal nor vertical: " .. rest) end
                if math.max(x1, x2) > 1000 or math.max(y1, y2) > 700 or math.min(x1, x2, y1, y2) < 0 then bad("L off the canvas: " .. rest) end
            end
            if not in_diagram then bad("L outside a diagram") end
        elseif tag == "T" then
            local x, y, t = rest:match("^(%-?[%d.]+)%s+(%-?[%d.]+)%s+(.+)$")
            if not x then bad("T line not read: " .. line)
            elseif #t > 63 then bad("T text over 63 letters") end
            if not in_diagram then bad("T outside a diagram") end
        elseif tag == "B" then
            local x, y, w, h, full, kind = rest:match("^(%-?[%d.]+)%s+(%-?[%d.]+)%s+(%-?[%d.]+)%s+(%-?[%d.]+)%s+(%S+)%s+(%S+)%s+(.+)$")
            if not x then bad("B line not read: " .. line)
            else
                if not list[full .. " " .. kind] then bad("B's failure not in the chapter's list: " .. full .. " " .. kind) end
                if tonumber(x) + tonumber(w) > 1000 or tonumber(y) + tonumber(h) > 700 then bad("B off the canvas: " .. rest) end
            end
            if not in_diagram then bad("B outside a diagram") end
        else
            bad("line not read: " .. line)
        end
    end
    return problems, seen
end

-- the samples: each must give the problem named
local samples = {
    {"C 21 X\nF laminar/B747/no/such/fail on NO SUCH", "no such dataref"},
    {"C 21 X\nF sim/weather/aircraft/temperature_ambient_deg_c xp OAT", "not writable"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht on PACK", "without an element"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[9] on PACK", "the element beyond"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] xp PACK", "kind xp on one of our datarefs"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] maybe PACK", "kind \"maybe\""},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] on " .. string.rep("A", 41), "label over 40 letters"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] on PACK\nF laminar/B747/air/fail/pack_ovht[0] on PACK", "the same failure twice"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] on PACK\nD\nL 0 0 10 10", "neither horizontal nor vertical"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] on PACK\nD\nB 10 10 50 20 laminar/B747/air/fail/pack_ovht[1] on PACK 2", "not in the chapter's list"},
    {"C 21 X\nF laminar/B747/air/fail/pack_ovht[0] on PACK\nD\nF laminar/B747/air/fail/pack_ovht[1] on PACK 2", "after the chapter's diagram began"},
}
for _, s in ipairs(samples) do
    local got = check_text(s[1])
    local hit = false
    for _, p in ipairs(got) do if p:find(s[2], 1, true) then hit = true end end
    T.check(hit, "the sample \"" .. s[1]:gsub("\n", " / ") .. "\": want \"" .. s[2] .. "\", got: " .. table.concat(got, "; "))
end
T.equal(#check_text("C 21 X\nG PACKS\nF laminar/B747/air/fail/pack_ovht[0] on PACK 1 OVERHEAT\nD\nL 10 10 100 10\nT 50 50 PACKS\n"
    .. "B 10 20 80 30 laminar/B747/air/fail/pack_ovht[0] on PACK 1"), 0, "a good sample: no problem")

-- the file
local file = io.open(FILE, "rb")
T.check(file ~= nil, FILE .. " not found")
local text = file and file:read("*a") or ""
if file then file:close() end
local problems, seen = check_text(text)
local count = 0
for _ in pairs(seen) do count = count + 1 end
T.check(count > 300, FILE .. ": failures found (" .. count .. ")")
for _, p in ipairs(problems) do T.check(false, FILE .. ": " .. p) end
T.done()
