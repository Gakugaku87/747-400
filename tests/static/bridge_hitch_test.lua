-- Run from the repository root with LuaJIT: luajit tests/static/bridge_hitch_test.lua
-- (2026-11-13; the 2026-11-12 review D-6, 案 22) the FMS bridge's hitch log
-- (plugins/b747_fms_bridge/src/hitch_log.c): a frame gap of 20 s or more
-- written, marked (before: left out); no lines-a-session cap (before: 300);
-- past 256 KB the file keeps its newest whole lines. Builds hitch_log_test.c
-- with the project's GCC (w64devkit, as docs/overhaul/tools/build_fms_bridge.sh;
-- W64DEVKIT overrides) into the TEMP folder and runs it there. Without that
-- GCC (another PC): skipped, and said so.
local T = dofile("tests/lib/check.lua")("bridge_hitch")

-- Git Bash's /c/... as C:/...
local function win_path(p)
    if p and p:match("^/%a/") then return p:sub(2, 2) .. ":" .. p:sub(3) end
    return p
end

-- a command through cmd.exe (the line quoted once more keeps its own
-- quotes); true when it exits 0 (Lua 5.1's and 5.2's os.execute)
local function run(cmd)
    local a, _, c = os.execute('"' .. cmd .. '"')
    if type(a) == "number" then return a == 0 end
    return a == true or c == 0
end

local function slurp(path)
    local h = io.open(path, "rb")
    if not h then return "" end
    local s = h:read("*a")
    h:close()
    return s
end

local dir = win_path(os.getenv("W64DEVKIT")) or "C:/Users/gakug/tools/w64devkit"
local gcc = (dir .. "/bin/gcc.exe"):gsub("/", "\\")
local h = io.open(gcc, "rb")
if not h then
    print("skipped: no GCC at " .. gcc)
    T.done()
    return
end
h:close()
local tmp = (os.getenv("TEMP") or os.getenv("TMP") or "."):gsub("/", "\\")
local exe = tmp .. "\\b747_hitch_log_test.exe"
local log = tmp .. "\\b747_hitch_log_test.txt"
os.remove(exe)
local built = run('"' .. gcc .. '" -O2 -Wall -Wextra -Werror -std=c99 -o "' .. exe
    .. '" plugins/b747_fms_bridge/src/hitch_log_test.c > "' .. log .. '" 2>&1')
T.check(built, "hitch_log_test.c builds without a warning: " .. slurp(log))
if built then
    -- (the folder ends in "/": a "\" before the closing quote would escape it)
    local ok = run('"' .. exe .. '" "' .. tmp .. '/" > "' .. log .. '" 2>&1')
    local out = slurp(log)
    local n = 0
    for line in out:gmatch("[^\r\n]+") do
        local mark, what = line:match("^(%a+)%s+(.*)$")
        if mark == "ok" or mark == "FAIL" then
            n = n + 1
            T.check(mark == "ok", what)
        end
    end
    T.check(n >= 15, "hitch_log_test.c's checks all reported (" .. n .. ")")
    T.check(ok and out:find("all passed, 0 failed", 1, true) ~= nil, "hitch_log_test.exe exits 0: " .. out)
end
os.remove(exe)
os.remove(log)
T.done()
