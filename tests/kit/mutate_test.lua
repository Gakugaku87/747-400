-- Run from the repository root with LuaJIT: luajit tests/kit/mutate_test.lua
-- The mutation tool (tests/tools/mutate.lua, 2026-11-12; docs/overhaul/
-- TESTING.md §3): the replacement of a text (once, the n-th place, every
-- place, CRLF files, a text not there or there more than once), and the
-- tool run on a small tree made in TEMP: a mutation its test catches, one
-- it does not see, one that loops for ever (the time limit), one not made;
-- the unbroken tests failing; the tree left as it was.
local T = dofile("tests/lib/check.lua")("mutate")
local M = dofile("tests/tools/mutate.lua")

-- the replacement
local text = "local a = 1\nlocal b = a + 1\nreturn a + b\n"
T.equal(M.apply(text, {"b = a + 1", "b = a - 1"}), "local a = 1\nlocal b = a - 1\nreturn a + b\n", "a text there once")
local out, why = M.apply(text, {"a + ", "a - "})
T.check(out == nil and why:find("2 times", 1, true), "a text there twice, no n: not made (" .. tostring(why) .. ")")
T.equal(M.apply(text, {"a + ", "a - ", n = 2}), "local a = 1\nlocal b = a + 1\nreturn a - b\n", "its second place")
T.equal(M.apply(text, {"a + ", "a - ", n = 1}), "local a = 1\nlocal b = a - 1\nreturn a + b\n", "its first place, asked")
T.equal(M.apply(text, {"a + ", "a - ", n = "all"}), "local a = 1\nlocal b = a - 1\nreturn a - b\n", "every place")
out, why = M.apply(text, {"a + ", "a - ", n = 3})
T.check(out == nil and why:find("not 3", 1, true), "a place it does not have: " .. tostring(why))
out, why = M.apply(text, {"nothing", "x"})
T.check(out == nil and why:find("not in the file", 1, true), "a text not there: " .. tostring(why))
out, why = M.apply(text, {"a", "a"})
T.check(out == nil and why:find("same", 1, true), "the same text: " .. tostring(why))
out, why = M.apply(text, {"", "x"})
T.check(out == nil, "no text: not made")
-- no patterns: the text as it is
T.equal(M.apply("x = t[1] % 2 -- (a.b)\n", {"t[1] % 2 -- (a.b)", "t[2]"}), "x = t[2]\n", "magic characters taken as they are")
-- a file with CRLF: the mutation's lines written with LF match, the replacement gets CRLF
local crlf = "if x then\r\n    y = 1\r\nend\r\n"
T.equal(M.apply(crlf, {"if x then\n    y = 1", "if x then\n    y = 2\n    z = 3"}), "if x then\r\n    y = 2\r\n    z = 3\r\nend\r\n",
    "a CRLF file: lines matched and written with CRLF")
T.equal(M.apply(crlf, {"if x then\r\n    y = 1", "y = 0"}), "y = 0\r\nend\r\n", "a mutation written with CRLF as well")

-- the tool on a small tree
local sep = package.config:sub(1, 1)
local WIN = sep == "\\"
local temp = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
local base = temp .. "/b747_mutate_test_" .. os.time()
local function native(p) return WIN and p:gsub("/", "\\") or p end
local function sh(cmd)
    if WIN then cmd = '"' .. cmd .. '"' end
    local a, _, c = os.execute(cmd)
    if a == true then return 0 end
    if type(a) == "number" then return a end
    return c or 1
end
sh((WIN and 'mkdir "' or 'mkdir -p "') .. native(base .. "/tree/lib") .. '" "' .. native(base .. "/tree/tests") .. '"')
local function write(path, s)
    local f = assert(io.open(base .. "/" .. path, "wb"))
    f:write(s)
    f:close()
end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local calc = "local C = {}\r\nfunction C.add(a, b) return a + b end\r\n"
    .. "function C.clamp(x, lo, hi)\r\n    if x < lo then return lo end\r\n    if x > hi then return hi end\r\n    return x\r\nend\r\n"
    .. "function C.sum(n)\r\n    local s, i = 0, 1\r\n    while i <= n do\r\n        s = s + i\r\n        i = i + 1\r\n    end\r\n    return s\r\nend\r\n"
    .. "return C\r\n"
