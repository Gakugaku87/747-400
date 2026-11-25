-- Run from the repository root with LuaJIT: luajit tests/eec/rr_model_test.lua
-- The RB211-524G/H's thrust and EPR by difference from the PW4056's
-- (plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.rr_model.lua, 2026-11-25,
-- GAP_ANALYSIS.md §8, notes/ATA-70-80.md §40): the ratings' ratios (TCDS),
-- the bypass ratios' fall (ICAO_EEDB), the EPR shown against the RB211's
-- takeoff EPR table and PMDG's long range cruise table (PMDG_CRZ p.34-35:
-- PMDG-derived, no real-aircraft source) at the thrust the FMC's drag polar
-- asks, and PMDG's maximum cruise EPR from the FCOM P&W's.
local T = dofile("tests/lib/check.lua")("rr_model")
local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
local R = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.rr_model.lua")
local E = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua")
local DB = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local function ram(m) return (1 + 0.2 * m * m) ^ 3.5 end

-- the variants
T.equal(R.variant("RB211-524G"), "G", "RB211-524G: G")
T.equal(R.variant("RB211-524H2"), "H", "RB211-524H2: H")
T.equal(R.variant("RB211-524H8T"), "H", "RB211-524H8T: H")
T.equal(R.variant(nil), "G", "no engine string: G")

-- the multiplier: the takeoff ratio standing, the continuous's from M .45,
-- the bypass ratio's a little more thrust at the takeoff's speeds
T.near(R.multiplier("G", 0), 56870 / 56750, 1e-9, "-524G standing: 56,870 / 56,750 lbf (TCDS_RB211 p.10, TCDS_PW4000 p.1)")
T.near(R.multiplier("H", 0), 59450 / 56750, 1e-9, "-524H standing: 59,450 / 56,750 lbf")
T.near(R.multiplier("G", 0.6), 47230 / 47970, 1e-9, "-524G from M .45: the maximum continuous 47,230 / 47,970 lbf")
T.near(R.multiplier("H", 0.85), 47230 / 47970, 1e-9, "-524H in the cruise: the same")
do
    local g = R.multiplier("G", 0.25) / (56870 / 56750) - 1
    local h = R.multiplier("H", 0.25) / (59450 / 56750) - 1
    T.check(g > 0.005 and g < 0.01 and h > g, string.format("M .25: the lower bypass ratio's +%.2f %% (G 4.3) and +%.2f %% (H 4.2) over the rating's ratio", 100 * g, 100 * h))
    -- the fall 1 - F/F0 at the P&W's takeoff EPR times sqrt((1 + B) / 5.7)
    local l = P.thrust(1.51, 1, 0.2) / P.thrust(1.51, 1, 0)
    local want = 1 - math.sqrt(5.3 / 5.7) * (1 - l)
    local got = R.thrust(1.51, 1, 0.2, "G") / R.thrust(1.51, 1, 0, "G")
    T.near(got, want, 1e-6, string.format("-524G at M .2: the fall %.4f, the P&W's %.4f times sqrt(5.3 / 5.7)", 1 - got, 1 - l))
end
local jump = 0
for _, v in ipairs({"G", "H"}) do
    for m = 0, 0.9, 0.001 do jump = math.max(jump, math.abs(R.multiplier(v, m + 0.001) - R.multiplier(v, m))) end
end
T.check(jump < 0.002, string.format("the multiplier without a jump from M 0 to .9 (at most %.4f a 0.001 of Mach)", jump))

-- the takeoff's thrust standing at the P&W's takeoff EPR, sea level
T.near(R.thrust(1.51, 1, 0, "G"), P.thrust(1.51, 1, 0) * 56870 / 56750, 1e-9, "-524G: the P&W's thrust at 1.51 (252.4 kN) times the ratio")
T.near(R.thrust(1.51, 1, 0, "H"), 264.4, 0.2, "-524H: 264.4 kN (ICAO_EEDB 1RR011's F00)")
T.near(R.display(1.51, 0), 1.713, 0.002, "the P&W's sea level takeoff EPR 1.51 shown as the RB211's 1.71 (TOGA_epr_RR)")

-- standing: the RB211's takeoff EPR table against the FPPM's at 10 C,
-- -2,000 to 6,000 ft (both flat rated)
do
    local f = io.open("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC.tbls.lua", "rb")
    local src = f:read("*a"):gsub("\r", ""); f:close()
    local env = {}
    setfenv(assert(loadstring(src:match("(TOGA_epr_RR = {.-\n}\n)"))), env)()
    local tpw, worst, n = E.TABLE.PW.to, 0, 0
    local row
    for j, t in ipairs(tpw.tat) do if t == 10 then row = tpw.v[j] end end
    for i, alt in ipairs(tpw.alt) do
        local rr = env.TOGA_epr_RR[10][alt]
        if alt <= 6000 and rr and row[i] then
            local e = R.display(row[i], 0) - rr
            n = n + 1
            if math.abs(e) > math.abs(worst) then worst = e end
        end
    end
    T.check(n == 9 and math.abs(worst) < 0.007, string.format("standing, 10 C: %d points of the takeoff tables within 0.007 (worst %+.4f)", n, worst))
