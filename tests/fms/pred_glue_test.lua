-- Run from the repository root with LuaJIT: luajit tests/fms/pred_glue_test.lua
-- The FMC's trajectory predictions in the FMS module (6-1/6-2 step 8c;
-- notes/ATA-34-61-FMC.md §47) as XTLua runs it (tests/lib/xtlua.lua), on
-- the synthetic CIFP of ZZAA: the active route's legs ahead with their
-- distances and constraints, the E/D at the approach's runway (50 ft above
-- it: FCOM p.1258), the SID's constraints the climb's, the predictions'
-- T/D and destination on the CRZ page, UNABLE CRZ ALT for a cruise
-- altitude the short route cannot reach (FCOM p.1436), none without an
-- active route or with CRZ ALT above MAX (ATA34_2 p.611).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("pred_glue")
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 250000)
rt:set("sim/flightmodel/weight/m_fuel_total", 40000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
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
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function pad() return (line(14):gsub("%s+$", "")) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end

-- no route: no predictions
key("func_key/index")
enter("100", "L5")
enter("350", "R1")
frames(11)
T.equal(fms.ns.B747_fms_preds(), nil, "no active route: no predictions")
T.equal(rt:get("laminar/B747/fms/profile/kind", 0), 0, "nor the ND's profile points")

-- the route: ZZAA to ZZAA, DIRECT ALPHA, DELTA; ZULU1 from 34L by ALPHA;
-- ALPHA1 by DELTA to the ILS 16R; ACTIVATE and EXEC
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("DELTA", "R2")
key("func_key/clb")
key("ls_key/L1")                 -- DEPARTURES
key("ls_key/L1")                 -- ZULU1
key("ls_key/R2")                 -- 34L
key("ls_key/L2")                 -- ALPHA
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")                 -- ARRIVALS
key("ls_key/L1")                 -- ALPHA1
key("ls_key/L2")                 -- DELTA
key("ls_key/R1")                 -- ILS16R
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1)
T.check(fms.ns.B747_fmc_route.active, "the route active")

