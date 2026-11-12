-- Run from the repository root with LuaJIT: luajit tests/static/sim_datarefs_test.lua
-- X-Plane's datarefs the aircraft's XTLua modules look up (find_dataref
-- with a sim/ name) and their types, against the list beside this file
-- (sim_datarefs.tsv: the name and its type, "-" for a name X-Plane's list
-- does not have), 2026-11-12 (docs/overhaul/TESTING.md §3).
-- The regression tests take the types of X-Plane's datarefs from X-Plane's
-- Resources/plugins/DataRefs.txt (tests/lib/xtlua.lua): a dataref missing
-- there reads 0 and takes no write, an int cuts its values. Where there is
-- no X-Plane (a cloud session) another list stands in for that file (set
-- XPLANE_ROOT to a folder with Resources/plugins/DataRefs.txt): this test
-- says whether it gives the modules the same datarefs as the development
-- PC's X-Plane did when the list was written.
--   luajit tests/static/sim_datarefs_test.lua write
-- writes the list anew from the DataRefs.txt the tests read: on the
-- development PC, when the test fails for a dataref a module newly looks
-- up (or no longer does), and after an X-Plane update that changed a type.
local T = dofile("tests/lib/check.lua")("sim_datarefs")
local xtlua = dofile("tests/lib/xtlua.lua")
local source = dofile("tests/lib/source.lua")
local LIST = "tests/static/sim_datarefs.tsv"

-- every module loaded as XTLua loads it: the sim/ names it looks up
local bound, types = {}, nil
for _, path in ipairs(source.lua_files()) do
    local instance, mod = path:match("^(plugins/[^/]+)/scripts/([^/]+)/[^/]+%.lua$")
    if instance and path == instance .. "/scripts/" .. mod .. "/" .. mod .. ".lua" then
        math.randomseed(1)
        local rt = xtlua.new()
        types = types or rt.types
        local ok, err = pcall(function() rt:load(path) end)
        T.check(ok, path .. " does not load: " .. tostring(err))
        for name in pairs(rt.bound) do
            if name:sub(1, 4) == "sim/" then bound[name] = true end
        end
    end
end
local function type_of(name)
    local t = types[name]
    if not t then return "-" end
    return (t.int and "int " or "") .. t.type
end
local names = {}
for name in pairs(bound) do names[#names + 1] = name end
table.sort(names)

if arg and arg[1] == "write" then
    assert(xtlua.datarefs_txt_found, "no Resources/plugins/DataRefs.txt (set XPLANE_ROOT): nothing written")
    local f = assert(io.open(LIST, "wb"))
    for _, name in ipairs(names) do f:write(name, "\t", type_of(name), "\n") end
    f:close()
    print(("%s: %d datarefs written"):format(LIST, #names))
    return
end

T.check(xtlua.datarefs_txt_found, "X-Plane's Resources/plugins/DataRefs.txt not found (set XPLANE_ROOT)")
local listed, count = {}, 0
local f = io.open(LIST, "rb")
T.check(f ~= nil, "no " .. LIST)
if f then
    for line in f:lines() do
        local name, t = line:gsub("\r", ""):match("^(%S+)\t(.+)$")
        if name then listed[name] = t; count = count + 1 end
    end
    f:close()
end
T.check(count > 500, "the list has " .. count .. " datarefs (more than 500 expected)")

local HOW = " - on the development PC (X-Plane's own DataRefs.txt): the modules or X-Plane changed, write the list anew"
    .. " (luajit tests/static/sim_datarefs_test.lua write) and commit it; without X-Plane (another list standing in):"
    .. " that list is short of these or types them otherwise, complete it (TESTING.md §3)"
local function some(list)
    table.sort(list)
    local n = #list
    if n > 12 then list = {unpack(list, 1, 12)}; list[#list + 1] = "... (" .. n .. ")" end
    return table.concat(list, ", ")
end
local new, gone, other = {}, {}, {}
for _, name in ipairs(names) do
    local want = listed[name]
    if want == nil then
        new[#new + 1] = name .. " (" .. type_of(name) .. ")"
    elseif want ~= type_of(name) then
        other[#other + 1] = name .. " (" .. type_of(name) .. ", the list: " .. want .. ")"
    end
end
for name in pairs(listed) do
    if not bound[name] then gone[#gone + 1] = name end
end
T.check(#other == 0, "datarefs of another type than the list's: " .. some(other) .. HOW)
T.check(#new == 0, "datarefs the modules look up that the list does not have: " .. some(new) .. HOW)
T.check(#gone == 0, "datarefs of the list that no module looks up any more: " .. some(gone) .. HOW)
T.done()
