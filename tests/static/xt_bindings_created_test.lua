-- Run from the repository root with LuaJIT: luajit tests/static/xt_bindings_created_test.lua
-- In an XTLua logic script (plugins/*/scripts/), deferred_dataref only finds a
-- dataref: one that no init script (plugins/*/init/scripts/) creates does not
-- exist, so its reads give 0 and its writes are lost (found on the old fork,
-- docs/overhaul/TESTING.md §1.2). Every laminar/ dataref an xt script binds
-- must be created by an init script of one of the aircraft's XTLua plugins.
local T = dofile("tests/lib/check.lua")("xt_bindings_created")
local src = dofile("tests/lib/source.lua")

-- Bindings that already miss their init script on the overhaul branch at
-- 041c9ffa. They are existing defects, listed so that new ones fail; remove
-- an entry when its system is rebuilt.
local KNOWN = {
    ["laminar/B747/electrical/oil"] = true,
}

local files = src.lua_files()
T.check(#files > 100, "aircraft Lua files found (" .. #files .. ")")
local created = src.created(files)
local missing = {}
local bound = 0
for _, path in ipairs(files) do
    if src.is_xt(path) then
        local text = src.read(path)
        for name in text:gmatch('deferred_dataref%s*%(%s*"(laminar/[^"]+)"') do
            bound = bound + 1
            if not created[name] and not KNOWN[name] then
                missing[#missing + 1] = name .. "  (" .. path .. ")"
            end
        end
    end
end
T.check(bound > 300, "xt bindings found (" .. bound .. ")")
table.sort(missing)
for _, m in ipairs(missing) do T.check(false, "not created by any init script: " .. m) end

-- Commands likewise: in a logic script deferred_command only attaches the
-- handler (replace_command), so a laminar/ command an xt script handles or
-- finds must be created by an init script (5-2 step 5c: the CDU's STD and DH
-- RESET commands were missing there and did nothing in X-Plane, while the
-- mock took them). Names built at run time ("laminar/B747/" .. id ..) are
-- not checked. The known ones miss their init script on the overhaul branch.
local KNOWN_CMDS = {
    ["laminar/B747/ai/fmsL_quick_start"] = true,
    ["laminar/B747/ai/fmsR_quick_start"] = true,
    ["laminar/B747/autopilot/heading_down"] = true,
    ["laminar/B747/autopilot/heading_up"] = true,
    ["laminar/B747/networking/nettest"] = true,
}
local init_cmds = {}
for _, path in ipairs(files) do
    if src.is_init(path) then
        local text = src.read(path)
        for name in text:gmatch('deferred_command%s*%(%s*"([^"]+)"') do init_cmds[name] = true end
        for name in text:gmatch('create_command%s*%(%s*"([^"]+)"') do init_cmds[name] = true end
    end
end
local cmd_missing, cmd_bound = {}, 0
for _, path in ipairs(files) do
    if src.is_xt(path) then
        local text = src.read(path)
        for kind, name in text:gmatch('([%a_]+_command)%s*%(%s*"(laminar/[^"]+)"') do
            local checked = kind == "deferred_command" or kind == "find_command"
                or kind == "replace_command" or kind == "wrap_command"
            if checked and name:sub(-1) ~= "/" then
                cmd_bound = cmd_bound + 1
                if not init_cmds[name] and not KNOWN_CMDS[name] then
                    cmd_missing[#cmd_missing + 1] = name .. "  (" .. path .. ")"
                end
            end
        end
    end
end
T.check(cmd_bound > 500, "xt command bindings found (" .. cmd_bound .. ")")
table.sort(cmd_missing)
for _, m in ipairs(cmd_missing) do T.check(false, "command not created by any init script: " .. m) end
T.done()
