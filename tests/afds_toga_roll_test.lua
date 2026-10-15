-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Selecting a roll mode in flight must replace the TO/GA roll annunciation
-- without touching TO/GA pitch. Simulator interfaces are mocks.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end

-- A: the pure rule. TO/GA roll stays up until a roll mode replaces it.
local function toga_roll(...)
    assert(type(afds.toga_roll_mode_active) == "function", "afds.toga_roll_mode_active is missing")
    return afds.toga_roll_mode_active(...)
end
equal(toga_roll(1, 0, 0, false), true, "TO/GA roll shows until a roll mode is selected")
equal(toga_roll(1, 0, 0, true), false, "HDG SEL/HOLD in flight clears TO/GA roll")
equal(toga_roll(1, 2, 0, false), false, "active LNAV replaces TO/GA roll")
equal(toga_roll(1, 0, 2, false), false, "LOC capture replaces TO/GA roll")
equal(toga_roll(0, 0, 0, false), false, "no TO/GA roll without TO/GA")

-- B: the production HDG SEL / HDG HOLD handlers, the roll FMA and the heading
-- target updater, sliced out of the autopilot module and run together.
local slices = {
    {"function B747_ap_switch_hdg_sel_mode_CMDhandler", "B747CMD_ap_thrust_mode ="},
    {"function B747_ap_heading_hold_mode_afterCMDhandler", 'dofile("json/json.lua")'},
    {"local apWasOn=0", "local restoreAlt=0"},
    {"function B474_ap_target_heading()", "----- EICAS MESSAGES"}
}
local file = assert(io.open(AP.."B747.70.xt.autopilot.lua"))
local source = file:read("*a")
file:close()
local parts = {}
for _,markers in ipairs(slices) do
    local first = assert(source:find(markers[1], 1, true), "missing marker "..markers[1])
    local last = assert(source:find(markers[2], first, true), "missing marker "..markers[2])
    parts[#parts+1] = source:sub(first, last-1)
end
local sliced = table.concat(parts, "\n")

local function new_aircraft()
    local r = {
        print = function() end,
        B747_afds_helpers = afds,
        B747CMD_fdr_log_headsel = {once=function() end},
        B747CMD_fdr_log_headhold = {once=function() end},
        B747_ap_button_switch_position_target = {},
        B747DR_toggle_switch_position = {[23]=1, [24]=1},
        B747DR_ap_cmd_L_mode = 1, B747DR_ap_cmd_C_mode = 0, B747DR_ap_cmd_R_mode = 0,
        B747DR_autopilot_TOGA_status = 1, B747DR_ap_autoland = 0,
        B747DR_ap_lnav_state = 0, B747DR_ap_ATT = 0, B747DR_ap_approach_mode = 0,
        -- Both nav statuses are explicit: B474_ap_target_heading tests the
        -- actual nav status before it re-selects the X-Plane heading mode.
        B747DR_autopilot_nav_status = 0, simDR_autopilot_nav_status = 0,
        B747DR_ap_AFDS_status_annun_pilot = 0, simDR_radarAlt1 = 1000,
        simDR_nav1_radio_course_deg = 0, simDR_onGround = 0,
        simDR_autopilot_heading_status = 0, simDR_autopilot_heading_hold_status = 0,
        simDR_autopilot_heading_deg = 90, B747DR_ap_heading_deg = 90,
        B747DR_ap_target_heading_deg = -1, B747DR_ap_activate_target_heading_deg = 0,
        B747DR_ap_FMA_active_roll_mode = 1, B747DR_ap_FMA_armed_roll_mode = 0,
        B747DR_ap_thrust_mode = 0, B747DR_ap_lastCommand = 90, simDRTime = 100
    }
    -- X-Plane HDG SEL engages on the next command.
    r.simCMD_autopilot_heading_select = {once=function() r.simDR_autopilot_heading_status = 2 end}
    setmetatable(r, {__index=_G})
    setfenv(assert(loadstring(sliced, "@"..AP.."B747.70.xt.autopilot.lua")), r)()
    return r
end
local function fma_at(r, time)
    r.simDRTime = time
    r.fma_rollModes()
    return r.B747DR_ap_FMA_active_roll_mode
end
-- after_physics runs the FMA (B747_ap_fma) before B474_ap_target_heading.
local function frame(r, time)
    local roll = fma_at(r, time)
    r.B474_ap_target_heading()
    return roll
end
local function press_hdg_sel(r, time)
    r.simDRTime = time
    r.B747_ap_switch_hdg_sel_mode_CMDhandler(0, 0)
    r.simDRTime = time + 0.1
    r.B474_ap_target_heading()
end

-- 1) HDG SEL in flight replaces TO/GA roll; TO/GA pitch stays.
local r = new_aircraft()
press_hdg_sel(r, 100)
equal(r.simDR_autopilot_heading_status, 2, "HDG SEL engaged the X-Plane heading mode")
equal(fma_at(r, 100.6), 6, "HDG SEL replaces TO/GA roll within 0.5 s")
equal(r.B747DR_autopilot_TOGA_status, 1, "HDG SEL leaves TO/GA pitch engaged")
-- The same press frame by frame: the roll FMA goes from TO/GA straight to
-- HDG SEL, never blank while X-Plane has not yet engaged its heading mode.
r = new_aircraft()
r.simDRTime = 100
r.B747_ap_switch_hdg_sel_mode_CMDhandler(0, 0)
local shown = {}
for step=1,6 do
    shown[step] = frame(r, 100 + step*0.1)