-- the predictions' input and result
local s = fms.ns.B747_fms_pred_input(35000)
local legs = fms.ns.B747_fmc_route.rte.legs
T.equal(#s.legs, #legs, "every leg ahead (" .. #legs .. ")")
local rwy, sid, star = nil, 0, false
for i, l in ipairs(legs) do
    if l.fix and l.fix.kind == "RWY" and l.proc ~= "SID" then rwy = i end
    if l.proc == "SID" then sid = i end
end
T.equal(s.ed, rwy, "the E/D: the approach's runway leg (" .. tostring(rwy) .. ")")
T.near(s.legs[rwy].con.a, (legs[rwy].fix.elev or 0) + 50, 1e-6, "its altitude 50 ft above the threshold")
T.equal(s.clb_last, sid, "the climb's legs the SID's (" .. sid .. ")")
local fixed = true
for i, l in ipairs(legs) do
    local prev = legs[i - 1] and legs[i - 1].fix
    local same = prev and l.fix and prev.ident == l.fix.ident
    if l.fix and i > 1 and not same and not (s.legs[i].dist > 0) then fixed = false end
end
T.check(fixed, "each leg with a point: its distance from the one before")
local total = 0
for _, l in ipairs(s.legs) do total = total + l.dist end
T.check(total > 20 and total < 400, string.format("the route %.0f NM", total))
T.check(s.clb.cas > 0 and s.des.cas > 0 and s.crzspd.mach, "the speeds from the FMC's data")

-- UNABLE CRZ ALT: at 390 t the route cannot reach FL320 (MAX FL326)
-- before its descent
rt:set("sim/flightmodel/weight/m_total", 390000)
key("func_key/index")
enter("320", "R1")
T.equal(pad(), "UNABLE CRZ ALT", string.format("CRZ ALT FL320 at 390 t over %.0f NM: UNABLE CRZ ALT", total))
clear()
frames(11)
local r = fms.ns.B747_fms_preds()
T.check(r ~= nil, "the predictions")
T.check(r.tc == nil and r.td and r.ed and r.crz < 32000, string.format("no T/C: the climb meets the descent at %.0f ft, T/D at %.0f NM", r.crz, r.td or -1))
T.near(r.dest.t, r.pts[#r.pts].t, 1e-6, "the destination's time: the last leg's")
T.check(r.dest.fuel < 40000 and r.dest.fuel > 25000, string.format("its fuel %.0f kg (40 t now)", r.dest.fuel))
-- 250 t, STEP SIZE 0, FL100: no message, T/C and T/D, every leg at or
-- below FL100
rt:set("sim/flightmodel/weight/m_total", 250000)
enter("0", "R5")
enter("FL100", "R1")
T.equal(pad(), "", "FL100: no message")
frames(11)
r = fms.ns.B747_fms_preds()
T.check(r.tc and r.td and r.tc < r.td, string.format("FL100: T/C %.0f NM before the T/D %.0f NM", r.tc or -1, r.td or -1))
for i, p in ipairs(r.pts) do
    T.check(p.h <= 10000 + 1, "leg " .. i .. " at or below FL100: " .. math.floor(p.h))
end
-- the ND's profile points (step 8d3; FCOM p.1149): T/C, T/D and E/D where
-- they are on the legs' great circles; no S/C with STEP SIZE 0
local PR = "laminar/B747/fms/profile/"
local prof = {}
for k = 0, 7 do
    local kind = rt:get(PR .. "kind", k)
    if kind > 0 then prof[kind] = {lat = rt:get(PR .. "lat", k), lon = rt:get(PR .. "lon", k)} end
end
T.check(prof[1] and prof[3] and prof[4] and not prof[2], "FL100, STEP SIZE 0: T/C, T/D and E/D, no S/C")
local rwFix = legs[rwy].fix
T.check(math.abs(prof[4].lat - rwFix.lat) < 1e-4 and math.abs(prof[4].lon - rwFix.lon) < 1e-4, "the E/D at the runway's threshold")
local function on_leg(p, x)
    local RM = fms.ns.B747_route_model
    local acc = 0
    for _, l in ipairs(fms.ns.B747_fms_pred_input(10000).legs) do
        if l.dist > 0 and x <= acc + l.dist then
            local _, d0 = RM.course(l.p0.lat, l.p0.lon, p.lat, p.lon)
            local _, d1 = RM.course(p.lat, p.lon, l.p1.lat, l.p1.lon)
            return math.abs(d0 - (x - acc)) < 0.05 and math.abs(d0 + d1 - l.dist) < 0.05
        end
        acc = acc + l.dist
    end
    return false
end
T.check(on_leg(prof[3], r.td), string.format("the T/D on its leg, %.1f NM along the route", r.td))
T.check(on_leg(prof[1], r.tc), string.format("the T/C on its leg, %.1f NM along the route", r.tc))

-- the predictions' winds (step 8e3; notes §53): a WIND page's entry at
-- FL100 straight down the longest leg, propagated everywhere; on the
-- ground (the climb) its share by the altitude from here (FMSPG p.233)
local Wm = fms.ns.B747_wind_model
local sIn = fms.ns.B747_fms_pred_input(10000)
local kLong, xMid, acc = 1, 0, 0
for k, l in ipairs(sIn.legs) do
    if l.dist > sIn.legs[kLong].dist then kLong = k end
end
for k, l in ipairs(sIn.legs) do
    if k == kLong then xMid = acc + l.dist / 2 end
    acc = acc + l.dist
end
local LL = sIn.legs[kLong]
local crsLong = fms.ns.B747_route_model.course(LL.p0.lat, LL.p0.lon, LL.p1.lat, LL.p1.lon)
local r0 = fms.ns.B747_fms_preds()
local st = fms.ns.B747_fmc_route
Wm.add_alt(st.rte, 10000)
Wm.set_wind(st.rte, kLong, 10000, math.floor(crsLong + 0.5) % 360, 100)
fms.ns.B747_fms_preds_now()
frames(1)
local s2 = fms.ns.B747_fms_pred_input(10000)
local share = Wm.mix((10000 - 100) / Wm.MIX_FT_PER_NM)
T.near(s2.field.wind(xMid, 10000, "crz"), 100 * (1 - share), 1.5,
    string.format("the longest leg's middle at FL100: a %.0f kt headwind (the forecast's 100, %.0f %% measured calm)", 100 * (1 - share), share * 100))
local r1 = fms.ns.B747_fms_preds()
T.check(r1 ~= r0 and math.abs(r1.dest.t - r0.dest.t) > 30, string.format("the predictions with the wind: the destination %.1f min apart", (r1.dest.t - r0.dest.t) / 60))
Wm.delete_alt(st.rte, 10000)
fms.ns.B747_fms_preds_now()
frames(1)


-- PROGRESS page 1 from the predictions (step 8d; FCOM p.1371-1373): TO
-- the first leg with a point, NEXT the one after, DEST; TO T/C on the
-- ground (the climb)
key("func_key/prog")
local legsR = fms.ns.B747_fmc_route.rte.legs
local to, nxt
for i, l in ipairs(legsR) do
    if l.fix and r.pts[i] then
        if not to then to = i elseif not nxt then nxt = i break end
    end
end
local function eta4(t) local _, h, m = fms.ns.get_ETA_for_Distance(0, t) return string.format("%02d%02d", h, m) end
local function row_ok(n, name, p)
    local tail = string.format("%4d %s  %5.1f", math.floor(p.x + 0.5), eta4(p.t), p.fuel / 1000)
    return line(n):find("^" .. name) and line(n):sub(-#tail) == tail
end
T.check(row_ok(5, legsR[to].fix.ident, r.pts[to]), "TO " .. legsR[to].fix.ident .. ": its distance, ETA and fuel predicted: " .. line(5))
T.check(row_ok(7, legsR[nxt].fix.ident, r.pts[nxt]), "NEXT " .. legsR[nxt].fix.ident .. ": " .. line(7))
T.check(row_ok(9, "ZZAA", r.dest), "DEST ZZAA: " .. line(9))
local tcText = string.format("%sz/%dNM", eta4(r.tc_t), math.floor(r.tc + 0.5))
T.check(small(10):find("TO T/C$") and line(11):sub(-#tcText) == tcText,
    "TO T/C: its ETA and distance: " .. small(10) .. "|" .. line(11))
T.check(small(10):find("^ ECON SPD"), "the speed's mode: ECON SPD: " .. small(10))

-- LEGS: the predicted speed and altitude in small font (step 8d; FCOM
-- p.1332): before an altitude constraint's slash the speed alone, without a
-- constraint speed/altitude, none under a speed and altitude constraint
key("func_key/legs")
local function spd_of(p) return p.machMode and string.format(".%03d", math.floor(p.mach * 1000 + 0.5)) or string.format("%3d", math.floor(p.cas + 0.5)) end
local function alt_of(p) return p.h > 18000 and string.format("FL%03d", math.floor(p.h / 100 + 0.5)) or string.format("%5d", math.floor(p.h / 10 + 0.5) * 10) end
local cons1 = fms.ns.B747_route_model.constraint_text(legsR[1], 18000)
T.equal(small(3), string.rep(" ", 24 - #cons1 - #spd_of(r.pts[1])) .. spd_of(r.pts[1]) .. string.rep(" ", #cons1),
    "(600) with " .. cons1 .. ": its predicted speed before the slash: " .. small(3) .. "|" .. line(3))
T.equal(small(5), string.rep(" ", 24 - #spd_of(r.pts[2]) - 1 - #alt_of(r.pts[2])) .. spd_of(r.pts[2]) .. "/" .. alt_of(r.pts[2]),
    "(INTC) without a constraint: speed/altitude: " .. small(5))
T.equal((small(7):gsub("%s+$", "")), "", "ZZV with 230/3000A: none: " .. line(7))
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(5):find("^RW16R") and small(5):find("240"), "the runway (the E/D): its speed: " .. small(5))
T.equal((small(7):gsub("%s+$", "")), "", "the missed approach after the E/D: none: " .. line(7))
key("func_key/legs")

-- RTE DATA (step 8d2; FCOM p.1360-1363): from the active LEGS page's 6R;
-- each waypoint's ETA and fuel in small font (FCOM p.1362), ">" for its
-- winds; LEGS> back on the 109, <LEGS on the 570 (the GE airplane)
key("func_key/legs")
T.check(line(13):find("RTE DATA>$"), "the active LEGS page: RTE DATA> at 6R: " .. line(13))
key("ls_key/R6")
T.check(line(1):find("ACT RTE 1 DATA"), "RTE DATA: " .. line(1))
T.equal(small(2), " ETA    WPT   FUEL  WIND", "its titles")
local function fuel_of(p) return string.format("%5.1f", p.fuel / 1000) end
T.check(line(3):find("^      %(600%) +>$"), "(600): its name at the 7th place, > at the 24th: " .. line(3))
T.equal(small(3), eta4(r.pts[1].t) .. "z         " .. fuel_of(r.pts[1]) .. "     ",
    "its ETA at the 1st to 5th places and fuel at the 15th to 19th, small")
T.check(line(7):find("^      ZZV") and small(7):sub(15, 19) == fuel_of(r.pts[3]), "ZZV: its fuel: " .. small(7))
T.equal(line(12), "--------------          ", "the 109's line above 6")
key("func_key/next_pg")
T.equal(small(9), "-- ROUTE DISCONTINUITY -", "the discontinuity (leg 9) on page 2's fourth row")
T.check(line(3):find("^      DELTA"), "page 2 from leg 6, DELTA: " .. line(3))
rt:set("laminar/B747/engines/type", 1)
frames(0.3)
T.check(line(13):find("^<LEGS +$"), "the 570: <LEGS at 6L, no SEND> without an uplink: " .. line(13))
key("ls_key/R6")
T.check(line(1):find("ACT RTE 1 DATA"), "the 570: 6R nothing: " .. line(1))
key("ls_key/L6")
T.check(line(1):find("ACT RTE 1 LEGS"), "the 570: <LEGS: the LEGS page: " .. line(1))
rt:set("laminar/B747/engines/type", 0)
key("ls_key/R6")
key("ls_key/R6")
T.check(line(1):find("ACT RTE 1 LEGS"), "the 109: LEGS>: the LEGS page: " .. line(1))

-- the CRZ page: the destination's ETA and fuel the predictions'
key("func_key/des")
key("func_key/next_pg")
local _, eh, em = fms.ns.get_ETA_for_Distance(0, r.dest.t)
T.check(line(7):find(string.format("%02d%02dz/%.1f$", eh, em, r.dest.fuel / 1000)), "the destination's ETA and fuel: " .. line(7))
T.check(small(6):find("ZZAA ETA/FUEL"), "the destination's identifier: " .. small(6))

-- CRZ ALT above MAX: no predictions (ATA34_2 p.611)
rt:set("sim/flightmodel/weight/m_total", 390000)
key("func_key/index")
enter("FL410", "R1")
T.check(pad():find("^MAX ALT FL"), "FL410 at 390 t: MAX ALT: " .. pad())
clear()
frames(11)
T.equal(fms.ns.B747_fms_preds(), nil, "above MAX: no predictions")

-- the FMC's VNAV (step 9b; notes §56) on the ground: the climb, VNAV SPD
-- with THR REF, the FMC altitude CRZ ALT (the SID's constraints at or
-- above only), the climb's 250 kt below 10,000 ft; valid once the gross
-- weight is in (PERF INIT's ZFW: FCOM p.645)
local VN = "laminar/B747/fms/vnav/"
T.equal(rt:get(VN .. "valid"), 0, "no ZFW on PERF INIT: VNAV not valid (PERF/VNAV UNAVAILABLE)")
T.equal(rt:get(VN .. "perf"), 0, "(step 9c) no gross weight: the VNAV switch's data not in")
key("func_key/index")
enter("210", "L3")
frames(0.5)
T.equal(rt:get(VN .. "valid"), 1, "ZFW 210: valid")
T.equal(rt:get(VN .. "phase"), 1, "on the ground: the climb")
T.equal(rt:get(VN .. "mode"), 1, "VNAV SPD")
T.equal(rt:get(VN .. "at"), 5, "THR REF")
T.equal(rt:get(VN .. "alt"), 41000, "the FMC altitude: CRZ ALT FL410")
T.near(rt:get(VN .. "cas"), 250, 0.5, "250 kt below SPD TRANS's 10,000 ft")
T.equal(rt:get(VN .. "perf"), 1, "(step 9c) the VNAV switch's data in: GW, COST INDEX 100, CRZ ALT (FCOM p.1433)")
-- (step 9c) the takeoff's target (FCOM p.1255): V2 160 entered on TAKEOFF
-- REF, on the ground stopped: V2 + 10
key("ls_key/L6")
key("ls_key/L5")
T.check(line(1):find("TAKEOFF REF"), "TAKEOFF REF: " .. line(1))
enter("160", "R3")
frames(0.5)
T.equal(rt:get("laminar/B747/airspeed/V2"), 160, "V2 160")
T.near(rt:get(VN .. "cas"), 170, 0.5, "the takeoff's target: V2 + 10 (not the climb's 250 kt)")
-- (step 9c) the distance to go to the E/D goes on from the active leg's
-- point when LNAV sequences between the predictions (before, from the
-- point passed: s140 went 700 ft off the path after ATMUG). CRZ ALT FL350
-- again for the predictions (none above MAX)
key("func_key/index")
enter("350", "R1")
frames(11)
T.check(fms.ns.B747_fms_preds() ~= nil, "FL350: the predictions")
local st, RM = fms.ns.B747_fmc_route, fms.ns.B747_route_model
local d0 = fms.ns.B747_fms_vnav_dist()
T.check(d0 ~= nil, "a distance to go to the E/D: " .. tostring(d0))
local n1, f1, f2 = nil, nil, nil
for i, l in ipairs(st.rte.legs) do
    if l.fix then
        if not f1 then n1, f1 = i, l.fix elseif not f2 then f2 = l.fix end
    end
end
local lat, lon = rt:get("sim/flightmodel/position/latitude"), rt:get("sim/flightmodel/position/longitude")
local _, a1 = RM.course(lat, lon, f1.lat, f1.lon)
local _, a2 = RM.course(lat, lon, f2.lat, f2.lon)
local _, d12 = RM.course(f1.lat, f1.lon, f2.lat, f2.lon)
-- sequenced with the airplane halfway on to the next point (the one passed
-- behind it): the distance from the next point, not from the one passed
RM.sequence(st, n1)
local mlat, mlon = (f1.lat + f2.lat) / 2, (f1.lon + f2.lon) / 2
rt:set("sim/flightmodel/position/latitude", mlat)
rt:set("sim/flightmodel/position/longitude", mlon)
frames(0.1)
local _, m1 = RM.course(mlat, mlon, f1.lat, f1.lon)
local _, m2 = RM.course(mlat, mlon, f2.lat, f2.lon)
local rem2 = d0 - a1 - d12
T.near(fms.ns.B747_fms_vnav_dist(), m2 + rem2, 0.01,
    string.format("%s sequenced: on from %s (%.1f NM; from %s %.1f)", f1.ident, f2.ident, fms.ns.B747_fms_vnav_dist(),
        f1.ident, m1 + d12 + rem2))
rt:set("sim/flightmodel/position/latitude", lat)
rt:set("sim/flightmodel/position/longitude", lon)

-- (step 9d1) the MCP altitude selector's push (FCOM p.649): in the climb
-- (on the ground) the next climb constraint between the airplane and the
-- MCP altitude goes from the active route itself (no modification), one a
-- push; none left, CRZ ALT the MCP altitude above it
frames(11)
local PUSHES = "laminar/B747/autopilot/alt_sel_pushes"
local MCPA = "laminar/B747/autopilot/heading/altitude_dial_ft"
local CRZA = "laminar/B747/autopilot/dist/cruise_alt"
local function cons()
    local n = 0
    for _, l in ipairs(st.rte.legs) do if l.alt then n = n + 1 end end
    return n
end
local function push() rt:set(PUSHES, rt:get(PUSHES) + 1) frames(0.2) end
rt:set(MCPA, 37000)
frames(0.2)
local n0 = cons()
T.check(n0 > 0, "constraints on the route: " .. n0)
push()
T.equal(cons(), n0 - 1, "a push: one constraint less")
T.check(st.mod == nil, "no modification to execute")
T.equal(rt:get(CRZA), 35000, "CRZ ALT kept while a constraint goes")
local n = 1
while rt:get(CRZA) == 35000 and n < 12 do push() n = n + 1 end
T.equal(rt:get(CRZA), 37000, string.format("none left in the climb: CRZ ALT the MCP's 37,000 ft (%d pushes)", n))
T.check(cons() > 0, "the descent's constraints kept: " .. cons())


-- (step 9d2a) in the air at CRZ ALT FL370: the cruise. The selector's push
-- with the MCP below CRZ ALT (FCOM p.649): more than 50 NM before the T/D
-- and above the descent's highest constraint, a cruise descent (CRZ ALT
-- the MCP's: p.1261) with a SPD RESTR above the MCP deleted (p.1257);
-- within 50 NM, the early descent (the descent phase, VNAV SPD with THR,
-- CRZ ALT kept: p.1260); more than 50 NM with the MCP under the highest
-- descent constraint, the early descent too (p.1389). The T/D's distance
-- here given (the short route has no cruise at FL370)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 37000)
rt:set(MCPA, 37000)
frames(11)
T.equal(rt:get(VN .. "phase"), 2, "in the air at CRZ ALT FL370: the cruise")
local top = fms.ns.B747_fms_des_top()
T.check(top and top < 29000, "the descent's highest constraint: " .. tostring(top))
local realTd = fms.ns.B747_fms_vnav_td
fms.ns.B747_fms_vnav_td = function() return 80 end
local function data(id) return (fms.ns.fmsModules.data[id]:gsub("%s+$", "")) end
key("func_key/des")
key("func_key/next_pg")
key("func_key/next_pg")
enter("240/33000", "L4")
T.equal(data("desrestalt"), "33000", "SPD RESTR 240/33000 on the DES page")
rt:set(MCPA, 31000)
frames(0.2)
push()
T.equal(rt:get(CRZA), 31000, "80 NM before the T/D, MCP FL310: CRZ ALT FL310 (the cruise descent)")
T.equal(rt:get(VN .. "phase"), 2, "the cruise phase")
T.check(rt:get(VN .. "mode") == 1 and rt:get(VN .. "at") == 4, "VNAV SPD with THR")
T.near(rt:get(VN .. "vs"), -1250, 1e-6, "1,250 fpm down")
T.check(data("desrestalt") == "-----" and data("desrestspd") == "---", "the SPD RESTR above it deleted")
T.equal(data("desspdtransalt"), "10000", "SPD TRANS's 10,000 ft below it kept")
T.check(line(1):find("ACT ECON DES") == nil, "the DES page not active: " .. line(1))
key("func_key/prev_pg")
T.check(line(1):find("ACT ECON CRZ DES"), "the CRZ page: ACT ECON CRZ DES (FCOM p.1347): " .. line(1))
local n0 = cons()
fms.ns.B747_fms_vnav_td = function() return 30 end
rt:set(MCPA, 29000)
frames(0.2)
push()
T.equal(rt:get(VN .. "phase"), 3, "30 NM before the T/D, MCP FL290: the early descent (the descent phase)")
T.check(rt:get(VN .. "mode") == 1 and rt:get(VN .. "at") == 4, "VNAV SPD with THR")
T.equal(rt:get(CRZA), 31000, "CRZ ALT kept")
T.equal(cons(), n0, "the descent's constraints kept (those after the T/D)")
key("func_key/next_pg")
T.check(line(1):find("ACT ECON DES"), "the DES page active: " .. line(1))
-- the cruise again (on the ground and up): more than 50 NM, the MCP under
-- the highest descent constraint: the early descent
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(0.2)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 31000)
rt:set(MCPA, 31000)
frames(0.5)
T.equal(rt:get(VN .. "phase"), 2, "at FL310 in the air: the cruise")
fms.ns.B747_fms_vnav_td = function() return 120 end
rt:set(MCPA, math.floor((top - 1000) / 100) * 100)
frames(0.2)
push()
T.equal(rt:get(VN .. "phase"), 3, "120 NM before the T/D, the MCP under the highest constraint: the early descent")
fms.ns.B747_fms_vnav_td = realTd
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
frames(0.2)

-- (step 9d2b) the VNAV pages' 6R (FCOM p.1329, p.1393; FMSPG p.116,
-- p.3.5-4 to 3.5-6). CLB DIR: in the climb at 5,000 ft with a SID
-- constraint ahead and the MCP at 10,000 ft: CLB DIR> on the active CLB
-- page. AT 12,000 (above the MCP altitude) and AT 10,000 (at it: FMSPG
-- p.116) stay on its modification; AT OR BELOW 8,000 (between the
-- airplane and the MCP altitude) goes. The push makes a modification
-- (EXEC lit, MOD ... CLB, ERASE at 6L), ERASE drops it, EXEC makes it
-- the active route's
local EXEC_L = "laminar/B747/fms/exec_light_pilot"
local sid = nil
for i, l in ipairs(st.rte.legs) do
    if not sid and l.proc == "SID" and l.fix and not l.altterm then sid = i end
end
T.check(sid ~= nil, "a SID leg with a point: " .. tostring(sid))
local c1 = st.rte.legs[sid]
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 5000)
rt:set(MCPA, 10000)
local function clb_dir(a, akind)
    c1.alt, c1.alt2, c1.akind = a, nil, akind
    fms.ns.B747_fmc_route_changed()
    frames(11)
    key("func_key/des")
    key("ls_key/R6")
end
clb_dir(12000, "")
T.equal(rt:get(VN .. "phase"), 1, "in the air at 5,000 ft: the climb")
T.check(st.mod ~= nil and st.mod.legs[sid].alt == 12000, "AT 12,000 above the MCP altitude: kept")
key("ls_key/L6")
clb_dir(10000, "")
T.check(st.mod ~= nil and st.mod.legs[sid].alt == 10000, "AT 10,000 at the MCP altitude: kept (FMSPG p.116)")
key("ls_key/L6")
clb_dir(8000, "B")
T.check(st.mod ~= nil and rt:get(EXEC_L) == 1, "CLB DIR: a modification, EXEC lit")
T.check(line(1):find("MOD .* CLB"), "MOD ... CLB: " .. line(1))
T.check(line(13):find("^<ERASE"), "ERASE at 6L: " .. line(13))
T.check(st.mod.legs[sid].alt == nil, "AT OR BELOW 8,000 between the airplane and the MCP altitude: deleted on it")
T.equal(c1.alt, 8000, "the active route's 8,000 still")
key("ls_key/L6")
T.check(st.mod == nil and rt:get(EXEC_L) == 0 and line(1):find("ACT .* CLB"), "ERASE: no modification, ACT ... CLB: " .. line(1))
T.check(line(13):find("CLB DIR>$"), "CLB DIR> at 6R: " .. line(13))
key("ls_key/R6")
key("key/execute")
-- (EXEC makes the modification the active route: its legs, not c1)
T.check(st.mod == nil and st.rte.legs[sid].alt == nil, "again with EXEC: the active route's 8,000 deleted")
T.check(line(1):find("ACT .* CLB") and not line(13):find("CLB DIR>"), "ACT ... CLB, no CLB DIR> (no constraint left): " .. line(1) .. "|" .. line(13))
-- DES NOW: in the cruise at FL310 with the T/D ahead (here given: 80 NM)
-- DES NOW> on the DES page; the push: MOD ... DES, EXEC lit; EXEC: the
-- early descent (the descent phase, VNAV SPD with THR)
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(0.2)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 31000)
rt:set(MCPA, 10000)
frames(0.5)
T.equal(rt:get(VN .. "phase"), 2, "at FL310: the cruise")
fms.ns.B747_fms_vnav_td = function() return 80 end
key("func_key/des")
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(13):find("DES NOW>$") and not line(1):find("ACT"), "the DES page: DES NOW> at 6R, not active: " .. line(13) .. "|" .. line(1))
key("ls_key/R6")
T.check(st.mod ~= nil and rt:get(EXEC_L) == 1 and line(1):find("MOD .* DES"), "DES NOW: MOD ... DES, EXEC lit: " .. line(1))
T.equal(rt:get(VN .. "phase"), 2, "not yet executed: the cruise")
key("key/execute")
T.equal(rt:get(VN .. "phase"), 3, "EXEC: the descent phase (the early descent)")
T.check(rt:get(VN .. "mode") == 1 and rt:get(VN .. "at") == 4, "VNAV SPD with THR")
T.check(st.mod == nil and line(1):find("ACT .* DES"), "ACT ... DES: " .. line(1))
-- DES DIR: in the descent with constraints between the airplane and the
-- E/D: DES DIR> (FMSPG p.3.5-4); the push and EXEC: those between the
-- airplane and the MCP altitude deleted (FCOM p.1393), those below kept
local top2 = fms.ns.B747_fms_des_top()
T.check(top2 ~= nil, "a descent constraint: " .. tostring(top2))
T.check(line(13):find("DES DIR>$"), "DES DIR> at 6R in the descent: " .. line(13))
local function above(h)
    local n = 0
    for _, l in ipairs(st.rte.legs) do
        if l.alt and l.proc ~= "SID" and math.max(l.alt, l.alt2 or l.alt) > h then n = n + 1 end
    end
    return n
end
rt:set(MCPA, math.floor((top2 - 1000) / 100) * 100)
frames(0.2)
local below0 = above(0) - above(rt:get(MCPA))
T.check(above(rt:get(MCPA)) > 0, "constraints above the MCP altitude: " .. above(rt:get(MCPA)))
key("ls_key/R6")
T.check(st.mod ~= nil and line(1):find("MOD .* DES"), "DES DIR: MOD ... DES: " .. line(1))
key("key/execute")
T.check(above(rt:get(MCPA)) == 0, "EXEC: none above the MCP altitude left")
T.equal(above(0), below0, "those below it kept: " .. below0)
-- (step 9d3) speed intervention (FCOM p.643; ATA34_2 p.623): the AP's
-- laminar/B747/autopilot/spd_intervention with the MCP's speed (a Mach as
-- Mach x 100 on the dial): the FMC's target the MCP's; the active page's
-- title MCP SPD (ATA34_2 p.563) and PROGRESS's 5L (p.568); shut, the FMC's
-- own again
local SPDINT, DIAL, ISMACH = "laminar/B747/autopilot/spd_intervention", "laminar/B747/autopilot/ias_dial_value",
    "sim/cockpit2/autopilot/airspeed_is_mach"
