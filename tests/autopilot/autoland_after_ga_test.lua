-- Run from the repository root with LuaJIT: luajit tests/autopilot/autoland_after_ga_test.lua
-- (2026-11-24, the stage 4 review's AFDS-3) The SRMs' autoland
-- (laminar/B747/autopilot/autoland: 1 in a multi-channel landing, LAND 3 or
-- LAND 2; the SRMs then put the rudder ratio changers at full authority and
-- trim without the autotrim's delay, ATA27 p.636, p.648) after a go-around
-- with the A/P engaged that levels at or under 1,500 ft of radio altitude
-- (a 1,500 ft pattern over a field near sea level). Before, the old code's
-- go-around wrote -2, which nothing reads now and which only a climb over
-- 1,500 ft or all the A/Ps off took back to 0; until then the glue wrote no
-- 1: the next approach's LAND 3 left it at -2. Now the flag is the autoland
-- status's alone: G/A ends LOC, G/S and their arms (FCOM p.660), so no LAND
-- 3 or 2 and 0 through the go-around. Through the real glue
-- (B747.70.xt.autopilot.lua) on the XTLua mock (the review's
-- autoland_after_ga.lua).
local xtlua = dofile("tests/lib/xtlua.lua")
local T = dofile("tests/lib/check.lua")("autoland_after_ga")
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local FD = "laminar/B747/toggle_switch/position"
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local RI = "sim/cockpit2/radios/indicators/"
local STATUS_P = "laminar/B747/autopilot/AFDS/status_annun_pilot"
local PITCH, ROLL = "laminar/B747/autopilot/FMA/active_pitch_mode", "laminar/B747/autopilot/FMA/active_roll_mode"
local PUSHES = "laminar/B747/autopilot/toga_pushes"
local AL = "laminar/B747/autopilot/autoland"

local function fly(ga_ra)
    local rt = xtlua.new()
    rt:load(AP)
    rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
    rt:set("laminar/B747/newsimconfig", 1)
    rt:set("xtlua/fms", "[]")
    rt:set("sim/time/total_running_time_sec", 10)
    rt:set("sim/flightmodel/failures/onground_any", 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
    rt:set(RA, 3000)
    for i = 1, 3 do rt:set("laminar/B747/hydraulics/pressure_" .. i, 3000) end
    for i = 0, 3 do
        rt:set("laminar/B747/electrical/bus/ac", i, 1)
        rt:set("laminar/B747/electrical/bus/dc", i, 1)
    end
    rt:set("laminar/B747/electrical/bus/bat_main", 1)
    rt:set("laminar/B747/electrical/bus/xfr_fo", 1)
    for i = 0, 2 do
        rt:set("laminar/B747/irs/att_valid", i, 1)
        rt:set("laminar/B747/airdata/valid", i, 1)
        rt:set("laminar/B747/irs/hdg_valid", i, 1)
        rt:set("laminar/B747/irs/nav_valid", i, 1)
        rt:set("laminar/B747/ra/valid", i, 1)
    end
    for i = 0, 1 do
        rt:set("laminar/B747/flt_ctrls/stab_trim/autotrim_valid", i, 1)
        rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", i, 1)
        rt:set("laminar/B747/fms/fmc_ok", i, 1)
    end
    rt:set("sim/flightmodel/position/local_vy", 0)
    rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 160)
    rt:set("sim/cockpit2/controls/flap_ratio", 0.668)
    rt:set("sim/flightmodel/position/groundspeed", 160 * 1852 / 3600)
    rt:callout("flight_start")
    local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
    frames(30)
    local function ils(on)
        local v = on and 1 or 0
        rt:set(RI .. "nav1_display_horizontal", v)
        rt:set(RI .. "nav2_display_horizontal", v)
        rt:set(RI .. "nav1_display_vertical", v)
        rt:set(RI .. "nav2_display_vertical", v)
        rt:set(RI .. "nav1_flag_glideslope", on and 0 or 1)
        rt:set(RI .. "nav2_flag_glideslope", on and 0 or 1)
        rt:set(RI .. "nav1_vdef_dots_pilot", 0)
        rt:set(RI .. "nav1_hdef_dots_pilot", 0)
    end
    rt:set("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot", 0, 336)
    rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 336)
    rt:set("sim/flightmodel/position/mag_psi", 336)
    -- APP, the three channels, below 1,500 ft: LAND 3
    local function approach()
        ils(true)
        rt:command("laminar/B747/autopilot/approach")
        frames()
        rt:set("laminar/B747/electrical/bus_isolated", 1)
        frames(30)
        rt:set(RA, 1400)
        frames(30 * 6)
    end
    rt:set(FD, 23, 1)
    frames()
    rt:command(CMD .. "cmd_L")
    frames()
    rt:command(CMD .. "alt_hold_mode")
    frames()
    local r = {}
    approach()
    r.status1, r.al1 = rt:get(STATUS_P), rt:get(AL)
    -- the go-around at 1,000 ft, levelled at ga_ra ft in ALT and HDG SEL
    rt:set(RA, 1000)
    frames()
    rt:set(PUSHES, (rt:get(PUSHES) or 0) + 1)
    frames()
    r.ga_pitch, r.ga_roll, r.al_ga = rt:get(PITCH), rt:get(ROLL), rt:get(AL)
    ils(false)
    rt:set(RA, ga_ra)
    frames(30)
    rt:command(CMD .. "alt_hold_mode")
    frames()
    rt:command(CMD .. "heading_select")
    frames(30)
    r.lvl_pitch, r.lvl_roll, r.al_lvl = rt:get(PITCH), rt:get(ROLL), rt:get(AL)
    approach()
    r.status2, r.al2 = rt:get(STATUS_P), rt:get(AL)
    return r
end

for _, ga_ra in ipairs({1490, 2000}) do
    local r = fly(ga_ra)
    local at = string.format("levelled at %d ft", ga_ra)
    T.check(r.status1 == 4 and r.al1 == 1, string.format("%s: the first approach LAND 3 (%d), the SRMs' autoland 1 (%d)", at, r.status1, r.al1))
    T.check(r.ga_pitch == 1 and r.ga_roll == 1, at .. ": TO/GA's G/A")
    T.equal(r.al_ga, 0, at .. ": in G/A no autoland (no LAND 3 or 2; before the old code's -2)")
    T.check(r.lvl_pitch == 9 and r.lvl_roll == 6, at .. ": levelled in ALT and HDG SEL")
    T.equal(r.al_lvl, 0, at .. ": levelled, no autoland")
    T.equal(r.status2, 4, at .. ": the second approach LAND 3")
    T.equal(r.al2, 1, at .. ": the second approach's LAND 3, the SRMs' autoland 1 (before -2 under 1,500 ft)")
end

T.done()
