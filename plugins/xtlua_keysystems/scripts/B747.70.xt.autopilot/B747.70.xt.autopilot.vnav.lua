--[[
*****************************************************************************************
* Program Script Name	:	B747.70.autopilot.vnav
* Author Name			:	Mark Parker (mSparks)
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2021-01-27	0.01a				Start of Dev
*
*
*
*
--]]
dofile("B747.70.xt.autopilot.vnavspd.lua")
local B747_afds_helpers = dofile("B747.70.xt.autopilot.afds_helpers.lua")

local VNAV_ENERGY_THRUST_ENTRY_DELAY_SEC = 2.0
local VNAV_ENERGY_THRUST_EXIT_DELAY_SEC = 5.0
local VNAV_ENERGY_DIAGNOSTIC_INTERVAL_SEC = 1.0
-- [B-13] The A/T's thrust is at idle for the descent's thrust release once its levers are at idle and X-Plane's
-- highest engine N1 (simDR_engine_N1) has stopped falling: less than VNAV_ENERGY_IDLE_N1_SETTLED_PCT_PER_SEC over
-- VNAV_ENERGY_N1_WINDOW_SEC.
local VNAV_ENERGY_IDLE_N1_SETTLED_PCT_PER_SEC = 0.1
local VNAV_ENERGY_N1_WINDOW_SEC = 2.0
local vnavEnergy = {
  active = false,
  pathAxis = 0,
  speedAxis = 0,
  pathError = 0,
  pathTrend = 0,
  lastPathError = nil,
  speedTrend = 0,
  lastSpeed = nil,
  lastSampleTime = nil,
  targetVSpeed = nil,
  thrustPolicy = B747_afds_helpers.VNAV_ENERGY_THRUST_NORMAL,
  thrustReason = B747_afds_helpers.VNAV_ENERGY_THRUST_REASON_NONE,
  protectionActive = false,
  pendingThrustPolicy = nil,
  pendingThrustSince = 0,
  lastDiagnosticTime = -VNAV_ENERGY_DIAGNOSTIC_INTERVAL_SEC,
  state = B747_afds_helpers.VNAV_ENERGY_STATE_INACTIVE,
  stateName = "INACTIVE",
  recoveryLimited = false,
  dragRequired = false,
  n1SampleTime = nil,
  n1Sample = nil,
  n1Rate = nil
}

function B747_reset_vnav_energy()
  vnavEnergy.active = false
  vnavEnergy.pathAxis = 0
  vnavEnergy.speedAxis = 0
  vnavEnergy.pathError = 0
  vnavEnergy.pathTrend = 0
  vnavEnergy.lastPathError = nil
  vnavEnergy.speedTrend = 0
  vnavEnergy.lastSpeed = nil
  vnavEnergy.lastSampleTime = nil
  vnavEnergy.targetVSpeed = nil
  vnavEnergy.thrustPolicy = B747_afds_helpers.VNAV_ENERGY_THRUST_NORMAL
  vnavEnergy.thrustReason = B747_afds_helpers.VNAV_ENERGY_THRUST_REASON_NONE
  vnavEnergy.protectionActive = false
  vnavEnergy.pendingThrustPolicy = nil
  vnavEnergy.state = B747_afds_helpers.VNAV_ENERGY_STATE_INACTIVE
  vnavEnergy.stateName = "INACTIVE"
  vnavEnergy.recoveryLimited = false
  vnavEnergy.dragRequired = false
  vnavEnergy.n1SampleTime = nil
  vnavEnergy.n1Rate = nil
  B747DR_vnav_energy_active = 0
  B747DR_vnav_energy_state = B747_afds_helpers.VNAV_ENERGY_STATE_INACTIVE
  B747DR_vnav_energy_thrust_policy = B747_afds_helpers.VNAV_ENERGY_THRUST_NORMAL
  B747DR_vnav_energy_thrust_reason = B747_afds_helpers.VNAV_ENERGY_THRUST_REASON_NONE
  B747DR_vnav_energy_path_trend = 0
  B747DR_vnav_energy_target_vspeed = 0
  B747DR_vnav_energy_drag_required = 0
end

local function B747_vnav_energy_update_trends(pathError, actualSpeed)
  local now = simDRTime
  local elapsed = vnavEnergy.lastSampleTime == nil and 0 or now - vnavEnergy.lastSampleTime
  if elapsed > 0 and elapsed <= 5 then
    local rawPathTrend = (pathError - vnavEnergy.lastPathError) * 60 / elapsed
    local rawSpeedTrend = (actualSpeed - vnavEnergy.lastSpeed) / elapsed
    vnavEnergy.pathTrend = vnavEnergy.pathTrend * 0.7 + rawPathTrend * 0.3
    vnavEnergy.speedTrend = vnavEnergy.speedTrend * 0.7 + rawSpeedTrend * 0.3
  elseif elapsed > 5 then
    vnavEnergy.pathTrend = 0
    vnavEnergy.speedTrend = 0
  end
  vnavEnergy.lastPathError = pathError
  vnavEnergy.lastSpeed = actualSpeed
  vnavEnergy.lastSampleTime = now
  return math.max(elapsed, 0)
