-- Run from the repository root with LuaJIT: luajit tests/fms/proc_arinc_test.lua
-- The CIFP's fields as ARINC 424-17 defines them (2026-11-20, GAP_ANALYSIS.md
-- §7 N19-NAV-01..08; notes/ATA-34-61-FMC.md §175), on a synthetic airport
-- ZZCC whose runways and procedures are charted in degrees true (as BGTL,
-- the Canadian north): the waypoint description's fly-over "B" (p.79), the
-- courses "085T" true (p.85) through the path and LNAV models and the LEGS
-- page's T, the recommended navaid's kind (p.71, p.82), a runway "RW08T"'s
-- length (p.94-95), the approach type letters F, W, Y (p.73), the
-- procedure turn's one minute outbound leg (p.200).
local T = dofile("tests/lib/check.lua")("proc_arinc")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.proc_model.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")
local PM = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")

-- the files in memory
local HEAD = "I\n1200 Version - data cycle 2610, build 20260927, metadata NavXP1200. Synthetic data for the tests.\n\n"
local FILES = {
    ["earth_aptmeta.dat"] = HEAD .. "ZZCC ZZ  60.000000000   10.000000000   100 C 12000 I 14000 FL140\n99\n",
    -- ZC: an NDB 3 nm north of ZZCC and a VOR 18 nm north with the same
    -- identifier; ICC: a localizer (course 080 true, 100 magnetic) and a
    -- locator nearer the airport with the same identifier
    ["earth_nav.dat"] = HEAD
        .. " 2  60.050000000   10.000000000        0      350    50      0.000   ZC ENRT ZZ ZULU CHARLIE NDB\n"
        .. " 3  60.300000000   10.000000000      100    11500   130    -20.000   ZC ENRT ZZ ZULU CHARLIE VOR/DME\n"
        .. " 4  60.000000000    9.950000000      100    10950    18  36080.000  ICC ZZCC ZZ 08T ILS-cat-I\n"
        .. " 2  60.010000000    9.990000000        0      330    25      0.000  ICC ZZCC ZZ ICC LOCATOR NDB\n99\n",
    ["earth_fix.dat"] = HEAD
        .. " 60.000000000   10.200000000  CWPT1 ENRT ZZ 2105430 CWPT1\n"
        .. " 60.000000000   10.400000000  CWPT2 ENRT ZZ 2105430 CWPT2\n"
        .. " 59.900000000   10.300000000  CWPT3 ENRT ZZ 2105430 CWPT3\n99\n",
    ["earth_awy.dat"] = HEAD .. "99\n",
    ["earth_hold.dat"] = HEAD .. "99\n",
    ["CIFP/ZZCC.dat"] = table.concat({
        "RWY:RW08T,     ,      ,00100, ,ICC ,1,   ;N60000000,E009560000,0000;",
        "RWY:RW26T,     ,      ,00100, ,    , ,   ;N60000000,E010040000,0500;",
        -- a heading 085 true to 660 ft; a course 095 true to CWPT1 (a
        -- fly-over ending the route type, "B"), the VOR ZC its navaid (D,
        -- blank); CWPT2 by the NDB ZC (D B); CWPT3 a fly-over ("Y")
        "SID:010,1,ZC1D,RW08T, , , , ,    , ,   ,VA, , , , , ,      ,    ,    ,085T,    ,+,00660,     ,06500, ,   ,    ,   , , , , , , , , ;",
        "SID:020,1,ZC1D,RW08T,CWPT1,ZZ,E,A,EB  , ,   ,CF, ,ZC,ZZ,D, ,      ,2645,0310,095T,0050, ,     ,     ,     , ,   ,    ,   , , , , , , , , ;",
        "SID:030,1,ZC1D,RW08T,CWPT2,ZZ,E,A,EE  , ,   ,TF, ,ZC,ZZ,D,B,      ,    ,    ,    ,    , ,     ,     ,     , ,   ,    ,   , , , , , , , , ;",
        "SID:040,1,ZC1D,RW08T,CWPT3,ZZ,E,A,EY  ,R,   ,DF, , , , , ,      ,    ,    ,    ,    , ,     ,     ,     , ,   ,    ,   , , , , , , , , ;",
        -- the ILS to 08T: the localizer ICC (P I), its final course 080 true
        "APPCH:010,I,I08T, ,CWPT3,ZZ,E,A,E  F, ,   ,IF, ,ICC,ZZ,P,I,      ,    ,    ,    ,    , ,02000,     ,14000, ,   ,    ,   , , , , , ,0, ,S;",
        "APPCH:020,I,I08T, ,RW08T,ZZ,P,G,G  M, ,   ,CF, ,ICC,ZZ,P,I,      ,    ,    ,080T,0050, ,00150,     ,     , ,   ,-300,   , , , , , ,0, ,S;",
    }, "\n") .. "\n",
}
local function memfile(text)
    local pos = 1
    return {
        read = function(_, n)
            if pos > #text then return nil end
            local s = text:sub(pos, pos + n - 1)
            pos = pos + n
            return s
        end,
        lines = function() return text:gmatch("([^\n]*)\n") end,
        close = function() end,
    }
