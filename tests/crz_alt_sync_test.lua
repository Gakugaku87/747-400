-- Run from the repository root with Lua 5.1 or LuaJIT.
-- CRZ ALT hand-over from the 747 to the native X-Plane FMS: the entry format
-- (FL330 above the transition altitude, feet below it), clearing the native
-- scratchpad before typing, keeping the 747 value when the native FMS refuses
-- it, the CDU CRZ ALT entry, and the cruise climb started 2 s after the ALT
-- selector push.  The native FMS is a mock that refuses five-digit feet above
-- its transition altitude and whose CLR removes one character at a time; this
-- does not validate the native FMS itself.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local failures = {}
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
-- Each case runs on its own, so one failure still reports the others.
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then failures[#failures+1] = name..": "..tostring(err) end
end
local function read_slice(path, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), "missing marker "..first_marker)
    local last = assert(source:find(last_marker, first, true), "missing marker "..last_marker)
    return source:sub(first, last-1)
end
local function load_in(path, runtime, first_marker, last_marker)
    local source = read_slice(path, first_marker, last_marker)
    setfenv(assert(loadstring(source, "@"..path)), runtime)()
end
-- Load one "elseif" branch of a long if-chain as function(fmsO,value).
local function load_branch(path, runtime, first_marker, last_marker)
    local source = "return function(fmsO,value) if false then "
        ..read_slice(path, first_marker, last_marker).."\nend end"
    return setfenv(assert(loadstring(source, "@"..path)), runtime)()
end
local function clear_list(list)
    for i=#list,1,-1 do list[i] = nil end
end

local step = dofile(FMS.."B744.fms.step.lua")

-- Native FMS mock (cdu1) behind the left CDU.  VNAV page 2 R1 is CRZ ALT; it
-- takes FLxxx, three digits, or feet below the transition altitude.
local native = {}
local keys_pressed = {}
local lines = {}
local function refresh_native_lines()
    for i=1,14 do lines[i] = string.rep(" ", 24) end
    lines[3] = string.rep(" ", 19)..string.format("%5s", native.crz)
    if native.msg ~= "" then
        lines[14] = step.fixed_width("["..native.msg.."]", 24)
    else
        lines[14] = step.fixed_width(native.scratch, 24)
    end
end
local function native_accepts(entry)
    local altitude = nil
    if string.match(entry, "^FL%d%d%d$") then
        altitude = tonumber(string.sub(entry, 3))*100
    elseif string.match(entry, "^%d%d%d$") then
        altitude = tonumber(entry)*100
    elseif string.match(entry, "^%d%d%d%d%d?$") then
        altitude = tonumber(entry)
        if altitude >= native.transition then return nil end
    end
    if altitude == nil or altitude < 1000 or altitude > native.limit then return nil end
    if altitude >= native.transition then
        return string.format("FL%03d", altitude/100)
    end
    return string.format("%d", altitude)
