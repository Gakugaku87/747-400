-- Run from the repository root with LuaJIT: luajit tests/static/simconfig_read_test.lua
-- (2026-11-12 review C-2; REVIEW_2026-11-12.md case 11) The simconfig module
-- with a livery file that is not one line of JSON: set out over several
-- lines, cut short, empty, a BOM in front, without the FMC section, without
-- PLANE.engines, the engines in lower case. Each one read without a Lua
-- error (before, all but the last stopped every module of this XTLua plugin),
-- the engine type from what is there, the defaults for what is not.
local T = dofile("tests/lib/check.lua")("simconfig_read")
local xtlua = dofile("tests/lib/xtlua.lua")
local dir = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/") .. "/b747_simconfig_test_" .. tostring(os.time()) .. "/"
local windows = package.config:sub(1, 1) == "\\"
os.execute(windows and ('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('mkdir -p "' .. dir .. '"'))

local good = '{"FMC":{"INIT":{"op_program":"","active":"","drag_ff":"+0.0/-0.0","nav_data":""}},'
    .. '"PLANE":{"pfd_style":"CRT","thrust_ref":"N1","civil_registration":"X","model":"747-400","airline":"X",'
    .. '"nd_style":"CRT","engines":"CF6-80C2-B1F","aircraft_type":"PASSENGER","fin_nbr":0},'
    .. '"SIM":{"std_pax_weight":120,"baro_sync":"NO","kgs_to_lbs":2.2046226218488,"fo_lwr":"NORM",'
    .. '"weight_display_units":"KGS","auto_fuel_mgmt":"NO","capt_inbd":"NORM","irs_align_time":600,'
    .. '"capt_lwr":"NORM","baro_indicator":"IN","fo_inbd":"NORM","lbs_to_kgs":0.45359237}}'
-- the third: the engine type; the fourth (2026-11-13, case 11): the file
-- did not decode (laminar/B747/simconfig/read_failed: the CDUs' SIM CONFIG
-- NOT READ)
local cases = {
    {"one line (as the CDU writes it)", good, 1, 0},
    {"set out over several lines", (good:gsub("{", "{\n"):gsub(",", ",\n")), 1, 0},
    {"cut short", good:sub(1, 200), 0, 1},
    {"empty", "", 0, 1},
    {"a BOM in front", "\239\187\191" .. good, 1, 0},
    {"without the FMC section", (good:gsub('"FMC":{.-}},', "")), 1, 0},
    {"without PLANE.engines", (good:gsub('"engines":"[^"]*",', "")), 0, 0},
    {"the engines in lower case", (good:gsub("CF6%-80C2%-B1F", "cf6-80c2-b1f")), 1, 0},
}
for _, c in ipairs(cases) do
    local f = assert(io.open(dir .. "B747-400_simconfig.dat", "wb"))
    f:write(c[2])
    f:close()
    local rt = xtlua.new{types = {["sim/aircraft/view/acf_livery_path"] = "string"}}
    rt:set("sim/aircraft/view/acf_livery_path", dir)
    rt:set("sim/aircraft/view/acf_livery_index", 1)   -- a livery (the default livery's index is 0)
    local ok, err = pcall(function()
        rt:load("plugins/xtlua/scripts/B747.05.xt.simconfig/B747.05.xt.simconfig.lua")
        rt:callout("flight_start")
        for _ = 1, 30 * 8 do rt:frame(1 / 30) end
    end)
    T.check(ok, c[1] .. ": no Lua error: " .. tostring(err))
    if ok then
        T.equal(rt:get("laminar/B747/engines/type"), c[3], c[1] .. ": engine type")
        T.equal(rt:get("laminar/B747/engines/thrust_ref"), c[3], c[1] .. ": thrust reference")
        T.equal(rt:get("laminar/B747/simconfig/read_failed"), c[4], c[1] .. ": read_failed (the CDUs' SIM CONFIG NOT READ)")
    end
end
-- (2026-11-13) the default livery (its path ""): the file in the
-- aircraft's folder, by its .acf (before, the file's name alone:
-- X-Plane's own folder, s333)
do
    local f = assert(io.open(dir .. "B747-400_simconfig.dat", "wb"))
    f:write(good)
    f:close()
    local rt = xtlua.new{types = {["sim/aircraft/view/acf_livery_path"] = "string",
        ["sim/aircraft/view/acf_relative_path"] = "string"}}
    rt:set("sim/aircraft/view/acf_livery_path", "")
    rt:set("sim/aircraft/view/acf_relative_path", dir .. "747-400_custom.acf")
    rt:load("plugins/xtlua/scripts/B747.05.xt.simconfig/B747.05.xt.simconfig.lua")
    rt:callout("flight_start")
    for _ = 1, 30 * 8 do rt:frame(1 / 30) end
    T.equal(rt:get("laminar/B747/engines/type"), 1, "the default livery: the aircraft folder's file read (CF6)")
    T.equal(rt:get("laminar/B747/simconfig/read_failed"), 0, "the default livery: read")
end
-- (2026-11-13) the paths read as XTLua reads X-Plane's datarefs (the value
-- fetched at the read before: the first ""): the .acf's path read once
-- before (do_flight_start, livery_load). Before, the first read gave "":
-- s333's second part found no file
do
    local rt = xtlua.new{types = {["sim/aircraft/view/acf_livery_path"] = "string",
        ["sim/aircraft/view/acf_relative_path"] = "string"}, lagged = {"sim/aircraft/view/acf_livery_path", "sim/aircraft/view/acf_relative_path"}}
    rt:set("sim/aircraft/view/acf_livery_path", "")
    rt:set("sim/aircraft/view/acf_relative_path", dir .. "747-400_custom.acf")
    rt:load("plugins/xtlua/scripts/B747.05.xt.simconfig/B747.05.xt.simconfig.lua")
    rt:callout("flight_start")
    for _ = 1, 30 * 8 do rt:frame(1 / 30) end
    T.equal(rt:get("laminar/B747/engines/type"), 1, "the default livery, the paths read as XTLua reads them: the aircraft folder's file read (CF6)")
end
-- (2026-11-13) a livery with the P&W, then the default livery: its index
-- 0 and XTLua's livery_load, the livery's path read still the livery
-- before's (as XTLua read it in X-Plane: s333's trace): its file in the
-- aircraft's folder (the CF6) read 2 s on. Before, the livery before's
-- path: back on the default livery its settings stayed (s333)
do
    local f = assert(io.open(dir .. "B747-400_simconfig.dat", "wb"))
    f:write(good)
    f:close()
    local liv = dir .. "liv/"
    os.execute(windows and ('mkdir "' .. liv:gsub("/", "\\") .. '" 2>nul') or ('mkdir -p "' .. liv .. '"'))
    f = assert(io.open(liv .. "B747-400_simconfig.dat", "wb"))
    f:write((good:gsub("CF6%-80C2%-B1F", "PW4056")))
    f:close()
    local rt = xtlua.new{types = {["sim/aircraft/view/acf_livery_path"] = "string",
        ["sim/aircraft/view/acf_relative_path"] = "string"},
        lagged = {"sim/aircraft/view/acf_livery_path", "sim/aircraft/view/acf_relative_path"}}
    rt:set("sim/aircraft/view/acf_livery_path", liv)
    rt:set("sim/aircraft/view/acf_livery_index", 1)
    rt:set("sim/aircraft/view/acf_relative_path", dir .. "747-400_custom.acf")
    rt:load("plugins/xtlua/scripts/B747.05.xt.simconfig/B747.05.xt.simconfig.lua")
    rt:callout("flight_start")
    for _ = 1, 30 * 8 do rt:frame(1 / 30) end
    T.equal(rt:get("laminar/B747/engines/type"), 0, "a livery with the P&W: P&W")
    rt:set("sim/aircraft/view/acf_livery_index", 0)
    rt:callout("livery_load")
    for _ = 1, 30 * 8 do rt:frame(1 / 30) end
    T.equal(rt:get("laminar/B747/engines/type"), 1, "back on the default livery (its index 0, the path read still the livery's): the aircraft folder's file read (CF6)")
    os.remove(liv .. "B747-400_simconfig.dat")
    os.execute(windows and ('rmdir "' .. liv:gsub("/", "\\") .. '" 2>nul') or ('rmdir "' .. liv .. '"'))
end
os.remove(dir .. "B747-400_simconfig.dat")
os.execute(windows and ('rmdir "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('rmdir "' .. dir .. '"'))
T.done()
