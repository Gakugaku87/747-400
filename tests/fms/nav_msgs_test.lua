-- Run from the repository root with LuaJIT: luajit tests/fms/nav_msgs_test.lua
-- The FMC's navigation alerts (6-1/6-2 step 11c3; notes/ATA-34-61-FMC.md
-- §96; FCOM p.1433-1434) in the FMS module as XTLua runs it (tests/lib/
-- xtlua.lua): IRS POS/ORIGIN DISAGREE on the ground (the IRS position 18
-- NM from the active route's origin ZZAA), SET CLOCK TO UTC TIME (a GPS
-- valid, the Captain's clock 20 s off; the F/O's without the Captain's;
-- none without a GPS), NAV INVALID-TUNE on approach (the approach's VOR,
-- put on the R09 approach's leg here since the test data has no VOR
-- approach, received by neither VOR receiver for 5 s).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("nav_msgs")
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
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
local function irs(lat, lon)
    for i = 0, 2 do
        rt:set("laminar/B747/irs/nav_valid", i, 1)
        rt:set("laminar/B747/irs/lat", i, lat)
        rt:set("laminar/B747/irs/lon", i, lon)
    end
end
irs(35, 140)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function pad() return (line(14):gsub("%s+$", "")) end
local NOTE = "laminar/B747/fms/notification"
local CLK = "laminar/B747/fltInst/"

-- the route ZZAA to ZZBB with the approach R09
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
clear()
key("func_key/clb")              -- DEPARTURES (the ground, an active route)
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")                 -- ZZBB ARRIVALS
key("ls_key/R1")                 -- R09
key("key/execute")
clear()
frames(1.2)

-- IRS POS/ORIGIN DISAGREE (FCOM p.1433)
T.equal(rt:get(NOTE, 23), 0, "the IRS position at the origin: none")
irs(35.3, 140)
frames(1.2)
T.equal(rt:get(NOTE, 23), 1, "18 NM from the origin ZZAA: IRS POS/ORIGIN DISAGREE")
frames(0.3)
T.equal(pad(), "IRS POS/ORIGIN DISAGREE", "on the CDU")
irs(35.05, 140)
frames(1.2)
T.equal(rt:get(NOTE, 23), 0, "3 NM: none")
clear()

-- SET CLOCK TO UTC TIME (FCOM p.1434)
rt:set("laminar/B747/gps/valid", 0, 1)
rt:set(CLK .. "capt/clock_valid", 1)
rt:set(CLK .. "capt/clock_utc_offset", 5)
frames(1.2)
T.equal(rt:get(NOTE, 41), 0, "the Captain's clock 5 s off: none")
rt:set(CLK .. "capt/clock_utc_offset", -20)
frames(1.2)
T.equal(rt:get(NOTE, 41), 1, "20 s off: SET CLOCK TO UTC TIME")
frames(0.3)
T.equal(pad(), "SET CLOCK TO UTC TIME", "on the CDU")
rt:set(CLK .. "capt/clock_valid", 0)
rt:set(CLK .. "fo/clock_valid", 1)
rt:set(CLK .. "fo/clock_utc_offset", 3)
frames(1.2)
T.equal(rt:get(NOTE, 41), 0, "the Captain's off, the F/O's 3 s off: none")
rt:set(CLK .. "fo/clock_utc_offset", 30)
frames(1.2)
T.equal(rt:get(NOTE, 41), 1, "the F/O's 30 s off: SET CLOCK TO UTC TIME")
rt:set("laminar/B747/gps/valid", 0, 0)
frames(1.2)
T.equal(rt:get(NOTE, 41), 0, "no GPS: none")
clear()

-- NAV INVALID-TUNE (FCOM p.1433): on approach (its first leg sequenced),
-- the approach's VOR ZZV
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 2000)   -- (not the approach's 500 ft hold)
local st = fms.ns.B747_fmc_route
T.check(fms.ns.B747_route_model.sequence(st, 1), "the approach's first leg sequenced")
local N = fms.ns.B747_navdb
local zzv = N.point(fms.ns.B747_fmc_navdb, "ZZV", "ZZ", N.VOR)
st.rte.legs[1].navaid = zzv
rt:set("sim/cockpit2/radios/indicators/nav3_nav_id", "ZZV")
rt:set("sim/cockpit2/radios/indicators/nav4_nav_id", "")
frames(6)
T.check(not pad():find("NAV INVALID", 1, true), "ZZV received on VOR L: none: " .. pad())
rt:set("sim/cockpit2/radios/indicators/nav3_nav_id", "")
frames(4)
T.check(not pad():find("NAV INVALID", 1, true), "4 s without it: not yet")
frames(2.2)
T.equal(pad(), "NAV INVALID-TUNE ZZV", "5 s without it: NAV INVALID-TUNE ZZV")
rt:set("sim/cockpit2/radios/indicators/nav4_nav_id", "ZZV")
frames(1.2)
T.check(not pad():find("NAV INVALID", 1, true), "received on VOR R: gone")
T.done()
