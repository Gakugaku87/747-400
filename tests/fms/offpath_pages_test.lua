-- Run from the repository root with LuaJIT: luajit tests/fms/offpath_pages_test.lua
-- OFFPATH DES (2026-11-04; notes/ATA-34-61-FMC.md §143) in the FMS module as
-- XTLua runs it (tests/lib/xtlua.lua), on the synthetic navigation data in
-- tests/fms/data/navdb, the active route ZZAA RW16R, ALPHA, Z1 to CHARL,
-- ZZBB: the DES page's and DESCENT FORECAST's <OFFPATH DES, the page (FCOM
-- p.1398's figure), DES TO (boxes without an E/D, an entered waypoint,
-- DELETE, the E/D again within 150 ft of its altitude), SPD/ALT (boxes, an
-- entry), DTG, CLEAN and DRAG CIRCLE (the drag one inside the clean one),
-- <DES, DISPLAY SELECT ON>/OFF> and the circles for the ND (FCOM
-- p.1398-1399; FMSPG p.190-194).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("offpath_pages")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local PM = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.pred_model.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

local CDU = {L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"}}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c].lines, n)) end
local function small(c, n) return rt:get(string.format("%sLine%02d_S", CDU[c].lines, n)) end
local function pad(c) return (line(c, 14):gsub("%s+$", "")) end
local function key(c, k, held)
    rt:command(CDU[c].keys .. k, held)
    frames(0.3)
end
local function type_in(c, text)
    for ch in text:gmatch(".") do
        rt:command(CDU[c].keys .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
end
local function enter(c, text, lsk) type_in(c, text) key(c, "ls_key/" .. lsk) end
local function clear(c) key(c, "key/clear") key(c, "key/clear", 1.2) end
local ns = fms.ns
local R = ns.B747_route_model
local st = ns.B747_fmc_route

-- the active route
key("L", "func_key/fpln")
enter("L", "ZZAA", "L1")
enter("L", "ZZBB", "R1")
enter("L", "16R", "L2")
key("L", "func_key/next_pg")
enter("L", "ALPHA", "R1")
key("L", "ls_key/L1")
enter("L", "Z1", "L2")
enter("L", "CHARL", "R2")
key("L", "func_key/legs")
key("L", "ls_key/R6")
key("L", "key/execute")
T.check(st.active and #st.rte.legs == 3, "the active route ALPHA, BRAVO, CHARL")

-- in the air at FL300 (the predictions' input a stub: the DES page's
-- speeds, 250 t, no wind)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 30000)
local s = {P = P, t = P.tables(0), isa = 0, gw = 250000, des = {cas = 290, mach = 0.84, trans_cas = 240, trans_alt = 10000},
    wind = {des = 0}}
ns.B747_fms_pred_input_last = function() return s end
frames(1)

-- the DES page's <OFFPATH DES (FCOM p.1398's figure)
key("L", "func_key/des")
key("L", "func_key/next_pg")
key("L", "func_key/next_pg")
T.check(line("L", 13):find("^<OFFPATH DES"), "DES: <OFFPATH DES at 6L: " .. line("L", 13))
key("L", "ls_key/L6")
T.equal(line("L", 1), "       OFFPATH DES      ", "OFFPATH DES (FCOM p.1398)")
T.equal(small("L", 2), " DES TO    DTG   SPD/ALT", "DES TO, DTG, SPD/ALT")
T.equal(small("L", 4), " ECON SPD CLEAN CIRCLE  ", "ECON SPD, CLEAN CIRCLE")
T.equal(small("L", 6), " SPD TRANS DRAG CIRCLE  ", "SPD TRANS, DRAG CIRCLE")
T.equal(small("L", 8), " SPD RESTR              ", "SPD RESTR")
T.equal(line("L", 10), string.rep("-", 24), "the line under them")
T.check(line("L", 11):find("FORECAST>$"), "FORECAST>")
T.equal(small("L", 12), "                 DISPLAY", "DISPLAY")
T.equal(line("L", 13), "<DES          SELECT ON>", "<DES and SELECT ON>")
T.equal(line("L", 3), "*****                   ", "no E/D (no predictions): DES TO boxes")

-- DES TO ALPHA (the nearer, by SELECT DESIRED WPT): its DTG; no
-- constraint: SPD/ALT boxes (FCOM p.1399)
enter("L", "ALPHA", "L1")
key("L", "ls_key/L1")
frames(0.6)
local _, dtg = R.course(35, 140, 35.5, 140.5)
local d = tostring(math.floor(dtg + 0.5))
T.equal(line("L", 3):sub(1, 5), "ALPHA", "DES TO ALPHA")
T.equal(line("L", 3):sub(15 - #d, 14), d, "its direct distance, DTG " .. d)
T.equal(line("L", 3):sub(16, 24), "***/*****", "SPD/ALT boxes: no constraint at ALPHA")
enter("L", "240/10000", "R1")
T.equal(line("L", 3):sub(16, 24), "240/10000", "SPD/ALT 240/10000")
frames(1.2)
local rc = PM.offpath(s, 250000, 30000, 10000, 240, false)
local rd = PM.offpath(s, 250000, 30000, 10000, 240, true)
T.check(rc and rd and rc > rd, ("the clean descent longer than the drag one: %.1f, %.1f NM"):format(rc or -1, rd or -1))
local cv = tonumber(line("L", 5):sub(9, 14))
T.check(cv and math.abs(cv - (dtg - rc)) <= 1, ("CLEAN CIRCLE: DTG - %.1f = %s"):format(rc, tostring(cv)))
if dtg < rc then
    local dv = tonumber(line("L", 7):sub(10, 14))
    T.check(dv and math.abs(dv - (dtg - rd)) <= 1, ("inside the clean circle: DRAG CIRCLE %s"):format(tostring(dv)))
else
    T.equal(line("L", 7):sub(10, 14), "     ", "outside the clean circle: no DRAG CIRCLE (FMSPG p.193)")
end

-- the ND: SELECT ON> the clean circle, the drag one once inside the clean
-- one (FMSPG p.194)
T.equal(#ns.B747_fms_offpath_nd(), 0, "SELECT ON not pushed: no circles")
key("L", "ls_key/R6")
T.check(line("L", 13):find("SELECT OFF>$"), "SELECT OFF> after it")
local c = ns.B747_fms_offpath_nd()
T.equal(c[1] and c[1].pen, 7, "the clean circle (style 7)")
T.near(c[1].r, rc, 0.5, "its radius")
T.equal(#c, dtg < rc and 2 or 1, "the drag circle only inside the clean one")
frames(1.5)
local cn = rt:get("laminar/B747/nd/circle/n")
local found = false
for k = 0, cn - 1 do if rt:get("laminar/B747/nd/circle/pen", k) == 7 then found = true end end
T.check(found, "laminar/B747/nd/circle: the clean circle for the bridge")
-- at FL150 (DTG the same) inside the clean circle: the drag circle too
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 22000)
frames(1.5)
local rc2 = PM.offpath(s, 250000, 22000, 10000, 240, false)
if dtg < rc2 then
    T.equal(#ns.B747_fms_offpath_nd(), 2, ("22,000 ft: inside the clean circle (%.0f NM): both circles"):format(rc2))
end
key("L", "ls_key/R6")
T.equal(#ns.B747_fms_offpath_nd(), 0, "SELECT OFF>: none")

-- within 150 ft of 10,000 ft: the E/D again (FMSPG p.192)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 10100)
frames(1.5)
T.equal(line("L", 3), "*****                   ", "10,100 ft: DES TO back to the E/D (none: boxes)")

-- DELETE: back to the E/D; <DES
enter("L", "BRAVO", "L1")
T.equal(line("L", 3):sub(1, 5), "BRAVO", "DES TO BRAVO")
key("L", "key/del")
key("L", "ls_key/L1")
T.equal(line("L", 3), "*****                   ", "DELETE: the E/D again")
key("L", "ls_key/L6")
T.check(small("L", 1):find("3/3"), "<DES: the DES page")

-- the DESCENT FORECAST page's <OFFPATH DES (the 109: FCOM p.1396)
key("L", "func_key/des")
key("L", "func_key/next_pg")
key("L", "func_key/next_pg")
key("L", "ls_key/R5")
T.check(line("L", 1):find("DESCENT FORECAST"), "DESCENT FORECAST")
T.check(line("L", 13):find("^<OFFPATH DES"), "its <OFFPATH DES")
key("L", "ls_key/L6")
T.equal(line("L", 1), "       OFFPATH DES      ", "6L: OFFPATH DES")

T.done()