end
local db = N.new(function(name) return FILES[name] and memfile(FILES[name]) or nil end)
while not N.load(db) do end
T.check(db.apt.ZZCC ~= nil, "the synthetic ZZCC loaded")

-- the SID: the legs' fields
local legs = P.sid_legs(N, db, "ZZCC", "ZC1D", "RW08T")
T.equal(#legs, 4, "ZC1D from RW08T: four legs")
local va, cf, tf, df = legs[1], legs[2], legs[3], legs[4]
-- (N19-NAV-02) "085T": 085 true; before nil
T.check(va.pt == "VA" and va.crs == 85 and va.crs_true == true, "the heading 085T: 085, true")
T.check(cf.crs == 95 and cf.crs_true == true and cf.theta == 264.5 and not cf.theta_true,
    "the course 095T true, the radial 2645 magnetic (264.5)")
T.check(tf.crs == nil and not tf.crs_true, "a TF: no course")
-- (N19-NAV-01) the fly-overs: "B" (ARINC 424 p.79 note 6) and "Y"; "E" a fly-by
T.check(cf.flyover == true, "CWPT1 \"EB\": a fly-over (before: flown by)")
T.check(tf.flyover == false, "CWPT2 \"EE\": a fly-by")
T.check(df.flyover == true, "CWPT3 \"EY\": a fly-over")
-- (N19-NAV-03) the recommended navaid of its kind
T.check(cf.navaid and cf.navaid.kind == "VOR" and cf.navaid.lat == 60.3,
    "CWPT1's navaid ZC (D, blank): the VOR 18 nm away, not the NDB nearer (before)")
T.check(tf.navaid and tf.navaid.kind == "NDB" and tf.navaid.lat == 60.05, "CWPT2's navaid ZC (D B): the NDB")

-- the approach: the localizer as its navaid (P I), the final course true
local alegs, rwy = P.approach_legs(N, db, "ZZCC", "I08T")
T.equal(rwy, "RW08T", "ILS08T lands on RW08T")
T.check(alegs[2] and alegs[2].navaid and alegs[2].navaid.kind == "LOC",
    "its navaid ICC (P I): the localizer, not the locator nearer (before)")
T.check(alegs[2].crs == 80 and alegs[2].crs_true, "the final course 080T")
T.equal(P.approach_name("I08T"), "ILS08T", "ILS08T")
-- (N19-NAV-08) the FMS and MLS approaches' letters (ARINC 424 p.73)
T.equal(P.approach_name("F22"), "FMS22", "F: an FMS approach, FMS22 (before F22)")
T.equal(P.approach_name("W04L"), "MLS04L", "W: an MLS (type A), MLS04L")
T.equal(P.approach_name("Y31"), "MLS31", "Y: an MLS (types B and C), MLS31")
-- (N19-NAV-02) a true runway's length: RW08T to RW26T, the latter's 500 ft
-- displaced; before nil
local c = N.cifp(db, "ZZCC")
local len = N.runway_length(c, "RW08T")
local want = N.distance(60, 9 + 56 / 60, 60, 10 + 4 / 60) * 6076.12 + 500
T.near(len, want, 1, "RW08T's length: its thresholds' distance and 500 ft displaced")
T.near(N.runway_length(c, "RW26T"), want, 1, "and RW26T's")
local found = N.find(db, "RW08T", 60, 10, {"ZZCC"})
local isrwy = false
for _, r in ipairs(found) do if r.kind == "RWY" then isrwy = true end end
T.check(isrwy, "RW08T found as the airport's runway")
-- the RUNWAY entry "08T"
local st = R.new(N, db)
st.P = P
R.set_origin(st, "ZZCC")
T.equal(R.set_runway(st, "08T"), nil, "RUNWAY 08T accepted")
T.equal(R.shown(st).runway and R.shown(st).runway.ident, "RW08T", "the origin's runway RW08T")

-- the path: a true course as it is, a magnetic one by its navaid's variation
local VAR = -20
local env = {var = function() return VAR end}
local prev = {lat = 60.0, lon = 10.0}
local e = PM.element(cf, 2, prev, nil, env, 0)
T.near(e.crs, 95, 1e-9, "the CF's course 095T flown 095 true")
local mag = {}
for k, v in pairs(cf) do mag[k] = v end
mag.crs_true = nil
T.near(PM.element(mag, 2, prev, nil, env, 0).crs, 75, 1e-9, "as 095 magnetic: 075 true (the VOR's 20 W, before)")
local ev = PM.element(va, 1, {lat = 60.0, lon = 9 + 56 / 60}, cf, env, 100)
T.check(ev.kind == "heading" and math.abs(ev.hdg - 85) < 1e-9 and ev.true_hdg, "the heading 085T: 085 true")
-- an AF's boundary radial and a hold's inbound course true
local hold = PM.element({pt = "HM", fix = {lat = 60, lon = 10.2}, crs = 263, crs_true = true, turn = "R"}, 1,
    prev, nil, env, 0)
T.near(hold.inbd, 263, 1e-9, "a hold's inbound 263T: 263 true")
-- LNAV holds the true heading (with the airplane's 20 W)
local SIM = dofile("tests/lib/lnav_sim.lua")(N, R, PM, L, VAR)
local RWY = {lat = 60.0, lon = 9 + 56 / 60}
local sst = SIM.route({{pt = "VA", crs = 85, crs_true = true, alt = 3000, altterm = true, name = "(3000)"},
    {pt = "DF", via = "ZC1D", fix = {ident = "CWPT3", lat = 59.9, lon = 10.3}}}, RWY)
local s = L.new(PM)
local a = SIM.plane({lat = RWY.lat, lon = RWY.lon, hdg = 85, tas = 160, alt = 100, vs = 1000})
local hdgerr = 0
SIM.fly(sst, s, a, 60, {each = function(t, s2, air, path)
    if path[1].kind == "heading" and t > 5 then hdgerr = math.max(hdgerr, math.abs(PM.wrap180(air.hdg - 85))) end
end})
T.check(hdgerr < 0.5, "LNAV holds 085 true (not 065, 085 magnetic): " .. string.format("%.2f", hdgerr))
-- (the LEGS page's "337`T HDG": tests/fms/deparr_pages_test.lua)

-- (N19-NAV-06) the procedure turn: one minute outbound (ARINC 424 p.200),
-- shorter where the "remain within" distance needs it
local Fp = {lat = 35.5, lon = 140.0}
local pe15 = PM.element({pt = "PI", fix = Fp, crs = 45, crs_true = true, turn = "R", dist = 15}, 1, Fp, nil, env, 0)
local g15 = PM.pturn(pe15, 220)
T.near(g15.dout, 220 / 60, 1e-6, "15 nm at 220 kt: the outbound leg one minute, 3.67 nm (before about 8)")
local _, far = PM.course(Fp, g15.c)
T.check(far + g15.r < 14, "its turn well inside 15 nm: " .. string.format("%.2f", far + g15.r))
local pe10 = PM.element({pt = "PI", fix = Fp, crs = 45, crs_true = true, turn = "R", dist = 10}, 1, Fp, nil, env, 0)
local g10 = PM.pturn(pe10, 220)
T.check(g10.dout < 220 / 60, "10 nm: shorter than a minute, to stay inside: " .. string.format("%.2f", g10.dout))
_, far = PM.course(Fp, g10.c)
T.near(far + g10.r, 9, 0.02, "its farthest point 1 nm inside the 10 nm")
T.near(pe15.pc, 45, 1e-9, "the 45 degree leg 045T as it is")
T.done()
