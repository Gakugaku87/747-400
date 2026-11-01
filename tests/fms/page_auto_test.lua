-- Run from the repository root with LuaJIT: luajit tests/fms/page_auto_test.lua
-- The CDUs' automatic page changes (6-1/6-2 step 12b; notes/ATA-34-61-FMC.md
-- §106) in the FMS module as XTLua runs it (tests/lib/xtlua.lua): a CDU on
-- the active VNAV page goes from CLB to CRZ at the T/C and from CRZ to DES
-- at the T/D (FCOM p.1345), one on another page stays; the 570's TAKEOFF
-- REF to VNAV CLB as the flap lever starts the retraction in the takeoff
-- phase (FCOM p.1325), the 109's stays. The FMC's phase page is set
-- through B747_fms_vnav_page.
local T = dofile("tests/lib/check.lua")("page_auto")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/flightmodel/weight/m_total", 300000)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
-- the left CDU (keys fms1) and the right (fms2)
local KEYS = {L = "laminar/B747/fms1/", R = "laminar/B747/fms2/"}
local IDS = {L = "fmsL", R = "fmsR"}
local function key(c, k) rt:command(KEYS[c] .. k) frames(0.1) end
local function shown(c)
    local o = fms.ns.fmsModules[IDS[c]]
    return o.currentPage .. " " .. o.pgNo
end
local active = 0
local realPage = fms.ns.B747_fms_vnav_page
fms.ns.B747_fms_vnav_page = function() return active end
local function phase(p) active = p frames(0.2) end
for _, c in ipairs({"L", "R"}) do key(c, "ls_key/L1") end

-- in the air, the climb: the VNAV key opens CLB, the active page
rt:set("sim/flightmodel/failures/onground_any", 0)
phase(1)
key("L", "func_key/des")
T.equal(shown("L"), "VNAV 1", "the climb: the VNAV key's CLB page")
key("R", "func_key/legs")
T.check(shown("R"):find("^LEGS"), "the right CDU on LEGS: " .. shown("R"))
phase(2)
T.equal(shown("L"), "VNAV 2", "T/C: CLB to CRZ (FCOM p.1345)")
T.check(shown("R"):find("^LEGS"), "the right CDU stays on LEGS")
-- a look at the DES page in the cruise, then CRZ again
key("L", "func_key/next_pg")
T.equal(shown("L"), "VNAV 3", "NEXT: the DES page")
key("L", "func_key/prev_pg")
T.equal(shown("L"), "VNAV 2", "PREV: CRZ")
-- the right CDU on the CLB page (not the active one) through the T/D
key("R", "func_key/des")
key("R", "func_key/prev_pg")
T.equal(shown("R"), "VNAV 1", "the right CDU: CLB, not active")
phase(3)
T.equal(shown("L"), "VNAV 3", "T/D: CRZ to DES")
T.equal(shown("R"), "VNAV 1", "the right CDU on CLB stays (not the active page)")
-- a missed approach (DES to CLB): no change in FCOM
phase(1)
T.equal(shown("L"), "VNAV 3", "DES to CLB (a missed approach): the DES page stays")
-- CLB straight to DES (a short flight): neither of FCOM's changes
key("R", "func_key/des")
T.equal(shown("R"), "VNAV 1", "the right CDU: the active CLB page")
phase(3)
T.equal(shown("R"), "VNAV 1", "CLB to DES: the CLB page stays")
-- a cruise climb (CRZ CLB on the CRZ page, B747_fms_vnav_page 2) and its end
phase(2)
key("L", "func_key/des")
T.equal(shown("L"), "VNAV 2", "the cruise: CRZ")
fms.ns.B747_fms_vnav_page = function() return 2, "CLB" end
frames(0.2)
T.equal(shown("L"), "VNAV 2", "CRZ CLB: the CRZ page")
fms.ns.B747_fms_vnav_page = function() return active end
frames(0.2)
T.equal(shown("L"), "VNAV 2", "at the new cruise altitude: CRZ")
-- no route or on the ground (0) and back: no change
phase(0)
phase(2)
T.equal(shown("L"), "VNAV 2", "0 to CRZ: stays")

-- the takeoff: TAKEOFF REF on the left CDU, the flap lever from 20 to 10
local FLAPS = "sim/cockpit2/controls/flap_ratio"
local function takeoff(engine)
    rt:set("laminar/B747/engines/type", engine)
    rt:set("sim/flightmodel/failures/onground_any", 1)
    rt:set(FLAPS, 0.5)
    phase(0)
    key("L", "func_key/index")
    key("L", "ls_key/L6")
    key("L", "ls_key/L5")
    T.equal(shown("L"), "TAKEOFF 1", "on the ground: TAKEOFF REF")
    T.equal(fms.ns.B747_fms_thrlim().mode, "TO", "the thrust limit TO")
    rt:set("sim/flightmodel/failures/onground_any", 0)
    frames(0.5)
    rt:set(FLAPS, 0.333)
    frames(0.2)
end
takeoff(0)
T.equal(shown("L"), "TAKEOFF 1", "the 109 (PW): the flaps retracting, TAKEOFF REF stays")
takeoff(1)
T.equal(shown("L"), "VNAV 1", "the 570 (GE): the flaps retracting, VNAV CLB (FCOM p.1325)")
-- the 570 with the flap lever down again: nothing
key("L", "func_key/index")
key("L", "ls_key/L6")
T.check(shown("L"):find("^INITREF"), "INIT/REF INDEX in the air: " .. shown("L"))
rt:set(FLAPS, 0.5)
frames(0.2)
T.check(shown("L"):find("^INITREF"), "the flap lever down: no change: " .. shown("L"))

fms.ns.B747_fms_vnav_page = realPage
T.done()
