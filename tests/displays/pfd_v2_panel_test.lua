-- Run from the repository root with LuaJIT: luajit tests/displays/pfd_v2_panel_test.lua
-- (2026-11-24, the stage 4 review's DSP-4) The 570's (GE) V2 on the PFD's
-- speed tape in the custom acf's panel: each PFD's V-speed group holds a V2
-- bug (image Vspeeds/V2, the stock "-V2" in the V1 and VR bugs' style) on
-- laminar/B747/airspeed/V2, moving as V1 does, shown with
-- laminar/B747/airspeed/v2_show (B747.60.speedtape_model.lua: the 570 only,
-- a V2 selected, until the flap retraction begins). FCOM p.970-972
-- (10.10.8-10): the 570 shows V1, VR and V2 for the takeoff; the 109 and 405
-- V1 and VR. Before, no V2 on the panel at all.
local T = dofile("tests/lib/check.lua")("pfd_v2_panel")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")

local v1s = P.find_all(panel, {kind = "gen_pointer", dref = "laminar/B747/airspeed/V1"})
local v2s = P.find_all(panel, {kind = "gen_pointer", dref = "laminar/B747/airspeed/V2"})
T.equal(#v1s, 4, "four V1 bugs (each side's two PFD formats)")
T.equal(#v2s, 4, "four V2 bugs")
for _, v1 in ipairs(v1s) do
    local v2
    for _, e in ipairs(v2s) do if e.parent == v1.parent then v2 = e end end
    T.check(v2 ~= nil, "line " .. v1.line .. ": a V2 bug in the same group as V1")
    if v2 then
        T.equal(v2.image, "CRT Displays/PFD/Vspeeds/V2", "line " .. v2.line .. ": the V2 image")
        T.check(v2.x == v1.x and v2.y == v1.y, "line " .. v2.line .. ": V1's place")
        for _, v in ipairs({0, 30, 60, 100, 160, 180}) do
            T.near(P.at(v2, v), P.at(v1, v), 1e-9, string.format("line %d: %g kt where V1's would be", v2.line, v))
        end
        T.equal(#v2.show, 1, "line " .. v2.line .. ": one condition")
        local s = v2.show[1]
        T.check(s and s.op == "EQUAL" and s.v == 1 and s.dref == "laminar/B747/airspeed/v2_show",
            "line " .. v2.line .. ": shown with airspeed/v2_show")
    end
end

T.done()
