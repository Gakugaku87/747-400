local step = dofile(
    "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.step.lua")

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
assert_equal(step.altitude_token("fl350s"),"FL350",
    "planned-step entry is case insensitive")
assert_nil(step.altitude_token("FL350"),
    "ordinary altitude constraint is not a planned step")
assert_nil(step.altitude_token("S"),
    "planned-step suffix requires an altitude")

print("FMS planned-step tests passed: "..tests_run)
