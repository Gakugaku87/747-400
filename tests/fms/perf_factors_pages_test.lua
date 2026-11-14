-- Run from the repository root with LuaJIT: luajit tests/fms/perf_factors_pages_test.lua
-- MAINTENANCE INDEX and PERF FACTORS (6-1/6-2 step 12c1; notes/ATA-34-61-
-- FMC.md §109; FCOM p.1239; FMSPG p.263-268; ATA34_2 p.678-679, p.681) in
-- the FMS module as XTLua runs it (tests/lib/xtlua.lua): the index's
-- prompts on the ground, <INDEX to INIT/REF INDEX; PERF FACTORS static
-- until ARM at 6R, its entries into the simconfig, IDENT's DRAG/FF, the
-- performance data's factors, the PFDs' margin, THRUST LIM's derates, the
-- cruise's thrust limit; TAKEOFF REF's defaults at the flight's completion.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("perf_factors_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
local CFG = "laminar/B747/simconfig"
rt:set(CFG, '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function seconds(n) for _ = 1, n do rt:frame(1) end end
frames(4)

-- the left CDU: keys laminar/B747/fms1/, display fms3
local K, D = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", D, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", D, n)) end
-- a line's left field (TAKEOFF REF's: the REF speeds on the right)
local function left(s) return (s:sub(1, 12):gsub("%s+$", "")) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or ch == "-" and "key/minus"
            or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function delete(lsk) clear() rt:command(K .. "key/del") frames(0.1) key("ls_key/" .. lsk) end
local function page(text) return line(1):find(text, 1, true) ~= nil end
local INOP = "laminar/B747/engines/inop"
for i = 0, 3 do rt:set(INOP, i, 0) end

-- INIT/REF INDEX (the INIT REF key gives PERF INIT on the ground; its
-- <INDEX) and MAINT>
key("func_key/index")
if not page("INIT/REF INDEX") then key("ls_key/L6") end
T.check(page("INIT/REF INDEX"), "INIT/REF INDEX")
key("ls_key/R6")
T.equal(line(1), "   MAINTENANCE INDEX    ", "MAINT>: MAINTENANCE INDEX (FCOM p.1239)")
T.equal(line(3), "<CROSS LOAD        BITE>", "<CROSS LOAD and BITE>")
T.equal(line(5), "<PERF FACTORS           ", "<PERF FACTORS")
T.equal(line(7), "<IRS MONITOR            ", "<IRS MONITOR")
T.equal(line(12), "------------------------", "the line above <INDEX")
T.equal(line(13), "<INDEX                  ", "<INDEX")
key("ls_key/L6")
T.check(page("INIT/REF INDEX"), "<INDEX: INIT/REF INDEX (before: ACMS)")
key("ls_key/R6")
key("ls_key/L2")

-- PERF FACTORS without entries (FMSPG p.265's form; ATA34_2 p.681's values)
T.equal(line(1), "      PERF FACTORS      ", "<PERF FACTORS: PERF FACTORS")
T.equal(small(2), " PERF CODE   OPTION CODE", "PERF CODE, OPTION CODE")
T.equal(line(3), "1111        000001004806", "1111, the option code")
T.equal(small(4), " DRAG/F-F        R/C CLB", "DRAG/F-F, R/C CLB")
T.equal(line(5), "+0.0/+0.0            300", "+0.0/+0.0, 300")
T.equal(small(6), " TO 1/TO 2       THR/CRZ", "TO 1/TO 2, THR/CRZ")
T.equal(line(7), " -8/-20          CRZ/100", "-8/-20 (PW), CRZ/100 (P&W's since 2026-11-14)")
T.equal(small(8), " MNVR MARGIN     THR RED", "MNVR MARGIN, THR RED")
T.equal(line(9), "1.30             FLAPS 5", "1.30, FLAPS 5")
T.equal(small(10), " MIN CRZ TIME   ACCEL HT", "MIN CRZ TIME, ACCEL HT")
T.equal(line(11), "5              1000/1000", "5, 1000/1000")
T.equal(line(13), "<INDEX               ---", "6R --- before ARM")

-- static before ARM
enter("1.5/-2.0", "L2")
T.equal(pad(), "INVALID ENTRY", "an entry before ARM: INVALID ENTRY")
clear()
enter("XYZ", "R6")
T.equal(pad(), "INVALID ENTRY", "6R: XYZ is not the code")
clear()
enter("ARM", "R6")
T.equal(line(13), "<INDEX               ARM", "ARM at 6R (ATA34_2 p.679)")
T.equal(pad(), "", "the scratchpad taken")

