-- Run from the repository root with LuaJIT: luajit tests/displays/pfd_slip_panel_test.lua
-- (2026-11-24, the stage 4 review's PNL-6) The PFD's slip/skid indication
-- in the custom acf's panel (gen_pointer Symbol, image HrznSlipSkid, 26 px
-- wide, under the bank pointer). FCOM p.975 (10.10.13) and p.977
-- (10.10.15): it displaces beneath the bank pointer to show slip or skid,
-- and (p.975) is "fully displaced" at an end. It comes from the IRS (FCOM
-- p.1044: the source for the slip/skid) - an inertial lateral acceleration,
-- the ball, not the air's sideslip: X-Plane's ball,
-- sim/cockpit2/gauges/indicators/slip_deg (slip_deg_copilot for the first
-- officer), with the ball's side (positive: the ball to the left, as
-- Laminar's PA-18 turn and slip ball and 737 PFD draw it), 2 px a degree as
-- before, stopping at 13 px (half its width; the end's size is not in the
-- sources: estimate). Before, X-Plane's aerodynamic sideslip
-- (sideslip_degrees) without an end: 43 px away from the bank pointer on a
-- 20 kt crosswind rollout (s116), where the ball stays near the middle.
local T = dofile("tests/lib/check.lua")("pfd_slip_panel")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")

local ptrs = P.find_all(panel, {kind = "gen_pointer", image = "CRT Displays/PFD/Artificial Horizon/HrznSlipSkid"})
T.equal(#ptrs, 4, "four slip/skid indications (each side's two PFD formats)")
for _, e in ipairs(ptrs) do
    local fo = e.x > 660                     -- the first officer's PFDs (x 994.5)
    local want = fo and "sim/cockpit2/gauges/indicators/slip_deg_copilot" or "sim/cockpit2/gauges/indicators/slip_deg"
    T.equal(e.dref, want, "line " .. e.line .. ": the ball of its side")
    T.check(P.ascending(e), "line " .. e.line .. ": ascending key frames")
    T.near(P.at(e, 0), 0, 1e-9, "line " .. e.line .. ": centred with the ball")
    T.near(P.at(e, 1), -2, 1e-6, "line " .. e.line .. ": a degree of the ball to the left, 2 px to the left")
    T.near(P.at(e, -3), 6, 1e-6, "line " .. e.line .. ": 3 degrees to the right, 6 px to the right")
    for _, v in ipairs({6.5, 10, 30, 90}) do
        T.near(P.at(e, v), -13, 1e-6, string.format("line %d: ball %g: stops 13 px to the left", e.line, v))
        T.near(P.at(e, -v), 13, 1e-6, string.format("line %d: ball %g: stops 13 px to the right", e.line, -v))
    end
end

T.done()
