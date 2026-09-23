-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Renders the production VNAV CLB page against the FCOM page layout:
--   *     ACT ECON CLB   1/3 *      *     ACT 230KT CLB  1/3 *
--   * ECON SPD   ERR AT RUBEL*      * SEL SPD    ERR AT RUBEL*
--   *280/.780     350LO 2LONG*
-- Simulator interfaces are mocked; this validates page text only.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": ["..tostring(actual).."] ~= ["
        ..tostring(expected).."]")
end

local step = dofile(FMS.."B744.fms.step.lua")
local data = {clbspd="280", clbmach="780", clbspdmode="ECON", crzalt="FL350",
    transpd="250", spdtransalt="10000", transalt="18000", clbrestspd="---",
    clbrestalt="-----", crzspd="810", stepsize="ICAO"}
local runtime = setmetatable({
    print=function() end,
    fmsPages={},
    fmsFunctionsDefs={VNAV={}},
    fmsModules={data=data},
    createPage=function(name) return {name=name} end,
    find_dataref=function() return 0 end,
    B747_fms_step=step,
    json=dofile(FMS.."json/json.lua"),
    fmsJson="[]",
    simConfigData={data={SIM={weight_display_units="KGS", kgs_to_lbs=2.205}}},
    simDR_groundspeed=250,
    simDR_pressureAlt1=12000,
    simDR_onGround=0,
    B747DR_airspeed_V2=160,
    B747DR_ap_flightPhase=0
}, {__index=_G})
setfenv(assert(loadfile(FMS.."activepages/B744.fms.pages.vnav.lua")), runtime)()

local function page()
    return runtime.fmsPages.VNAV:getPage(1, "fmsL")
end
local function smallPage()
    return runtime.fmsPages.VNAV:getSmallPage(1, "fmsL")
end

-- ECON climb, armed and then active.
equal(page()[1], "       ECON CLB         ", "armed ECON CLB title")
runtime.B747DR_ap_flightPhase = 1
equal(page()[1], "     ACT ECON CLB       ", "active ECON CLB title")
equal(smallPage()[4], " ECON SPD          ERROR", "ECON SPD label")

-- ECON SPD is a CAS/Mach pair, not a bare CAS.
equal(page()[5]:sub(1, 8), "280/.780", "ECON SPD shows the CAS/Mach pair")

-- A crew-entered climb speed selects a fixed-speed climb.  The FCOM title is
-- "ACT 230KT CLB" - the xxxKT form the reference pages also use for
-- "ACT E/O 230KT CLB" and "ACT 230KT DES" - in the same columns as ECON.
data.clbspdmode = "SEL "
data.clbspd = "230"
equal(page()[1], "     ACT 230KT CLB      ", "active selected-speed CLB title")
runtime.B747DR_ap_flightPhase = 0
equal(page()[1], "       230KT CLB        ", "armed selected-speed CLB title")
equal(smallPage()[4], " SEL SPD           ERROR", "SEL SPD label")
equal(page()[5]:sub(1, 8), "230/.780",
    "a selected CAS keeps the scheduled climb Mach")

-- SPD REST reads "---/-----" until the crew enters one, and the page must
-- render a blank field rather than an invented 250/5000 restriction.
equal(smallPage()[8], " SPD REST      MAX ANGLE", "SPD REST label")
equal(page()[9]:sub(1, 9), "---/-----", "SPD REST is blank by default")
data.clbrestspd = "210"
data.clbrestalt = "8000 "
equal(page()[9]:sub(1, 9), "210/8000 ", "an entered SPD REST is displayed")
data.clbrestspd = "---"
data.clbrestalt = "-----"

for _, line in ipairs(page()) do
    checks = checks + 1
    assert(string.len(line) == 24,
        "CLB page line is not 24 columns: ["..line.."]")
end

print("VNAV CLB page tests passed: "..checks)
