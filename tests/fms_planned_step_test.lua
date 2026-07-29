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
    local leg={}
    leg[8]=name
    leg[9]=altitude
    leg[10]=active==true
    return leg
end

local flight_plan={
    route_leg("START",29000,true),
    route_leg("ALPHA",29000,false),
    route_leg("BRAVO",29000,false),
    route_leg("CHARL",29000,false),
    route_leg("DELTA",29000,false),
    route_leg("ECHO",29000,false)
}

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
