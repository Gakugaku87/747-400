-- Run from the repository root with LuaJIT: luajit tests/fms/fixinfo_pages_test.lua
-- FIX INFO (6-1/6-2 step 7e3b; notes/ATA-34-61-FMC.md §39) in the FMS module
-- as XTLua runs it (tests/lib/xtlua.lua), on the synthetic navigation data
-- in tests/fms/data/navdb, the active route ZZAA RW16R, ALPHA, Z1 to CHARL,
-- ZZBB: the FIX key, the boxes and headers, FIX (SELECT DESIRED WPT, NOT
-- IN DATA BASE, no DELETE, the copy), BRG/DIS FR, BRG/DIS (a radial, a
-- distance, both; the crossings, DTG; the copy and its entry on the LEGS
-- page; DELETE), <ABEAM (INVALID ENTRY without one, the copy), <ERASE FIX,
-- PRED ETA-ALT, the second page, both CDUs (FCOM p.1358-1359; FMSPG
-- p.166-169).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("fixinfo_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

local CDU = {L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"},
             R = {keys = "laminar/B747/fms2/", lines = "laminar/B747/fms2/"}}
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
local function onces(suffix)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.phase == "once" and tostring(e.name):find(suffix .. "$") then n = n + 1 end
    end
    return n
end
local BLANK = string.rep(" ", 24)
local R = fms.ns.B747_route_model
local st = fms.ns.B747_fmc_route

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

-- the page (FMSPG p.166's figure)
local x0 = onces("FMS/fix")
key("L", "func_key/dir_intc")
T.equal(onces("FMS/fix"), x0, "the FIX key: the FMC's page, no X-Plane FIX key (before: X-Plane's FIX page)")
T.equal(line("L", 1), "      FIX INFO          ", "FIX INFO (FCOM p.1358)")
T.equal(small("L", 1), "                    1/2 ", "1/2")
T.equal(small("L", 2), " FIX  BRG/DIS FR        ", "FIX and BRG/DIS FR")
T.equal(line("L", 3), "*****                   ", "the FIX boxes (FMSPG p.166)")
T.equal(small("L", 4), " BRG/DIS ETA   DTG   ALT", "BRG/DIS ETA DTG ALT")
T.equal(line("L", 5) .. line("L", 11), BLANK .. BLANK, "nothing more without a fix")
T.equal(small("L", 12), "            PRED ETA-ALT", "PRED ETA-ALT")
T.equal(line("L", 13), string.rep(" ", 19) .. "-----", "its dashes; no ERASE FIX without a fix (FMSPG p.168)")

-- FIX
enter("L", "QQQQ", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "QQQQ: NOT IN DATA BASE")
clear("L")
enter("L", "N35E140", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "a lat/lon: NOT IN DATA BASE (the database's points: FCOM p.1358)")
clear("L")
enter("L", "ZB002", "L1")
local fx = {lat = 35.95, lon = 140.7646}
local c, d = R.course(fx.lat, fx.lon, 35, 140)
local function brg3(b) local n = math.floor(b + 0.5) % 360 return string.format("%03d", n == 0 and 360 or n) end
T.equal(line("L", 3), (string.format("%-8s%s/%d", "ZB002", brg3(c + 7), math.floor(d + 0.5)) .. BLANK):sub(1, 24),
    "ZB002 and the airplane's bearing (magnetic: 7 W) and distance from it (FMSPG p.167)")
T.equal(line("L", 5), "---/---                 ", "BRG/DIS dashes (FMSPG p.167's figure)")
T.equal(small("L", 10), " ABEAM                  ", "ABEAM")
T.equal(line("L", 11), "<ABEAM                  ", "<ABEAM (FMSPG p.168)")
T.check(line("L", 13):find("^<ERASE FIX"), "<ERASE FIX")
key("L", "key/del")
key("L", "ls_key/L1")
T.equal(pad("L"), "INVALID DELETE", "no DELETE of the fix (FMSPG p.167: ERASE FIX only)")
clear("L")
key("L", "ls_key/L1")
T.equal(pad("L"), "ZB002", "an empty scratchpad copies the fix")
clear("L")

-- BRG/DIS: a radial, a distance, both (FCOM p.1358-1359; FMSPG p.167-168)
local path = R.fix_path(st, {lat = 35, lon = 140})
enter("L", "263", "L2")
local rx = R.fix_radial(path, fx, 256, 512)
local _, rd = R.course(fx.lat, fx.lon, rx.lat, rx.lon)
local dtg = tostring(math.floor(rx.dtg + 0.5))
T.equal(line("L", 5), "263/" .. string.rep(" ", 14 - #dtg) .. dtg .. string.rep(" ", 6), "263: the radial entered, its DTG (" .. dtg .. ")")
T.equal(small("L", 5), "    " .. tostring(math.floor(rd + 0.5)) .. string.rep(" ", 20 - #tostring(math.floor(rd + 0.5))),
    "its crossing's distance in small font after the slash (FMSPG p.167)")
enter("L", "/20", "L3")
local cx = R.fix_circle(path, fx, 20)
local cb = brg3(R.course(fx.lat, fx.lon, cx.lat, cx.lon) + 7)
T.check(line("L", 7):find("^   /20") and small("L", 7):sub(1, 3) == cb, "/20: the crossing's bearing in small font before it: " .. small("L", 7))
T.equal(line("L", 7):sub(15, 18), string.format("%4d", math.floor(cx.dtg + 0.5)), "its DTG")
enter("L", "090/10", "L4")
T.equal(line("L", 9), "090/10                  ", "a bearing and a distance: no crossing (FCOM p.1359)")
enter("L", "361", "L4")
T.equal(pad("L"), "INVALID ENTRY", "361: INVALID ENTRY")
clear("L")
enter("L", "/0", "L4")
T.equal(pad("L"), "INVALID ENTRY", "/0: INVALID ENTRY")
clear("L")
key("L", "key/del")
key("L", "ls_key/L4")
T.equal(line("L", 9), "---/---                 ", "DELETE: dashes again")
key("L", "ls_key/L2")
T.equal(pad("L"), string.format("ZB002263.0/%05.1f", math.floor(rd * 10 + 0.5) / 10), "the copy: ABC180.0/026.4's form (FCOM p.1359)")
local copy = pad("L")

-- ABEAM (FMSPG p.168)
clear("L")
key("L", "ls_key/L5")
local ab = R.fix_abeam(path, fx)
local _, abd = R.course(fx.lat, fx.lon, ab.lat, ab.lon)
local abb = brg3(R.course(fx.lat, fx.lon, ab.lat, ab.lon) + 7)
T.check(line("L", 11):find("^" .. abb .. "/" .. math.floor(abd + 0.5) .. " ") and line("L", 11):sub(15, 18) == string.format("%4d", math.floor(ab.dtg + 0.5)),
    "<ABEAM: the bearing and distance square to the route, DTG: " .. line("L", 11))
key("L", "ls_key/L5")
T.check(pad("L"):find("^ZB002" .. abb .. "%.%d/0" .. math.floor(abd) .. "%.%d$"), "pushed again: its place/bearing/distance copied: " .. pad("L"))
clear("L")
key("L", "key/del")
key("L", "ls_key/L5")
T.equal(line("L", 11), "<ABEAM                  ", "DELETE: the prompt again")

-- the copy on the LEGS page: a waypoint (FCOM p.1359)
key("L", "func_key/legs")
enter("L", copy, "L4")
T.equal(line("L", 9):sub(1, 6), "ZB001 ", "the copy after CHARL: ZB001 (ZB002's first three, 01)")
local f = st.mod.legs[4].fix
local fc, fd = R.course(fx.lat, fx.lon, f.lat, f.lon)
T.check(math.abs((fc + 7) - 263) < 0.01 and math.abs(fd - rd) < 0.06, "on the 263 radial where it crosses the route")
key("L", "ls_key/L6")

-- ERASE FIX, PRED ETA-ALT, the second page, the other CDU
key("L", "func_key/dir_intc")
enter("L", "1234Z", "R6")
T.equal(line("L", 13):sub(20, 24), "1234 ", "PRED ETA-ALT 1234Z (FMSPG p.169)")
T.equal(small("L", 13):sub(24, 24), "z", "z in small font")
enter("L", "FL190", "R6")
T.equal(line("L", 13):sub(20, 24), "FL190", "FL190")
enter("L", "2460Z", "R6")
T.equal(pad("L"), "INVALID ENTRY", "24:60: INVALID ENTRY")
clear("L")
key("L", "ls_key/L6")
T.equal(line("L", 3), "*****                   ", "<ERASE FIX: the boxes again (FMSPG p.168)")
T.equal(line("L", 13), string.rep(" ", 19) .. "FL190", "PRED ETA-ALT kept")
key("L", "key/del")
key("L", "ls_key/R6")
T.equal(line("L", 13), string.rep(" ", 19) .. "-----", "DELETE: dashes")
enter("L", "ALPHA", "L1")
key("L", "ls_key/L1")
frames(0.6)
T.check(line("L", 3):find("^ALPHA"), "ALPHA, the nearer, by SELECT DESIRED WPT")
key("L", "func_key/next_pg")
T.equal(small("L", 1), "                    2/2 ", "NEXT: 2/2")
T.equal(line("L", 3), "*****                   ", "the second page's own fix")
enter("L", "ZZD", "L1")
key("L", "func_key/next_pg")
T.check(small("L", 1):find("1/2") and line("L", 3):find("^ALPHA"), "NEXT: back to 1/2 with ALPHA")
key("R", "func_key/dir_intc")
T.check(line("R", 3):find("^ALPHA"), "the right CDU: the same fixes (the FMC's)")
key("R", "func_key/next_pg")
T.check(line("R", 3):find("^ZZD"), "and its second page")

T.done()
