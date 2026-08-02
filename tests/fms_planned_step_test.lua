local step = dofile(
    "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.step.lua")
local json = dofile(
    "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/json/json.lua")

local tests_run = 0

local function assert_equal(actual,expected,message)
    tests_run=tests_run+1
    assert(actual==expected,(message or "values differ")..": expected "
        ..tostring(expected)..", got "..tostring(actual))
end

local function assert_nil(value,message)
    tests_run=tests_run+1
    assert(value==nil,message or "expected nil")
end

local function assert_contains(value,expected,message)
    tests_run=tests_run+1
    assert(string.find(tostring(value or ""),expected,1,true)~=nil,
        (message or "text missing")..": expected "..expected.." in "..tostring(value))
end

local stored_fix=step.fixed_width("FITES",12)
assert_equal(string.len(stored_fix),12,
    "planned-step waypoint field keeps its fixed width")
assert_equal(step.trim(stored_fix),"FITES",
    "five-character waypoint survives fixed-width storage")
assert_equal(step.trim(step.fixed_width("KAE",12)),"KAE",
    "three-character waypoint survives fixed-width storage")
assert_equal(step.trim(step.fixed_width("NRE160025",12)),"NRE160025",
    "generated waypoint survives fixed-width storage")
assert_equal(step.fixed_width("TOOLONG",5),"TOOLO",
    "fixed-width values truncate to the field width")

assert_equal(step.altitude_token("FL350S"),"FL350",
    "standard planned-step entry")
assert_equal(step.altitude_token("/FL350S"),"FL350",
    "altitude-only planned-step entry")
assert_equal(step.altitude_token("350S"),"350",
    "planned-step entry accepts a flight level without the FL prefix")
assert_equal(step.altitude_token("/350S"),"350",
    "altitude-only entry accepts a flight level without the FL prefix")
assert_equal(step.altitude_token("fl350s"),"FL350",
    "planned-step entry is case insensitive")
assert_nil(step.altitude_token("FL350"),
    "ordinary altitude constraint is not a planned step")
assert_nil(step.altitude_token("S"),
    "planned-step suffix requires an altitude")

local function route_leg(name,altitude,active)
    return {0,0,0,0,0,0,0,name,altitude,active==true}
end

local flight_plan={
    route_leg("START",29000,true),
    route_leg("ALPHA",29000,false),
    route_leg("BRAVO",29000,false),
    route_leg("CHARL",29000,false),
    route_leg("DELTA",29000,false),
    route_leg("ECHO",29000,false)
}

assert_equal(step.page_number("  ACT RTE 1 LEGS    1/3 "),1,
    "LEGS page number is parsed from the page fraction")
assert_equal(step.page_number("  ACT RTE 1 LEGS   12/12"),12,
    "multi-digit LEGS page number is parsed")
local resolved_waypoint,resolved_index=step.resolve_leg_row(
    flight_plan,1,1,3,"BRAVO            FL290")
assert_equal(resolved_waypoint,"BRAVO",
    "displayed LEGS waypoint resolves to the route waypoint")
assert_equal(resolved_index,3,
    "displayed LEGS row resolves to the route index")
local page_two_waypoint,page_two_index=step.resolve_leg_row(
    flight_plan,1,2,1,"ECHO             FL290")
assert_equal(page_two_waypoint,"ECHO",
    "LEGS page offset resolves the correct waypoint")
assert_equal(page_two_index,6,
    "LEGS page offset resolves the correct route index")
local _,missing_index=step.resolve_leg_row(
    flight_plan,1,1,1,"MISSING          FL290")
assert_nil(missing_index,
    "a waypoint absent from the route remains unresolved")

local unresolved_plan=step.upsert({},"MISSING","FL310",nil)
assert_equal(step.valid_climb_sequence(
    unresolved_plan,flight_plan,29000,1),false,
    "unresolved route entries cannot create a planned-step MOD")
assert_equal(step.exec_light_value(0,0,true),1,
    "planned-step MOD illuminates the combined EXEC light")
assert_equal(step.exec_light_value(0.75,0,false),0.75,
    "native FMC EXEC illumination remains visible")

local active_plan=step.upsert({},"BRAVO","FL310",3)
local modified_plan=step.normalize_list(active_plan)
modified_plan=step.upsert(modified_plan,"DELTA","FL330",5)
assert_equal(#active_plan,1,
    "MOD entry leaves the active planned-step list unchanged")
assert_equal(#modified_plan,2,
    "MOD entry is retained in the provisional planned-step list")
assert_equal(step.lists_equal(active_plan,modified_plan,flight_plan),false,
    "pending vertical-profile change is detected")

local executed_plan=step.normalize_list(modified_plan)
assert_equal(step.lists_equal(executed_plan,modified_plan,flight_plan),true,
    "EXEC can promote the complete provisional list")
local erased_plan=step.normalize_list(active_plan)
assert_equal(step.lists_equal(erased_plan,active_plan,flight_plan),true,
    "ERASE can restore the unchanged active list")

local planned={}
planned=step.upsert(planned,"BRAVO","FL310",3)
planned=step.upsert(planned,"DELTA","FL330",5)
assert_equal(#planned,2,
    "adding a second planned step retains the first")