end
equal(shown[1], 1, "TO/GA roll until HDG SEL is engaged")
for step=2,6 do
    local roll = shown[step]
    equal(roll == 1 or roll == 6, true, "no blank roll FMA at step "..step..", roll "..tostring(roll))
end
equal(shown[5], 6, "HDG SEL shown 0.5 s after the press")
equal(r.B747DR_autopilot_TOGA_status, 1, "TO/GA pitch stays through the frames")
-- 2) A new TO/GA press in the air (engines set autoland -2) brings TO/GA roll back.
r.B747DR_ap_autoland = -2
equal(fma_at(r, 100.7), 1, "airborne TO/GA press restores TO/GA roll")
equal(fma_at(r, 100.8), 1, "TO/GA roll stays while autoland remains -2")

-- 3) HDG HOLD in flight replaces TO/GA roll.
r = new_aircraft()
r.simDR_autopilot_heading_hold_status = 2
r.B747_ap_heading_hold_mode_afterCMDhandler(0, 0)
equal(fma_at(r, 100.5), 7, "HDG HOLD replaces TO/GA roll")
equal(r.B747DR_autopilot_TOGA_status, 1, "HDG HOLD leaves TO/GA pitch engaged")

-- 4) LNAV engagement also ends TO/GA roll, even after LNAV drops out.
r = new_aircraft()
r.B747DR_ap_lnav_state = 2
equal(fma_at(r, 100.5), 2, "active LNAV shows LNAV")
r.B747DR_ap_lnav_state = 0
r.simDR_autopilot_heading_status = 2
equal(fma_at(r, 100.6), 6, "LNAV dropping out does not bring TO/GA roll back")
-- 5) TO/GA cleared by a pitch mode and engaged again shows TO/GA roll.
r.B747DR_autopilot_TOGA_status = 0
equal(fma_at(r, 100.7), 6, "HDG SEL without TO/GA")
r.B747DR_autopilot_TOGA_status = 1
equal(fma_at(r, 100.8), 1, "TO/GA engaged again shows TO/GA roll")

-- 6) HDG SEL pressed on the ground does not cancel the takeoff TO/GA roll.
r = new_aircraft()
r.simDR_onGround = 1
press_hdg_sel(r, 100)
equal(fma_at(r, 100.6), 1, "HDG SEL on the ground keeps TO/GA roll")
r.simDR_onGround = 0
equal(fma_at(r, 100.7), 1, "a ground press is not remembered after liftoff")

-- 7) A TO/GA press just before HDG SEL, before the FMA has run, does not
-- undo the later HDG SEL.
r = new_aircraft()
r.B747DR_ap_autoland = -2
press_hdg_sel(r, 100)
equal(fma_at(r, 100.6), 6, "HDG SEL after a fresh TO/GA press still shows HDG SEL")

-- 8) Nothing is remembered on the ground: LNAV still active from the last
-- flight, or a selection that outlived the landing, must not hide TO/GA roll
-- at the next takeoff.
r = new_aircraft()
r.simDR_onGround = 1
r.B747DR_ap_lnav_state = 2
equal(fma_at(r, 100.5), 0, "stale LNAV on the ground shows no roll mode")
r.B747DR_ap_lnav_state = 1
equal(fma_at(r, 100.6), 1, "LNAV armed again on the ground shows TO/GA roll")
r.simDR_onGround = 0
equal(fma_at(r, 100.7), 1, "TO/GA roll after liftoff with LNAV still armed")
r = new_aircraft()
press_hdg_sel(r, 100)
equal(fma_at(r, 100.6), 6, "HDG SEL in flight before the landing")
r.simDR_onGround = 1
r.simDR_autopilot_heading_status = 0
equal(fma_at(r, 100.7), 1, "TO/GA roll on the ground after the landing")
r.simDR_onGround = 0
equal(fma_at(r, 100.8), 1, "TO/GA roll at the next liftoff")

print("AFDS TO/GA roll tests passed: "..checks)
