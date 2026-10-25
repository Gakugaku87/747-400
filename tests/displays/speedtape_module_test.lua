-- Run from the repository root with LuaJIT: luajit tests/displays/speedtape_module_test.lua
-- The PFD speed tape glue (B747.60.xt.speedtape.lua, 5-2 step 3a) in the
-- flight instruments module (B747.60.xt.fltInst) as XTLua runs it
-- (tests/lib/xtlua.lua): the weight, the altitude, the flap lever, the
-- landing flaps selected on the CDU and the PSEU's air mode in; the flap
-- maneuver speeds, which bugs show and pfd/show_mins out. The model is tested
-- in speedtape_model_test.lua.
local T = dofile("tests/lib/check.lua")("speedtape_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local A = "laminar/B747/airspeed/"
local BUS = "laminar/B747/electrical/bus/"
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set(BUS .. b, 1) end
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 0)
rt:set("sim/cockpit2/controls/flap_ratio", 4 / 6)                   -- flaps 20
rt:set("laminar/B747/gear/air_ground/pri_air", 0)
rt:callout("flight_start")
frames(1)

local function bugs()
    local t = {}
    for k = 0, 6 do if rt:get(A .. "show_vf", k) == 1 then t[#t + 1] = k end end
    return table.concat(t, ",")
end
local vref30 = rt:get(A .. "Vref30")
T.check(vref30 > 150 and vref30 < 165, "VREF30 at 300 t near FCOM PI.10.2's 157 (" .. vref30 .. ")")
T.near(rt:get(A .. "Vf0"), vref30 + 80, 1e-6, "UP: VREF30 + 80 (FCOM PI.10.3)")
T.near(rt:get(A .. "Vf25"), 164, 1e-6, "25: VREF25 at 300 t (FCOM PI.10.2)")
T.equal(bugs(), "3,4", "flaps 20: the 20 and 10 bugs (FCOM p.972)")
T.equal(rt:get("laminar/B747/pfd/show_mins"), 0, "on the ground: no minimum maneuvering band")
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
-- fltInst02 clears the CDU's landing flaps below 5 ft RA
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 1000)
frames(0.2)
T.equal(rt:get("laminar/B747/pfd/show_mins"), 0, "airborne at the takeoff flaps: not yet")
rt:set("sim/cockpit2/controls/flap_ratio", 3 / 6)                   -- flaps 10
frames(0.2)
T.equal(rt:get("laminar/B747/pfd/show_mins"), 1, "the first retraction: shown (FCOM p.973)")
T.equal(bugs(), "2,3", "flaps 10: 10 and 5")
rt:set("sim/cockpit2/controls/flap_ratio", 1)                       -- flaps 30
rt:set(A .. "VrefFlap", 2)                                          -- landing flaps 30 on the CDU
frames(0.2)
T.equal(bugs(), "5", "flaps 30 with landing flaps 30: 25 only (the REF bug is VREF30)")
T.equal(rt:get(A .. "showVf25"), 1, "showVf25 kept")
T.equal(rt:get(A .. "showVf30"), 0, "showVf30 kept")

T.done()
