-- Run from the repository root with Lua 5.1 or LuaJIT.
-- XTLua gives every script its own namespace: assigning to a name that the
-- script never bound with find_dataref/deferred_dataref only stores a Lua value
-- and never reaches the simulator. The hydraulics script loads the override
-- file into its namespace, so every simDR_/B747DR_ name the override file
-- writes must be bound in one of those two files.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function read_lines(path)
    local file = assert(io.open(path))
    local lines = {}
    for line in file:lines() do lines[#lines+1] = line end
    file:close()
    return lines
end
local function is_dataref_name(name)
    return name:sub(1, 6) == "simDR_" or name:sub(1, 7) == "B747DR_"
end

-- Bound names and their dataref paths, from lines such as
-- "name = find_dataref("path")" or "local name = deferred_dataref("path", ...)".
local function collect_bindings(path, bindings)
    for _, line in ipairs(read_lines(path)) do
        local name, finder, dataref = line:match(
            "^%s*([%w_]+)%s*=%s*([%w_]+)%(%s*\"([^\"]+)\"")
        if not name then
            name, finder, dataref = line:match(
                "^%s*local%s+([%w_]+)%s*=%s*([%w_]+)%(%s*\"([^\"]+)\"")
        end
        if name and (finder == "find_dataref" or finder == "deferred_dataref") then
            bindings[name] = dataref
        end
    end
    return bindings
end

local hydraulics = collect_bindings(HYD.."B747.19.xt.hydraulicsmodel.lua", {})
local bound = collect_bindings(HYD.."B747.19.xt.hydraulics_override.lua",
    collect_bindings(HYD.."B747.19.xt.hydraulicsmodel.lua", {}))

local written = {}
local written_names = {}
for number, line in ipairs(read_lines(HYD.."B747.19.xt.hydraulics_override.lua")) do
    local name = line:match("^%s*([%w_]+)%s*=[^=]")
    if name and is_dataref_name(name) and not written[name] then
        written[name] = number
        written_names[#written_names+1] = name
    end
end
check(#written_names > 40, "override assignments were found ("..#written_names..")")

local unbound = {}
for _, name in ipairs(written_names) do
    checks = checks + 1
    if bound[name] == nil then
        unbound[#unbound+1] = name.." (override line "..written[name]..")"
    end
end
assert(#unbound == 0, "override writes datarefs that the hydraulics namespace never binds: "
    ..table.concat(unbound, ", "))

-- The capture in ap_director_pitch clears the FLCH and V/S requests. Those
-- names must reach the same datarefs the autopilot script binds and reads.
local autopilot = collect_bindings(AP.."B747.70.xt.autopilot.lua", {})
equal(hydraulics.simDR_autopilot_vs_status, "laminar/B747/autopilot/vvi_status",
    "hydraulics binds the V/S request")
equal(hydraulics.simDR_autopilot_flch_status, "laminar/B747/autopilot/speed_status",
    "hydraulics binds the FLCH request")
equal(autopilot.simDR_autopilot_vs_status, hydraulics.simDR_autopilot_vs_status,
    "V/S request is the dataref the autopilot reads")
equal(autopilot.simDR_autopilot_flch_status, hydraulics.simDR_autopilot_flch_status,
    "FLCH request is the dataref the autopilot reads")

print("Hydraulics dataref binding tests passed: "..checks.." ("..#written_names.." names)")