end

-- [B-13] X-Plane's highest engine N1 (nil where it is not known) and how fast it moved over at least
-- VNAV_ENERGY_N1_WINDOW_SEC (%/s; nil until it has been seen that long). [review 24] Not the EEC's display N1
-- (laminar/B747/engines/display_N1): the PW EEC's is at least its low idle (48-50 % at FL260-350, X-Plane's idle
-- about 36 %) and lags X-Plane's N1 by about 10 s when its thrust formula reads low, so after a short SPD burst it sat
-- flat while X-Plane's N1 still fell and the speed rose (p23-line1, t=2846: the thrust would have ended 5 s after idle).
local function B747_vnav_energy_n1_rate()
  local n1 = nil
  if simDR_engine_N1 == nil then return nil, nil end
  for i = 0, 3 do
    local value = tonumber(simDR_engine_N1[i])
    if value ~= nil and (n1 == nil or value > n1) then n1 = value end
  end
  if n1 == nil then return nil, nil end
  local now = simDRTime
  local since = vnavEnergy.n1SampleTime
  if since == nil or now < since or now - since > 3 * VNAV_ENERGY_N1_WINDOW_SEC then
    vnavEnergy.n1SampleTime, vnavEnergy.n1Sample, vnavEnergy.n1Rate = now, n1, nil
  elseif now - since >= VNAV_ENERGY_N1_WINDOW_SEC then
    vnavEnergy.n1Rate = (n1 - vnavEnergy.n1Sample) / (now - since)
    vnavEnergy.n1SampleTime, vnavEnergy.n1Sample = now, n1
  end
  return n1, vnavEnergy.n1Rate
end

local function B747_vnav_energy_latch_thrust(guidance)
  local desiredPolicy = guidance.thrust_policy
  if not vnavEnergy.active or guidance.protection_active then
    vnavEnergy.thrustPolicy = desiredPolicy
    vnavEnergy.thrustReason = guidance.thrust_reason
    vnavEnergy.pendingThrustPolicy = nil
    return
  end
  if desiredPolicy == vnavEnergy.thrustPolicy then
    vnavEnergy.thrustReason = guidance.thrust_reason
    vnavEnergy.pendingThrustPolicy = nil
    return
  end
  if vnavEnergy.pendingThrustPolicy ~= desiredPolicy then
    vnavEnergy.pendingThrustPolicy = desiredPolicy
    vnavEnergy.pendingThrustSince = simDRTime
    return
  end

  local delay = VNAV_ENERGY_THRUST_ENTRY_DELAY_SEC
  if vnavEnergy.thrustPolicy == B747_afds_helpers.VNAV_ENERGY_THRUST_ALLOW then
    delay = VNAV_ENERGY_THRUST_EXIT_DELAY_SEC
  end
  if simDRTime - vnavEnergy.pendingThrustSince >= delay then
    vnavEnergy.thrustPolicy = desiredPolicy
    vnavEnergy.thrustReason = guidance.thrust_reason
    vnavEnergy.pendingThrustPolicy = nil
  end
end

local function B747_vnav_energy_is_available()
  return B747_afds_helpers.vnav_energy_mode_is_active({
    in_vnav_descent = B747DR_ap_inVNAVdescent,
    vnav_state = B747DR_ap_vnav_state,
    active_pitch_mode = B747DR_ap_FMA_active_pitch_mode,
    vs_status = simDR_autopilot_vs_status,
    flch_status = simDR_autopilot_flch_status,
    alt_hold_status = simDR_autopilot_alt_hold_status,
    gs_status = B747DR_autopilot_gs_status,
    actual_gs_status = simDR_autopilot_gs_status,
    approach_mode = B747DR_ap_approach_mode,
    actual_approach_status = simDR_autopilot_approach_status,
    autoland = B747DR_ap_autoland,
    active_land = B747DR_ap_active_land,
    radar_alt_ft = simDR_radarAlt1,
    altitude_to_capture_ft = simDR_pressureAlt1 - simDR_autopilot_altitude_ft,
    capture_window_ft = B747DR_alt_capture_window
  })
end

function B747_update_vnav_energy_mode_isolation()
  if vnavEnergy.active and not B747_vnav_energy_is_available() then
    B747_reset_vnav_energy()
  end
end

