-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_vnav_alt_test.lua
-- VNAV ALT in the descent (6-3; LF2: notes/ATA-34-61-FMC.md §127) in the
-- autopilot module as XTLua runs it (tests/lib/xtlua.lua), the FMC's VNAV
-- (laminar/B747/fms/vnav/*) set here: descending in VNAV PTH to the MCP
-- altitude, VNAV ALT there (FCOM p.645). FCOM p.665: to continue the
-- descent, change the MCP altitude and push the altitude selector; below
-- the VNAV path, resetting the MCP altitude and intercepting the path also
-- continues it. Below or not is the airplane's when the MCP altitude is
-- reset (before, when it levelled: s198's second flight levelled on the
-- path at 4,000 ft, the path went on down, the MCP reset to 1,300 ft took
-- it on in VNAV without the push 1,000 ft above the path). (The FMC's step
-- 9i) VNAV's VNAV ALT and its captures go by the MCP altitude settled, 3 s
-- after the window's last change (or the selector's push): a new MCP
-- altitude here waited for (settle) before the airplane meets it.
local T = dofile("tests/lib/check.lua")("afds_vnav_alt")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local PITCH = "laminar/B747/autopilot/FMA/active_pitch_mode"
local VNAV_STATE = "laminar/B747/autopilot/vnav_state"
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local ALT_IND, VSI = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/flightmodel/position/vh_ind_fpm"
local MCP_ALT = "laminar/B747/autopilot/heading/altitude_dial_ft"
local PUSH = "laminar/B747/button_switch/press_altitude"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(RA, 9000)
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
end
local ATV = "laminar/B747/flt_ctrls/stab_trim/autotrim_valid"
rt:set(ATV, 0, 1)
rt:set(ATV, 1, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 0, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 1, 1)
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
rt:set(ALT_IND, 8000)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
-- a new MCP altitude settled (VNAV's 3 s)
local function settle() frames(95) end
frames(30)

-- CMD C, the FMC's VNAV valid in the descent on its path (VNAV PTH), the
-- MCP at 4,000 ft
local FVN = "laminar/B747/fms/vnav/"
local function fvn(t) for k, v in pairs(t) do rt:set(FVN .. k, v) end end
rt:command(CMD .. "cmd_C")
frames()
fvn({perf = 1, valid = 1, phase = 3, mode = 2, cas = 250, mach = 0.6, mach_mode = 0, alt = 4000,
    vs = -1500, path_dev = 0, at = 2})
for i = 0, 3 do rt:set("laminar/B747/engines/display_N1", i, 40) end
rt:set("laminar/B747/engines/autothrottle_fail", 0)
rt:set("laminar/B747/toggle_switch/position", 29, 1)
rt:set("laminar/B747/autothrottle/armed", 1)
rt:set("laminar/B747/airspeed/Vmo", 365)
rt:set(MCP_ALT, 4000)
settle()
rt:command(CMD .. "VNAV")
frames(30)
T.equal(rt:get(VNAV_STATE), 2, "VNAV engaged")
T.equal(rt:get(PITCH), 6, "the descent on the path: VNAV PTH")

-- descending through 4,060 ft at 1,500 fpm on the path: VNAV ALT at the MCP
-- altitude
rt:set(ALT_IND, 4060)
rt:set(VSI, -1500)
fvn({path_dev = -5})
frames()
T.equal(rt:get(PITCH), 5, "60 ft above the MCP altitude: VNAV ALT (FCOM p.645)")
-- level there, the path gone on down (600 ft above it): the MCP reset to
-- 1,300 ft without the push, VNAV ALT still; the push, VNAV PTH
rt:set(ALT_IND, 4000)
rt:set(VSI, 0)
fvn({path_dev = 600})
frames(30)
T.equal(rt:get(PITCH), 5, "level 600 ft above the path: VNAV ALT")
rt:set(MCP_ALT, 1300)
frames(30)
T.equal(rt:get(PITCH), 5, "the MCP reset lower 600 ft above the path, no push: VNAV ALT still (FCOM p.665)")
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 6, "the selector pushed: VNAV PTH")

-- again level at 4,000 ft, 300 ft under the path (held there): the MCP reset
-- lower, VNAV ALT until the path comes down to it, then VNAV PTH without the
-- push
rt:set(MCP_ALT, 4000)
settle()
rt:set(ALT_IND, 4060)
rt:set(VSI, -1500)
fvn({path_dev = -300})
frames()
T.equal(rt:get(PITCH), 5, "at the MCP altitude 300 ft under the path: VNAV ALT")
rt:set(ALT_IND, 4000)
rt:set(VSI, 0)
frames(30)
rt:set(MCP_ALT, 1300)
frames(30)
T.equal(rt:get(PITCH), 5, "the MCP reset lower under the path: VNAV ALT until the path comes down")
fvn({path_dev = -40})
frames(30)
T.equal(rt:get(PITCH), 5, "the path 40 ft above: still")
fvn({path_dev = 5})
frames()
T.equal(rt:get(PITCH), 6, "the path down to it: VNAV PTH without the push (FCOM p.665)")

-- the MCP set back to the level altitude and lower again: the reset judged
-- anew (above the path then: the push wanted)
rt:set(MCP_ALT, 4000)
settle()
rt:set(ALT_IND, 4060)
rt:set(VSI, -1500)
fvn({path_dev = -300})
frames()
rt:set(ALT_IND, 4000)
rt:set(VSI, 0)
rt:set(MCP_ALT, 1300)
frames()
rt:set(MCP_ALT, 4000)
fvn({path_dev = 300})
frames(30)
rt:set(MCP_ALT, 1300)
frames()
fvn({path_dev = 320})
frames(30)
T.equal(rt:get(PITCH), 5, "reset back and lower again above the path: VNAV ALT, the push wanted")

T.done()
