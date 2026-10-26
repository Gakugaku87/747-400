-- Run from the repository root with LuaJIT: luajit tests/fms/fmc_fixes_test.lua
-- The FMC's and CDU's small fixes (6-1/6-2 step 1; notes/ATA-34-61-FMC.md
-- §10) in the FMS module (B747.68.xt.fms) as XTLua runs it
-- (tests/lib/xtlua.lua): the VNAV CLB page's ECON SPD 340 (estimate, FCOM PI
-- p.316), SPD TRANS from VREF 30 + 100 kt, deleted only, SPD RESTR dashes
-- until entered (FCOM p.1328), the DES page's (FCOM p.1392); the THRUST LIM
-- page's <GA, <CON and <CRZ in the air (CDU-10); APPROACH REF's FLAP/SPEED
-- (FCOM p.1412); PERF INIT's CRZ CG (FCOM p.1311); the EMERGENCY REPORT's
-- DIVERT TO (FCOM p.729).
local T = dofile("tests/lib/check.lua")("fmc_fixes")
local xtlua = dofile("tests/lib/xtlua.lua")

-- X-Plane's own CDUs' lines (byte arrays the mock does not type)
local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
-- the CDUs' power (no keys without it: 6-1/6-2 step 2)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:set("laminar/B747/airspeed/Vf30", 178)
rt:callout("flight_start")
-- X-Plane's own CDUs' lines: blank (the mock's 0 would show as a message)
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the left CDU: its keys fms1, its lines fms3 (setDREFs)
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function small(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_S", n)) end
local function key(k)
    rt:command("laminar/B747/fms1/" .. k)
    frames(1)
end
local function type_in(text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
end
local function clear_all()
    for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end
    frames(0.2)
end

-- the VNAV CLB page
key("func_key/des")
T.check(line(1):find("CLB"), "the VNAV CLB page: " .. line(1))
T.check(line(5):find("^340"), "ECON SPD 340 (before 250, SPD TRANS's speed): " .. line(5))
T.check(line(7):find("^278/10000"), "SPD TRANS 278/10000: VREF 30 178 + 100 (before a fixed 272): " .. line(7))
T.check(line(9):find("^%-%-%-/%-%-%-%-%-"), "SPD RESTR ---/----- (before 250/5000): " .. line(9))
rt:set("laminar/B747/airspeed/Vf30", 140)
frames(0.5)
T.check(line(7):find("^250/10000"), "VREF 30 140: SPD TRANS 250 (the greater): " .. line(7))
type_in("250")
key("ls_key/L3")
T.equal(line(14):gsub("%s+$", ""), "INVALID ENTRY", "an entry into SPD TRANS: INVALID ENTRY (deleted only)")
clear_all()
key("key/del")
key("ls_key/L3")
T.check(line(7):find("^%-%-%-/"), "SPD TRANS deleted: dashes: " .. line(7))
frames(1)
T.check(line(7):find("^%-%-%-/"), "and it stays deleted: " .. line(7))
type_in("240/8000")
key("ls_key/L4")
T.check(line(9):find("^240/8000"), "SPD RESTR 240/8000 entered: " .. line(9))
key("key/del")
key("ls_key/L4")
T.check(line(9):find("^%-%-%-/%-%-%-%-%-"), "SPD RESTR deleted: dashes again: " .. line(9))
key("func_key/next_pg")
key("func_key/next_pg")
T.check(line(1):find("DES"), "the VNAV DES page: " .. line(1))
T.check(line(9):find("^%-%-%-/%-%-%-%-%-"), "the DES page's SPD RESTR ---/----- (before 180/5000): " .. line(9))
T.check(line(7):find("^240/10000"), "the DES page's SPD TRANS 240/10000: " .. line(7))

-- THRUST LIM in the air (sim/flightmodel/failures/onground_any 0)
rt:set("laminar/B747/engine/derate/TO", 1)
key("func_key/index")
key("ls_key/L6")  -- <INDEX: INIT/REF INDEX (the INIT REF key goes by context: step 3a)
key("ls_key/L4")
T.check(line(5):find("<GA"), "THRUST LIM in the air: <GA: " .. line(5))
key("ls_key/L2")
T.equal(line(14):gsub("%s+$", ""), "KEY/FUNCTION INOP", "<GA in the air: KEY/FUNCTION INOP (the thrust management's, 6-4)")
T.equal(rt:get("laminar/B747/engine/derate/TO"), 1, "the takeoff derate stays TO 1 (before: TO, and TO 1/TO 2 cut the GA thrust)")
clear_all()
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(0.5)
key("func_key/index")
key("ls_key/L6")  -- <INDEX: INIT/REF INDEX (the INIT REF key goes by context: step 3a)
key("ls_key/L4")
key("ls_key/L2")
T.equal(rt:get("laminar/B747/engine/derate/TO"), 0, "on the ground <TO selects TO")
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(0.5)

-- APPROACH REF's FLAP/SPEED
key("func_key/index")
key("ls_key/L6")  -- <INDEX: INIT/REF INDEX (the INIT REF key goes by context: step 3a)
key("ls_key/L6")
T.check(line(1):find("APPROACH REF"), "APPROACH REF: " .. line(1))
T.check(line(9):find("%-%-/%-%-%-$"), "FLAP/SPEED --/--- until entered (before boxes): " .. line(9))
key("ls_key/R4")
T.equal(line(14):gsub("%s+$", ""), "", "the empty scratchpad, nothing entered: nothing copied (before: VREF cleared)")
type_in("/150")
key("ls_key/R4")
T.check(rt:get("laminar/B747/airspeed/Vref") == 150 and rt:get("laminar/B747/airspeed/VrefFlap") == 2,
    "/150: VREF 150, flaps 30 (estimate; before: XX/YYY only)")
T.check(line(9):find("30/150$"), "30/150 shown: " .. line(9))
key("ls_key/R4")
T.equal(line(14):gsub("%s+$", ""), "30/150", "the empty scratchpad: the value copied")
T.equal(rt:get("laminar/B747/airspeed/VrefFlap"), 2, "VREF stays")
clear_all()
type_in("25/155")
key("ls_key/R4")
T.check(rt:get("laminar/B747/airspeed/Vref") == 155 and rt:get("laminar/B747/airspeed/VrefFlap") == 1, "25/155: flaps 25")
type_in("160")
key("ls_key/R4")
T.check(rt:get("laminar/B747/airspeed/Vref") == 160 and rt:get("laminar/B747/airspeed/VrefFlap") == 1, "160 alone: flaps 25 kept")
type_in("20/150")
key("ls_key/R4")
T.equal(line(14):gsub("%s+$", ""), "INVALID ENTRY", "flaps 20: INVALID ENTRY")
clear_all()
key("key/del")
key("ls_key/R4")
T.equal(rt:get("laminar/B747/airspeed/VrefFlap"), 0, "DELETE: VREF off the PFD")
T.check(line(9):find("%-%-/%-%-%-$"), "and --/--- again: " .. line(9))

-- PERF INIT's CRZ CG
key("func_key/index")
key("ls_key/L6")  -- <INDEX: INIT/REF INDEX (the INIT REF key goes by context: step 3a)
key("ls_key/L3")
T.check(line(1):find("PERF INIT"), "PERF INIT: " .. line(1))
type_in("A")
key("ls_key/R4")
T.equal(line(14):gsub("%s+$", ""), "INVALID ENTRY", "CRZ CG A: INVALID ENTRY (before stored, the page's drawing stopped)")
clear_all()
type_in("40")
key("ls_key/R4")
T.equal(line(14):gsub("%s+$", ""), "INVALID ENTRY", "CRZ CG 40: INVALID ENTRY (8.5 to 33.0)")
clear_all()
type_in("25.5")
key("ls_key/R4")
T.check(line(9):find("25%.5%%"), "CRZ CG 25.5 %: " .. line(9))
T.check(line(1):find("PERF INIT"), "the page still drawn")
key("key/del")
key("ls_key/R4")
T.check(small(9):find("20%.0%%"), "DELETE: the default 20.0 % in small font: " .. small(9))

-- the EMERGENCY REPORT's DIVERT TO
key("func_key/crz")
key("ls_key/L1")
T.check(line(1):find("EMERGENCY REPORT"), "EMERGENCY REPORT: " .. line(1))
T.check(small(5):find("^ %*%*%*%*"), "DIVERT TO: the destination (none) by default: " .. small(5))
type_in("RJTT")
key("ls_key/L2")
T.check(small(5):find("^ RJTT"), "RJTT entered: " .. small(5))
T.check(rt:get("laminar/B747/fms/data"):find('"fltdst":"****"', 1, true), "the route's destination unchanged (before: RJTT, sent to X-Plane's FMS)")
T.equal(#small(5), 24, "the line 24 characters")
key("key/del")
key("ls_key/L2")
T.check(small(5):find("^ %*%*%*%*"), "DELETE: the destination again: " .. small(5))

T.done()