local function B747_vnav_energy_target_vspeed(nominalVSpeed)
  local pathError = B747BR_fpe
  -- [B-13] the A/T's thrust at idle: its levers at idle and X-Plane's N1 settled there (the levers alone where the
  -- N1 is not known; nil where the throttle is not known: released at 2 kt past the target). The levers at idle
  -- alone, the thrust ended while X-Plane's engines were still spooling down (N1 77 to 46 in 37 s at FL290) and the
  -- speed still rising, on a path idle could not hold the speed on (p23-line1: SPD, HOLD, SPD every 80-95 s).
  local atIdle = nil
  local n1, n1Rate = B747_vnav_energy_n1_rate()
  if tonumber(simDR_allThrottle) ~= nil then
    atIdle = simDR_allThrottle <= 0.001
    if n1 ~= nil then
      atIdle = atIdle and n1Rate ~= nil and n1Rate > -VNAV_ENERGY_IDLE_N1_SETTLED_PCT_PER_SEC
    end
  end
  local actualSpeed = simDR_ind_airspeed_kts_pilot
  local elapsed = B747_vnav_energy_update_trends(pathError, actualSpeed)
  local guidance = B747_afds_helpers.vnav_energy_guidance({
    path_error_ft = pathError,
    path_trend_fpm = vnavEnergy.pathTrend,
    target_speed_kts = simDR_autopilot_airspeed_kts,
    actual_speed_kts = actualSpeed,
    speed_trend_kts_per_sec = vnavEnergy.speedTrend,
    nominal_vspeed_fpm = nominalVSpeed,
    actual_vspeed_fpm = simDR_vvi_fpm_pilot,
    min_safe_speed_kts = B747DR_airspeed_Vmc + 15,
    previous_path_axis = vnavEnergy.pathAxis,
    previous_speed_axis = vnavEnergy.speedAxis,
    protection_active = vnavEnergy.protectionActive,
    -- The latched thrust policy lets a limited path recovery keep its
    -- thrust; an extended speedbrake holds that thrust at idle instead.
    previous_thrust_policy = vnavEnergy.thrustPolicy,
    previous_thrust_reason = vnavEnergy.thrustReason,
    speedbrake_lever = B747DR_speedbrake_lever,
    -- [B-13] the thrust for a slow speed ends only with the thrust at idle (and the speed not falling)
    thrust_at_idle = atIdle
  })

  if not vnavEnergy.active then
    vnavEnergy.targetVSpeed = nominalVSpeed
  end
  vnavEnergy.targetVSpeed = B747_afds_helpers.rate_limit(vnavEnergy.targetVSpeed,
    guidance.target_vspeed_fpm, elapsed,
    B747_afds_helpers.VNAV_ENERGY_DESCENT_RATE_LIMIT_FPM_PER_SEC,
    B747_afds_helpers.VNAV_ENERGY_SHALLOW_RATE_LIMIT_FPM_PER_SEC)
  if guidance.thrust_reason == B747_afds_helpers.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED
    and vnavEnergy.targetVSpeed > B747_afds_helpers.VNAV_ENERGY_MAX_DESCENT_FPM + 100 then
    -- Finish exchanging altitude for speed before declaring pitch recovery
    -- exhausted and allowing the speed loop to add energy.
    guidance.thrust_policy = B747_afds_helpers.VNAV_ENERGY_THRUST_IDLE
    guidance.thrust_reason = B747_afds_helpers.VNAV_ENERGY_THRUST_REASON_NONE
  end
  B747_vnav_energy_latch_thrust(guidance)
  vnavEnergy.active = true
  vnavEnergy.pathAxis = guidance.path_axis
  vnavEnergy.speedAxis = guidance.speed_axis
  vnavEnergy.pathError = pathError
  vnavEnergy.state = guidance.state
  vnavEnergy.stateName = guidance.state_name
  vnavEnergy.protectionActive = guidance.protection_active
  vnavEnergy.recoveryLimited = guidance.recovery_limited
  vnavEnergy.dragRequired = guidance.drag_required

  B747DR_vnav_energy_active = 1
  B747DR_vnav_energy_state = vnavEnergy.state
  B747DR_vnav_energy_thrust_policy = vnavEnergy.thrustPolicy
  B747DR_vnav_energy_thrust_reason = vnavEnergy.thrustReason
  B747DR_vnav_energy_path_trend = vnavEnergy.pathTrend
  B747DR_vnav_energy_target_vspeed = vnavEnergy.targetVSpeed
  B747DR_vnav_energy_drag_required = vnavEnergy.dragRequired and 1 or 0
  return vnavEnergy.targetVSpeed
end

function B747_get_vnav_energy_diagnostics()
  return vnavEnergy
end

