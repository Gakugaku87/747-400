-- Run from the repository root with LuaJIT: luajit tests/fms/simconfig_late_start_test.lua
-- (2026-11-11, the user on the release custom-2026.11.11: the CDU blank,
-- the weight and balance window's inputs dead and the MCP's IAS window dark)
-- The FMC and the autopilot (plugin xtlua_keysystems) took the livery's
-- config only while the simconfig module (plugin xtlua) held newsimconfig at
-- 1, about 4 s after its start; started later, they never saw it and
-- returned at the top of after_physics for good. Now a module without a
-- config after 10 s (SIMCONFIG_LATE_S) takes the published one when it
-- decodes to a config (a table with PLANE); before that it waits for the
-- pulse as before (a usual start keeps its moment); the pulse works as
-- before, and a config taken stays until the next pulse.
local T = dofile("tests/lib/check.lua")("simconfig_late_start")
local xtlua = dofile("tests/lib/xtlua.lua")

local MODULES = {
    "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua",
    "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua",
}
-- a livery's config as the simconfig module publishes it
local CFG = '{"PLANE":{"airline":"","aircraft_type":"PASSENGER","engines":"CF6-80C2-B1F","fin_nbr":"0",'
    .. '"pfd_style":"CRT","nd_style":"CRT","civil_registration":"","thrust_ref":"N1","model":"747-400"},'
    .. '"FMC":{"INIT":{"drag_ff":"+0.0/-0.0","op_program":"XP12-43","nav_data":"","active":""}},'
    .. '"SOUND":{"paOption":0,"musicOption":0,"PM_toggle":0,"V1Option":0,"alarmsOption":0,"seatBeltOption":0},'
    .. '"SIM":{"baro_sync":"NO","kgs_to_lbs":2.2046226218488,"irs_align_time":600,"fo_lwr":"NORM",'
    .. '"capt_inbd":"NORM","weight_display_units":"KGS","auto_fuel_mgmt":"NO","std_pax_weight":120,'
    .. '"capt_lwr":"NORM","fo_inbd":"NORM","lbs_to_kgs":0.45359237,"baro_indicator":"IN"}}'
-- another plugin's datarefs: XTLua's reads of them lag a read
local LAG = {"laminar/B747/simconfig", "laminar/B747/newsimconfig"}

-- the module's simConfigData.data.PLANE.engines (a global table is an
-- XTLua namespace that keeps its values itself, and a missing key read
-- through it overflows the stack: read under pcall)
local function config(m)
    local ok, v = pcall(function() return m.ns.simConfigData.data.PLANE.engines end)
    return ok and v or nil
end

local function frames(rt, seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function start(path, cfg, flag, seconds)
    local rt = xtlua.new({lagged = LAG})
    rt:set("laminar/B747/simconfig", cfg)
    rt:set("laminar/B747/newsimconfig", flag)
    rt:set("xtlua/fms", "[]")  -- X-Plane's flight plan, as XTLua gives it
    local m = rt:load(path)
    rt:callout("flight_start")
    frames(rt, seconds or 0.4)
    return rt, m
end

for _, path in ipairs(MODULES) do
    local name = path:match("([^/]+)%.lua$")
    -- started after the pulse: the config published, the flag down again;
    -- it waits 10 s for a pulse first
    local rt, m = start(path, CFG, 0, 5)
    T.check(m.ns.hasSimConfig() == false, name .. ": 5 s after its start without the pulse, it still waits")
    frames(rt, 6)
    T.check(m.ns.hasSimConfig() == true, name .. ": after 10 s without the pulse, it takes the published config")
    T.equal(config(m), "CF6-80C2-B1F", name .. ": the config taken")
    -- once taken, a new config comes with the next pulse only (no decode
    -- every frame)
    rt:set("laminar/B747/simconfig", (CFG:gsub("CF6%-80C2%-B1F", "PW4056")))
    for _ = 1, 3 do rt:frame(1 / 30) end
    T.equal(config(m), "CF6-80C2-B1F", name .. ": no new config without the pulse")
    rt:set("laminar/B747/newsimconfig", 1)
    for _ = 1, 3 do rt:frame(1 / 30) end
    T.equal(config(m), "PW4056", name .. ": the pulse brings the new config")

    -- before the livery's config: the simconfig module's first publish
    -- ("null", do_flight_start) is no config, so it waits
    local _, m2 = start(path, "null", 0, 11)
    T.check(m2.ns.hasSimConfig() == false, name .. ": waits while the published value is no config")
    local _, m3 = start(path, "", 0, 11)
    T.check(m3.ns.hasSimConfig() == false, name .. ": waits while nothing is published")

    -- the pulse, as before
    local _, m4 = start(path, CFG, 1)
    T.check(m4.ns.hasSimConfig() == true, name .. ": the pulse, as before")
end
T.done()
