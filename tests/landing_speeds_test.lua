-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The landing reference speeds (B747_setVref30 and B747_Vspeeds, B747.60.xt.fltInst02.lua): VREF30 from the FCOM's
-- table (PI.10.2, 747-400/PW4056: 127 kt at 200 t to 184 at 400 t; cckit research_vref.md) by the gross weight alone,
-- as the FMC works it out, between the table's weights that bracket it and carried on along its end rows' slope beyond
-- 200-400 t (the CF6 table has 121 kt at 181 t). The production functions run in XTLua's namespace (the plugin's
-- init.lua) against mocked datarefs.
local DIR = "plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/"

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
-- the source of fltInst02.lua from one marker to the next, at its own line numbers
local function slice(first_marker, last_marker)
    local source = read(DIR.."B747.60.xt.fltInst02.lua")
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1)
end

-- XTLua's script runtime, for its namespaces
local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua_keysystems/init.lua")), runtime)()

-- The instruments' speeds in XTLua's namespace at a gross weight (kg) and altitude (ft), flaps up on the ground;
-- frame(env) runs B747_setVref30 and B747_Vspeeds once (nil and the error kept if it failed)
local frame_error
local function load(weight, altitude)
    local env = runtime.create_namespace()
    for name, value in pairs({simDR_acf_weight_total_kg = weight, simDR_altitude_ft_pilot = altitude or 0,
            simDR_flap_ratio_control = 0, B747DR_airspeed_VrefFlap = 0, simDR_radio_alt_height_capt = 0,
            B747DR_ref_thr_limit_mode = "TO", B747DR_radio_altitude = 0, simDR_airspeed = 0,
            simDR_innerslats_ratio = 0, simDR_wing_flap1_deg = {[0] = 0}, simDR_gear_deploy_ratio = {[0] = 1},
            B747DR_airspeed_Vref30 = 0}) do
        env[name] = value
    end
    local tables = read(DIR.."B747.60.xt.fltInst.lua")
    tables = tables:sub(1, assert(tables:find('dofile("B747.60.xt.fltInst02.lua")', 1, true)) - 1)
    setfenv(assert(loadstring(tables)), env)()
    for _, part in ipairs({{"function B747_rescale(", "function roundUp(x)"},
            {"function B747_vref(flaps, weight)", "function B747_animate_value("}}) do
        setfenv(assert(loadstring(slice(part[1], part[2]))), env)()
    end
    return env
end
local function frame(env)
    local ok, err = pcall(function()
        env.B747_setVref30()
        env.B747_Vspeeds()
    end)
    if not ok then
        frame_error = frame_error or err
        return nil
    end
    return env.B747DR_airspeed_Vref30
end
local function near(got, want) return got ~= nil and math.abs(got - want) < 0.01 end

-- between the weights that bracket the gross weight: at 225 t a quarter of the way from 220 t's 133 to 240 t's 140,
-- 134.75 (to the nearest 20 t the lower row was held through the lower half of each 20 t); at a row itself its value;
-- beyond the table along its end rows (181 t: 121.3; 410 t: 186.5; they were held)
for _, case in ipairs({{225000, 134.75}, {300000, 157}, {219000, 132.70}, {181000, 121.3}, {410000, 186.5}}) do
    local vref = frame(load(case[1]))
    check(near(vref, case[2]), string.format("VREF30 at %.0f t: %s (%.2f)", case[1] / 1000, tostring(vref), case[2]))
end
-- by the gross weight alone, not the present altitude: 233.4 t 137.69 at FL370, 6,000 ft, sea level and -1,000 ft
-- (the stall speed source's rows by the altitude in steps gave 140.25 at FL370 and 139.28 at 6,000 ft, where crews
-- select VREF, and the flap speeds stepped down at 6,000 and 2,000 ft on the approach)
for _, altitude in ipairs({37000, 6000, 0, -1000}) do
    local vref = frame(load(233400, altitude))
    check(near(vref, 137.69), string.format("VREF30 at 233.4 t and %d ft: %s (137.69)", altitude, tostring(vref)))
end

check(frame_error == nil, "a frame failed: "..tostring(frame_error))
assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("Landing speed tests passed: "..checks)
