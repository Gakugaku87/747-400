-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The MCP altitude knob while it is dialled (item B-12). It wrote B747DR_ap_lastCommand 1 s ahead at each click (and
-- every frame held), which froze everything waiting 0.5 s on it - VNAV's mode switching and descent V/S target, the
-- start of the descent at T/D, the A/T modes, LOC and G/S capture, the roll FMA, APP arming, AFDS status - for the
-- whole dial and 1.5 s after it (the kit dials 37000 -> 2000 ft before T/D at 0.079 s a click, 28 s); a real
-- 747-400's AFDS uses the selection at once. Unfrozen naively, VNAV's altitude legs would take each passing value as
-- a level-off. The production code in tests/mcp_alt_dial_model.lua's closed loop.
local M = dofile("tests/mcp_alt_dial_model.lua")
local route_north, dial = M.route_north, M.dial

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local function climb_vnav(alt, mcp)
    return function() return {alt = alt, vs = 2000, mcp = mcp, route = route_north({{"WPA", 260}, {"DEST", 600, 0, 1}}),
        d = {B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 0, B747DR_ap_inDescent = 0, B747DR_ap_flightPhase = 1,
            simDR_autopilot_flch_status = 2, simDR_autopilot_vs_status = 0, B747DR_ap_FMA_active_pitch_mode = 4,
            B747BR_totalDistance = 500, B747BR_tod = 300, B747DR_ap_thrust_mode = 2, B747DR_ap_FMA_autothrottle_mode = 5}} end
end
local function flch(alt, vs, mcp, mode)
    return function() return {alt = alt, vs = vs, vs_cmd = vs, mcp = mcp, route = route_north({{"WPA", 260}, {"DEST", 600, 0, 1}}),
        d = {B747DR_ap_vnav_state = 0, B747DR_ap_flightPhase = vs > 0 and 1 or 3,
            simDR_autopilot_flch_status = mode == "flch" and 2 or 0, simDR_autopilot_vs_status = mode == "vs" and 2 or 0,
            simDR_autopilot_alt_hold_status = 0, B747DR_ap_FMA_active_pitch_mode = mode == "flch" and 8 or 7,
            B747BR_totalDistance = 500, B747BR_tod = 300, B747DR_ap_thrust_mode = mode == "flch" and 2 or 0,
            B747DR_ap_FMA_autothrottle_mode = mode == "flch" and 5 or 3, B747DR_ap_vs_window_open = mode == "vs" and 1 or 0}} end
end
local function cruise(td_nm)
    return function() return {alt = 37000, vs = 0, mcp = 37000, gs_ms = 240,
        route = route_north({{"TENK", td_nm + 93.1, 10000}, {"DEST", td_nm + 200, 0, 1}}),
        d = {B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 0, B747DR_ap_inDescent = 0, B747DR_ap_flightPhase = 2,
            simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 0, simDR_autopilot_alt_hold_status = 2,
            simDR_autopilot_hold_altitude_ft = 37000, B747DR_ap_FMA_active_pitch_mode = 6,
            B747BR_totalDistance = td_nm + 300, B747BR_tod = 300, B747DR_ap_thrust_mode = 0,
            B747DR_ap_FMA_autothrottle_mode = 3, simDR_airspeed_mach = 0.84, B747DR_ap_vnav_target_alt = 10000}} end
end
local function descent(alt, mcp)
    return function() return {alt = alt, vs = -2000, vs_cmd = -2000, mcp = mcp,
        route = route_north({{"TENK", 30, 6000}, {"DEST", 200, 0, 1}}),
        d = {B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 2, B747DR_ap_inDescent = 1, B747DR_ap_flightPhase = 3,
            simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 2, simDR_autopilot_alt_hold_status = 0,
            B747DR_ap_FMA_active_pitch_mode = 6, B747BR_totalDistance = 200, B747BR_tod = 300,
            B747DR_ap_thrust_mode = 0, B747DR_ap_FMA_autothrottle_mode = 2, simDR_airspeed_mach = 0.6,
            simDR_ind_airspeed_kts_pilot = 290, simDR_autopilot_airspeed_kts = 290, B747DR_ap_vnav_target_alt = 6000}} end
end
local function hold(vnav)
    return function() return {alt = 15000, vs = 0, mcp = 15000, route = route_north({{"WPA", 260}, {"DEST", 600, 0, 1}}),
        d = {B747DR_ap_vnav_state = vnav and 2 or 0, B747DR_mcp_hold = vnav and 1 or 0, B747DR_ap_flightPhase = 2,
            simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 0, simDR_autopilot_alt_hold_status = 2,
            simDR_autopilot_hold_altitude_ft = 15000, B747DR_ap_FMA_active_pitch_mode = vnav and 5 or 9,
            B747BR_totalDistance = 500, B747BR_tod = 300, B747DR_ap_thrust_mode = 0, B747DR_ap_FMA_autothrottle_mode = 3,
            B747DR_mcp_hold_pressed = -1000}} end
