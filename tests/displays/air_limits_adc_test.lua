-- Run from the repository root with LuaJIT: luajit tests/displays/air_limits_adc_test.lua
-- (2026-11-13; the 2026-11-12 review DSP-3, 案 12) The air data limits on
-- the Captain's selected ADC's altitude (laminar/B747/airdata/alt_capt, the
-- AIR DATA switch's source; B747.60.xt.fltInst02.lua, B747.60.xt.speedtape.lua),
-- not X-Plane's own Captain's altimeter, which a blocked static port freezes
-- (the failure window's STATIC CAPT BLOCKED): the maximum speed (FCOM p.969),
-- the flap maneuvering speed bugs (none above about 20,000 ft: FCOM p.972),
-- the 10,000 ft callout. Vmo M.92's CAS at the altitude, exact (before, a
-- line up to 3.4 kt over it at FL370).
local T = dofile("tests/lib/check.lua")("air_limits_adc")
local xtlua = dofile("tests/lib/xtlua.lua")
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
local function frames(s) for _ = 1, math.floor(s * 30 + 0.5) do rt:frame(1 / 30) end end

-- the ISA's CAS of a Mach at a pressure altitude, independently
local function mach_cas(mach, alt)
    local T0, L, g, R = 288.15, 0.0065, 9.80665, 287.053
    local h = alt * 0.3048
    local d
    if h <= 11000 then d = (1 - L * h / T0) ^ (g / (R * L))
    else d = (1 - L * 11000 / T0) ^ (g / (R * L)) * math.exp(-g * (h - 11000) / (R * 216.65)) end
    local qc = d * ((1 + 0.2 * mach * mach) ^ 3.5 - 1)
    return 661.4786 * math.sqrt(5 * ((qc + 1) ^ (2 / 7) - 1))
end

local function set(xp_alt, adc_alt, flaps, ias, mach)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", xp_alt)   -- X-Plane's own (the blocked port's)
    rt:set("laminar/B747/airdata/alt_capt", adc_alt)                     -- the selected ADC's
    rt:set("sim/flightmodel2/position/pressure_altitude", adc_alt)
    rt:set("sim/flightmodel/weight/m_total", 260000)
    rt:set("laminar/B747/gear/air_ground/pri_air", 1)
    rt:set("laminar/B747/airdata/valid_capt", 1)
    rt:set("laminar/B747/airdata/mach_capt", mach or 0.33)
    rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", ias or 210)
    rt:set("laminar/B747/fms/vref30", 146)
    rt:set("laminar/B747/fms/vref25", 152)
    rt:set("sim/cockpit2/controls/flap_ratio", flaps == 5 and 2 / 6 or 0)
    rt:set("laminar/B747/flt_ctrls/fcu/flap_pos", flaps)
    frames(1)
end

-- the altimeter frozen at 10,000 ft, the airplane at FL350 on ADC R
set(10000, 35000, 0, 270, 0.85)
T.near(rt:get("laminar/B747/airspeed/Vmax"), mach_cas(0.92, 35000), 0.2,
    string.format("X-Plane's altimeter frozen at 10,000 ft, the ADC at FL350: Vmax M.92's %.1f kt (before 365)", mach_cas(0.92, 35000)))
-- frozen at 35,000 ft, the approach at 3,000 ft with flaps 5
set(35000, 3000, 5)
local up = rt:get("laminar/B747/airspeed/show_vf", 1) + rt:get("laminar/B747/airspeed/show_vf", 2)
T.check(up > 0, "frozen at 35,000 ft, the ADC at 3,000 ft, flaps 5: the flap bugs shown (before none)")
T.equal(rt:get("laminar/B747/airspeed/Vmax") <= 365 and 1 or 0, 1, "  Vmax not over 365")
-- Vmo exact (no blockage): FL370 and FL390
for _, a in ipairs({30000, 37000, 39000}) do
    set(a, a, 0, 260, 0.85)
    T.near(rt:get("laminar/B747/airspeed/Vmo"), mach_cas(0.92, a), 0.2,
        string.format("%d ft: Vmo M.92's CAS %.1f kt (before a line up to 3.4 kt over)", a, mach_cas(0.92, a)))
end
set(20000, 20000, 0, 300, 0.7)
T.near(rt:get("laminar/B747/airspeed/Vmo"), 365, 1e-6, "20,000 ft: Vmo 365 kt")
-- the 10,000 ft callout on the ADC's altitude
set(12000, 12000, 0, 250, 0.5)
set(12000, 9600, 0, 250, 0.5)
T.equal(rt:get("laminar/B747/fmod/callouts/10000"), 1, "the ADC at 9,600 ft (X-Plane's frozen at 12,000): the 10,000 ft callout")
T.done()
