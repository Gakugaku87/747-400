-- Run from the repository root with LuaJIT: luajit tests/fms/posinit_lastpos_test.lua
-- (2026-11-05 review) POS INIT's LAST POS (the livery's
-- B747-400_lastpos.dat, written when the aircraft unloads) in the FMS
-- module as XTLua runs it (tests/lib/xtlua.lua): read once, not in every
-- frame the page is drawn (before, the file was opened and read in each of
-- them, on both CDUs: a lead for the user's freezes on CDU input), and an
-- empty file leaves the line blank (before, nil in the FMS data: the next
-- read of it stopped every module of the plugin).
local T = dofile("tests/lib/check.lua")("posinit_lastpos")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["sim/aircraft/view/acf_livery_path"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
-- the livery's path is a prefix: the file is <prefix>B747-400_lastpos.dat
local prefix = (os.getenv("TEMP") or os.getenv("TMP") or ".") .. "/b747_posinit_test_"
local path = prefix .. "B747-400_lastpos.dat"

local function new_rt(content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
    local rt = xtlua.new{types = types}
    local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
    -- the module's io, counting the opens of the last position's file
    local count = {n = 0}
    fms.env.io = setmetatable({open = function(p, m)
        if tostring(p):find("lastpos", 1, true) then count.n = count.n + 1 end
        return io.open(p, m)
    end}, {__index = io})
    rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
    rt:set("laminar/B747/newsimconfig", 1)
    rt:set("sim/operation/prefs/startup_running", 1)
    rt:set("sim/aircraft/view/acf_livery_path", prefix)
    for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
    for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
    rt:set("sim/flightmodel/failures/onground_any", 1)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
    rt:callout("flight_start")
    for _, cdu in ipairs({"cdu1", "cdu2"}) do
        for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
    end
    for _ = 1, 60 do rt:frame(1 / 30) end
    return rt, count
end
local function frames(rt, seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
local function pos_init(rt, side)
    rt:set("laminar/B747/irs/set_pos", 1)
    frames(rt, 0.1)
    rt:command("laminar/B747/" .. side .. "/func_key/index")
    frames(rt, 0.1)
end

local rt, count = new_rt("N35`45.6 E140`23.4\n")
pos_init(rt, "fms1")
T.check(rt:get("laminar/B747/fms3/Line01_L"):find("POS INIT", 1, true) ~= nil, "INIT REF with the IRS position wanted: POS INIT")
T.check(rt:get("laminar/B747/fms3/Line03_L"):find("N35`45.6 E140`23.4", 1, true) ~= nil, "LAST POS from the livery's file: " .. rt:get("laminar/B747/fms3/Line03_L"))
pos_init(rt, "fms2")
frames(rt, 2)
T.equal(count.n, 1, "2 s of POS INIT on both CDUs: the file opened once (before, in every frame on each CDU)")

-- an empty file: LAST POS blank, the FMC runs on
local rt2, count2 = new_rt("")
local ok, err = pcall(function()
    pos_init(rt2, "fms1")
    frames(rt2, 1)
end)
T.check(ok, "an empty file: no Lua error (" .. tostring(err) .. ")")
T.check(rt2:get("laminar/B747/fms3/Line01_L"):find("POS INIT", 1, true) ~= nil, "POS INIT drawn")
T.check(rt2:get("laminar/B747/fms3/Line03_L"):find("^%s*$") ~= nil, "LAST POS blank")
T.equal(count2.n, 1, "the file opened once")
os.remove(path)
T.done()
