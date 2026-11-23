-- Run from the repository root with LuaJIT: luajit tests/engines/panel_ge_command_n1_test.lua
-- (2026-11-24, the stage 4 review's PNL-5) The GE's command N1 marks
-- (laminar/B747/engines/TRA[n], white) in the custom acf's panel: on the N1
-- tape's own scale, so that a command equal to the N1 puts the mark at the
-- bar's end (FCOM p.835 (7.10.7): command N1, the N1 the thrust lever
-- commands; p.873 (7.20.3): equal to the actual N1 once stable), stopping at
-- the tape's box (the bottom line, the red line on top). Before, the marks
-- had their own POS (6.5 px under the tape's) and stopped at 31 % (y 816.5:
-- 14 px over the bar's end at a 21.7 % idle) and at 116 %, between them
-- 0.8-2.1 % under the tape. The idle N1 the EEC shows as the command (not
-- its own 25 % under any idle): tests/eec/eec_module_test.lua.
local T = dofile("tests/lib/check.lua")("panel_ge_command_n1")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")

local ge_tape_group = P.find(panel, {kind = "GROUP", name = "N1 Tape GE"})
local cmd_group = P.find(panel, {kind = "GROUP", name = "Thrust Command N1 G"})
T.check(ge_tape_group ~= nil and cmd_group ~= nil, "the GE's N1 tape and command groups")
local tapes = P.find_all(panel, {kind = "gen_tape", under = ge_tape_group})
local marks = P.find_all(panel, {kind = "gen_pointer", under = cmd_group})
T.equal(#marks, 4, "four command marks")
-- the box's bottom line (N1_tapeW-2.png rows 194-196 of 200: 95.5 px under
-- the tape's POS) and the red line (on the box's top)
local red = P.find_all(panel, {kind = "gen_rotary", under = P.find(panel, {kind = "GROUP", name = "Redline Markers", under = ge_tape_group})})
for _, m in ipairs(marks) do
    local n = tonumber((m.dref or ""):match("^laminar/B747/engines/TRA%[(%d)%]$"))
    T.check(n ~= nil, "line " .. m.line .. ": a TRA mark")
    T.check(P.ascending(m), "line " .. m.line .. ": ascending key frames")
    local tape, line
    for _, t in ipairs(tapes) do if not tape and math.abs(t.x - m.x) < 0.01 then tape = t end end
    for _, r in ipairs(red) do if math.abs(r.x - m.x) < 0.01 then line = r end end
    T.check(tape ~= nil and line ~= nil, "line " .. m.line .. ": its tape and red line")
    if tape and line then
        for _, v in ipairs({20, 21.7, 25, 25.9, 31, 40, 50, 80, 100, 110, 116, 117.5}) do
            T.near(m.y + P.at(m, v), tape.y + P.at(tape, v), 0.01,
                string.format("line %d: command %g %% at the bar's end for N1 %g %%", m.line, v, v))
        end
        local bottom = tape.y - 95.5
        for _, v in ipairs({-50, 0, 10, 17}) do
            T.near(m.y + P.at(m, v), bottom, 0.5, string.format("line %d: command %g %%: stops on the box's bottom line", m.line, v))
        end
        for _, v in ipairs({118, 130, 300}) do
            T.near(m.y + P.at(m, v), line.y, 0.01, string.format("line %d: command %g %%: stops on the red line", m.line, v))
        end
    end
end

T.done()
