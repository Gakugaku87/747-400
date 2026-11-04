-- Run from the repository root with LuaJIT: luajit tests/fms/fms_power_test.lua
-- (1-1) the FMC side's IRS, navigation and tuning updates by the 747's
-- buses, not X-Plane's bus 0 (FCOM p.800, p.804; ATA34_2 p.496; notes/
-- ATA-34-61-FMC.md §144; tests/lib/xtlua.lua): the IRUs' status for the
-- CDU and the ND's TIME TO ALIGN while an FMC's bus (the Captain's transfer
-- bus, the APU standby bus, the F/O's transfer bus) is powered, an FMC
-- failed or not; nothing while none is. Before, X-Plane's bus 0 above 22 V
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("fms_power")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for n = 1, 4 do types["laminar/B747/irs/line" .. n] = "string" end
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
local POWER = "laminar/B747/electrical/display_has_power"
local BUS = "laminar/B747/electrical/bus/"
local function power(capt, apu, fo)
    for i = 6, 8 do rt:set(POWER, i, 6) end
    rt:set(BUS .. "xfr_capt", capt and 1 or 0)
    rt:set(BUS .. "stby_apu", apu and 1 or 0)
    rt:set(BUS .. "xfr_fo", fo and 1 or 0)
end
power(true, true, true)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 0)             -- X-Plane's bus 0 dead
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the IRUs aligning (the IRS module's outputs; irs_system.lua's modes)
local MODE_ALIGN, MODE_NAV = 1, 2
local function aligning(on)
    rt:set("laminar/B747/irs/aligning", on and 1 or 0)
    for i = 0, 2 do
        rt:set("laminar/B747/irs/mode", i, on and MODE_ALIGN or MODE_NAV)
        rt:set("laminar/B747/irs/nav_valid", i, on and 0 or 1)
        rt:set("laminar/B747/irs/time_left", i, on and 600 or 0)
        rt:set("laminar/B747/irs/lat", i, 35)
        rt:set("laminar/B747/irs/lon", i, 140)
    end
end
local function line(n) return rt:get("laminar/B747/irs/line" .. n) end

aligning(true)
frames(2)
T.equal(line(1), "TIME TO ALIGN", "X-Plane's bus 0 dead, the FMCs' buses powered: the ND's TIME TO ALIGN")
T.equal(line(2), "L 7+ MIN", "the left IRU's time to align")

-- the FMCs' buses dead: the FMC side stands still
power(false, false, false)
aligning(false)
frames(2)
T.equal(line(1), "TIME TO ALIGN", "the FMCs' buses dead: not updated")

-- the APU standby bus alone (the left FMC: FCOM p.800, p.804)
power(false, true, false)
frames(2)
T.equal(line(1), " ", "the APU standby bus: updated, no IRU aligning")

-- the left FMC failed, the F/O's transfer bus: still updated
aligning(true)
power(false, false, true)
rt:set("laminar/B747/fms/fail", 0, 1)
frames(2)
T.equal(line(1), "TIME TO ALIGN", "the left FMC failed, the right one's bus: updated")
rt:set("laminar/B747/fms/fail", 0, 0)
T.done()
