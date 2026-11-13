-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_spd_rest_test.lua
-- (2026-11-13; the 2026-11-12 review FMC-10, 案 10) The CLB page's SPD RESTR
-- (4L) in the FMS module as XTLua runs it (tests/lib/xtlua.lua): a speed,
-- "/" and an altitude, both valid, the altitude at or over the airplane's
-- and under the cruise altitude (FMSPG p.114); else INVALID ENTRY and the
-- restriction kept. Before, the first three characters were the speed and
-- the rest the altitude when valid: 250/1500 left 250/----- with no message,
-- 230 and 240X8000 were taken. The 1R DELETE: tests/fms/route_model_test.lua
-- (the model) and the X-Plane scenario s319.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("vnav_spd_rest")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
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
frames(4)
local K = "laminar/B747/fms1/"
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function rest()
    local d = fms.ns.fmsModules["data"]
    return (d["clbrestspd"]:gsub("%s+$", "")) .. "/" .. (d["clbrestalt"]:gsub("%s+$", ""))
end

-- PERF INIT: the cruise altitude FL350
key("func_key/index") enter("100", "L5") enter("350", "R1")
key("func_key/des")                        -- VNAV: the CLB page on the ground
T.check(line(1):match("CLB"), "the CLB page: " .. line(1))
enter("250/8000", "L4")
T.equal(rest(), "250/8000", "250/8000: the restriction")
enter("250/1500", "L4")
T.equal(pad(), "INVALID ENTRY", "250/1500 (an altitude under 2,000 ft): INVALID ENTRY (before: 250/----- with no message)")
T.equal(rest(), "250/8000", "  the restriction kept")
enter("230", "L4")
T.equal(pad(), "INVALID ENTRY", "230 alone: INVALID ENTRY (before: taken)")
enter("240X8000", "L4")
T.equal(pad(), "INVALID ENTRY", "240X8000: INVALID ENTRY (before: taken)")
enter("250/FL360", "L4")
T.equal(pad(), "INVALID ENTRY", "250/FL360 at or over the cruise altitude FL350: INVALID ENTRY (FMSPG p.114)")
enter("90/8000", "L4")
T.equal(pad(), "INVALID ENTRY", "90/8000: INVALID ENTRY")
T.equal(rest(), "250/8000", "the restriction still 250/8000")
clear()
enter("DELETE", "L4")
T.equal(rest(), "---/-----", "DELETE: none")
T.done()
