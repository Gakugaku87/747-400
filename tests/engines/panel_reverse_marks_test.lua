-- Run from the repository root with LuaJIT: luajit tests/engines/panel_reverse_marks_test.lua
-- (2026-11-24, the stage 4 review's PNL-4 = DSP-1) The upper EICAS's
-- thrust marks with a reverser out, in the custom acf's panel. FCOM p.832
-- (7.10.4): with reverse thrust the 570 (GE) shows neither the command N1
-- nor the reference N1; the 109 (P&W, RR) does not show the reference EPR -
-- its command EPR stays; p.833 (7.10.5)'s figure: engine 1 in reverse keeps
-- its command mark at its bar's end, engines 2-4 keep their reference
-- digits and marks. So the marks go engine by engine, with that engine's
-- reverser (sim/flightmodel2/engines/thrust_reverser_deploy_ratio[n], as the
-- reference digits already did). Before, all of them hung on X-Plane's
-- sim/cockpit2/annunciators/reverser_deployed (any reverser): one reverser
-- took the marks of all four engines away, and the P&W's and RR's command
-- EPR too (58a70e1d's groups nested it into effect). The RR's command EPR in
-- reverse: no source for what it would show (no reverse model of its EEC),
-- so it goes with its engine's reverser (estimate; the P&W's shows the
-- reverse N1 command's EPR: tests/eec/eec_module_test.lua).
local T = dofile("tests/lib/check.lua")("panel_reverse_marks")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")
local DEPLOY = "sim/flightmodel2/engines/thrust_reverser_deploy_ratio"

T.check(P.find(panel, {dref = "sim/cockpit2/annunciators/reverser_deployed"}) == nil
    and (function()
        for _, e in ipairs(panel) do
            for _, s in ipairs(e.show) do
                if s.dref == "sim/cockpit2/annunciators/reverser_deployed" then return false end
            end
        end
        return true
    end)(), "nothing in the panel hangs on the any-reverser annunciator")

local engine = P.find(panel, {kind = "GROUP", name = "Engine"})
T.check(engine ~= nil, "the upper EICAS's GROUP Engine")

-- the marks: command (TRA, image N1_thrust) and reference (EPR or N1, white and magenta)
local marks = {}
for _, e in ipairs(P.find_all(panel, {kind = "gen_pointer", under = engine})) do
    local d = e.dref or ""
    local kind, n
    n = d:match("^laminar/B747/engines/TRA%[(%d)%]$")
    if n then kind = "command" end
    if not n then
        n = d:match("^laminar/B747/engines/display_EPR_ref%[(%d)%]$") or d:match("^laminar/B747/engines/display_N1_ref%[(%d)%]$")
        if n then kind = "reference" end
    end
    if kind then marks[#marks + 1] = {e = e, kind = kind, n = tonumber(n)} end
end

local TYPES = {
    {name = "P&W", type = 0, thrust_ref = 0, command_in_reverse = true},
    {name = "RR", type = 2, thrust_ref = 0, command_in_reverse = false},
    {name = "GE", type = 1, thrust_ref = 1, command_in_reverse = false},
}
for _, ty in ipairs(TYPES) do
    for _, magenta in ipairs({0, 1}) do
        for rev = -1, 3 do               -- -1: no reverser; else that engine's out
            local values = {["laminar/B747/engines/type"] = ty.type, ["laminar/B747/engines/thrust_ref"] = ty.thrust_ref,
                ["laminar/B747/engines/display_ref_line_magenta"] = magenta,
                ["sim/cockpit2/annunciators/reverser_deployed"] = rev >= 0 and 2 ^ rev or 0}
            for n = 0, 3 do values[DEPLOY .. "[" .. n .. "]"] = n == rev and 1 or 0 end
            local seen = {command = {}, reference = {}}
            for _, m in ipairs(marks) do
                if P.shown(m.e, values, engine) then
                    seen[m.kind][m.n] = (seen[m.kind][m.n] or 0) + 1
                end
            end
            for n = 0, 3 do
                local label = string.format("%s, magenta %d, %s: engine %d's ", ty.name, magenta,
                    rev < 0 and "no reverser" or ("engine " .. (rev + 1) .. "'s reverser out"), n + 1)
                local want_ref = (n == rev) and 0 or 1
                local want_cmd = (n == rev and not ty.command_in_reverse) and 0 or 1
                T.equal(seen.reference[n] or 0, want_ref, label .. "reference mark")
                T.equal(seen.command[n] or 0, want_cmd, label .. "command mark")
            end
        end
    end
end

T.done()
