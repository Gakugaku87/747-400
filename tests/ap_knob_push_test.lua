-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The MCP IAS/MACH selector push (speed knob) and ALT selector push
-- (altitude knob) when the release of the previous push never reached the
-- handler. XTLua does not pass the end phase of a command fired once
-- (command_once from FlyWithLua, a Web API activation of duration 0) to the
-- aircraft's handler, so the knob animation target stays "in" (1). The
-- handlers took a push that found the knob in as the release of the
-- previous push: they put the animation out and returned without acting,
-- so every second push was lost (2026-10-10, TST744L on the P2 branch: the
-- step-climb ALT push at ETARI was ignored after the one at BEDRA, both sent
-- with command_once). Loads the production handlers from
-- B747.70.xt.autopilot.lua with mocked interfaces.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
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
    setfenv(assert(loadstring(read_slice(path, first_marker, last_marker), "@"..path)), runtime)()
end

local function new_autopilot()
    local vnav = {manualVNAVspd=0}
    local r = setmetatable({
        print=function() end,
        B747CMD_fdr_log_spdmod={once=function() end},
        B747CMD_fdr_log_altmod={once=function() end},
        B747_ap_button_switch_position_target={[15]=0, [16]=0},
        B747DR_ap_vnav_state=2, B747DR_switchingIASMode=0,
        setVNAVState=function(key, value) vnav[key] = value end,
        getVNAVState=function(key) return vnav[key] end,
        speed_updates=0,
        B747_invalidate_vnav_speed=function() end,
        simDRTime=100, simDR_onGround=0, B747DR_ap_inVNAVdescent=0,
        B747BR_cruiseAlt=31000, simDR_autopilot_alt_hold_status=2, simDR_pressureAlt1=31000,
        B747DR_autopilot_altitude_ft=33000, simDR_autopilot_altitude_ft=31000,
        B747DR_ap_flightPhase=2, B747DR_mcp_hold=1,
        B747BR_totalDistance=1500, B747BR_tod=100,
        setFMSData=function() end,
        update_new_crzalt=function() end,
        is_timer_scheduled=function() return false end,
        stop_timer=function() end,
        scheduled=0,
    }, {__index=_G})
    r.B747_vnav_speed = function() r.speed_updates = r.speed_updates + 1 end
    r.run_after_time = function(callback, delay)
        if callback == r.update_new_crzalt then r.scheduled = r.scheduled + 1 end
    end
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function B747_ap_switch_vnavspeed_mode_CMDhandler(phase, duration)", "function update_new_crzalt()")
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function B747_ap_switch_vnavalt_mode_CMDhandler(phase, duration)",
        "function B747_ap_ias_mach_sel_button_CMDhandler(phase, duration)")
    return r, vnav
end

-- 1. Speed knob in VNAV: each push toggles the speed intervention. Two pushes
-- whose releases are lost: the second ends the intervention (it was taken
-- as the release and ignored).
local r, vnav = new_autopilot()
r.B747_ap_switch_vnavspeed_mode_CMDhandler(0, 0)
equal(vnav.manualVNAVspd, 1, "first speed knob push opens the speed intervention")
equal(r.B747_ap_button_switch_position_target[15], 1, "speed knob in after the push")
r.B747_ap_switch_vnavspeed_mode_CMDhandler(0, 0)
equal(vnav.manualVNAVspd, 0, "second speed knob push without a release in between ends the intervention")
equal(r.speed_updates, 1, "ending the intervention recomputes the VNAV speed")
equal(r.B747_ap_button_switch_position_target[15], 1, "speed knob in after the second push")

-- 2. Guard (passes before and after): with the releases the same two pushes
-- act, and the release puts the knob out.
r, vnav = new_autopilot()
r.B747_ap_switch_vnavspeed_mode_CMDhandler(0, 0)
r.B747_ap_switch_vnavspeed_mode_CMDhandler(2, 0)
equal(r.B747_ap_button_switch_position_target[15], 0, "speed knob out after the release")
r.B747_ap_switch_vnavspeed_mode_CMDhandler(0, 0)
r.B747_ap_switch_vnavspeed_mode_CMDhandler(2, 0)
equal(vnav.manualVNAVspd, 0, "push, release, push, release: intervention opened and ended")

-- 3. ALT knob in VNAV cruise with the MCP altitude above CRZ ALT: the push
-- makes it the new CRZ ALT and schedules the cruise climb. A second step
-- (FL330 to FL350) whose previous release was lost is not ignored.
r = new_autopilot()
r.B747_ap_switch_vnavalt_mode_CMDhandler(0, 0)
equal(r.B747BR_cruiseAlt, 33000, "first ALT push: CRZ ALT FL330")
equal(r.scheduled, 1, "first ALT push schedules the cruise climb")
equal(r.B747_ap_button_switch_position_target[16], 1, "ALT knob in after the push")
r.simDR_pressureAlt1, r.B747DR_autopilot_altitude_ft, r.simDRTime = 33000, 35000, 3100
r.B747_ap_switch_vnavalt_mode_CMDhandler(0, 0)
equal(r.B747BR_cruiseAlt, 35000, "second ALT push without a release in between: CRZ ALT FL350")
equal(r.scheduled, 2, "second ALT push schedules the cruise climb")
equal(r.B747_ap_button_switch_position_target[16], 1, "ALT knob in after the second push")

