-- Run from the repository root with LuaJIT: luajit tests/fms/simconfig_msg_test.lua
-- (2026-11-13; the 2026-11-12 review C-2, case 11) A livery's simconfig that
-- did not decode (laminar/B747/simconfig/read_failed, the simconfig module's
-- flag: tests/static/simconfig_read_test.lua) shows SIM CONFIG NOT READ on
-- the CDUs' scratchpads as an FMC advisory while it holds, in the FMS module
-- as XTLua runs it (tests/lib/xtlua.lua). Before, nothing told the crew: the
-- module's print reaches no log.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("simconfig_msg")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
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
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
local function pad() return (rt:get("laminar/B747/fms3/Line14_L"):gsub("^%s+", ""):gsub("%s+$", "")) end
frames(4)
T.check(pad() ~= "SIM CONFIG NOT READ", "a livery's simconfig read: no message (" .. pad() .. ")")
rt:set("laminar/B747/simconfig/read_failed", 1)
frames(1)
T.equal(pad(), "SIM CONFIG NOT READ", "not read: SIM CONFIG NOT READ on the scratchpad")
rt:command("laminar/B747/fms1/key/clear")
frames(0.5)
T.check(pad() ~= "SIM CONFIG NOT READ", "CLR takes it off the scratchpad (" .. pad() .. ")")
rt:set("laminar/B747/simconfig/read_failed", 0)
frames(1)
T.check(pad() ~= "SIM CONFIG NOT READ", "read again: no message")
T.done()