-- the entries
enter("1.5/-2.0", "L2")
T.equal(line(5), "+1.5/-2.0            300", "DRAG/F-F +1.5/-2.0")
T.check(rt:get(CFG):find('"PERF"', 1, true) ~= nil, "kept in the simconfig (FMC.PERF)")
T.check(rt:get(CFG):find('"drag_ff":"+1.5/-2.0"', 1, true) ~= nil, "FMC.INIT.drag_ff too")
frames(0.2)
T.near(fms.ns.B747_perf_db.DRAG_F, 1.015, 1e-9, "the performance data's drag factor 1.015")
T.near(fms.ns.B747_perf_db.FF_F, 0.98, 1e-9, "the fuel flow's 0.98")
enter("1", "L1")
T.equal(pad(), "INVALID ENTRY", "PERF CODE: not an entry")
clear()
enter("1", "R1")
T.equal(pad(), "INVALID ENTRY", "OPTION CODE: not an entry")
clear()
delete("L4")
T.equal(pad(), "INVALID DELETE", "DELETE: INVALID DELETE")
clear()
enter("1.35", "L4")
T.equal(pad(), "INVALID ENTRY", "MNVR MARGIN 1.35: INVALID ENTRY")
clear()
enter("/25", "L3")
T.equal(line(7), " -8/-25          CRZ/100", "TO 2 25")
enter("1.25", "L4")
T.equal(line(9), "1.25             FLAPS 5", "MNVR MARGIN 1.25")
frames(0.2)
T.near(rt:get("laminar/B747/fms/mnvr_margin"), 1.25, 1e-9, "laminar/B747/fms/mnvr_margin 1.25")
T.near(fms.ns.B747_perf_db.MARGIN_G, 1.25, 1e-9, "the maximum altitude's margin 1.25")
enter("12", "L5")
enter("100", "R2")
enter("CLB/", "R3")
T.equal(line(11):sub(1, 2), "12", "MIN CRZ TIME 12")
T.equal(line(7), " -8/-25          CLB/100", "THR/CRZ CLB/100 (entered over P&W's CRZ)")
T.equal(fms.ns.B747_fms_perf_factors().thr_crz, "CLB", "the cruise's limit CLB")
T.equal(line(5), "+1.5/-2.0            100", "R/C CLB 100")
enter("1200", "R4")
enter("800/1500", "R5")
T.equal(line(9), "1.25                1200", "THR RED 1200")
T.equal(line(11), "12              800/1500", "ACCEL HT 800/1500")

-- leaving the page deletes the code (FMSPG p.268)
key("ls_key/L6")
key("ls_key/L2")
T.equal(line(13), "<INDEX               ---", "back on the page: --- again")
enter("1.0", "L2")
T.equal(pad(), "INVALID ENTRY", "an entry: INVALID ENTRY again")
clear()

-- IDENT's DRAG/FF (ATA34_2 p.678)
key("ls_key/L6")
key("ls_key/L6")
key("ls_key/L1")
T.check(page("IDENT"), "IDENT")
T.equal(line(7):gsub("%s+$", ""), "+1.5/-2.0", "IDENT's DRAG/FF +1.5/-2.0")

-- THRUST LIM's TO 2 derate
key("ls_key/L6")
key("ls_key/L4")
T.check(page("THRUST LIM"), "THRUST LIM")
T.equal(line(9):sub(1, 6), "<-25 %", "TO 2's derate -25 %")
T.equal(line(7):sub(1, 5), "<-8 %", "TO 1's -8 %")

-- TAKEOFF REF: the defaults stay until the flight's completion (ATA34_2
-- p.678)
key("ls_key/L6")
key("ls_key/L5")
T.check(page("TAKEOFF REF"), "TAKEOFF REF")
T.equal(left(small(7)), "FLAPS 5", "THR REDUCTION FLAPS 5 still")
T.equal(left(small(5)), "1000FT", "E/O ACCEL HT 1000FT still")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
seconds(5)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
seconds(5)
for i = 0, 3 do rt:set(INOP, i, 1) end
seconds(31)
T.equal(left(small(7)), "1200FT", "after the flight: THR REDUCTION 1200FT")
T.equal(left(small(5)), "800FT", "E/O ACCEL HT 800FT")
T.equal(left(small(3)), "  /1500FT", "ACCEL HT /1500FT")
enter("5", "L3")
T.equal(line(7):sub(1, 7), "FLAPS 5", "THR REDUCTION 5 entered")
delete("L3")
T.equal(left(small(7)), "1200FT", "DELETE: PERF FACTORS' 1200FT")

-- in the air the index's prompts are blank and do nothing
key("ls_key/L6")
key("ls_key/R6")
T.check(page("MAINTENANCE INDEX"), "MAINTENANCE INDEX")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(0.5)
T.equal(line(5), "                        ", "in the air: <PERF FACTORS blank")
key("ls_key/L2")
T.check(page("MAINTENANCE INDEX"), "2L in the air: nothing")
T.done()
