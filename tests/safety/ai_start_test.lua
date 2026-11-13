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

-- (2026-11-13; finding 3 of the 2026-11-12 review) auto board's steps 5
-- and 9 with the switches as cold and dark leaves them (every button switch
-- off) and X-Plane's cross tie closed (the electrical glue keeps it so):
--   - step 5 sets the four BUS TIE switches to AUTO and is done only then.
--     Before, no push with X-Plane's cross tie closed, the step done at once
--     with them OFF (X-Plane s305: the APU's power on no AC bus, no engine
--     started);
--   - step 9 pushes APU GEN 1 once its AVAIL light is on, not before (a push
--     before AVAIL is dropped: FCOM p.783), and is done with APU power 1 on.
-- The other modules' part as they would do it: the switch commands toggle
-- the switches, X-Plane's APU at speed at once, AVAIL 3 s later, a push
-- with AVAIL lit puts APU power 1 on
do
    local AVAIL, ON = "laminar/B747/electrical/apu_pwr1_avail", "laminar/B747/electrical/apu_pwr1_on"
    local POS = "laminar/B747/button_switch/position"
    local rt = xtlua.new{types = {[AVAIL] = "number", [ON] = "number"}}
    rt:load("plugins/xtlua/scripts/B747.95.xt.AI/B747.95.xt.AI.lua")
    rt:set("sim/operation/prefs/startup_running", 0)
    rt:callout("flight_start")
    rt:frame(1 / 30)
    local SYS = {"manip", "elec", "gear", "com", "hyd", "fuel", "fltmgmt", "fire", "engines", "fltctrls",
        "ice", "air", "inst", "safety", "warning", "lighting"}
    local BTN = {elec_util_L = 11, elec_util_R = 12, elec_battery = 13}
    for n = 1, 4 do
        BTN["elec_bus_tie_" .. n] = 17 + n
        BTN["elec_gen_ctrl_" .. n] = 21 + n
    end
    local ties, gen_pushes, gen_push_avail, seen = 0, 0, true, 0
    local function others()
        for _, s in ipairs(SYS) do
            local n = "laminar/B747/" .. s .. "/init_CD"
            if rt:get(n) == 1 then
                rt:set(n, 2)
                -- cold and dark: every button switch off (B747_set_manip_CD)
                if s == "manip" then for i = 0, 86 do rt:set(POS, i, 0) end end
            end
        end
        for i = seen + 1, #rt.command_log do
            local c = rt.command_log[i]
            local btn = BTN[c.name:match("^laminar/B747/button_switch/(.+)$") or ""]
            if btn and c.phase == "once" then
                rt:set(POS, btn, 1 - rt:get(POS, btn))
                if btn >= 18 and btn <= 21 then ties = ties + 1 end
            elseif c.name == "sim/electrical/APU_start" then
                rt:set("sim/cockpit2/electrical/APU_running", 1)
                rt:set("sim/cockpit2/electrical/APU_N1_percent", 100)
            elseif c.name == "laminar/B747/button_switch/elec_apu_gen_1" and c.phase == "once" then
                gen_pushes = gen_pushes + 1
                if rt:get(AVAIL) == 1 then
                    rt:set(ON, 1)
                    rt:set(AVAIL, 0)
                else
                    gen_push_avail = false
                end
            end
        end
        seen = #rt.command_log
        rt:set("sim/cockpit2/electrical/battery_on", 0, rt:get(POS, 13))
        rt:set("sim/cockpit2/electrical/cross_tie", 1)
    end
    rt:command("sim/operation/auto_board")
    local avail_at
    for k = 1, 30 * 40 do
        rt:frame(1 / 30)
        others()
        if avail_at == nil and rt:get("sim/cockpit2/electrical/APU_running") == 1 then avail_at = k + 90 end
        if k == avail_at and rt:get(ON) == 0 then rt:set(AVAIL, 1) end
    end
    local function logged(p)
        for _, line in ipairs(rt.log) do if line:find(p) then return true end end
        return false
    end
    T.equal(ties, 4, "auto board step 5: the four BUS TIE switches pushed with X-Plane's cross tie closed (before: none)")
    for n = 18, 21 do T.equal(rt:get(POS, n), 1, "auto board step 5: BUS TIE " .. (n - 17) .. " AUTO") end
    T.check(logged("Step:05/Phase:04 %- Completed, Bus Tie Switches are AUTO"), "auto board step 5 done with the switches AUTO")
    T.equal(gen_pushes, 1, "auto board step 9: APU GEN 1 pushed once")
    T.check(gen_push_avail, "auto board step 9: the push with AVAIL lit (before: at once after the APU at speed)")
    T.check(logged("Step:09/Phase:04 %- Completed"), "auto board step 9 done (APU power 1 on)")
end

T.done()
