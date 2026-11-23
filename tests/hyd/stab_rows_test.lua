-- Run from the repository root with LuaJIT: luajit tests/hyd/stab_rows_test.lua
-- The stabilizer's two controlObject rows (B747.19.xt.hydraulicsmodel.lua)
-- run as XTLua runs them (tests/lib/xtlua.lua's apply_control_objects, after
-- XTLua's updateCommands): X-Plane's stabilizer is the trim's angle, 3
-- degrees leading edge up at 0 units to 12 down at 15 (ATA22 p.132), plus
-- the aerodynamic corrections' degrees (laminar/B747/flt_ctrls/
-- stab_corr_deg: B747.45.aero_corr_model.lua), the whole of both.
-- (2026-11-24, the 2026-11-23 review's FCTL-6) Before, the second row's
-- range of +-10 held the sum to -10 degrees: over 8 units of trim a leading
-- edge down correction was cut (9 units and -5 degrees: -10 for -11; from
-- 13 units all of it).
local T = dofile("tests/lib/check.lua")("stab_rows")
local xtlua = dofile("tests/lib/xtlua.lua")
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulicsmodel.lua")
rt:callout("flight_start")
local TRIM = "sim/flightmodel2/controls/elevator_trim"
local CORR = "laminar/B747/flt_ctrls/stab_corr_deg"
local STAB = "sim/flightmodel2/controls/stabilizer_deflection_degrees"
local n = 0
for _, s in ipairs(rt.control_rows) do if s:find("stabilizer_deflection", 1, true) then n = n + 1 end end
T.equal(n, 2, "two rows to X-Plane's stabilizer: the trim and the corrections")
local function stab(units, corr)
    rt:set(TRIM, units / 7.5 - 1)
    rt:set(CORR, corr)
    rt:apply_control_objects()
    return rt:get(STAB)
end
-- the trim alone: ATA22 p.132
T.near(stab(0, 0), 3, 1e-9, "0 units: 3 degrees leading edge up")
T.near(stab(3, 0), 0, 1e-9, "3 units: 0")
T.near(stab(15, 0), -12, 1e-9, "15 units: 12 degrees leading edge down")
-- the corrections added whole, both ways, over the trim's range
local cases = {
    {5.1, 6.2}, {7.13, 4.0}, {4.0, -0.3},          -- a takeoff, an approach, the cruise
    {0.25, 7.2},                                   -- flaps 20 at the nose-down end, no alpha
    {8, -5}, {8, -6}, {9, -5}, {9, -6}, {10, -5},  -- high alpha, flaps up, from 8 units (cut before)
    {11.6, -3}, {11.6, -5}, {13.5, -5}, {14.75, -5}, {14.75, -10},
    {0, 11.2}, {0, 16.2},                          -- every part leading edge up at 0 units
    {15, -10},                                     -- and down at 15
}
for _, c in ipairs(cases) do
    local want = 3 - c[1] + c[2]
    T.near(stab(c[1], c[2]), want, 1e-9, string.format("%.2f units and %+.2f degrees of correction: %.2f degrees", c[1], c[2], want))
end
-- the sum's ends: nothing the model can ask for is cut (the flaps' 6.2 and
-- the downwash's and the thrust's 5 each: 16.2 up, 10 down)
T.near(stab(0, 16.2), 19.2, 1e-9, "the most leading edge up: 19.2 degrees, whole")
T.near(stab(15, -10), -22, 1e-9, "the most leading edge down: -22 degrees, whole")
T.done()