write("tree/lib/calc.lua", calc)
-- the test: add and sum checked, clamp's upper limit not
write("tree/tests/calc_test.lua", 'local C = dofile("lib/calc.lua")\n'
    .. 'assert(C.add(2, 3) == 5, "add")\nassert(C.clamp(-1, 0, 10) == 0, "clamp low")\nassert(C.clamp(5, 0, 10) == 5, "clamp in")\n'
    .. 'assert(C.sum(4) == 10, "sum")\nprint("calc: 4 checks passed")\n')
write("tree/tests/other_test.lua", 'local C = dofile("lib/calc.lua")\nassert(C.add(1, 1) == 2)\n')
write("spec.lua", [[return {
    file = "lib/calc.lua",
    tests = {"tests/other_test.lua", "tests/calc_test.lua"},
    files = {"lib/calc.lua"},
    timeout = 4,
    mutations = {
        {"return a + b", "return a - b"},
        {"if x > hi then return hi end", "if x > hi then return x end", name = "the upper limit"},
        {"i = i + 1", "i = i + 0"},
        {"return a * b", "return a / b"},
        {"if x <", "if x <=", n = 2},
        {"return a + b", "return a + b + 1"},
        {"while i <= n do\n        s = s + i", "while i <= n do\n        s = s + 2 * i"},
    },
}
]])
local luajit = arg and arg[-1] or "luajit"
local function tool(spec, extra)
    local log = base .. "/out.txt"
    local cmd = string.format('"%s" tests/tools/mutate.lua "%s" -r "%s" -m "%s" %s > "%s" 2>&1', luajit, base .. "/" .. spec,
        base .. "/tree", base .. "/mirror", extra or "", log)
    local code = sh(cmd)
    -- (the tool's lines end with CRLF on Windows)
    return code, ((read(log) or ""):gsub("\r\n", "\n"))
end
local code, log = tool("spec.lua")
T.equal(code, 1, "mutations not caught and not made: exit status 1\n" .. log)
T.check(log:find("unbroken: tests/calc_test.lua passes", 1, true), "the unbroken tests pass first")
T.check(log:find("  1  caught by other_test.lua: return a + b -> return a - b", 1, true), "1: caught by the first test that fails")
T.check(log:find("  2  NOT CAUGHT: the upper limit", 1, true), "2: clamp's upper limit not caught, by its name")
T.check(log:find("  3  caught by calc_test.lua", 1, true), "3: a loop that never ends: caught by the time limit")
T.check(log:find("  4  not made (the text is not in the file)", 1, true), "4: a text not there: not made")
T.check(log:find("  5  not made (the text is in the file 1 time(s), not 2)", 1, true), "5: a place not there: not made")
T.check(log:find("  6  caught by other_test.lua", 1, true), "6: caught")
T.check(log:find("  7  caught by calc_test.lua", 1, true), "7: two lines of a CRLF file, the mutation written with LF")
T.check(log:find("7 mutations: 4 caught, 1 not caught, 2 not made", 1, true), "the count")
T.check(log:find("not caught 2 (lib/calc.lua):\n  - if x > hi then return hi end\n  + if x > hi then return x end", 1, true),
    "the one not caught, with its texts")
T.equal(read(base .. "/tree/lib/calc.lua"), calc, "the tree's file as it was")
T.check(read(base .. "/mirror/lib/calc.lua") == nil, "the mirror removed")

-- all caught: exit status 0; -k keeps the mirror, the file there unbroken
write("spec_ok.lua", [[return {
    file = "lib/calc.lua", tests = {"tests/calc_test.lua"}, files = {"lib/calc.lua"},
    mutations = { {"return a + b", "return a - b"}, {"return lo", "return hi"} },
}
]])
code, log = tool("spec_ok.lua", "-k -j")
T.equal(code, 0, "all caught: exit status 0\n" .. log)
T.check(log:find("2 mutations: 2 caught, 0 not caught, 0 not made", 1, true), "the count")
T.equal(read(base .. "/mirror/lib/calc.lua"), calc, "-k: the mirror kept, its file put back")

-- the unbroken test fails: nothing mutated, exit status 3
write("tree/tests/bad_test.lua", 'error("always")\n')
write("spec_bad.lua", [[return {
    file = "lib/calc.lua", tests = {"tests/bad_test.lua"}, files = {"lib/calc.lua"},
    mutations = { {"return a + b", "return a - b"} },
}
]])
code, log = tool("spec_bad.lua")
T.equal(code, 3, "the test fails on the unbroken file: exit status 3")
T.check(log:find("the test fails on the unbroken file: tests/bad_test.lua", 1, true), "and says so")

sh((WIN and 'rmdir /s /q "' or 'rm -rf "') .. native(base) .. '"')
T.done()
