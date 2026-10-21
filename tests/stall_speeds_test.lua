-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The stall speed (B747_Vs, B747.60.xt.fltInst02.lua: the PFD's red checker box, the stall warning and TO/GA's pitch
-- below V2 + 10) from the stall speed table (VsData: flaps, altitude, gross weight in t): between the table's weights
-- that bracket the gross weight (to the nearest 20 t the lower row was held through the lower half of each 20 t) and
-- between its rows by altitude that bracket the altitude, held at 10,000 ft above (the band tests ran from the lowest,
-- so above sea level only 0-2,000 ft was ever taken). The production function runs in XTLua's namespace against
-- mocked datarefs; its smoothing is run to the end.
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
local function slice(first_marker, last_marker)
    local source = read(DIR.."B747.60.xt.fltInst02.lua")
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1)
end

local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua_keysystems/init.lua")), runtime)()

-- The stall speed at a gross weight (kg), altitude (ft) and flap angle, in the air at 250 kt (nil and the error kept
-- if a frame failed)
local frame_error
local function stall_speed(weight, altitude, flaps)
    local env = runtime.create_namespace()
    local stalled = {}
    for i = 0, 320 do stalled[i] = 0 end
    for name, value in pairs({simDR_acf_weight_total_kg = weight, simDR_altitude_ft_pilot = altitude,
            simDR_wing_flap1_deg = {[0] = flaps or 0}, simDR_airspeed = 250, simDR_stalled_elements = stalled,
            simDR_all_wheels_on_ground = 0, B747DR_airspeed_V2 = 999, B747DR_airspeed_Vs = 0, SIM_PERIOD = 1}) do
        env[name] = value
    end
    local tables = read(DIR.."B747.60.xt.fltInst.lua")
    tables = tables:sub(1, assert(tables:find('dofile("B747.60.xt.fltInst02.lua")', 1, true)) - 1)
    setfenv(assert(loadstring(tables)), env)()
    for _, part in ipairs({{"function B747_rescale(", "function roundUp(x)"},
            {"function B747_animate_value(", "-- INIT V1 / Vr / V2"}}) do
        setfenv(assert(loadstring(slice(part[1], part[2]))), env)()
    end
    local ok, err = pcall(function()
        for _ = 1, 300 do env.B747_Vs() end
    end)
    if not ok then
        frame_error = frame_error or err
        return nil
    end
    return env.B747DR_airspeed_Vs
end
local function near(got, want) return got ~= nil and math.abs(got - want) < 0.01 end
local function show(v) return v and string.format("%.3f", v) or "nil" end

-- between the weights that bracket the gross weight: flaps up at sea level, 225 t a quarter of the way from 220 t's
-- 150.74 to 240 t's 157.96, 152.545 (the lower row held: 150.74); 230 t 154.35, 410 t along the end rows 208.235
for _, case in ipairs({{225000, 152.545}, {230000, 154.35}, {300000, 179.72}, {410000, 208.235}}) do
    local vs = stall_speed(case[1], 0)
    check(near(vs, case[2]), string.format("Vs flaps up, sea level, %.0f t: %s (%.3f)", case[1] / 1000, show(vs),
        case[2]))
end

-- by altitude, flaps up at 240 t (-2,000/0/2,000/6,000/10,000 ft rows 157.53/157.96/158.63/160.12/161.66): FL370 and
-- 10,000 ft 161.66, 8,000 ft 160.89, 4,000 ft 159.375, 1,000 ft 158.295, -1,000 ft 157.745, -3,000 ft 157.53 (from
-- 2,000 ft up it was held at 158.63)
for _, case in ipairs({{37000, 161.66}, {10000, 161.66}, {8000, 160.89}, {4000, 159.375}, {1000, 158.295},
        {-1000, 157.745}, {-3000, 157.53}}) do
    local vs = stall_speed(240000, case[1])
    check(near(vs, case[2]), string.format("Vs flaps up, 240 t, %d ft: %s (%.3f)", case[1], show(vs), case[2]))
end

-- the table's flaps 20 cells as its neighbours read: 200 t at 10,000 ft 113.60 (133.60, 20 kt over its 6,000 ft row's
-- 113.03 and its 220 t neighbour's 119.47) and 360 t at sea level 153.66 (156.66, over 380 t's 157.72 less 4 kt and
-- between -2,000 and 2,000 ft's 153.32 and 154.09)
for _, case in ipairs({{200000, 10000, 113.60}, {360000, 0, 153.66}}) do
    local vs = stall_speed(case[1], case[2], 20)
    check(near(vs, case[3]), string.format("Vs flaps 20, %.0f t, %d ft: %s (%.2f)", case[1] / 1000, case[2], show(vs),
        case[3]))
end

check(frame_error == nil, "a frame failed: "..tostring(frame_error))
assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("Stall speed tests passed: "..checks)