-- 4. Guard (passes before and after): with the release in between.
r = new_autopilot()
r.B747_ap_switch_vnavalt_mode_CMDhandler(0, 0)
r.B747_ap_switch_vnavalt_mode_CMDhandler(2, 0)
equal(r.B747_ap_button_switch_position_target[16], 0, "ALT knob out after the release")
r.simDR_pressureAlt1, r.B747DR_autopilot_altitude_ft, r.simDRTime = 33000, 35000, 3100
r.B747_ap_switch_vnavalt_mode_CMDhandler(0, 0)
r.B747_ap_switch_vnavalt_mode_CMDhandler(2, 0)
equal(r.B747BR_cruiseAlt, 35000, "push, release, push, release: CRZ ALT FL350")
equal(r.scheduled, 2, "both pushes schedule the cruise climb")

-- The VR controls (B747.99.VRcontrols.lua): the VR "use" button on the IAS or
-- ALT knob is one push, held from the button's press to its release. They
-- fired the push command once on the press and once more on the release,
-- which only worked while the handlers took the second push as the release;
-- with every push acting, a VR click pushed the knob twice. The commands are
-- modelled as XTLua delivers them: a command fired once reaches the handler
-- with its begin phase only, a held one (start, then stop) with both.
local VR = "plugins/xtlua/init/scripts/B747.99.VRcontrols/B747.99.VRcontrols.lua"
local function xtlua_command(handler)
    local held = false
    return {
        once=function() handler(0, 0) end,
        start=function() held = true; handler(0, 0) end,
        stop=function() if held then held = false; handler(2, 0.3) end end,
    }
end
local function new_vr(r)
    local pushes = {hdg=0}
    local handlers = {
        ["laminar/B747/button_switch/press_airspeed"]=r.B747_ap_switch_vnavspeed_mode_CMDhandler,
        ["laminar/B747/button_switch/press_altitude"]=r.B747_ap_switch_vnavalt_mode_CMDhandler,
        ["laminar/B747/autopilot/button_switch/heading_select"]=function(phase)
            if phase == 0 then pushes.hdg = pushes.hdg + 1 end
        end,
    }
    local vr = setmetatable({
        print=function() end,
        find_dataref=function() return 0 end,
        create_command=function() return {} end,
        find_command=function(name) return xtlua_command(handlers[name] or function() end) end,
    }, {__index=_G})
    setfenv(assert(loadfile(VR)), vr)()
    return vr, pushes
end
-- a VR click while the view points at `pressed` (and at `released` when the
-- button comes up)
local function vr_click(vr, pressed, released)
    vr.findHotSpot = function() return vr[pressed] end
    vr.VR_use_CMDhandler(0, 0)
    vr.findHotSpot = function() return vr[released or pressed] end
    vr.VR_use_CMDhandler(2, 0.3)
end

-- 5. A VR click on the speed knob in VNAV opens the speed intervention once
-- and leaves the knob out; the next click ends it.
r, vnav = new_autopilot()
local vr = new_vr(r)
vr_click(vr, "useIAS")
equal(vnav.manualVNAVspd, 1, "VR click on the speed knob opens the speed intervention")
equal(r.B747_ap_button_switch_position_target[15], 0, "speed knob out after the VR click")
vr_click(vr, "useIAS")
equal(vnav.manualVNAVspd, 0, "second VR click ends the speed intervention")

-- 6. A VR click on the ALT knob in VNAV cruise with the MCP above CRZ ALT
-- makes the MCP altitude the new CRZ ALT and leaves the climb to the
-- scheduled update_new_crzalt (which holds it near T/D); a second push on the
-- release left ALT HOLD and climbed at once.
r = new_autopilot()
vr = new_vr(r)
vr_click(vr, "useAlt")
equal(r.B747BR_cruiseAlt, 33000, "VR click on the ALT knob: CRZ ALT FL330")
equal(r.scheduled, 1, "VR click on the ALT knob schedules the cruise climb")
equal(r.simDR_autopilot_alt_hold_status, 2, "VR click on the ALT knob: still in ALT HOLD until the scheduled climb")
equal(r.B747_ap_button_switch_position_target[16], 0, "ALT knob out after the VR click")

-- 7. The release ends the held push even when the view has moved to another
-- knob by then (findHotSpot picks the knob at each phase), and pushes nothing
-- else.
r, vnav = new_autopilot()
local pushes
vr, pushes = new_vr(r)
vr_click(vr, "useIAS", "useHDG")
equal(vnav.manualVNAVspd, 1, "VR click with the view moved at the release: one speed knob push")
equal(r.B747_ap_button_switch_position_target[15], 0, "speed knob out after the release over the HDG knob")
equal(pushes.hdg, 0, "no HDG push from the release")
vr_click(vr, "useIAS")
equal(vnav.manualVNAVspd, 0, "the next VR click on the speed knob acts")

print("AP knob push tests passed: "..checks)