function B747_log_vnav_energy_diagnostics()
  if not vnavEnergy.active
    or simDRTime - vnavEnergy.lastDiagnosticTime < VNAV_ENERGY_DIAGNOSTIC_INTERVAL_SEC then
    return
  end
  vnavEnergy.lastDiagnosticTime = simDRTime
  local autothrottleModes = {[0] = "NONE", [1] = "HOLD", [2] = "IDLE", [3] = "SPD",
    [4] = "THR", [5] = "THR REF"}
  print(string.format(
    "[VNAV ENERGY] path=%+.0fft trend=%+.0fft/min targetIAS=%.1f actualIAS=%.1f cmdVS=%+.0f actualVS=%+.0f pitchTarget=%.2f atMode=%s thrustCmd=%.3f quadrant=%s thrustReason=%s",
    vnavEnergy.pathError, vnavEnergy.pathTrend, simDR_autopilot_airspeed_kts,
    simDR_ind_airspeed_kts_pilot, simDR_autopilot_vs_fpm, simDR_vvi_fpm_pilot,
    B747DR_flight_director_pitch or 0,
    autothrottleModes[B747DR_ap_FMA_autothrottle_mode] or "UNKNOWN", simDR_allThrottle,
    vnavEnergy.stateName,
    B747_afds_helpers.vnav_energy_thrust_reason_name(vnavEnergy.thrustReason)))
end

function deceleratedDesent(targetvspeed)
  if simDR_autopilot_airspeed_is_mach == 1 then return targetvspeed end --can't do this in mach mode, slow tf down already

  local meet = B747_rescale(0,0,400,500,B747BR_fpe)
  -- SPD REST is blank until the crew enters one; SPD TRANS is then both
  -- boundaries and there is no lower speed to decelerate towards.
  local transitionAlt=tonumber(getFMSData("desspdtransalt"))
  local restrictionAlt=tonumber(getFMSData("desrestalt")) or transitionAlt
  local upperAlt=math.max(transitionAlt,restrictionAlt)
  if simDR_pressureAlt1>upperAlt+1000 then 
    return targetvspeed -meet
  end --nowhere near a restriction yet
  local lowerAlt=math.min(transitionAlt,restrictionAlt)
  local upperAltspdval=tonumber(getFMSData("destranspd"))
  local lowerAltspdval=tonumber(getFMSData("desrestspd")) or upperAltspdval

  if simDR_ind_airspeed_kts_pilot<=(lowerAltspdval+5) then return targetvspeed end --already low enough
  --less than upperAlt+1000
   -- greater than lowerAltspdval
  if simDR_ind_airspeed_kts_pilot>(upperAltspdval+5) then 
    --print("upperAltspdval deceleratedDesent upperAlt"..upperAlt.." lowerAlt=".. lowerAlt .." upperAltspdval=".. upperAltspdval .." simDR_pressureAlt1="..simDR_pressureAlt1.." simDR_ind_airspeed_kts_pilot="..simDR_ind_airspeed_kts_pilot)
    return -500 
  end --approximate 500fpm

  if simDR_pressureAlt1>lowerAlt+1000 then return targetvspeed end --not at next restriction yet

  if simDR_ind_airspeed_kts_pilot>(lowerAltspdval+5) then 
    --print("lowerAltspdval deceleratedDesent upperAlt"..upperAlt.." lowerAlt=".. lowerAlt .." upperAltspdval=".. upperAltspdval .." simDR_pressureAlt1="..simDR_pressureAlt1.." simDR_ind_airspeed_kts_pilot="..simDR_ind_airspeed_kts_pilot)
    return -500 
  end --approximate 500fpm

  return targetvspeed-meet
  --print("oob deceleratedDesent upperAlt"..upperAlt.." lowerAlt=".. lowerAlt .." upperAltspdval=".. upperAltspdval .." simDR_pressureAlt1="..simDR_pressureAlt1.." simDR_ind_airspeed_kts_pilot="..simDR_ind_airspeed_kts_pilot)


