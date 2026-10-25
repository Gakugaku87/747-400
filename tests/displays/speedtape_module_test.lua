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
rt:set("sim/flightmodel/forces/g_nrml", 1)                         -- 1 g (the minimum speeds)
rt:set("laminar/B747/airdata/valid_capt", 1)                      -- the captain's air data valid
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 0)
rt:set("sim/cockpit2/controls/flap_ratio", 4 / 6)                   -- flaps 20
rt:set("laminar/B747/gear/air_ground/pri_air", 0)
rt:callout("flight_start")
frames(6)                                                           -- on the ground for the band: 5 s

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

-- the minimum speeds (step 3b, the minimum speed model): 300 t at 10,000 ft
-- with the trailing edge flaps at 20
local MS = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.minspeed_model.lua")
local D10 = MS.delta(10000)
rt:set("sim/flightmodel2/position/pressure_altitude", 10000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 10000)
rt:set("sim/flightmodel2/wing/flap1_deg", 0, 20)
rt:set("sim/flightmodel/forces/g_nrml", 1)
rt:set("laminar/B747/airdata/mach_capt", MS.cas_to_mach(200, D10))
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 200)
frames(3)
local vs = rt:get(A .. "Vs")
T.near(vs, 146.3, 1.0, "the red and black band: the FCTM's flaps 20 shaker speed at 300 t (" .. vs .. ")")
T.near(rt:get(A .. "Vminm"), vs * math.sqrt(1.3), 2.5, "the minimum maneuvering speed: about 1.3 g to the shaker")
T.check(rt:get(A .. "Vmc") < rt:get(A .. "Vminm"), "Vmc: still the old formula for the AFDS and A/T floors")
T.equal(rt:get(A .. "Vmaxm"), rt:get(A .. "Vmax"), "no maximum maneuvering speed here: the maximum speed")
-- the panel's band pointers read the bands minus each PFD's airspeed
rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", 190)
frames(0.1)
T.near(rt:get(A .. "tape_capt", 0), rt:get(A .. "Vs") - 200, 1e-6, "tape_capt[0]: the minimum speed minus the captain's 200 kt")
T.near(rt:get(A .. "tape_capt", 1), rt:get(A .. "Vminm") - 200, 1e-6, "tape_capt[1]: the minimum maneuvering speed")
T.near(rt:get(A .. "tape_capt", 3), rt:get(A .. "Vmax") - 200, 1e-6, "tape_capt[3]: the maximum speed")
T.near(rt:get(A .. "tape_fo", 1), rt:get(A .. "Vminm") - 190, 1e-6, "tape_fo[1]: minus the first officer's 190 kt")
T.near(rt:get(A .. "tape_fo", 2), rt:get(A .. "Vmaxm") - 190, 1e-6, "tape_fo[2]: the maximum maneuvering speed")
T.equal(rt:get("sim/flightmodel/failures/stallwarning"), 0, "200 kt: no stick shaker")
T.equal(rt:get("laminar/B747/CAS/caution_status", 0), 0, "200 kt: no AIRSPEED LOW")
rt:set("laminar/B747/airdata/mach_capt", MS.cas_to_mach(vs - 3, D10))
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", vs - 3)
frames(1)
T.equal(rt:get("sim/flightmodel/failures/stallwarning"), 1, "3 kt below the band: the stick shaker")
T.equal(rt:get("laminar/B747/CAS/caution_status", 0), 1, "AIRSPEED LOW")
T.equal(rt:get("laminar/B747/airspeed_window/min"), 1, "the amber box")
-- the captain's air data not valid: the first officer's (here 200 kt)
rt:set("laminar/B747/airdata/valid_capt", 0)
rt:set("laminar/B747/airdata/valid_fo", 1)
rt:set("laminar/B747/airdata/mach_fo", MS.cas_to_mach(200, D10))
rt:set("laminar/B747/gauges/indicators/airspeed_kts_copilot", 200)
frames(1)
T.equal(rt:get("sim/flightmodel/failures/stallwarning"), 0, "the first officer's 200 kt: no stick shaker")
T.equal(rt:get("laminar/B747/CAS/caution_status", 0), 0, "the first officer's 200 kt: no AIRSPEED LOW")
rt:set("laminar/B747/airdata/valid_fo", 0)
rt:set("laminar/B747/airdata/mach_capt", 0)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 0)
frames(1)
T.equal(rt:get("sim/flightmodel/failures/stallwarning"), 0, "no valid air data: no stick shaker (estimate)")
T.equal(rt:get("laminar/B747/CAS/caution_status", 0), 0, "no valid air data: no AIRSPEED LOW")
rt:set("laminar/B747/gear/air_ground/pri_air", 0)
frames(0.2)
T.equal(rt:get("sim/flightmodel/failures/stallwarning"), 0, "on the ground: no stick shaker")
T.equal(rt:get("laminar/B747/CAS/caution_status", 0), 0, "on the ground: no AIRSPEED LOW")

T.done()
