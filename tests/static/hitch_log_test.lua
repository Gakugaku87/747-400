-- Run from the repository root with LuaJIT: luajit tests/static/hitch_log_test.lua
-- (2026-11-05, the user's freezes) the XTLua plugins' init.lua (the threaded
-- one, as the mock loads it) times each callout, timer function and command
-- handler and writes one over 0.2 s of wall time to
-- Output/B747_hitches.txt: the module's script, what it was, its time. A
-- module's main file replaced by a slow one (the mock's opts.files).
local T = dofile("tests/lib/check.lua")("hitch_log")
local xtlua = dofile("tests/lib/xtlua.lua")

local report = {}
local real_open = io.open
io.open = function(path, mode)
    if path == "Output/B747_hitches.txt" then
        return {write = function(_, ...) for _, s in ipairs({...}) do report[#report + 1] = s end end,
            close = function() end}
    end
    return real_open(path, mode)
end

local SLOW = [[
local function spin(s) local t = os.clock() while os.clock() - t < s do end end
local slow_frames = 0
function after_physics()
    if slow_frames > 0 then slow_frames = slow_frames - 1 spin(0.25) end
end
function slow_next() slow_frames = 1 end
function quick() end
local function slow_timer() spin(0.25) end
run_after_time(slow_timer, 0.05)
replace_command("laminar/B747/test/slow", function(phase) if phase == 0 then spin(0.25) end end)
]]
local rt = xtlua.new()
local module = rt:load("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua",
    {files = {["B747.10.xt.gear.lua"] = SLOW}})
for _ = 1, 3 do rt:frame(1 / 30) end
local text = table.concat(report)
T.check(text:find("xtlua B747%.10%.xt%.gear%.lua timer B747%.10%.xt%.gear%.lua:%d+ 0%.%d%d s\n") ~= nil,
    "a slow timer: the module's script, the timer's line, its time: " .. text)
report = {}
for _ = 1, 3 do rt:frame(1 / 30) end
T.equal(table.concat(report), "", "quick frames: nothing")
module.ns.slow_next()
rt:frame(1 / 30)
text = table.concat(report)
T.check(text:find("xtlua B747%.10%.xt%.gear%.lua after_physics 0%.%d%d s\n") ~= nil, "a slow callout: " .. text)
report = {}
rt:command("laminar/B747/test/slow")
text = table.concat(report)
T.check(text:find("xtlua B747%.10%.xt%.gear%.lua command laminar/B747/test/slow 0%.%d%d s\n") ~= nil,
    "a slow command handler: " .. text)
io.open = real_open
T.done()
