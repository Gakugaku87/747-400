-- Run from the repository root with LuaJIT: luajit tests/static/no_frame_gc_test.lua
-- (2026-11-05 review) no full garbage collection in the aircraft's Lua:
-- the fuel, EEC, ND and FDR modules called collectgarbage("collect") in
-- after_physics, marking and sweeping their plugin's whole Lua state (all
-- its modules' tables) every frame, fuel and EEC twice in one state. Lua's
-- incremental collector runs as memory is allocated. A collection at a
-- module's load, once, is allowed (ALLOWED).
local T = dofile("tests/lib/check.lua")("no_frame_gc")
local src = dofile("tests/lib/source.lua")

local ALLOWED = {
    ["B747.95.xt.AI.lua"] = true,   -- once, when the module loads (upstream)
}

local files = src.lua_files()
T.check(#files > 100, "aircraft Lua files found (" .. #files .. ")")
local found = 0
for _, path in ipairs(files) do
    local name = path:match("([^/]+)$")
    local n = 0
    for line in (src.read(path) .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        if code:find('collectgarbage%s*%(%s*"collect"') then
            found = found + 1
            T.check(ALLOWED[name] ~= nil, "a full garbage collection: " .. path .. ":" .. n)
        end
    end
end
T.check(found <= 1, "only the AI module's load-time collection (" .. found .. ")")
T.done()