local cas0 = rt:get(VN .. "cas")
rt:set(DIAL, 270)
rt:set(ISMACH, 0)
rt:set(SPDINT, 1)
frames(0.5)
T.near(rt:get(VN .. "cas"), 270, 1e-6, "speed intervention: the FMC's target the MCP's 270 kt")
T.check(line(1):find("ACT MCP SPD DES"), "the DES page: ACT MCP SPD DES (ATA34_2 p.563): " .. line(1))
key("func_key/prog")
frames(1.2)
T.check(small(10):find("^ MCP SPD"), "PROGRESS 5L: MCP SPD (ATA34_2 p.568): " .. small(10))
rt:set(DIAL, 80.5)
rt:set(ISMACH, 1)
frames(0.5)
T.check(rt:get(VN .. "mach_mode") == 1 and math.abs(rt:get(VN .. "mach") - 0.805) < 1e-6, "the MCP in Mach: M.805")
rt:set(SPDINT, 0)
rt:set(ISMACH, 0)
frames(1.2)
T.near(rt:get(VN .. "cas"), cas0, 0.5, "shut: the FMC's own target again")
T.check(small(10):find("^ ECON SPD"), "PROGRESS 5L: ECON SPD again: " .. small(10))
key("func_key/des")
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(1):find("ACT ECON DES"), "the DES page: ACT ECON DES again: " .. line(1))
fms.ns.B747_fms_vnav_td = realTd
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
frames(0.2)
T.done()
