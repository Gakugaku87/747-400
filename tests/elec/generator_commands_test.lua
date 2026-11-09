-- Run from the repository root with LuaJIT: luajit tests/elec/generator_commands_test.lua
-- X-Plane's generator commands (B747.01.xt.manipulators.lua's replacements) as
-- XTLua runs them (tests/lib/xtlua.lua): each moves its GEN CONT switch
-- (laminar/B747/button_switch/elec_gen_ctrl_N, which the electrical model
-- reads) when the switch is not already there; generators_toggle each of
-- the four. 2026-11-09's audit: before, they called themselves (the
-- replaced commands) and never moved the 747's switches. The mock logs the
-- commands a module runs instead of running them, so the test runs them as
-- X-Plane would.
local T = dofile("tests/lib/check.lua")("generator_commands")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.01.xt.manipulators/B747.01.xt.manipulators.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(1)
-- the commands a module ran (once) since mark, by name
local mark = 0
local function sent()
    local t = {}
    for i = mark + 1, #rt.command_log do
        local c = rt.command_log[i]
        if c.phase == "once" then t[c.name] = (t[c.name] or 0) + 1 end
    end
    mark = #rt.command_log
    return t
end
local GEN = "laminar/B747/button_switch/elec_gen_ctrl_"
sent()
rt:command("sim/electrical/generator_1_on", 0.1)
local s = sent()
T.equal(s[GEN .. "1"], 1, "generator_1_on with GEN CONT 1 off: GEN CONT 1 pushed")
T.equal(s["sim/electrical/generator_1_on"], nil, "and not itself again (before, it called itself)")
-- X-Plane runs the push: the switch on
rt:command(GEN .. "1", 0)
sent()
rt:command("sim/electrical/generator_1_on", 0.1)
T.equal(sent()[GEN .. "1"], nil, "generator_1_on with GEN CONT 1 on: nothing")
rt:command("sim/electrical/generator_1_off", 0.1)
T.equal(sent()[GEN .. "1"], 1, "generator_1_off with it on: GEN CONT 1 pushed")
rt:command(GEN .. "1", 0)
sent()
rt:command("sim/electrical/generator_4_off", 0.1)
T.equal(sent()[GEN .. "4"], nil, "generator_4_off with GEN CONT 4 off: nothing")
rt:command("sim/electrical/generators_toggle", 0.1)
s = sent()
local all = true
for n = 1, 4 do if s[GEN .. n] ~= 1 then all = false end end
T.check(all, "generators_toggle: each GEN CONT pushed once")

T.done()
