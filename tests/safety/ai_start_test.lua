-- Run from the repository root with LuaJIT: luajit tests/safety/ai_start_test.lua
-- (2026-11-12 review SM-1, SM-3; REVIEW_2026-11-12.md case 14) X-Plane's
-- quick start and auto board as B747.95.xt.AI replaces them:
--   - quick start sends every system's laminar/B747/ai/*_quick_start
--     through the last (lighting), each one a command an init script makes;
--     before, it stopped on a Lua error at the autopilot's (a nil name),
--     after sending two commands no script makes (fmsL, fmsR);
--   - auto board's step 1 (the airplane cold and dark: each system answers
--     its laminar/B747/<sys>/init_CD = 2) completes when every system that
--     has the flag answers; before, it also waited for fmsL/fmsR init_CD,
--     which no script makes, and aborted after its time-out.
-- The steps after step 1 need the other modules (X-Plane: s305).
-- (2026-11-13) the warning module answers its flag without power: in
-- X-Plane (s305) step 1 still timed out, the airplane cold and dark and the
-- EIUs unpowered in the same frame, the warning module's answer only made
-- while they were powered.
local T = dofile("tests/lib/check.lua")("ai_start")
local xtlua = dofile("tests/lib/xtlua.lua")
local src = dofile("tests/lib/source.lua")
local _, created = src.created(src.lua_files())

-- quick start
do
    local rt = xtlua.new()
    rt:load("plugins/xtlua/scripts/B747.95.xt.AI/B747.95.xt.AI.lua")
    rt:set("sim/operation/prefs/startup_running", 0)
    rt:callout("flight_start")
    rt:frame(1 / 30)
    local ok, err = pcall(function() rt:command("sim/operation/quick_start") end)
    T.check(ok, "quick start: no Lua error: " .. tostring(err))
    local sent = {}
    for _, c in ipairs(rt.command_log) do
        if c.name:find("^laminar/B747/ai/") then
            sent[#sent + 1] = c.name
            T.check(created[c.name] ~= nil, "quick start: " .. c.name .. " made by an init script")
        end
    end
    T.equal(sent[#sent], "laminar/B747/ai/lighting_quick_start", "quick start: through the last system (lighting)")
    local ap = false
    for _, n in ipairs(sent) do if n == "laminar/B747/ai/autopilot_quick_start" then ap = true end end
    T.check(ap, "quick start: the autopilot's sent")
end

-- auto board, step 1
do
    local rt = xtlua.new()
    rt:load("plugins/xtlua/scripts/B747.95.xt.AI/B747.95.xt.AI.lua")
    rt:set("sim/operation/prefs/startup_running", 0)
    rt:callout("flight_start")
    rt:frame(1 / 30)
    local SYS = {"manip", "elec", "gear", "com", "hyd", "fuel", "fltmgmt", "fire", "engines", "fltctrls",
        "ice", "air", "inst", "safety", "warning", "lighting"}
    rt:command("sim/operation/auto_board")
    for _ = 1, 30 * 12 do
        rt:frame(1 / 30)
        for _, s in ipairs(SYS) do       -- each system answers its flag at once
            local n = "laminar/B747/" .. s .. "/init_CD"
            if rt:get(n) == 1 then rt:set(n, 2) end
        end
    end
    local completed, aborted_step1 = false, false
    for _, line in ipairs(rt.log) do
        if line:find("Step:01/Phase:04 %- Completed") then completed = true end
        if line:find("Step:01/Phase:03 %- Step Has Timed Out") then aborted_step1 = true end
    end
    T.check(completed, "auto board: step 1 completed (the airplane cold and dark)")
    T.check(not aborted_step1, "auto board: step 1 not timed out")
end
-- (2026-11-13; the review SM-1, 案 14) the warning module answers the auto
-- board's flag unpowered (X-Plane s305: step 1 timed out on it)
do
    local rt = xtlua.new()
    rt:load("plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.warning.lua")
    rt:set("sim/operation/prefs/startup_running", 0)
    rt:callout("flight_start")
    for _ = 1, 30 do rt:frame(1 / 30) end
    rt:set("laminar/B747/warning/init_CD", 1)
    for _ = 1, 3 do rt:frame(1 / 30) end
    T.equal(rt:get("laminar/B747/warning/init_CD"), 2, "the warning module unpowered: its cold and dark flag answered (before: never)")
end

T.done()
