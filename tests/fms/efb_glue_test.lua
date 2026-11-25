-- Run from the repository root with LuaJIT: luajit tests/fms/efb_glue_test.lua
-- (2026-11-25; notes/ATA-34-61-FMC.md §191) the sim's takeoff and landing
-- performance window's FMC side (B747.68.efb_glue.lua) in the FMS module as
-- XTLua runs it (tests/lib/xtlua.lua), the window's requests read as XTLua
-- reads another plugin's datarefs (a read late: X-Plane s259): a runway
-- from the navigation data (the test airport ZZAA: tests/fms/data/navdb),
-- the takeoff worked out, a start further down the runway, SEND into the
-- TAKEOFF REF and THRUST LIM pages' entries, the FMC's route for the
-- window's defaults; the models all loaded (the paths into the flight
-- instruments' and the EEC's folders).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("efb_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local REQ_ID, REQ_KIND, REQ_I, REQ_F = "laminar/B747/efb/req_id", "laminar/B747/efb/req_kind",
    "laminar/B747/efb/req_i", "laminar/B747/efb/req_f"
local types = {["xtlua/loadtoFMS"] = "string", [REQ_ID] = "number", [REQ_KIND] = "number", [REQ_I] = "array[16]",
    [REQ_F] = "array[16]"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types, lagged = {REQ_ID, REQ_KIND, REQ_I, REQ_F}}
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
rt:set("sim/aircraft/weight/acf_m_max", 396893)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
for _ = 1, 900 do
    if fms.ns.B747_fmc_navdb and fms.ns.B747_fmc_navdb.ready then break end
    rt:frame(1 / 30)
end
T.check(fms.ns.B747_fmc_navdb.ready, "the navigation data read")
T.check(fms.ns.B747_efb_to_model ~= nil and fms.ns.B747_to_speeds_model ~= nil and fms.ns.B747_ref_thrust_model ~= nil
    and fms.ns.B747_rr_model ~= nil, "the models loaded, the flight instruments' and the EEC's too")

-- the window's packing (perf_window.c pw_pack): 4 characters in base 37
-- (A-Z 1-26, 0-9 27-36, none 0), whole in a float's 24 bits: XTLua reads
-- another plugin's int as a float (X-Plane s435, 2026-11-25: a byte a
-- character lost the last ones and the airport was not found)
local function pack(s)
    local v, n = 0, 0
    for c in s:upper():gmatch(".") do
        local b = c:byte()
        v = v * 37 + ((b >= 65 and b <= 90) and b - 64 or (b >= 48 and b <= 57) and b - 48 + 27 or 0)
        n = n + 1
    end
    for _ = n + 1, 4 do v = v * 37 end
    return v
