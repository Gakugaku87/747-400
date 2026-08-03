local function load_in_environment(path, environment)
    local chunk, load_error = loadfile(path)
    assert(chunk ~= nil, load_error)
    setfenv(chunk, environment)
    chunk()
end

local runtime = {}
setmetatable(runtime, {__index = _G})
load_in_environment("plugins/xtlua_keysystems/init.lua", runtime)

local function load_helper_with_xtlua_dofile(path)
    runtime.XLuaGetCode = function(requested_path)
        assert(requested_path == path, "unexpected helper path: " .. tostring(requested_path))
        local chunk, load_error = loadfile(requested_path)
        assert(chunk ~= nil, load_error)
        return chunk
    end

    local namespace = {}
    setmetatable(namespace, {__index = _G})
    return runtime.get_run_file_in_namespace(namespace)(path)
end

local nav_helpers = load_helper_with_xtlua_dofile(
    "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.afds_helpers.lua")
assert(type(nav_helpers) == "table", "XTLua dofile discarded the navigation helper table")
assert(nav_helpers.flap_speed_bucket(0.2) == 5, "navigation helper table is not callable")

local control_helpers = load_helper_with_xtlua_dofile(
    "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulics_afds_helpers.lua")
assert(type(control_helpers) == "table", "XTLua dofile discarded the control helper table")
assert(type(control_helpers.adaptive_roll_filter) == "function", "control helper table is not callable")

local nd_plan_helpers = load_helper_with_xtlua_dofile(
    "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.nd.lua")
assert(type(nd_plan_helpers) == "table", "XTLua dofile discarded the ND PLN helper table")
assert(nd_plan_helpers.display_waypoint("RJAA", {{0, 0, 0, 0, 0, 0, 0, "ALPHA"}},
    {1}, 3) == "ALPHA", "ND PLN helper table is not callable")

local function load_script_with_xtlua_dofile(path, script_directory)
    runtime.XLuaGetCode = function(requested_path)
        local resolved_path = requested_path
        if not string.find(requested_path, "/", 1, true) then
            resolved_path = script_directory .. "/" .. requested_path
        end
        local chunk, load_error = loadfile(resolved_path)
        assert(chunk ~= nil, load_error)
        return chunk
    end

    local namespace = {}
    setmetatable(namespace, {__index = _G})
    namespace.dofile = runtime.get_run_file_in_namespace(namespace)
    namespace.dofile(path)
    return namespace
end

local autopilot_directory =
    "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot"
local vnav_namespace = load_script_with_xtlua_dofile(
    autopilot_directory .. "/B747.70.xt.autopilot.vnav.lua",
    autopilot_directory)
assert(type(vnav_namespace.B747_reset_vnav_energy) == "function",
    "VNAV module failed to load its AFDS helper in its own XTLua chunk")

print("XTLua dofile return-value tests passed")