assert_equal(step.entry_at_index(planned,flight_plan,3).altitude,"FL310",
    "first planned step remains attached to its waypoint")
assert_equal(step.entry_at_index(planned,flight_plan,5).altitude,"FL330",
    "second planned step is stored independently")
assert_equal(step.planned_altitude_for_index(planned,flight_plan,4,29000),31000,
    "first step altitude propagates to following cruise legs")
assert_equal(step.planned_altitude_for_index(planned,flight_plan,6,29000),33000,
    "second step altitude propagates to its following cruise legs")
assert_equal(step.valid_climb_sequence(planned,flight_plan,29000),true,
    "ascending multiple-step plan is valid")
assert_equal(step.valid_climb_sequence(planned,flight_plan,31000,4),true,
    "completed steps do not invalidate later plan edits")
local descending_plan=step.upsert(planned,"DELTA","FL300",5)
assert_equal(step.valid_climb_sequence(descending_plan,flight_plan,29000),false,
    "later planned steps must remain above earlier step altitudes")

local next_step,next_index=step.next_entry(planned,flight_plan,1,29000)
assert_equal(next_step.waypoint,"BRAVO",
    "next-step selection starts with the first route step")
assert_equal(next_index,3,
    "next-step selection publishes the first route index")
next_step,next_index=step.next_entry(planned,flight_plan,4,31000)
assert_equal(next_step.waypoint,"DELTA",
    "next-step selection advances after passing the first step")
assert_equal(next_index,5,
    "next-step selection publishes the second route index")

planned=step.upsert(planned,"DELTA","FL350",5)
assert_equal(#planned,2,
    "editing one planned step does not duplicate or erase another")
assert_equal(step.entry_at_index(planned,flight_plan,5).altitude,"FL350",
    "editing updates only the selected planned step")

local restored=json.decode(json.encode(planned))
assert_equal(#restored,2,
    "serialized FMS storage retains multiple planned steps")
assert_equal(step.entry_at_index(restored,flight_plan,3).altitude,"FL310",
    "serialized FMS storage retains the first planned step")

planned=step.remove(planned,"BRAVO",3)
assert_equal(#planned,1,
    "deleting one planned step retains the others")
assert_equal(planned[1].waypoint,"DELTA",
    "remaining planned step survives deletion")

local displayed_steps=step.upsert({},"BRAVO","FL310",3)
B747_fms_step=step
fmsPages={}
fmsFunctionsDefs={LEGS={}}
function createPage(name)
    return {name=name,getSmallPage=function() return {} end}
end
function cleanFMSLine(line) return tostring(line or "") end
function string.starts(value,prefix)
    return string.sub(value,1,string.len(prefix))==prefix
end
fmsModules={data={crzalt="FL290"}}
B747BR_cruiseAlt=29000
fmsFlightPlan=json.encode(flight_plan)
fmsJSON="[]"
B747DR_srcfms={fmsL={}}
for line=1,14,1 do B747DR_srcfms.fmsL[line]=string.rep(" ",24) end
B747DR_srcfms.fmsL[1]="  ACT RTE 1 LEGS    1/2 "
local function displayed_leg(name,altitude)
    return string.format("%-18s%6s",name,altitude)
end
B747DR_srcfms.fmsL[3]=displayed_leg("START","FL290")
B747DR_srcfms.fmsL[5]=displayed_leg("ALPHA","FL290")
B747DR_srcfms.fmsL[7]=displayed_leg("BRAVO","FL290")
B747DR_srcfms.fmsL[9]=displayed_leg("CHARL","FL290")
B747DR_srcfms.fmsL[11]=displayed_leg("DELTA","FL290")
function B747_hasPlannedStepModification() return true end
function B747_getDisplayedPlannedSteps() return displayed_steps end
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/activepages/B744.fms.pages.legs.lua")

local waypoint,route_index,display_flight_plan=
    B747_getLegStepWaypoint({id="fmsL"},"R3")
assert_equal(waypoint,"BRAVO",
    "real LEGS row lookup returns the programmed waypoint")
assert_equal(route_index,3,
    "real LEGS row lookup returns a usable route index")
assert_equal(#display_flight_plan,#flight_plan,
    "LEGS input and display share the same decoded flight plan")

local mod_page=fmsPages.LEGS:getPage(1,"fmsL")
assert_contains(mod_page[1],"MOD RTE 1 LEGS",
    "pending step displays the MOD LEGS title")
assert_equal(string.sub(mod_page[7],19,24),"FL310S",
    "pending step altitude is rendered on its LEGS row")
assert_contains(mod_page[13],"<ERASE",
    "pending step displays the ERASE prompt")

run_after_time=function() end
switchCustomMode=function() end
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.createfms.lua")
local modification_executed=false
local native_exec_forwarded=false
B747_executePlannedStepModification=function()
    modification_executed=true
    return true
end
simCMD_FMS_key.test={
    exec={once=function() native_exec_forwarded=true end}
}
keyDown("test","exec")
assert_equal(modification_executed,true,
    "EXEC promotes a pending planned-step modification")
assert_equal(native_exec_forwarded,true,
    "EXEC also reaches the native FMC modification handler")

print("FMS planned-step tests passed: "..tests_run)