end

-- the takeoff roll and the go-around: the EEC holds the P&W's scale's EPR
-- and the RB211's shown stays (to M .30; the first version rose 1.71 ->
-- 1.75 by 80 kt, s427 2026-11-25)
do
    local worst = 0
    for m = 0, 0.30001, 0.02 do
        for _, e in ipairs({1.02, 1.3, 1.51, 1.6}) do worst = math.max(worst, math.abs(R.display(e, m) - R.display(e, 0))) end
    end
    T.check(worst < 1e-9, string.format("to M .30 the P&W's scale's EPR shown as standing (1.51 as %.3f): the roll, the go-around", R.display(1.51, 0)))
end

-- the cruise: PMDG's long range cruise RR-RB211 (FL300-370) at the thrust
-- the FMC's drag polar asks (the P&W's), the EEC's scale the thrust over
-- the multiplier
local LRC = {   -- FL (1000 ft) -> weight (1000 kg) -> {EPR, Mach} (PMDG_CRZ p.34-35)
  [37] = {[330] = {1.70, .856}, [300] = {1.62, .855}, [250] = {1.51, .842}, [200] = {1.42, .809}},
  [35] = {[360] = {1.69, .856}, [330] = {1.62, .855}, [300] = {1.55, .850}, [250] = {1.47, .830}, [200] = {1.39, .790}},
  [33] = {[390] = {1.68, .856}, [350] = {1.59, .853}, [300] = {1.50, .841}, [250] = {1.43, .815}, [200] = {1.36, .769}},
  [31] = {[400] = {1.62, .855}, [350] = {1.53, .847}, [300] = {1.46, .830}, [250] = {1.40, .798}, [200] = {1.33, .742}},
  [30] = {[400] = {1.59, .853}, [350] = {1.51, .843}, [300] = {1.44, .822}, [250] = {1.38, .788}, [200] = {1.32, .727}},
}
do
    local PWT = DB.tables(0)
    local e2, n, worst, wat = 0, 0, 0, ""
    for fl, row in pairs(LRC) do
        for w, c in pairs(row) do
            local ft = fl * 1000
            local f = DB.drag(PWT, w * 1000, ft, c[2]) / 4 / 1000
            local got = R.epr(f, DB.atmos(ft) / 101325, c[2], "G")
            local e = got - c[1]
            e2, n = e2 + e * e, n + 1
            if math.abs(e) > math.abs(worst) then worst, wat = e, string.format("FL%d %d t", fl, w) end
        end
    end
    T.check(math.sqrt(e2 / n) < 0.008 and math.abs(worst) < 0.016, string.format("PMDG's long range cruise: %d points rms %.4f, worst %+.4f (%s)", n, math.sqrt(e2 / n), worst, wat))
end
-- PMDG's maximum cruise EPR (PMDG_CRZ p.34) against the FCOM P&W's mapped
do
    local PM = {[30] = {1.67, 0}, [33] = {1.69, -6}, [35] = {1.70, -11}, [37] = {1.71, -13}}
    local worst = 0
    for fl, c in pairs(PM) do
        local pw = E.lookup_crz(E.TABLE.PW.crz, c[2], fl * 1000)
        local e = R.display(pw, 0.85) - c[1]
        if math.abs(e) > math.abs(worst) then worst = e end
    end
    T.check(math.abs(worst) < 0.02, string.format("PMDG's maximum cruise EPR from the FCOM P&W's maximum cruise (not fitted): within 0.02 (worst %+.4f)", worst))
end

-- the way back, the shape
local back, falls = 0, 0
for m = 0, 0.9, 0.05 do
    for e = 0.6, 1.9, 0.01 do
        back = math.max(back, math.abs(R.pw_of_display(R.display(e, m), m) - e))
        if R.display(e + 0.01, m) <= R.display(e, m) then falls = falls + 1 end
    end
end
T.check(back < 1e-9, string.format("pw_of_display undoes display (at most %.1e)", back))
T.equal(falls, 0, "the EPR shown rises with the P&W's scale's at M 0 to .9")
T.near(R.display(1 / ram(0.8), 0.8), 1 / ram(0.8), 1e-12, "no net thrust shown as the P&W's (NPR 1)")
T.near(R.display(0.6, 0.8), 0.6, 1e-12, "below no net thrust the P&W's")
local mj = 0
for m = 0, 0.9, 0.001 do
    for _, e in ipairs({1.0, 1.2, 1.5}) do mj = math.max(mj, math.abs(R.display(e, m + 0.001) - R.display(e, m))) end
end
T.check(mj < 0.005, string.format("the EPR shown without a jump in the Mach (at most %.4f a 0.001)", mj))
T.done()