end
local function first(res, from, test)
    for _, s in ipairs(res.samples) do if s.t >= from and test(s) then return s end end
end
local function any(res, from, to, test)
    for _, s in ipairs(res.samples) do if s.t >= from and s.t <= to and test(s) then return s end end
end
-- levelled at want at the end: holding that altitude (the model's hold converges slowly) and within 150 ft of it
local function levelled(res, want)
    local s = res.samples[#res.samples]
    return s.alt_hold == 2 and math.abs((s.hold or 0) - want) <= 1 and math.abs(res.alt - want) <= 150,
        string.format("holds %s at %.0f ft", tostring(s.alt_hold == 2 and s.hold or "nothing"), res.alt)
end

-- K: the knob itself writes no lastCommand, on a click or held
do
    local o = climb_vnav(19500, 23000)()
    local d = M.base(o)
    local ap = M.load(d)
    d.B747DR_ap_lastCommand = -100
    ap.B747_ap_altitude_down_CMDhandler(0, 0)
    ap.B747_ap_altitude_down_CMDhandler(1, 0.6)
    check(d.B747DR_ap_lastCommand == -100, "K the knob wrote lastCommand: "..tostring(d.B747DR_ap_lastCommand))
end

-- A: VNAV SPD climb at 9,000 ft, MCP 10,000 dialled up to 23,000 (130 clicks): no level-off at a passing altitude,
-- VNAV SPD throughout and still climbing to the new MCP altitude (it latched ALT at 10,000 and went VNAV PTH)
local function climbing_on(res, mcp)
    local s = res.samples[#res.samples]
    return not any(res, 0, 1e9, function(x) return x.alt_hold == 2 end) and s.afds == mcp and res.vs > 1500,
        string.format("ALT hold %s, AFDS %s, ends %.0f ft at %+.0f fpm",
            tostring(any(res, 0, 1e9, function(x) return x.alt_hold == 2 end) ~= nil), tostring(s.afds), res.alt, res.vs)
end
local res = M.run({setup = climb_vnav(9000, 10000), clicks = dial(1.0, 130, 1), seconds = 30})
do
    local ok, what = climbing_on(res, 23000)
    check(ok and not any(res, 0, 30, function(s) return s.fma ~= 4 end), "A VNAV climb dialled up: "..what..", FMA "
        ..tostring((any(res, 0, 30, function(s) return s.fma ~= 4 end) or {fma = 4}).fma))
end

-- B: VNAV SPD climb at 19,500 ft, MCP 23,000: ATC stop climb at FL200 (30 clicks down) at 0.079, 0.15 and 0.25 s a
-- click, three starts each: levels at 20,000
for _, cadence in ipairs({0.079, 0.15, 0.25}) do
    for k = 0, 2 do
        res = M.run({setup = climb_vnav(19500, 23000), clicks = dial(1.0 + 0.05 * k, 30, -1, cadence), seconds = 35})
        local ok, what = levelled(res, 20000)
        check(ok, string.format("B VNAV stop climb at %.3f s a click (start +%.2f): %s", cadence, 0.05 * k, what))
    end
end

-- C: cruise at FL370, T/D 2 nm (15.4 s at 240 m/s) ahead, MCP 37,000 dialled down to 2,000 (350 clicks from 1 s): the
-- descent starts at T/D, not after the dial (at 30.1 s before)
res = M.run({setup = cruise(2.0), clicks = dial(1.0, 350, -1), seconds = 40})
local started = first(res, 0, function(s) return (s.inDes or 0) > 0 end)
check(started ~= nil and started.t <= 16.0, string.format("C T/D in the dial: the descent started at %s s (T/D 15.4 s)",
    started and string.format("%.1f", started.t) or "never"))

-- C1: T/D 0.1 s after a first click, then a 0.6 s pause, then the dial on: the descent starts (no level-off at
-- the one click below CRZ ALT)
do
    local c = {{t = 1.0, dir = -1}}
    for _, k in ipairs(dial(1.7, 349, -1)) do c[#c + 1] = k end
    res = M.run({setup = cruise(240 / 1852 * 1.1), clicks = c, seconds = 45})
    check(res.alt < 36000, string.format("C1 T/D after a first click and a pause: ends at %.0f ft", res.alt))
end

-- D: VNAV PTH descent at 15,000 ft, MCP 11,000 dialled down to 7,000 (40 clicks): the V/S target keeps changing in
-- the dial (it was frozen for the dial and 1.5 s)
res = M.run({setup = descent(15000, 11000), clicks = dial(1.0, 40, -1), seconds = 12})
do
    local seen, n = {}, 0
    for _, s in ipairs(res.samples) do
        if s.t >= 1.2 and s.t <= 4.0 and not seen[s.vs_cmd] then seen[s.vs_cmd], n = true, n + 1 end
    end
    check(n >= 3, string.format("D VNAV PTH descent in the dial: %d V/S targets between 1.2 and 4.0 s (at least 3)", n))
end

-- D3: VNAV PTH descent at 12,000 ft, MCP 9,000: ATC stop descent at 11,000 (20 clicks up): levels at 11,000
res = M.run({setup = descent(12000, 9000), clicks = dial(1.0, 20, 1), seconds = 90})
do
    local ok, what = levelled(res, 11000)
    check(ok, "D3 VNAV stop descent at 11,000: "..what)
end

-- E: ALT HOLD (VNAV off) and VNAV ALT at 15,000: MCP up 3,000, then down 6,000: still at 15,000
for _, vnav in ipairs({false, true}) do
    local c = dial(1.0, 30, 1)
    for _, k in ipairs(dial(1.0 + 30 * 0.079 + 2.0, 60, -1)) do c[#c + 1] = k end
    res = M.run({setup = hold(vnav), clicks = c, seconds = 25})
    local off = 0
    for _, s in ipairs(res.samples) do off = math.max(off, math.abs(s.alt - 15000)) end
    check(off <= 30, string.format("E %s at 15,000 with the MCP dialled: %.0f ft off", vnav and "VNAV ALT" or "ALT HOLD", off))
end

-- F1: FLCH climb at 19,500 ft, MCP 23,000: stop climb at 20,000 at three cadences: levels at 20,000
for _, cadence in ipairs({0.079, 0.15, 0.25}) do
    res = M.run({setup = flch(19500, 2000, 23000, "flch"), clicks = dial(1.0, 30, -1, cadence), seconds = 35})
    local ok, what = levelled(res, 20000)
    check(ok, string.format("F1 FLCH stop climb at %.3f s a click: %s", cadence, what))
end

-- F3: V/S +2,000 fpm at 10,150 ft toward MCP 11,000 (outside the capture window): ATC stop at 10,000 (10 clicks from
-- 0.5 s): levels at 10,000 (the 3 s copy left the old 11,000 to capture)
res = M.run({setup = flch(10150, 2000, 11000, "vs"), clicks = dial(0.5, 10, -1), seconds = 30})
do
    local ok, what = levelled(res, 10000)
    check(ok, "F3 V/S stop at 10,000 from 10,150: "..what)
end

-- F4: FLCH climb at 9,000 ft toward MCP 10,000, dialled up to 23,000: no level-off at 10,000
res = M.run({setup = flch(9000, 2000, 10000, "flch"), clicks = dial(1.0, 130, 1), seconds = 30})
do
    local ok, what = climbing_on(res, 23000)
    check(ok, "F4 FLCH dialled up from MCP 10,000: "..what)
end

-- G: the approach, VNAV PTH at 3,000 ft (-800 fpm), MCP 2,000, LOC captured, G/S armed and in range from 2 s while the
-- missed approach altitude 5,000 is dialled (30 clicks from 1 s): G/S captured within 0.6 s (at 4.85 s before)
do
    local function app()
        local r = route_north({{"FAF", 5, 2000}, {"RW18", 10, 50}, {"DEST", 11, 0, 1}})
        return {alt = 3000, vs = -800, vs_cmd = -800, mcp = 2000, route = r, elev = 0,
            d = {B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 2, B747DR_ap_inDescent = 1, B747DR_ap_flightPhase = 3,
                simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 2, simDR_autopilot_alt_hold_status = 0,
                B747DR_ap_FMA_active_pitch_mode = 6, B747BR_totalDistance = 11, B747BR_tod = 150,
                B747DR_ap_FMA_autothrottle_mode = 3, simDR_ind_airspeed_kts_pilot = 180, simDR_autopilot_airspeed_kts = 180,
                B747DR_ap_approach_mode = 1, simDR_autopilot_nav_status = 2, simDR_autopilot_gs_status = 1,
                B747DR_autopilot_nav_status = 2, B747DR_autopilot_gs_status = 1, simDR_hsi_nav1_horizontal_signal = 1,
                simDR_hsi_nav2_horizontal_signal = 1, simDR_hsi_nav1_vertical_signal = 1, simDR_hsi_nav2_vertical_signal = 1,
                simDR_hsi_vdef_dots_pilot = 2.5, B747DR_ils_dots = 1, simDR_radio_nav1_bearing_deg = 0,
                simDR_radio_nav2_bearing_deg = 0, simDR_autopilot_approach_status = 0}}
    end
    res = M.run({setup = app, clicks = dial(1.0, 30, 1), seconds = 12,
        each = function(d, t) if t >= 2.0 then d.simDR_hsi_vdef_dots_pilot = 0.3 end end})
    local gs = first(res, 0, function(s) return s.gs == 2 end)
    check(gs ~= nil and gs.t <= 2.6, string.format("G G/S captured at %s s with the MCP dialled (in range from 2.0 s)",
        gs and string.format("%.2f", gs.t) or "never"))
    check(not any(res, 0, 12, function(s) return s.alt_hold == 2 end), "G no level-off at a passing altitude in the approach")
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("MCP altitude dial tests passed: "..checks)