end
-- [B-14] The distance to the route's entry fmsO[index] through the fly-by turn LNAV flies at the fix it holds
-- (B747_lnav_vnav_turn, afds.vnav_turn_distance_nm): to that fix (until the bisector, and on past it while the path
-- still aims at it: the profile's flags change up to 2 s later), or once past the bisector to the fix after it;
-- elsewhere the straight distance (direct). A turn taken while the one before it still gives back its cut (prev, a
-- short leg) adds what that one gives back to the distance to its fix, and the turn before serves its own fix (the
-- profile up to 2 s late). Off the turn's path while LNAV does not fly the turns (HDG SEL, a direct-to) the turn fades
-- out towards the straight distance (turn.fade, moved by LNAV with the distance flown: B747_lnav_update_vnav_hold):
-- ended there, the path stepped 330-500 ft (review 29 MAJOR 1).
local function B747_vnav_turn_distance(fmsO, index, direct)
  local turn = B747_lnav_vnav_turn
  if turn == nil or fmsO == nil or fmsO[index] == nil then return direct end
  local prev = turn.prev
  if prev ~= nil and index == prev.fix then turn, prev = prev, nil end
  if fmsO[turn.fix] == nil then return direct end
  local toFix = index == turn.fix
  if not toFix and not (turn.released and index == turn.fix + 1) then return direct end
  local fix = fmsO[turn.fix]
  local d = getDistance(fix[5], fix[6], simDR_latitude, simDR_longitude)
  local b = math.rad(getHeading(fix[5], fix[6], simDR_latitude, simDR_longitude))
  local leg = toFix and 0 or getDistance(fix[5], fix[6], fmsO[index][5], fmsO[index][6])
  local extra = 0
  if toFix and prev ~= nil and fmsO[prev.fix] ~= nil then
    local p = fmsO[prev.fix]
    local pd = getDistance(p[5], p[6], simDR_latitude, simDR_longitude)
    local pb = math.rad(getHeading(p[5], p[6], simDR_latitude, simDR_longitude))
    extra = B747_afds_helpers.vnav_turn_give_back_nm(pd * math.sin(pb), pd * math.cos(pb), prev.in_course,
      prev.out_course, prev.lead_nm)
  end
  local distance = B747_afds_helpers.vnav_turn_distance_nm(d * math.sin(b), d * math.cos(b), turn.in_course,
    turn.out_course, turn.lead_nm, turn.start_nm, toFix, leg, direct, extra)
  local fade = turn.fade or 0
  return distance + (direct - distance) * fade
end
-- the same to the descent profile's entry `point` (its position), when that is the turn's fix, the one after it or
-- the fix of the turn before it
local function B747_vnav_point_distance(fmsO, point, direct)
  local turn = B747_lnav_vnav_turn
  if turn == nil or fmsO == nil then return direct end
  for _, index in ipairs({turn.fix, turn.fix + 1, turn.prev ~= nil and turn.prev.fix or 0}) do
    local entry = fmsO[index]
    if entry ~= nil and math.abs(entry[5] - point[1]) <= 1e-7 and math.abs(entry[6] - point[2]) <= 1e-7 then
      return B747_vnav_turn_distance(fmsO, index, direct)
    end
  end
  return direct
end
-- [B-14] When the path's next point (lat, lon) changes, or LNAV's turn (B747_lnav_vnav_turn: taken, ended, another),
-- the path's altitude is carried on from where it was and the step is taken out over the next VNAV_PATH_BLEND_NM of
-- `distance` flown, nearer or farther (a real FMC's path is one line along the lateral path): the turns' legs and arcs
-- do not quite match (LNAV draws its arc for the TAS it is coming to, in the wind), the descent profile's flags change
-- up to 2 s after the bisector, and a turn that ends at HDG SEL, a direct-to or a route edit leaves the cut it had
-- taken off (77 ft 2.5 nm before NETOM's 86 deg turn). A step over VNAV_PATH_BLEND_MAX_FT (a new route, a direct-to)
-- is taken at once, but one at a turn's own bisector - the path's point going from the turn's fix to the next (or the
-- turn before's, carried on) - is taken out up to VNAV_PATH_BLEND_TURN_MAX_FT: on a leg shorter than about 2.4 nm the
-- 747 crosses the next fix's bisector inside the turn's cut, and the step there (+255 ft with 2.2 nm, +268 with 2.0)
-- was taken at once (review 28 MINOR 2). What the blend still had to take out goes on through a change whose own step
-- (raw: the path before the blend) is within the limit: with the step at a bisector still being taken out when the
-- turn ended, the two together went over 250 ft and at once (-503 ft; review 30 MINOR 2). Over it, the new path is
-- shown at once, the blend with it: a route edit's own step over 250 ft blended as a turn's end ran the path up to
-- 258 ft off the new one (review 31 MINOR 1), and with the blend carried on through it the path stepped -265 ft at
-- once and ran as far off the new one (review 32 MINOR 1). Taken out only as the distance fell, a step stayed while it
-- grew under vectors (review 27). state: the descent profile's (vnavPathBlend) or the approach path's.
local VNAV_PATH_BLEND_NM = 2
local VNAV_PATH_BLEND_MAX_FT = 250
local VNAV_PATH_BLEND_TURN_MAX_FT = 1000
local vnavPathBlend = {lat = nil, lon = nil, turn = nil, alt = 0, raw = 0, offset = 0, from = 0, t = -100}
local approachPathBlend = {lat = nil, lon = nil, turn = nil, alt = 0, raw = 0, offset = 0, from = 0, t = -100}
-- whether the path's point going from (fromLat, fromLon) to (lat, lon) is turn t's bisector: its fix to the next
local function B747_vnav_turn_switch(t, fromLat, fromLon, lat, lon)
  return t ~= nil and t.lat ~= nil and math.abs(fromLat - t.lat) <= 1e-7 and math.abs(fromLon - t.lon) <= 1e-7
    and math.abs(lat - t.next_lat) <= 1e-7 and math.abs(lon - t.next_lon) <= 1e-7
end
local function B747_vnav_path_continuity(state, lat, lon, distance, alt)
  local b = state
  local turn = B747_lnav_vnav_turn
  if b.lat ~= nil and simDRTime - b.t <= 5 then
    if math.abs(lat - b.lat) > 1e-7 or math.abs(lon - b.lon) > 1e-7 or turn ~= b.turn then
      local carry, own = b.alt - b.raw, b.raw - alt
      local limit = VNAV_PATH_BLEND_MAX_FT
      if turn ~= nil and turn == b.turn and (B747_vnav_turn_switch(turn, b.lat, b.lon, lat, lon)
          or B747_vnav_turn_switch(turn.prev, b.lat, b.lon, lat, lon)) then
        limit = VNAV_PATH_BLEND_TURN_MAX_FT
      end
      if math.abs(own) > limit then
        b.offset = 0
      else
        b.offset, b.from = carry + own, distance
      end
    end
  else
    b.offset = 0
  end
  local offset = 0
  if b.offset ~= 0 then
    local w = math.max(0, math.min(1, 1 - math.abs(b.from - distance) / VNAV_PATH_BLEND_NM))
    offset = b.offset * w
    if w <= 0 then b.offset = 0 end
  end
  b.lat, b.lon, b.turn, b.t = lat, lon, turn, simDRTime
  b.raw, b.alt = alt, alt + offset
  return b.alt
end
-- [A-5] The approach's path to the runway (B747_afds_helpers.vnav_approach_path) at the aircraft:
-- {alt, gradient, distance, ahead = the next fix's point} within VNAV_APPROACH_RANGE_NM of the arrival
-- runway along the route (then
-- within VNAV_APPROACH_LEAVE_NM), else nil. The distance goes by a fix sequenced early for its turn until
-- it is passed, and the final approach angle is the CIFP's (B747_route_constraints) from there to the
-- runway. [B-14] Through a fly-by turn the distance goes along the turn (B747_vnav_turn_distance) and the path
-- carries on across the change of the fix it goes by (B747_vnav_path_continuity): straight to the held fix and then
-- to the next one it stepped by 100-200 ft at the bisector.
local approachRunway = nil   -- the runway of the approach the aircraft is in: its name and position
function B747_vnav_approach_path(fmsO)
  if fmsO == nil then approachRunway = nil return nil end
  local runway = B747_afds_helpers.route_runway_index(fmsO, getDistance, 10)
  local active = B747DR_fmscurrentIndex
  if runway == nil or active < 1 or active > runway then approachRunway = nil return nil end
  local first = active
  local held = B747DR_vnav_hold_index or 0
  if held > 0 and held < first then first = held end
  local glide = B747_afds_helpers.VNAV_APPROACH_GLIDE_DEG
  if B747_route_constraints ~= nil then
    for i = first, runway do
      local c = B747_route_constraints[i]
      if c ~= nil and c.vangle ~= nil then glide = c.vangle end
    end
  end
  local points, toRunway = B747_afds_helpers.vnav_approach_path(fmsO, runway, first, getDistance,
    tonumber(getFMSData("transalt")), B747BR_cruiseAlt, glide, B747_route_constraints)
  local distance = B747_vnav_turn_distance(fmsO, first,
    getDistance(simDR_latitude, simDR_longitude, fmsO[first][5], fmsO[first][6])) + toRunway[first]
  local runwayKey = tostring(fmsO[runway][8]).."|"..tostring(fmsO[runway][5]).."|"..tostring(fmsO[runway][6])
  if distance <= B747_afds_helpers.VNAV_APPROACH_RANGE_NM then
    approachRunway = runwayKey
  elseif approachRunway ~= runwayKey or distance > B747_afds_helpers.VNAV_APPROACH_LEAVE_NM then
    approachRunway = nil
    return nil
  end
  local alt, gradient = B747_afds_helpers.vnav_path_at(points, distance)
  alt = B747_vnav_path_continuity(approachPathBlend, fmsO[first][5], fmsO[first][6], distance, alt)
  -- the next fix ahead in the route's order (the one flown to, or held, and on), not by distance: off the route
  -- the distance to the fix flown to can be more than to the one before it
  local ahead = points[1]
  for _, point in ipairs(points) do
    if point.index ~= nil and point.index >= first and point.index < ahead.index then ahead = point end
  end
  return {alt = alt, gradient = gradient, distance = distance, ahead = ahead}
end
function setDescentVSpeed(fmsO)
  -- [A-5] In the approach VNAV PTH flies the path to the runway: the path error is from it, and the V/S
  -- is its gradient at the ground speed corrected by the path error, never a climb, also within 600 ft
  -- above the AP altitude (the altitude capture levels off there). Before, within 15 NM of the end of
  -- descent the path error was from a 290 ft/nm line to the airport's reference point and the V/S aimed
  -- at the next fix's altitude, left alone within 600 ft above the AP altitude: p6-line1 (EHAM,
  -- 2026-10-16) climbed at +600 fpm to a passed fix's 3,400 ft and p6-L1 (EINN) stayed at 3,450 ft,
  -- 450 ft above the 3,000 ft it was cleared to; both then captured a false glide slope lobe.
  -- The path holds the speed within the flaps' placard - 2 kt and Vmo - 11 kt: at idle above the path the
  -- 747 accelerated through the flaps 5 placard in the approach model. The limit lies above the A/T's
  -- targets with the flaps out (VNAV's and the window's speed at most the placard - 5), or the path could not
  -- be regained from above with the target there; at the placard - 3 high approaches at the cap took the
  -- false glide slope lobe more often, and in a strong tailwind the V/S's lag leaves the 747 up to 0.3 kt
  -- over the placard.
  local approach = nil
  if simDR_radarAlt1 > 10 then approach = B747_vnav_approach_path(fmsO) end
  B747_vnav_approach_active = approach ~= nil and B747DR_ap_vnav_state > 0
  if approach ~= nil then
    B747BR_fpe = simDR_pressureAlt1 - approach.alt
    B747_reset_vnav_energy()
    if B747DR_ap_vnav_state > 0 then
      local speedLimit = flapPlacardSpeedLimit() + 3
      if (B747DR_airspeed_Vmo or 0) > 100 then speedLimit = math.min(speedLimit, B747DR_airspeed_Vmo - 11) end
      simDR_autopilot_vs_fpm = B747_afds_helpers.vnav_path_vspeed(approach.gradient,
        simDR_groundspeed * 1.94384, B747BR_fpe, speedLimit - simDR_ind_airspeed_kts_pilot)
    end
    -- the vertical bearing: from here down to the next fix's altitude
    B747DR_ap_vb = math.deg(math.atan((simDR_pressureAlt1 - approach.ahead.alt)
      / (math.max(approach.distance - approach.ahead.d, 0.1) * 6076.12)))
    B747DR_ap_fpa = math.atan2(simDR_autopilot_vs_fpm, simDR_groundspeed * 196.85) * -57.2958
    return
  end

  local pathGradient=nil -- ft/nm, the path's into the target, where the path error is from the FMC's profile
  if B747BR_totalDistance>=15 then
    --set in setDistances when < 15
    local glideAlt= B747DR_fmstargetDistance*290 +B747DR_ap_vnav_target_alt
    pathGradient=290
    if string.len(B747BR_vnavProfile)>2 then
      local vnavData=json.decode(B747BR_vnavProfile)
      --print("B747BR_vnavProfile in setDescentVSpeed="..B747BR_vnavProfile)
      local endI = table.getn(vnavData)
      for i = 1, endI, 1 do
        if vnavData[i][4] then
          --if i==1 then break end
          --local altDiff=vnavData[i-1][3]-vnavData[i][3]

          local legDist = B747_vnav_point_distance(fmsO, vnavData[i],
            getDistance(simDR_latitude, simDR_longitude, vnavData[i][1], vnavData[i][2]))
          glideAlt = B747_vnav_path_continuity(vnavPathBlend, vnavData[i][1], vnavData[i][2], legDist,
            legDist*vnavData[i][5] +vnavData[i][3])
          pathGradient=vnavData[i][5]
          B747DR_ap_vnav_target_alt=vnavData[i][3]
          B747DR_fmstargetDistance=legDist
          --print("setDescentVSpeed "..glideAlt)
          break
        end
      end
    end
    B747BR_fpe	= simDR_pressureAlt1-glideAlt
  end
  if simDR_autopilot_altitude_ft+600 > simDR_pressureAlt1 then
    B747_reset_vnav_energy()
    return
  end --dont set fpm near hold alt
  local distanceNM=B747DR_fmstargetDistance
  
  
  if distanceNM<1 then
    distanceNM=1
  end

  local nextDistanceInFeet=distanceNM*6076.12
  local time=distanceNM*30.8666/(simDR_groundspeed) --time in minutes, gs in m/s....
  -- [B-13] The V/S aims at the target's altitude from the aircraft's (the energy mode corrects the path error, which
  -- is from the path through the target). With the AFDS's altitude (simDR_autopilot_altitude_ft, which VNAV sets)
  -- above 5,000 ft it aimed 250 ft below the target: the 747 sat below the path, reached the point's altitude about
  -- 1 nm before the point, levelled off there 230-270 ft below the path and climbed back with thrust after it: the A/T
  -- SPD, IDLE, HOLD, SPD at every point of EIDW-EHAM's descent (p21-line1: 37 changes, every 95-105 s). At or below
  -- 5,000 ft it aimed at the target less the path error, which doubled its own correction of the path error (the
  -- energy mode's on top).
  local vdiff=B747DR_ap_vnav_target_alt-simDR_pressureAlt1 --to be negative
  local vspeed=vdiff/time
  -- [B-13] Within the last nm (the distance held at 1 nm above) the path's own V/S - its gradient at the ground
  -- speed - and the path error over the time the 1 nm takes, which is vdiff / time further out. vdiff over the 1 nm's
  -- time took the V/S down with the distance to 0 at the point (p23-line1: -1,700 to 0 fpm in the last 8 s at each
  -- point): the 747 levelled off there, and with the next segment's path below it the descent went on 130-275 ft
  -- above the path, the A/T to IDLE and HOLD, and SPD again once the speed fell.
  if pathGradient~=nil and B747DR_fmstargetDistance<1 then
    vspeed=-pathGradient*simDR_groundspeed*1.94384/60-B747BR_fpe/time
  end
  --[[if B747DR_ap_vnav_target_alt>simDR_pressureAlt1 then
    vspeed=0
  end]]--
  --print("setDescentVSpeed speed=".. simDR_groundspeed .. " distance=".. distanceNM .. " vspeed=" .. vspeed .. " vdiff=" .. vdiff .. " time=" .. time.. " B747DR_ap_vnav_target_alt=" .. B747DR_ap_vnav_target_alt)
		  --speed=89.32039642334 distance=2.9459299767094vspeed=-6559410.6729958
  B747DR_ap_vb = math.atan2(vdiff,nextDistanceInFeet)*-57.2958
  if vspeed<-2500 then vspeed=-2500 end
  if vspeed>1500 then vspeed=1500 end
  if simDR_radarAlt1<=10 then
    simDR_autopilot_vs_fpm = -250 -- slow descent, reduces AoA which if it goes to high spoils the landing
    B747_reset_vnav_energy()
    B747DR_ap_inVNAVdescent=0
    B747DR_ap_vnav_state=0
    B747DR_ap_thrust_mode=0
    setDescent(false)
    print("End Descent")
    return
  end
  if B747DR_ap_vnav_state > 0 then
    local targetVSpeed = deceleratedDesent(vspeed)
    if B747_vnav_energy_is_available() then
      targetVSpeed = B747_vnav_energy_target_vspeed(targetVSpeed)
    else
      B747_reset_vnav_energy()
    end
    simDR_autopilot_vs_fpm = targetVSpeed
  else
    B747_reset_vnav_energy()
  end
  B747DR_ap_fpa=math.atan2(simDR_autopilot_vs_fpm,simDR_groundspeed*196.85)*-57.2958
  
  --[[if B747DR_descentSpeedGradient>0 and simDR_pressureAlt1>B747DR_target_descentAlt then
    simDR_autopilot_airspeed_kts=B747DR_target_descentSpeed+(simDR_pressureAlt1-B747DR_target_descentAlt)*B747DR_descentSpeedGradient
    if simDR_autopilot_airspeed_is_mach == 1 then
      B747DR_ap_ias_dial_value=simDR_autopilot_airspeed_kts_mach*100
    end
    --print("set descentSpeed to " .. simDR_autopilot_airspeed_kts)
  end]]

  
end
  
  function getDescentTarget()
    B747DR_target_descentSpeed=tonumber(getFMSData("destranspd"))
    B747DR_target_descentAlt=tonumber(getFMSData("desspdtransalt"))
    if B747DR_target_descentAlt>simDR_pressureAlt1 
      or simDR_autopilot_airspeed_kts<B747DR_target_descentSpeed 
      then 
      B747DR_descentSpeedGradient=0 
      return 
    end
    B747DR_descentSpeedGradient=(simDR_autopilot_airspeed_kts-B747DR_target_descentSpeed)/(simDR_pressureAlt1-B747DR_target_descentAlt)
    print("set descentSpeedGradient to " .. B747DR_descentSpeedGradient)
  end
