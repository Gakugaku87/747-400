-- Run from the repository root with Lua 5.1 or LuaJIT.
-- In the approach the A/T holds the speed, VNAV's or the IAS window's: VNAV_DES
-- does not turn it off at idle, and its FMA is SPD at idle; VNAV PTH stays with
-- the window open, also above SPD TRANS (no VNAV SPD in the approach), and the
-- descent resumes from ALT HOLD there in VNAV PTH. Before, with the
-- window open (the kit's speed intervention for the flaps) VNAV_DES turned the
-- A/T off as soon as the throttles were at idle and left it off until the
-- speed fell below Vmc + 15 kt: p6-line1 (EHAM, 2026-10-16) slowed from 194 to
-- 149 kt after APP; in the approach model EINN's A/T went off at 15.6 nm.
-- The production VNAV_DES, setDescentVSpeed and B747_ap_fma run in the
-- autopilot's namespace (approach_model.lua's loader) against mocked datarefs,
-- for the resumed descent read back as XTLua does within a frame.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then
        checks = checks + 1
        failures[#failures + 1] = name..": "..tostring(err)
    end
end

-- EINN ILS 06 descending to ELPOM (3,000 ft) at 236 kt with flaps 5, nm_before ELPOM, the IAS window open
-- at 230 kt and the throttles at idle; the A/T engaged or not. datarefs: the datarefs' table ({}).
local function new_runtime(nm_before, at_active, datarefs)
    local o = model.einn()
    local d = datarefs or {}
    local ap = model.load(d, {fmsData = o.fms_data, B747_route_constraints = o.constraints})
    model.set_datarefs(d, o, 0.01)
    local route = o.route
    local elpom, bilto = route[6], route[5]
    d.simDR_latitude, d.simDR_longitude = ap.movePoint(elpom[5], elpom[6], nm_before,
        ap.getHeading(elpom[5], elpom[6], bilto[5], bilto[6]))
    for i = 1, #route do route[i][10] = (i == 6) end
    d.B747DR_fmscurrentIndex = 6
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 3000 + nm_before * 290, 3000 + nm_before * 290 - 46
    d.simDR_ind_airspeed_kts_pilot, d.simDR_groundspeed = 236, 236 * 0.514444
    d.simDR_vvi_fpm_pilot = -1000
    d.B747DR_airspeed_Vmc = model.vmc(279000, 5)
    d.B747DR_flap_ratio = 2 / 6
    d.B747DR_ap_ias_mach_window_open, d.B747DR_ap_ias_dial_value, d.simDR_autopilot_airspeed_kts = 1, 230, 230
    d.B747DR_autothrottle_active = at_active
    d.B747BR_totalDistance, d.B747BR_tod = nm_before + 13.6, 120
    d.simDRTime = 1000
    return d, ap, route
end

case("in the approach", function()
    -- 2.7 nm before ELPOM: 15.6 nm from the runway along the route
    local d, ap, route = new_runtime(2.7, 1)
    ap.VNAV_DES(1, route)
    check(d.B747DR_autothrottle_active == 1, "at idle with the window open: the A/T stays on")
    check(d.simDR_autopilot_vs_status == 2 and d.B747DR_ap_thrust_mode == 0, "VNAV PTH's V/S, no THR REF")
    ap.B747_ap_fma(route)
    check(d.B747DR_ap_FMA_autothrottle_mode == 3, "its FMA at idle: SPD, got "..d.B747DR_ap_FMA_autothrottle_mode)
    -- turned off before: back on, above Vmc + 15 kt
    d, ap, route = new_runtime(2.7, 0)
    ap.VNAV_DES(1, route)
    check(d.B747DR_autothrottle_active == 1, "off before: back on at 236 kt")
end)

case("the window open above SPD TRANS in the approach", function()
    -- 10,000 ft above the path 7 nm before ELPOM (a high airport's approach): VNAV PTH stays, the A/T holds the
    -- window's speed (above SPD TRANS VNAV_DES made it VNAV SPD, FLCH, against the A/T's SPD)
    local d, ap, route = new_runtime(7, 1)
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 15100, 15054
    ap.VNAV_DES(1, route)
    check(d.simDR_autopilot_flch_status == 0 and d.simDR_autopilot_vs_status == 2, "VNAV PTH's V/S, not FLCH")
    check(d.B747DR_ap_thrust_mode == 0, "no THR REF")
    -- 30 nm out it is VNAV SPD (FLCH) as before
    d, ap, route = new_runtime(17, 1)
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 15100, 15054
    ap.VNAV_DES(1, route)
    check(d.simDR_autopilot_flch_status == 2 and d.B747DR_ap_thrust_mode == 2, "30 nm out: VNAV SPD")
end)

-- Datarefs as XTLua gives them to a script: within a frame it reads back their values from the frame's start,
-- and its writes (and commands) take effect after it. The second result ends a frame. Not emulated: a write to
-- an element of an array dataref (B747DR_throttle[i]) takes effect at once; and the last write to a dataref
-- in the frame stands, the commands' (closures writing datarefs here) included in the order they were issued,
-- which need not be the order XTLua applies them in.
local function xtlua_datarefs()
    local now, written = {}, {}
    local d = setmetatable({}, {
        __index = function(_, key) return now[key] end,
        __newindex = function(_, key, value) written[key] = value end})
    return d, function()
        for key, value in pairs(written) do now[key] = value end
        written = {}
    end
end

case("resuming the descent above SPD TRANS in the approach, the window open", function()
    -- 10,000 ft above the path 7 nm before ELPOM in ALT HOLD (VNAV ALT), the MCP below: in that frame the
    -- window's block's V/S reads back ALT HOLD, so VNAV_DES goes on to resume the descent - with V/S (VNAV
    -- PTH), not VNAV SPD (FLCH) as above SPD TRANS before the approach
    local d, end_frame = xtlua_datarefs()
    local _, ap, route = new_runtime(7, 1, d)
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 15100, 15054
    d.simDR_autopilot_alt_hold_status, d.simDR_autopilot_vs_status, d.simDR_autopilot_flch_status = 2, 0, 0
    d.B747DR_ap_inVNAVdescent = 1
    end_frame()
    ap.VNAV_DES(1, route)
    end_frame()
    check(d.B747DR_ap_inVNAVdescent == 2, "the descent resumed")
    check(d.simDR_autopilot_flch_status == 0 and d.simDR_autopilot_vs_status == 2
        and d.simDR_autopilot_alt_hold_status == 0, "resumed in VNAV PTH's V/S, not FLCH")
    check(d.B747DR_ap_thrust_mode == 0, "resumed without THR REF")
end)

case("before the approach", function()
    -- 17 nm before ELPOM, 30 nm out: the descent's energy mode keeps the A/T on, IDLE at idle, as before
    local d, ap, route = new_runtime(17, 1)
    ap.VNAV_DES(1, route)
    check(d.B747DR_vnav_energy_active == 1 and d.B747DR_autothrottle_active == 1, "30 nm out: the energy mode's A/T")
    ap.B747_ap_fma(route)
    check(d.B747DR_ap_FMA_autothrottle_mode == 2, "30 nm out: IDLE at idle, got "..d.B747DR_ap_FMA_autothrottle_mode)
    -- 30 nm out within 600 ft of a level-off (the energy mode out): off at idle with the window open, as before,
    -- and IDLE
    d, ap, route = new_runtime(17, 1)
    d.simDR_autopilot_altitude_ft, d.B747DR_autopilot_altitude_ft = 7500, 7500
    ap.VNAV_DES(1, route)
    check(d.B747DR_vnav_energy_active == 0 and d.B747DR_autothrottle_active == 0, "30 nm out, no energy mode: off")
    ap.B747_ap_fma(route)
    check(d.B747DR_ap_FMA_autothrottle_mode == 2, "30 nm out, off at idle: IDLE, got "..d.B747DR_ap_FMA_autothrottle_mode)
    -- the same with the window shut: past the T/D the A/T stays on for VNAV's speed, and on at idle its FMA is
    -- IDLE too (SPD at idle only in the approach)
    d, ap, route = new_runtime(17, 1)
    d.B747DR_ap_ias_mach_window_open = 0
    d.simDR_autopilot_altitude_ft, d.B747DR_autopilot_altitude_ft = 7500, 7500
    ap.VNAV_DES(1, route)
    check(d.B747DR_vnav_energy_active == 0 and d.B747DR_autothrottle_active == 1, "the window shut, 30 nm out: on")
    ap.B747_ap_fma(route)
    check(d.B747DR_ap_FMA_autothrottle_mode == 2,
        "the window shut, 30 nm out, on at idle: IDLE, got "..d.B747DR_ap_FMA_autothrottle_mode)
end)

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV approach A/T tests passed: "..checks)
