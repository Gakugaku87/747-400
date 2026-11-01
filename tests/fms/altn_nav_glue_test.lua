-- Run from the repository root with LuaJIT: luajit tests/fms/altn_nav_glue_test.lua
-- The CDUs' alternate navigation in the FMS module as XTLua runs it
-- (6-1/6-2 step 11e1; notes/ATA-34-61-FMC.md §102; FCOM p.1275,
-- p.1421-1424; FMSPG p.248-249; tests/lib/xtlua.lua) on the synthetic
-- navigation data: an active route ZZAA 16R, ALPHA, Z1 to CHARL, ZZBB;
-- both FMCs failed: the MENU page without <FMC, LEGS the ACT IRS LEGS page
-- with the CDU's copy of the route (the active course magnetic, the others
-- true, the distances, the coordinates); a latitude/longitude entered: MOD
-- IRS LEGS, that CDU's EXEC light, EXEC; the right CDU's copy unchanged;
-- in flight the left CDU's active waypoint sequenced on the left IRU.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("altn_nav_glue")
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
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
local IRS = "laminar/B747/irs/"
local function iru(i, lat, lon)
    rt:set(IRS .. "nav_valid", i, 1)
    rt:set(IRS .. "lat", i, lat)
    rt:set(IRS .. "lon", i, lon)
    rt:set(IRS .. "gs", i, 250)
end
for i = 0, 2 do iru(i, 35, 140) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

local CDU = {fmsL = {k = "laminar/B747/fms1/", d = "laminar/B747/fms3/"},
    fmsR = {k = "laminar/B747/fms2/", d = "laminar/B747/fms2/"}}
