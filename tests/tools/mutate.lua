-- Mutation testing: breaks a file one place at a time and runs the tests on
-- each, to find the places a test does not see (2026-11-12; docs/overhaul/
-- TESTING.md §3). For the speed law's near-level path the law, the VNAV
-- mode model and the glue were broken in 64 ways with a throwaway tool and
-- the gaps in the tests closed (notes/ATA-22.md §62); this is that tool,
-- kept. Run from the repository's root:
--   luajit tests/tools/mutate.lua <spec.lua> [-k] [-j] [-m <folder>] [-r <root>]
-- The spec is a Lua file that returns a table:
--   return {
--     file = "plugins/.../B747.70.afds_pitch_model.lua",   -- the file broken
--     tests = {"tests/autopilot/afds_pitch_model_test.lua", ...},
--     mutations = {
--       {"SPD_LEVEL_FPM = 100", "SPD_LEVEL_FPM = 0"},      -- text -> text
--       {"way > 0", "way < 0", n = 2},                     -- its 2nd place
--       {"math.max(", "math.min(", n = "all"},             -- every place
--       {"x + 1", "x - 1", file = "plugins/.../other.lua", name = "the sign"},
--     },
--     files = {"747-400_custom.acf"},     -- more files the tests read
--     timeout = 120,                      -- seconds a test may take (below)
--   }
-- The text is taken as it is (no patterns) and must be in the file once,
-- unless n says which place; line ends are matched as LF or CRLF.
-- Nothing in the repository is changed: the files the tests need (the
-- working tree's plugins and tests as git lists them, tracked or not, less
-- binaries; docs/overhaul/INTERFACES.tsv; the spec's files) are copied to
-- a folder under TEMP (or -m), the mutations made there and the tests run
-- there (XPLANE_ROOT set to X-Plane's folder as the tests find it here).
-- First the tests run unbroken: they must pass. Then, for each mutation,
-- the tests in their order until one fails (the mutation is caught).
-- Printed: a line a mutation (caught by which test, or NOT CAUGHT, or not
-- made: the text not found, or found more than once without n), then the
-- ones not caught. Exit status 1 when any was not caught or not made.
-- A broken loop can run for ever: each test runs with the JIT compiler off
-- and a time limit (ten times its unbroken time, at least 60 s, or the
-- spec's timeout); over it counts as caught. -j keeps the JIT on, with no
-- limit (faster; for mutations that cannot loop). -k keeps the folder.
--   local M = dofile("tests/tools/mutate.lua")     -- in the tests:
--   M.apply(text, mutation) -> text or nil, why
local M = {}

local WIN = package.config:sub(1, 1) == "\\"

-- the text with the mutation made, or nil and why not. Line ends: the
-- mutation's LF also matches the file's CRLF
function M.apply(text, m)
    local from, to = m[1], m[2]
    if type(from) ~= "string" or type(to) ~= "string" or from == "" then return nil, "no text to replace" end
    if from == to then return nil, "the replacement is the same text" end
    local crlf = text:find("\r\n", 1, true) ~= nil
    if crlf then
        from = from:gsub("\r?\n", "\r\n")
        to = to:gsub("\r?\n", "\r\n")
    end
    local places = {}
    local at = 1
    while true do
        local s, e = text:find(from, at, true)
        if not s then break end
        places[#places + 1] = {s, e}
        at = e + 1
    end
    if #places == 0 then return nil, "the text is not in the file" end
    local n = m.n or 1
    if n == "all" then
        local out, last = {}, 1
        for _, p in ipairs(places) do
            out[#out + 1] = text:sub(last, p[1] - 1)
            out[#out + 1] = to
            last = p[2] + 1
        end
        out[#out + 1] = text:sub(last)
        return table.concat(out)
    end
    if not m.n and #places > 1 then return nil, "the text is in the file " .. #places .. " times (give n)" end
    local p = places[n]
    if not p then return nil, "the text is in the file " .. #places .. " time(s), not " .. tostring(n) end
    return text:sub(1, p[1] - 1) .. to .. text:sub(p[2] + 1)
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function write_file(path, s)
    local f = assert(io.open(path, "wb"))
    f:write(s)
    f:close()
end
local function native(path) return WIN and path:gsub("/", "\\") or path end
local function quote(s) return '"' .. s .. '"' end
-- os.execute's status as a number (LuaJIT gives the number, or true/nil and
-- the code with the 5.2 options)
local function run(cmd)
    if WIN then cmd = '"' .. cmd .. '"' end
    local a, _, c = os.execute(cmd)
    if a == true then return 0 end
    if type(a) == "number" then return a end
    return c or 1
end
local function capture(cmd)
    local p = io.popen(cmd)
    if not p then return nil end
    local s = p:read("*a")
    p:close()
    return s
end

local BINARY = {xpl = true, dll = true, exe = true, png = true, dds = true, obj = true, wav = true, bank = true,
    pdf = true, zip = true, jpg = true, lib = true, o = true, a = true, so = true, dylib = true, ogg = true}

-- the files to copy: what git lists (tracked, and untracked but not
-- ignored) under plugins and tests, less binaries; without git, nothing
local function listed(root)
    local out = {}
    local cmd = (WIN and 'cd /d ' or 'cd ') .. quote(native(root)) .. ' && git ls-files -co --exclude-standard -- plugins tests'
        .. (WIN and ' 2>nul' or ' 2>/dev/null')
    local s = capture(cmd) or ""
    for line in s:gmatch("[^\r\n]+") do
        local ext = line:match("%.([%w_]+)$")
        if not (ext and BINARY[ext:lower()]) then out[#out + 1] = line end
    end
    return out
end

local function make_dirs(mirror, files)
    local dirs, seen = {}, {}
    for _, f in ipairs(files) do
        local d = f:match("^(.*)/[^/]*$")
        if d and not seen[d] then seen[d] = true; dirs[#dirs + 1] = d end
    end
    -- a folder whose subfolder is made is made with it: the deepest only
    table.sort(dirs)
    local leaves = {}
    for i, d in ipairs(dirs) do
        local nxt = dirs[i + 1]
        if not (nxt and nxt:sub(1, #d + 1) == d .. "/") then leaves[#leaves + 1] = d end
    end
    local batch, len = {}, 0
    local function flush()
        if #batch == 0 then return end
        run((WIN and "mkdir " or "mkdir -p ") .. table.concat(batch, " ") .. (WIN and " 2>nul" or ""))
        batch, len = {}, 0
    end
    for _, d in ipairs(leaves) do
        local q = quote(native(mirror .. "/" .. d))
        if len + #q > 6000 then flush() end
        batch[#batch + 1] = q
        len = len + #q + 1
    end
    flush()
end

local function abs_path(root)
    local s = capture((WIN and 'cd /d ' or 'cd ') .. quote(native(root)) .. (WIN and ' && cd' or ' && pwd'))
    return s and s:gsub("[\r\n]+$", "") or root
end

-- the child: a test with the JIT off and a time limit
local function child(seconds, test)
    if jit then jit.off() end
    local limit = os.clock() + seconds
    debug.sethook(function()
        if os.clock() > limit then error("mutate: over the time limit of " .. seconds .. " s", 0) end
    end, "", 100000)
    arg = {[0] = test, [-1] = arg and arg[-1]}
    local ok, err = pcall(dofile, test)
    debug.sethook()
    if not ok then
        io.stderr:write(tostring(err), "\n")
        os.exit(1)
    end
    os.exit(0)
end

local function main(argv)
    local spec_path, mirror, root
    local keep, jit_on = false, false
    local i = 1
    while argv[i] do
        local a = argv[i]
        if a == "-k" then keep = true
        elseif a == "-j" then jit_on = true
        elseif a == "-m" then i = i + 1; mirror = argv[i]
        elseif a == "-r" then i = i + 1; root = argv[i]
        elseif not spec_path then spec_path = a
        else error("what is " .. a .. "?", 0) end
        i = i + 1
    end
    if not spec_path then
        io.stderr:write("usage: luajit tests/tools/mutate.lua <spec.lua> [-k] [-j] [-m <folder>] [-r <root>]\n")
        return 2
    end
    root = root or "."
    local spec = assert(loadfile(spec_path))()
    assert(type(spec) == "table" and type(spec.tests) == "table" and #spec.tests > 0, "the spec: tests = {...}")
    assert(type(spec.mutations) == "table" and #spec.mutations > 0, "the spec: mutations = {...}")
    local luajit = arg and arg[-1] or "luajit"
    local tool = (arg and arg[0]) or "tests/tools/mutate.lua"

    -- the mirror
    local temp = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
    mirror = mirror or (temp:gsub("\\", "/") .. "/b747_mutate_" .. os.time() .. "_" .. math.floor(os.clock() * 1000))
    local files, have = {}, {}
    local function want(f)
        if not have[f] then have[f] = true; files[#files + 1] = f end
    end
    for _, f in ipairs(listed(root)) do want(f) end
    if read_file(root .. "/docs/overhaul/INTERFACES.tsv") then want("docs/overhaul/INTERFACES.tsv") end
    for _, f in ipairs(spec.files or {}) do want(f) end
    for _, t in ipairs(spec.tests) do want(t) end
    if spec.file then want(spec.file) end
    for _, m in ipairs(spec.mutations) do if m.file then want(m.file) end end
    local tool_rel = tool:gsub("\\", "/")
    want(tool_rel)
    make_dirs(mirror, files)
    local copied = 0
    for _, f in ipairs(files) do
        local s = read_file(root .. "/" .. f) or (f == tool_rel and read_file(tool)) or nil
        if s then write_file(mirror .. "/" .. f, s); copied = copied + 1 end
    end
    print(string.format("%d files copied to %s", copied, mirror))

    -- X-Plane's folder for the tests' DataRefs.txt, as they find it here
    local xp = os.getenv("XPLANE_ROOT")
    if not xp then
        local here = abs_path(root)
        local up = here:gsub("[/\\][^/\\]+[/\\][^/\\]+$", "")
        if read_file(up .. "/Resources/plugins/DataRefs.txt") then xp = up end
    end
    local env = ""
    if xp then env = WIN and ('set "XPLANE_ROOT=' .. xp .. '" && ') or ('XPLANE_ROOT=' .. quote(xp) .. ' ') end
    local function run_test(test, seconds)
        local cmd = (WIN and 'cd /d ' or 'cd ') .. quote(native(mirror)) .. ' && ' .. env .. quote(luajit) .. ' '
        if seconds then
            cmd = cmd .. quote(tool_rel) .. ' --run ' .. seconds .. ' ' .. quote(test)
        else
            cmd = cmd .. quote(test)
        end
        cmd = cmd .. (WIN and ' >nul 2>nul' or ' >/dev/null 2>&1')
        local t0 = os.time()
        local code = run(cmd)
        return code == 0, os.time() - t0
    end

    -- unbroken: the tests must pass; their time for the limit
    local limit = {}
    for _, t in ipairs(spec.tests) do
        local ok, secs = run_test(t, (not jit_on) and (spec.timeout or 3600) or nil)
        if not ok then
            print("the test fails on the unbroken file: " .. t .. " (in " .. mirror .. ")")
            return 3
        end
        limit[t] = spec.timeout or math.max(60, secs * 10)
        print(string.format("unbroken: %s passes (%d s)", t, secs))
    end

    local not_caught, not_made = {}, {}
    for n, m in ipairs(spec.mutations) do
        local file = m.file or spec.file
        local label = m.name or (tostring(m[1]):gsub("%s+", " "):sub(1, 60) .. " -> " .. tostring(m[2]):gsub("%s+", " "):sub(1, 60))
        local text = file and read_file(root .. "/" .. file)
        local broken, why
        if not text then
            why = "no file " .. tostring(file)
        else
            broken, why = M.apply(text, m)
        end
        if not broken then
            not_made[#not_made + 1] = n
            print(string.format("%3d  not made (%s): %s", n, why, label))
        else
            write_file(mirror .. "/" .. file, broken)
            local caught
            for _, t in ipairs(spec.tests) do
                local ok = run_test(t, (not jit_on) and limit[t] or nil)
                if not ok then caught = t; break end
            end
            write_file(mirror .. "/" .. file, text)
            if caught then
                print(string.format("%3d  caught by %s: %s", n, caught:match("[^/]+$"), label))
            else
                not_caught[#not_caught + 1] = n
                print(string.format("%3d  NOT CAUGHT: %s", n, label))
            end
        end
    end
    print(string.format("%d mutations: %d caught, %d not caught, %d not made", #spec.mutations,
        #spec.mutations - #not_caught - #not_made, #not_caught, #not_made))
    for _, n in ipairs(not_caught) do
        local m = spec.mutations[n]
        print(string.format("not caught %d (%s):\n  - %s\n  + %s", n, m.file or spec.file, tostring(m[1]), tostring(m[2])))
    end
    if not keep then
        run((WIN and "rmdir /s /q " or "rm -rf ") .. quote(native(mirror)))
    else
        print("kept: " .. mirror)
    end
    return (#not_caught + #not_made) > 0 and 1 or 0
end

if arg and arg[0] and arg[0]:match("mutate%.lua$") then
    if arg[1] == "--run" then
        child(tonumber(arg[2]), arg[3])
    else
        local ok, code = pcall(main, arg)
        if not ok then
            io.stderr:write(tostring(code), "\n")
            os.exit(2)
        end
        os.exit(code)
    end
end

return M
