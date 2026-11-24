-- Run from the repository root with LuaJIT: luajit tests/fltctrls/panel_stat_rudder_test.lua
-- (2026-11-24, the stage 4 review's PNL-7) The STAT page's rudder pointers
-- (upper and lower: laminar/B747/flt_ctrls/rudder_upr_pos, rudder_lwr_pos,
-- degrees) in the custom acf's panel: full pointer deflection is full
-- surface deflection (FCOM p.939 (9.10.13)), 32 degrees left or right at
-- low speed (ATA27 p.658; p.682: 31.5 +/- 1.5 in the ground test), the
-- scale's ends 82 px out; past it (the yaw damper's 4 degrees on full
-- pedal: B747.19.xt.hydraulicsmodel.lua) they stay at the ends. Before,
-- 25 degrees at the ends and no stop: 105 px at 32 degrees, over the "RUD"
-- label, 118 px with the yaw damper.
local T = dofile("tests/lib/check.lua")("panel_stat_rudder")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")

for _, d in ipairs({"laminar/B747/flt_ctrls/rudder_upr_pos", "laminar/B747/flt_ctrls/rudder_lwr_pos"}) do
    local all = P.find_all(panel, {kind = "gen_pointer", dref = d})
    T.equal(#all, 1, d .. ": one pointer")
    local e = all[1]
    if e then
        T.check(P.ascending(e), d .. ": ascending key frames")
        T.near(P.at(e, 0), 0, 1e-9, d .. ": 0 in the middle")
        T.near(P.at(e, 16), 41, 1e-6, d .. ": half the travel, half the scale")
        T.near(P.at(e, 32), 82, 1e-6, d .. ": 32 degrees at the scale's end")
        T.near(P.at(e, -32), -82, 1e-6, d .. ": -32 degrees at the other end")
        for _, v in ipairs({33, 36, 60}) do
            T.near(P.at(e, v), 82, 1e-6, string.format("%s: %g degrees stays at the end", d, v))
            T.near(P.at(e, -v), -82, 1e-6, string.format("%s: %g degrees stays at the end", d, -v))
        end
    end
end

T.done()