end
local function press(key)
    keys_pressed[#keys_pressed+1] = key
    if key == "fpln" then
        native.page = "RTE"
    elseif key == "clb" then
        native.page = "VNAV1"
    elseif key == "next" then
        if native.page == "VNAV1" then native.page = "VNAV2" end
    elseif key == "clear" then
        -- Worst case: the message goes first, then one character per press.
        if native.msg ~= "" then
            native.msg = ""
        elseif native.scratch == "DELETE" then
            native.scratch = ""
        else
            native.scratch = string.sub(native.scratch, 1, -2)
        end
    elseif key == "del" then
        if native.msg == "" and native.scratch == "" then native.scratch = "DELETE" end
    elseif key == "R1" then
        native.scratch_at_r1 = native.scratch
        assert(native.page == "VNAV2", "R1 pressed off the native VNAV CRZ page")
        if native.scratch ~= "" then
            local accepted = native_accepts(native.scratch)
            if accepted ~= nil then
                native.crz, native.scratch = accepted, ""
            else
                native.msg = "INVALID ENTRY"
            end
        end
    elseif string.len(key) == 1 then
        -- Typing does not remove what is already there.
        native.scratch = native.scratch..key
    end
    refresh_native_lines()
end
local key_commands = setmetatable({}, {__index=function(commands, key)
    local command = {once=function() press(key) end}
    rawset(commands, key, command)
    return command
end})

-- XTLua re-arms an existing timer for the same function.
local timers = {}
local function find_timer(callback)
    for i=1,#timers do
        if timers[i].callback == callback then return i end
    end
    return nil
end
local function cdu(id) return {id=id, scratchpad="", notify=""} end
local r = setmetatable({
    print=function() end,
    B747_fms_step=step,
    B747DR_srcfms={fmsL=lines},
    simCMD_FMS_key={fmsL=key_commands},
    simDR_GRWT=300000,
    simDR_fms_transition_alt=0,
    B747BR_cruiseAlt=0,
    B747DR_crzalt_sync_fault=0,
    is_timer_scheduled=function(callback) return find_timer(callback) ~= nil end,
    stop_timer=function(callback)
        local index = find_timer(callback)
        if index ~= nil then table.remove(timers, index) end
    end,
    run_after_time=function(callback, delay)
        local index = find_timer(callback)
        if index ~= nil then table.remove(timers, index) end
        timers[#timers+1] = {callback=callback, delay=delay}
    end
}, {__index=_G})
r.fmsL, r.fmsC, r.fmsR = cdu("fmsL"), cdu("fmsC"), cdu("fmsR")
r.fmsModules = {fmsL=r.fmsL, fmsC=r.fmsC, fmsR=r.fmsR, data={crzalt="*****"},
    setData=function(self, id, value)
        self.data[id] = step.fixed_width(value, string.len(self.data[id]))
    end}
load_in(FMS.."B744.fms.pages.lua", r, "function validAlt(value)", "function validFL(value)")
load_in(FMS.."B744.fms.pages.lua", r,
    'local updateFrom="fmsL"', "function fmsFunctions.getdata(fmsO,value)")

local function run_next_timer()
    local timer = table.remove(timers, 1)
    assert(timer ~= nil, "no timer was scheduled")
    timer.callback()
    return timer
end
local function typed_tail(count)
    local first = math.max(1, #keys_pressed-count+1)
    return table.concat(keys_pressed, ",", first, #keys_pressed)
end
local function reset_native(crz)
    native.page, native.scratch, native.msg = "", "", ""
    native.crz, native.limit, native.transition = crz, 45000, 18000
    native.scratch_at_r1 = nil
    refresh_native_lines()
end
-- A read-back with nothing pending is what a CDU entry gets: the 747 CRZ ALT
-- takes the native value.  The first call settles anything an earlier failed
-- case left pending.
local function synchronise(crz)
    reset_native(crz)
    r.updateCRZ()
    r.updateCRZ()
    clear_list(timers)
    clear_list(keys_pressed)
    r.fmsL.notify, r.fmsC.notify, r.fmsR.notify = "", "", ""
end

case("native CRZ ALT entry format", function()
    local entry = step.native_cruise_altitude_entry
    equal(entry(33000, 18000), "FL330", "33000 FT above the transition altitude")
    equal(entry(31237, 18000), "FL312", "odd altitudes round to the nearest flight level")
    equal(entry(10000, 18000), "10000", "feet below the transition altitude")
    equal(entry(18000, 18000), "FL180", "the transition altitude itself is a flight level")
    equal(entry(0, 18000), nil, "no entry for CRZ ALT 0")
    equal(entry(nil, 18000), nil, "no entry for an unknown CRZ ALT")
    equal(entry("33000", nil), "FL330", "an unknown transition altitude is the native 18000")
    equal(entry(10000, nil), "10000", "below the default transition altitude")
    equal(entry(10000, 0), "10000", "transition altitude 0 also means the native 18000")
    equal(entry(10000, 5000), "FL100", "the native transition altitude is used when set")
end)

case("ALT selector CRZ ALT reaches the native FMS as FL330", function()
    synchronise("FL310")
    equal(tonumber(r.B747BR_cruiseAlt), 31000, "read-back sets the 747 CRZ ALT")
    r.B747BR_cruiseAlt = 33000
    r.monitorCRZALT()
    local typed = typed_tail(6)
    run_next_timer()
    equal(tonumber(r.B747BR_cruiseAlt), 33000, "the new CRZ ALT is not put back")
    equal(step.trim(r.fmsModules.data.crzalt), "FL330", "CDU CRZ ALT shows FL330")
    equal(typed, "F,L,3,3,0,R1", "CRZ ALT 33000 is typed as FL330")
    equal(native.crz, "FL330", "native FMS accepts FL330")
    equal(r.B747DR_crzalt_sync_fault, 0, "no synchronisation fault")
end)

case("CRZ ALT 0 types nothing", function()
    synchronise("FL310")
    r.B747BR_cruiseAlt = 0
    r.monitorCRZALT()
    r.monitorCRZALT()
    equal(#keys_pressed, 0, "nothing is typed for CRZ ALT 0")
    equal(#timers, 0, "no read-back is scheduled for CRZ ALT 0")
end)

case("leftover native scratchpad is cleared first", function()
    synchronise("FL310")
    native.scratch, native.msg = "33000", "INVALID ENTRY"
    refresh_native_lines()
    r.B747BR_cruiseAlt = 35000
    r.monitorCRZALT()
    equal(native.scratch_at_r1, "FL350", "only the new entry is in the scratchpad at R1")
    run_next_timer()
    equal(native.crz, "FL350", "native FMS accepts the new entry")
    equal(tonumber(r.B747BR_cruiseAlt), 35000, "the new CRZ ALT is not put back")
end)

case("native refusal keeps the 747 CRZ ALT", function()
    synchronise("FL310")
    native.limit = 32000
    r.B747BR_cruiseAlt = 33000
    r.monitorCRZALT()
    equal(native.msg, "INVALID ENTRY", "the mock native FMS refuses FL330")
    run_next_timer()
    equal(tonumber(r.B747BR_cruiseAlt), 33000, "the 747 keeps the CRZ ALT the native FMS refused")
    equal(step.trim(r.fmsModules.data.crzalt), "FL330", "CDU CRZ ALT shows the 747 value")
    equal(r.B747DR_crzalt_sync_fault, 1, "synchronisation fault is raised")
    equal(native.scratch, "", "the refused entry is cleared from the native scratchpad")
    equal(native.msg, "", "the native INVALID ENTRY is cleared")
    clear_list(keys_pressed)
    r.monitorCRZALT()
    equal(#keys_pressed, 0, "the refused value is not typed again")
    equal(#timers, 1, "the CDU message is shown after the native scratchpad is clear")
    check(timers[1].delay >= 0.5, "the CDU message waits for the native clear")
    run_next_timer()
    check(string.find(r.fmsC.notify, "CRZ ALT", 1, true) ~= nil, "centre CDU shows the fault")
    check(string.find(r.fmsL.notify, "CRZ ALT", 1, true) ~= nil, "left CDU shows the fault")
end)

case("CDU-path read-back is still authoritative", function()
    native.limit = 45000
    native.crz = "FL350"
    refresh_native_lines()
    r.updateCRZ()
    equal(tonumber(r.B747BR_cruiseAlt), 35000, "read-back with nothing pending sets the 747 CRZ ALT")
    equal(r.B747DR_crzalt_sync_fault, 0, "an accepted CDU value clears the fault")
end)

case("odd CRZ ALT is accepted as the nearest flight level", function()
    synchronise("FL310")
    r.B747BR_cruiseAlt = 31237
    r.monitorCRZALT()
    equal(typed_tail(6), "F,L,3,1,2,R1", "31237 is typed as FL312")
    run_next_timer()
    equal(tonumber(r.B747BR_cruiseAlt), 31237, "the 747 keeps its own CRZ ALT")
    equal(step.trim(r.fmsModules.data.crzalt), "FL312", "CDU CRZ ALT shows the native value")
    equal(r.B747DR_crzalt_sync_fault, 0, "FL312 is within 50 FT of 31237")
    clear_list(keys_pressed)
    r.monitorCRZALT()
    equal(#keys_pressed, 0, "the accepted value is not typed again")
end)

case("CDU CRZ ALT entry reaches the native FMS as FL330", function()
    local sent = nil
    local no_key = {once=function() end}
    local cdu_runtime = setmetatable({
        print=function() end,
        simDR_inReplay=0,
        validAlt=r.validAlt,
        setFMSData=function() end,
        simCMD_FMS_key={fmsL=setmetatable({}, {__index=function() return no_key end})},
        fmsFunctions={custom2fmc=function(fmsO, value)
            equal(value, "R1", "CRZ ALT goes to native R1")
            sent, fmsO.scratchpad = fmsO.scratchpad, ""
        end},
        B747DR_srcfms={fmsL=lines},
        run_after_time=function() end,
        updateCRZ=function() end,
        B747_fms_step=step,
        simDR_fms_transition_alt=0,
        fmsModules={setData=function() end},
        pendingCrz=33000
    }, {__index=_G})
    local crzalt_entry = load_branch(FMS.."B744.fms.pages.lua", cdu_runtime,
        'elseif value=="crzalt" then', 'elseif value=="irspos" then')
    for _,input in ipairs({"33000", "330", "FL330"}) do
        sent = nil
        crzalt_entry({id="fmsL", scratchpad=input, notify=""}, "crzalt")
        equal(sent, "FL330", "CDU entry "..input.." is sent as FL330")
    end
    crzalt_entry({id="fmsL", scratchpad="10000", notify=""}, "crzalt")
    equal(sent, "10000", "CDU entry below the transition altitude stays in feet")
    equal(cdu_runtime.pendingCrz, nil, "a CDU entry makes the native read-back authoritative")
end)

-- The cruise climb itself starts 2 s after the ALT selector push.
local helpers = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")
local descent_calls = 0
local ap = setmetatable({
    print=function() end,
    B747_afds_helpers=helpers,
    B747DR_alt_capture_window=235,
    setVNAVState=function() end,
    getVNAVState=function() return 0 end,
    B747_invalidate_vnav_speed=function() end,
    B747_vnav_speed=function() end,
    setDescent=function() descent_calls = descent_calls + 1 end,
    getDescentTarget=function() end,
    simDRTime=100
}, {__index=_G})
load_in(AP.."B747.70.xt.autopilot.lua", ap, "function update_new_crzalt()",
    "function B747_ap_switch_vnavalt_mode_CMDhandler(phase, duration)")
local function cruise_climb_after_push(crz, altitude, mcp, remaining, tod)
    ap.B747BR_cruiseAlt, ap.simDR_pressureAlt1, ap.B747DR_autopilot_altitude_ft = crz, altitude, mcp
    ap.B747BR_totalDistance, ap.B747BR_tod = remaining, tod
    ap.simDR_autopilot_alt_hold_status, ap.B747DR_ap_vnav_state, ap.B747DR_ap_flightPhase = 2, 2, 2
    ap.B747DR_ap_inVNAVdescent, ap.B747DR_mcp_hold = 0, 1
    descent_calls = 0
    ap.update_new_crzalt()
end

case("cruise climb decision", function()
    local action = helpers.cruise_climb_action
    equal(action(33000, 31000, 276.3, 235), "climb", "CRZ ALT above the aircraft, T/D far")
    equal(action(31000, 30997, 276.3, 235), "cancelled", "CRZ ALT put back to the level flown")
    equal(action(31300, 31000, 276.3, 235), "climb", "a step just above the capture window")
    equal(action(35000, 32985, -60.6, 235), "tod", "T/D already passed")
    equal(action(35000, 32985, 50, 235), "tod", "within 50 NM of T/D")
end)

case("CRZ ALT put back before the climb starts", function()
    cruise_climb_after_push(31000, 30997, 33000, 390.1, 113.8)
    equal(ap.simDR_autopilot_alt_hold_status, 2, "altitude hold stays engaged")
    equal(ap.B747DR_ap_vnav_state, 2, "VNAV stays in cruise")
    equal(ap.B747DR_ap_flightPhase, 2, "flight phase stays cruise")
end)

case("ALT push near T/D neither climbs nor descends", function()
    cruise_climb_after_push(35000, 32985, 35000, 60.1, 120.7)
    equal(ap.B747DR_ap_inVNAVdescent, 0, "no descent is started")
    equal(descent_calls, 0, "no descent path is set up")
    equal(ap.simDR_autopilot_alt_hold_status, 2, "altitude hold stays engaged")
end)

case("cruise climb still starts", function()
    cruise_climb_after_push(33000, 31000, 33000, 390.1, 113.8)
    equal(ap.simDR_autopilot_alt_hold_status, 0, "altitude hold is released for the climb")
    equal(ap.B747DR_ap_vnav_state, 3, "VNAV resumes")
    equal(ap.B747DR_ap_flightPhase, 1, "flight phase is climb")
    equal(descent_calls, 0, "no descent path is set up")
end)

if #failures > 0 then
    for _,failure in ipairs(failures) do print("FAIL "..failure) end
    error(#failures.." CRZ ALT synchronisation case(s) failed", 0)
end
print("CRZ ALT synchronisation tests passed: "..checks)
