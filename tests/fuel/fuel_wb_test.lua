-- Run from the repository root with LuaJIT: luajit tests/fuel/fuel_wb_test.lua
-- (2026-11-05, the user) the sim's weight and balance window's fuel total
-- (b747_fms_bridge wb_window.c: laminar/B747/wb/req_field 10, req_value
-- kg, req_id counted up) in the fuel module as XTLua runs it
-- (tests/lib/xtlua.lua): at once, in the refuelling's load order (the mains
-- evenly, 1 and 4 full first, then 2 and 3, the reserves, the centre, the
-- stabilizer; upstream's, an estimate), within the tanks' capacities, on
-- the ground only; a refuelling under way stops; the totaliser set to it.
local T = dofile("tests/lib/check.lua")("fuel_wb")
local xtlua = dofile("tests/lib/xtlua.lua")

local FUEL = "sim/flightmodel/weight/m_fuel"
local RATIO = {0.3, 0.078, 0.22, 0.22, 0.078, 0.023, 0.023, 0.058}   -- both acfs, from index 0
local CAP = 173069.12
local types = {["laminar/B747/wb/req_id"] = "number", ["laminar/B747/wb/req_field"] = "number",
    ["laminar/B747/wb/req_value"] = "number"}

-- (the window's three as XTLua reads another plugin's datarefs: X-Plane s259)
local rt = xtlua.new{types = types, lagged = {"laminar/B747/wb/req_id", "laminar/B747/wb/req_field", "laminar/B747/wb/req_value"}}
rt:load("plugins/xtlua/scripts/B747.25.xt.fuel/B747.25.xt.fuel.lua")
rt:set("sim/aircraft/weight/acf_m_fuel_tot", CAP)
for i, r in ipairs(RATIO) do rt:set("sim/aircraft/overflow/acf_tank_rat", i - 1, r) end
for i, kg in ipairs({0, 10000, 15000, 15000, 10000, 0, 0, 0}) do rt:set(FUEL, i - 1, kg) end
for n = 0, 3 do
    for _, bus in ipairs({"ac", "dc", "utility"}) do rt:set("laminar/B747/electrical/bus/" .. bus, n, 1) end
end
for _, bus in ipairs({"bat_main", "hot_bat_main", "gnd_svc", "bat_apu"}) do
    rt:set("laminar/B747/electrical/bus/" .. bus, 1)
end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:callout("flight_start")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function tanks()
    local t, kg = {}, 0
    for i = 0, 7 do t[i] = rt:get(FUEL, i) kg = kg + t[i] end
    return t, kg
end
local function req(field, value)
    rt:set("laminar/B747/wb/req_field", field)
    rt:set("laminar/B747/wb/req_value", value)
    rt:set("laminar/B747/wb/req_id", rt:get("laminar/B747/wb/req_id") + 1)
    frames(0.5)
end
local function near(a, b) return math.abs(a - b) < 1 end
frames(12)                                  -- the flight start's settling
local _, kg0 = tanks()
T.check(near(kg0, 50000), "50 t to start with: " .. kg0)

req(10, 100000)
local t, kg = tanks()
local m14, m23 = RATIO[2] * CAP, 100000 / 2 - RATIO[2] * CAP
T.check(near(kg, 100000), "100 t entered: 100 t in the tanks (" .. kg .. ")")
T.check(near(t[1], m14) and near(t[4], m14), "mains 1 and 4 full (" .. t[1] .. ")")
T.check(near(t[2], m23) and near(t[3], m23), "the rest in mains 2 and 3 (" .. t[2] .. ")")
T.check(t[0] == 0 and t[5] == 0 and t[6] == 0 and t[7] == 0, "nothing in the centre, the reserves, the stabilizer")
T.check(near(rt:get("sim/cockpit2/fuel/fuel_totalizer_init_kg"), 100000), "the totaliser set to it")

req(10, 150000)
t, kg = tanks()
T.check(near(kg, 150000), "150 t entered: 150 t")
T.check(near(t[2], RATIO[3] * CAP) and near(t[5], RATIO[6] * CAP) and near(t[6], RATIO[7] * CAP), "mains 2 and 3 and the reserves full")
T.check(t[0] > 30000 and t[7] == 0, "the rest in the centre (" .. t[0] .. "), none in the stabilizer")

req(10, 999999)
t, kg = tanks()
T.check(near(kg, CAP), "more than the tanks hold: full (" .. kg .. ")")

req(3, 50000)
_, kg = tanks()
T.check(near(kg, CAP), "another field (cargo AFT, the FMC's): the fuel kept")

rt:set("laminar/B747/fuel/refuel", 5000)
req(10, 80000)
_, kg = tanks()
T.check(near(kg, 80000), "80 t entered while a refuelling was under way: 80 t")
T.equal(rt:get("laminar/B747/fuel/refuel"), 0, "and the refuelling stopped")

rt:set("sim/flightmodel/failures/onground_any", 0)
req(10, 120000)
_, kg = tanks()
T.check(near(kg, 80000), "in the air: refused (" .. kg .. ")")
T.done()
