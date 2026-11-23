-- Run from the repository root with LuaJIT: luajit tests/displays/pfd_fd_bar_panel_test.lua
-- (2026-11-24, the stage 4 review's PNL-1) The PFD's flight director pitch
-- bar in the custom acf's panel: with the pitch on the command the bar sits
-- on the airplane symbol's wings, at every pitch; a degree of command off
-- the pitch moves it a degree of the pitch scale. FCOM p.980 (10.10.18): the
-- bars indicate the flight director's pitch and roll steering commands
-- (laminar/B747/autopilot/flight_director_pitch_deg is a pitch attitude
-- command: B747.19.xt.afds_control.lua). Before, the group on the pitch had
-- the key frames 10 -> -68.5 / 1 -> 0 / -10 -> 68.5 (descending, the middle
-- at 1 degree): the bar 4 px under the wings at 7.5 degrees, a 12.5 px jump
-- across 10 degrees, 1.2 to 1.6 degrees over them after takeoff.
local T = dofile("tests/lib/check.lua")("pfd_fd_bar_panel")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")

-- the images (cockpit_3d/generic/CRT Displays/PFD): FDbarVertical-1.png is
-- 171 x 19 with the bar on rows 13-17, 6 px under the image's centre;
-- HrznArplnSymbol-1.png is 255 x 37 with the wings on rows 1-11, 12 px over it
local BAR_BELOW_CENTRE = 6
local WINGS_ABOVE_CENTRE = 12
local PITCH = {pilot = "sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot",
    copilot = "sim/cockpit2/gauges/indicators/pitch_AHARS_deg_copilot"}
local CMD = "laminar/B747/autopilot/flight_director_pitch_deg"

-- the pitch scale: the horizon's DEFLECT_PIX over 90 degrees (613: 6.811 px a degree)
local horizon = P.find(panel, {kind = "gen_needle", name = "Pitch Scale"})
T.check(horizon ~= nil and horizon.DEFLECT_PIX ~= nil, "the pitch scale's needle")
local px_per_deg = tonumber(horizon.DEFLECT_PIX) / 90
T.near(px_per_deg, 6.8111, 0.001, "the pitch scale, px a degree")

local groups = {}
for _, g in ipairs(P.find_all(panel, {kind = "GROUP"})) do
    if g.name == "Flt Dir Offset" or g.name == "Flt Dir Offset 2" then groups[#groups + 1] = g end
end
T.equal(#groups, 4, "four F/D offset groups (each side's two PFD formats)")

for _, g in ipairs(groups) do
    local side = g.dref == PITCH.pilot and "pilot" or (g.dref == PITCH.copilot and "copilot" or nil)
    T.check(side ~= nil, "line " .. g.line .. ": the group moves on a side's pitch (" .. tostring(g.dref) .. ")")
    T.check(g.mode == "TRANSLATE" and P.ascending(g), "line " .. g.line .. ": a TRANSLATE group with ascending key frames")
    local bar = P.find(panel, {kind = "gen_pointer", dref = CMD, under = g})
    T.check(bar ~= nil and bar.name:match("^FD Bar %- Pitch") ~= nil, "line " .. g.line .. ": its pitch bar reads the F/D pitch command")
    -- the airplane symbol of the same PFD: the last one before the group
    local symbol
    for _, e in ipairs(panel) do
        if e.line > g.line then break end
        if e.kind == "gen_rotary" and e.name:match("^Airplane Symbol") then symbol = e end
    end
    T.check(symbol ~= nil and bar ~= nil and math.abs(symbol.x - bar.x) < 0.01, "line " .. g.line .. ": the airplane symbol above the bar")
    if bar and symbol and side then
        T.check(P.ascending(bar), "line " .. bar.line .. ": the bar's key frames ascend")
        local wings = symbol.y + WINGS_ABOVE_CENTRE
        local function drawn(pitch, cmd)
            local values = {[g.dref] = pitch}
            return bar.y + P.at(bar, cmd) + P.offset(bar, values) - BAR_BELOW_CENTRE
        end
        for _, pitch in ipairs({-15, -5, 0, 1, 2.5, 5, 7.5, 9.99, 10.01, 12.5, 15, 17.5, 25}) do
            T.near(drawn(pitch, pitch) - wings, 0, 0.5,
                string.format("line %d: pitch %.2f on the command: the bar on the wings (px off)", g.line, pitch))
            T.near(drawn(pitch, pitch + 1) - drawn(pitch, pitch), px_per_deg, 0.05,
                string.format("line %d: pitch %.2f, a degree of command over it: a degree of the pitch scale up", g.line, pitch))
        end
        -- no jump anywhere on the way up
        local last = drawn(-20, -20)
        local worst = 0
        for p10 = -199, 300 do
            local p = p10 / 10
            local y = drawn(p, p)
            worst = math.max(worst, math.abs(y - last))
            last = y
        end
        T.check(worst < 0.05, string.format("line %d: the bar does not move as the pitch climbs on the command (largest step %.2f px)", g.line, worst))
    end
end

T.done()