end
local ffi = require("ffi")
local function as_float(v) return tonumber(ffi.new("float", v)) end
T.equal(as_float(pack("ZZ99")), pack("ZZ99"), "the largest packing survives a float (" .. pack("ZZ99") .. ")")
T.equal(pack("RJAA"), 925482, "RJAA packed (the scenarios' value)")
T.equal(pack("34L"), 1562473, "34L packed")
local function out(k) return rt:get("laminar/B747/efb/out", k) end
local function rwy(k) return rt:get("laminar/B747/efb/rwy", k) end
local function msg() return rt:get("laminar/B747/efb/msg") end
-- a request: the arrays, the kind, the id counted up (the window's order)
local function ask(kind, i, f)
    for k = 0, 15 do
        rt:set(REQ_I, k, i[k] or 0)
        rt:set(REQ_F, k, f[k] or 0)
    end
    rt:set(REQ_KIND, kind)
    rt:set(REQ_ID, rt:get(REQ_ID) + 1)
    frames(0.3)
    return rt:get("laminar/B747/efb/ans_id") == rt:get(REQ_ID)
end
local TO_I = {[0] = pack("ZZAA"), pack("16R"), 20, 0, 1, 3, 0, 0}
local TO_F = {[0] = 15, 1013.25, 0, 300000, 22, 0, 0, -99}

-- the runway: ZZAA 16R to 34L, 1.70 nm and 34L's 500 ft displaced
T.check(ask(1, TO_I, TO_F), "a runway: answered")
T.equal(rwy(0), 1, "ZZAA 16R found")
local N = fms.ns.B747_navdb
local d_ft = N.distance(35 + 36 / 3600, 140 + 18 / 3600, 34 + 59 / 60, 140 + 1 / 60) * 6076.12
T.near(rwy(1), d_ft + 500, 1, string.format("its length: the thresholds' %.0f ft and 34L's 500 ft displaced", d_ft))
T.equal(rwy(3), 500, "the far end's displacement")
T.near(rwy(7), (98 - 100) / d_ft * 100, 1e-6, "the slope: 100 to 98 ft (downhill)")
T.check(rwy(8) > 150 and rwy(8) < 165, string.format("the true bearing about 157: %.1f", rwy(8)))
T.equal(rwy(6), 100, "the airport's elevation (earth_aptmeta.dat)")
T.equal(rt:get("laminar/B747/efb/rwy_list"), "16R 34L", "the airport's runways")
T.equal(msg(), "", "no message")
-- unknown: the reasons
local i2 = {}
for k, v in pairs(TO_I) do i2[k] = v end
i2[1] = pack("09")
ask(1, i2, TO_F)
T.check(rwy(0) == -1 and msg() == "RUNWAY NOT FOUND", "ZZAA 09: runway not found (" .. msg() .. ")")
i2[0], i2[1] = pack("ZZXX"), pack("16R")
ask(1, i2, TO_F)
T.check(rwy(0) == 0 and msg() == "AIRPORT NOT FOUND", "ZZXX: airport not found (" .. msg() .. ")")

-- the takeoff
T.check(ask(2, TO_I, TO_F), "the takeoff: answered")
T.equal(out(1), 1, "worked out (" .. msg() .. ")")
local P = fms.ns.B747_efb_to_model
local inp = {engine = 0, flaps = 20, rating = 0, to_pct = 0, atm = true, cond = 0, packs = 3, eng_ai = false,
    wing_ai = false, oat_c = 15, qnh_hpa = 1013.25, elev_ft = 100, fla_ft = d_ft + 500, slope_pct = (98 - 100) / d_ft * 100,
    wind_kt = 0, tow_kg = 300000, cg_pct = 22, mtow_kg = 396893}
local want = P.calc(inp)
T.check(not want.err, "the model's own answer: " .. tostring(want.err))
T.near(out(12), want.v1, 0, "V1 the model's")
T.near(out(13), want.vr, 0, "VR")
T.near(out(14), want.v2, 0, "V2")
T.near(out(8), want.max_kg, 1, "the most")
T.near(out(10), want.sel_c or -99, 0, "the assumed temperature")
T.near(out(17), want.thrust, 1e-4, "EPR")
T.near(out(22), d_ft + 500, 1, "the field length: the whole runway")
T.near(out(25), 100, 0, "the airport's elevation")
-- a start 600 m down the runway
local f2 = {}
for k, v in pairs(TO_F) do f2[k] = v end
f2[5] = 600
ask(2, TO_I, f2)
T.near(out(22), d_ft + 500 - 600 / 0.3048, 1, "a start 600 m down: that much less field length")
T.check(out(8) < want.max_kg, "less field length: a lower limit")

-- SEND: into the pages' entries
ask(3, TO_I, TO_F)
T.equal(out(29), 1, "SEND done (" .. msg() .. ")")
local data = fms.ns.fmsModules["data"]
T.equal(tonumber(data["v1sel"]), want.v1, "TAKEOFF REF V1 entered")
T.equal(tonumber(data["vrsel"]), want.vr, "VR")
T.equal(tonumber(data["v2sel"]), want.v2, "V2")
T.equal(rt:get("laminar/B747/airspeed/flapsRef"), 20, "flaps 20")
if want.sel_c then
    T.equal(tonumber(data["thrustsel"]), want.sel_c, "THRUST LIM SEL the assumed temperature")
end
T.equal(tonumber(data["cg_mac"]), 22, "the CG")
-- in the air: refused
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(0.2)
ask(3, TO_I, TO_F)
T.check(out(29) == 0 and msg() == "ON THE GROUND ONLY", "SEND in the air: refused (" .. msg() .. ")")
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
frames(0.2)

-- the FMC's route for the window's defaults
ask(5, TO_I, TO_F)
T.check(rt:get("laminar/B747/efb/route"):match("^%S+ %S+ %S+ %S+ %d+ %d+$") ~= nil,
    "the route: " .. rt:get("laminar/B747/efb/route"))
-- the same in numbers (the window's: an XTLua string reaches it later)
T.equal(rt:get("laminar/B747/efb/route_n", 4), 20, "route_n: the TAKEOFF REF flaps the SEND set")
T.equal(rt:get("laminar/B747/efb/route_n", 1), 0, "route_n: no departure runway in the FMC")
-- with a route: the RTE page's origin and runway (as the CDU's entries)
local K = "laminar/B747/fms1/"
local function key(k) rt:command(K .. k) frames(0.3) end
local function typed(s) for c in s:gmatch(".") do rt:command(K .. "alphanum_key/" .. c) end frames(0.3) end
for _, k in ipairs({"func_key/fix", "ls_key/L1", "func_key/fpln"}) do key(k) end
typed("ZZAA")
key("ls_key/L1")
typed("16R")
key("ls_key/L2")
ask(5, TO_I, TO_F)
T.equal(rt:get("laminar/B747/efb/route_n", 0), pack("ZZAA"), "route_n: the origin ZZAA (" .. rt:get("laminar/B747/efb/route") .. ")")
T.equal(rt:get("laminar/B747/efb/route_n", 1), pack("16R"), "route_n: its runway 16R")

-- the landing (kind 4): ZZAA 34L (500 ft displaced), flaps 30, dry,
-- autobrakes 3, 4 reversers, 250 t, VREF + 5; each answer the models' own
local LI = {[0] = pack("ZZAA"), pack("34L"), 30, 0, 0, 3, 0, 0, 3, 4}
local LF = {[0] = 15, 1013.25, 0, 250000, 0, 0, 0, -99, 5}
T.check(ask(4, LI, LF), "the landing: answered")
T.equal(out(0), 4, "the landing's answer")
T.equal(out(1), 1, "worked out (" .. msg() .. ")")
local LM, V = fms.ns.B747_efb_ldg_model, fms.ns.B747_vref_model
local slope34 = (100 - 98) / d_ft * 100
local vref = V.vref(30, 250000, 100)
T.equal(out(3), math.floor(vref + 0.5), "VREF 30: the FMC's table")
T.equal(out(4), math.floor(vref + 5 + 0.5), "the approach speed: VREF + 5")
local d = LM.distance(0, 30, "DRY", "3", 250000, 100, 15, 0, slope34, 5, 4)
T.near(out(5), d, 0.5, string.format("the landing distance: the model's %.0f m", d))
T.near(out(6), d_ft * 0.3048, 0.5, "the runway's from 34L's threshold: its 500 ft displaced not counted")
T.near(out(7), d_ft * 0.3048 - d, 1, "the margin")
local disp = LM.dispatch({flaps = 30, lda_m = d_ft * 0.3048, pa_ft = 100, elev_ft = 100, oat_c = 15, wind_kt = 0,
    slope_pct = slope34, cond = "DRY", packs = 3, mlw_kg = 285763, weight_kg = 250000, vref_add_kt = 5})
T.near(out(10), disp.normal.kg, 1, string.format("the dispatch's normal limit %.0f (%s)", disp.normal.kg, disp.normal.limit))
T.near(out(12), disp.qt_kg or 0, 1, "the quick turnaround limit")
T.equal(out(22), 285763, "the 109's structural landing weight (FCOM p.78)")
-- heavier than the structural: worked out, with the message
LF[3] = 300000
ask(4, LI, LF)
T.check(out(1) == 1 and msg() == "ABOVE THE MAXIMUM LANDING WEIGHT", "300 t: worked out, above the maximum landing weight (" .. msg() .. ")")
T.done()
