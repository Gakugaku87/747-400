local ndPlan=dofile(
  "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.nd.lua")

local testsRun=0

local function assert_equal(actual,expected,message)
  testsRun=testsRun+1
  assert(actual==expected,(message or "values differ")..": expected "
    ..tostring(expected)..", got "..tostring(actual))
end

local function route_leg(name)
  return {0,0,0,0,0,0,0,name,29000,false}
end

local route={
  route_leg("RJAA"),
  route_leg("ALPHA"),
  route_leg("BRAVO"),
  route_leg("CHARL")
}

local waypoint,index=ndPlan.selected_plan_waypoint(route,{3})
assert_equal(waypoint,"BRAVO",
  "PLN selection resolves the selected route waypoint instead of the origin")
assert_equal(index,3,"PLN selection retains the route index")
assert_equal(ndPlan.display_waypoint("RJAA",route,{2},3),"ALPHA",
  "captain PLN mode displays the selected waypoint")
assert_equal(ndPlan.display_waypoint("RJAA",route,{4},3),"CHARL",
  "first officer PLN mode displays the selected waypoint")
assert_equal(ndPlan.display_waypoint("RJAA",route,{3},2),"RJAA",
  "MAP mode keeps the active waypoint display")
assert_equal(ndPlan.display_waypoint("RJAA",route,{8},3),"RJAA",
  "an out-of-range PLN selection keeps the active waypoint")

route[2][8]=" latlon "
assert_equal(ndPlan.display_waypoint("RJAA",route,{2},3),"-----",
  "coordinate-only PLN legs use the placeholder identifier")

print("ND PLN waypoint tests passed: "..testsRun)
