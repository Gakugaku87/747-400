-- Run from the repository root with LuaJIT: luajit tests/fltctrls/srm_lag_test.lua
-- (2026-11-05 review 3) the SRMs' "outside change" of X-Plane's trim
-- (B747.45.xt.srm.lua) with XTLua's late reads: in X-Plane a read can give a
-- value written some frames before (a slow frame), the mock gives the last
-- one. Here each frame reads the trim written three frames before, while the
-- autotrim runs: our own writes, not an outside change. Before, only the
-- last two writes counted as ours: the stabilizer was set back to the late
-- value every frame and hardly moved (and speed trim cleared).
local T = dofile("tests/lib/check.lua")("srm_lag")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.xt.fltCtrls.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:callout("flight_start")
local TRIM = "sim/flightmodel2/controls/elevator_trim"
local STAB = "laminar/B747/flt_ctrls/stab_trim/"
local function units() return rt:get(STAB .. "units") end

-- powered, the hydraulics up, in the air at 200 kt, the L A/P engaged
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
for n = 1, 4 do rt:set("laminar/B747/hydraulics/pressure_" .. n, 3000) end
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/stby_main", 1)
rt:set("laminar/B747/air/duct_pressure_L", 35)
rt:set("laminar/B747/air/duct_pressure_R", 35)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 200)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", 200)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 5000)
for _ = 1, 150 do rt:frame(1 / 30) end          -- past the start (3 s)
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 1)
rt:set(STAB .. "autotrim_cmd", 1)
for _ = 1, 100 do rt:frame(1 / 30) end          -- the autotrim's 3 s wait
local written = {rt:get(TRIM)}
local u0, back = units(), 0
for k = 1, 90 do
    -- X-Plane's read three frames late
    local late = written[math.max(1, #written - 2)]
    rt:set(TRIM, late)
    local before = units()
    rt:frame(1 / 30)
    if units() < before - 1e-9 then back = back + 1 end
    written[#written + 1] = rt:get(TRIM)
end
T.equal(back, 0, "the stabilizer never set back by its own late values")
T.check(units() > u0 + 0.6, string.format("3 s of autotrim at 200 kt: %.3f units (0.25 a second)", units() - u0))

-- an outside change still taken: X-Plane's trim set far from what was
-- written (5 units)
rt:set(STAB .. "autotrim_cmd", 0)
for _ = 1, 30 do rt:frame(1 / 30) end
rt:set(TRIM, -1 / 3)
rt:frame(1 / 30)
rt:frame(1 / 30)
T.check(math.abs(units() - 5) < 0.01, "X-Plane's trim set from outside: followed (" .. units() .. ")")
T.done()