local function line(n, cdu) return rt:get(string.format("%sLine%02d_L", CDU[cdu or "fmsL"].d, n)) end
local function small(n, cdu) return rt:get(string.format("%sLine%02d_S", CDU[cdu or "fmsL"].d, n)) end
local function pad(cdu) return (line(14, cdu):gsub("%s+$", "")) end
local function key(k, cdu) rt:command(CDU[cdu or "fmsL"].k .. k) frames(0.3) end
local function type_in(text)
    for ch in text:gmatch(".") do
        rt:command(CDU.fmsL.k .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
end
local function enter(text, lsk) type_in(text) key("ls_key/" .. lsk) end
local FAIL = "laminar/B747/fms/fail"

-- the route: ZZAA 16R, DIRECT ALPHA, Z1 to CHARL, ZZBB; ACTIVATE, EXEC
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("Z1", "L2")
enter("CHARL", "R2")
key("func_key/legs")
key("ls_key/R6")
key("key/execute")
frames(1.5)
local copy = fms.ns.B747_fms_altn("fmsL")
T.check(#copy.legs >= 2 and copy.legs[1].ident == "ALPHA", "the CDU's copy of the active route (FMSPG p.248): " .. tostring(copy.legs[1] and copy.legs[1].ident))
local second = copy.legs[2].ident

-- both FMCs failed: MENU without <FMC; LEGS the ACT IRS LEGS page
rt:set(FAIL, 0, 1)
rt:set(FAIL, 1, 1)
frames(0.3)
T.check(line(1):find("MENU"), "both FMCs failed: MENU")
T.equal(line(3):sub(1, 17), string.rep(" ", 17), "no <FMC (FCOM p.1275)")
key("key/clear")
key("func_key/legs")
T.check(line(1):find("ACT IRS LEGS"), "LEGS: ACT IRS LEGS (FCOM p.1423): " .. line(1))
T.check(line(3):find("^ALPHA%s+N3%d`%d%d%.%d E14%d`%d%d%.%d$"), "ALPHA and its coordinates: " .. line(3))
T.check(small(2):find("^ %d%d%d`M"), "the active leg's course magnetic (FMSPG p.249): " .. small(2))
T.check(not small(2):find("NM"), "no distance for the active leg")
T.check(small(4):find("^ %d%d%d`T%s+%d+NM"), "the next leg's course true with its distance: " .. small(4))
T.check(line(5):find("^" .. second), "then " .. second)
T.check(small(1):find("1/%d"), "the page number")
T.equal(line(12), "------------------------", "the separator")

-- a latitude/longitude on 2L: MOD IRS LEGS, the left CDU's EXEC light
enter("N3510.0E14010.0", "L2")
T.check(line(1):find("MOD IRS LEGS"), "MOD IRS LEGS")
T.check(line(5):find("^N35E140"), "N35E140 on line 2: " .. line(5))
T.equal(line(7), "*****                   ", "a ROUTE DISCONTINUITY after it")
T.check(small(6):find("THEN"), "THEN over the boxes")
T.check(line(13):find("^<ERASE"), "<ERASE at 6L")
T.equal(rt:get("laminar/B747/fms/exec_light_pilot"), 1, "the left CDU's EXEC light")
T.equal(rt:get("laminar/B747/fms/exec_light_copilot"), 0, "not the right CDU's")
key("key/execute")
T.check(line(1):find("ACT IRS LEGS"), "EXEC: ACT IRS LEGS")
T.equal(rt:get("laminar/B747/fms/exec_light_pilot"), 0, "the EXEC light off")
-- the right CDU's own copy unchanged (FCOM p.1422)
key("key/clear", "fmsR")
key("func_key/legs", "fmsR")
T.check(line(1, "fmsR"):find("ACT IRS LEGS"), "the right CDU: ACT IRS LEGS")
T.check(line(5, "fmsR"):find("^" .. second), "its line 2 still " .. second .. " (a change to one CDU not the others)")
-- an identifier not in the route
enter("ZZZ", "L3")
T.equal(pad(), "INVALID ENTRY", "an identifier not in the route: INVALID ENTRY (FMSPG p.248)")
for _ = 1, 4 do key("key/clear") end      -- the message, then ZZZ
-- DELETE on the active waypoint
key("key/del")
key("ls_key/L1")
T.equal(pad(), "INVALID DELETE", "DELETE on the active waypoint: INVALID DELETE")
key("key/clear")

-- in flight: the left IRU past ALPHA: the left CDU's next waypoint active
rt:set("sim/flightmodel/failures/onground_any", 0)
local a, from = copy.legs[1], copy.from
iru(0, a.lat + (a.lat - from.lat) * 0.2, a.lon + (a.lon - from.lon) * 0.2)
frames(1.5)
T.check(line(3):find("^N35E140"), "ALPHA passed on the left IRU: N35E140 active (FCOM p.1421)")
T.equal(fms.ns.B747_fms_altn("fmsL").last.ident, "ALPHA", "LAST ALPHA")
key("func_key/legs", "fmsR")
T.check(line(3, "fmsR"):find("^ALPHA"), "the right CDU on its own IRU: still ALPHA")

-- (6-1/6-2 step 11e2) PROG: IRS PROGRESS (FCOM p.1425-1426; FMSPG
-- p.250-251) on the left CDU's own route and IRU
key("func_key/prog")
T.check(line(1):find("IRS PROGRESS"), "PROG: IRS PROGRESS: " .. line(1))
T.check(line(3):find("^ALPHA"), "LAST ALPHA: " .. line(3))
T.check(small(2):find("^ LAST%s+ALT"), "LAST and ALT")
T.check(line(5):find("^N35E140%s+%d+NM%s+%d%d:%d%d$"), "TO N35E140, its DTG and TTG at 250 kt: " .. line(5))
T.check(small(4):find("^ TO%s+DTG%s+TTG$"), "the TO line's titles")
T.check(line(9):find("^ZZBB%s+%d+NM%s+%d%d:%d%d$"), "DEST ZZBB along the route: " .. line(9))
T.check(small(8):find("^ DEST"), "DEST")
T.check(small(10):find("^ IRS L%s+GS$"), "IRS L (the left CDU's IRU) and GS: " .. small(10))
T.check(line(11):find("^N3%d`%d%d%.%d E14%d`%d%d%.%d%s+250KT$"), "its position and ground speed: " .. line(11))
T.check(line(13):find("^[LR] %d+%.%dNM"), "XTK ERROR: " .. line(13))
T.check(small(12):find("XTK ERROR%s+DTK%s+TK"), "the last line's titles")
-- 4L: a route waypoint ENROUTE WPT; the page left and shown again: DEST
for _ = 1, 3 do key("key/clear") end      -- (DELETE left from above)
enter(second, "L4")
T.check(small(8):find("^ ENROUTE WPT"), "a route waypoint on 4L: ENROUTE WPT (FMSPG p.251)")
T.check(line(9):find("^" .. second), "its distance and time")
key("func_key/legs")
key("func_key/prog")
T.check(small(8):find("^ DEST"), "the page left: DEST again (FMSPG p.251)")
key("func_key/prog", "fmsR")
T.check(small(10, "fmsR"):find("^ IRS R"), "the right CDU: IRS R")
T.check(line(5, "fmsR"):find("^ALPHA"), "its TO still ALPHA (its own IRU)")

-- (6-1/6-2 step 11e3) NAV RAD: ALTN NAV RADIO (FCOM p.1427-1428; FMSPG
-- p.252-254): an entry tunes the left CDU's side at once (FCOM p.1422);
-- PRESELECT down-selected; the right radios untouched
local NAVF, OBS = "sim/cockpit2/radios/actuators/nav_frequency_hz", "sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot"
local vorR = rt:get(NAVF, 3)
key("func_key/navrad")
T.check(line(1):find("ALTN NAV RADIO"), "NAV RAD: ALTN NAV RADIO: " .. line(1))
T.check(small(2):find("^ VOR") and small(4):find("^ CRS") and small(6):find("^ ADF") and small(8):find("^ ILS%-MLS"), "VOR, CRS, ADF, ILS-MLS")
T.check(small(12):find("PRESELECT"), "PRESELECT")
for _ = 1, 3 do key("key/clear") end
enter("114.50/270", "L1")
T.equal(rt:get(NAVF, 2), 11450, "VOR L (NAV3) 114.50 at once")
T.near(rt:get(OBS, 2), 270, 1e-6, "its course 270")
T.check(line(3):find("^114%.50") and small(3):find("^      M"), "1L 114.50 with M")
T.check(line(5):find("^270"), "2L 270")
T.equal(string.sub(rt:get("laminar/B747/radio/tuningmodes"), 2, 2), "M", "VOR L manual")
enter("109.50/157", "L4")
T.equal(rt:get(NAVF, 0), 10950, "ILS L (NAV1) 109.50")
T.near(rt:get(OBS, 0), 157, 1e-6, "its course 157")
T.equal(rt:get("laminar/B747/autopilot/ils_dots"), 1, "the PFDs' ILS scales")
T.check(line(9):find("^109%.50/157"), "4L 109.50/157")
enter("1304.5B", "L3")
T.equal(rt:get("sim/cockpit2/radios/actuators/adf1_frequency_hz"), 1304, "ADF L 1304")
T.equal(string.sub(rt:get("laminar/B747/radio/tuningmodes"), 4, 4), "B", "BFO")
T.check(line(7):find("^1304%.5") and small(7):find("BFO"), "3L 1304.5 BFO")
enter("110.90/128", "L6")
T.check(line(13):find("^110%.90/128"), "PRESELECT 6L")
key("ls_key/L6")
T.equal(pad(), "110.90/128", "6L down-selected into the scratchpad (FMSPG p.254)")
key("ls_key/L4")
T.equal(rt:get(NAVF, 0), 11090, "into 4L: ILS L 110.90")
key("key/del")
key("ls_key/L4")
T.check(line(9):find("^PARK"), "DELETE: PARK")
T.equal(rt:get("laminar/B747/autopilot/ils_dots"), 0, "no ILS tuned: no scales")
T.equal(rt:get(NAVF, 3), vorR, "VOR R untouched (the right CDU's)")

-- an FMC back: the copies the FMC's route again
rt:set(FAIL, 0, 0)
frames(1.5)
T.equal(fms.ns.B747_fms_altn("fmsL").legs[1].ident, "ALPHA", "the left FMC back: the copy the FMC's route again")

T.done()
