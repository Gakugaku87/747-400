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

local VNAV_ENERGY_THRUST_ENTRY_DELAY_SEC = 2.0
local VNAV_ENERGY_THRUST_EXIT_DELAY_SEC = 5.0
local VNAV_ENERGY_DIAGNOSTIC_INTERVAL_SEC = 1.0
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
  dragRequired = false
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
    protection_active = vnavEnergy.protectionActive
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
  local upperAlt=math.max(tonumber(getFMSData("desspdtransalt")),tonumber(getFMSData("desrestalt")))
  if simDR_pressureAlt1>upperAlt+1000 then 
    return targetvspeed -meet
  end --nowhere near a restriction yet
  local lowerAlt=math.min(tonumber(getFMSData("desspdtransalt")),tonumber(getFMSData("desrestalt")))
  local upperAltspdval=tonumber(getFMSData("destranspd"))
  local lowerAltspdval=tonumber(getFMSData("desrestspd"))

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
function setDescentVSpeed(fmsO)

  if B747BR_totalDistance>=15 then
    --set in setDistances when < 15
    local glideAlt= B747DR_fmstargetDistance*290 +B747DR_ap_vnav_target_alt
    if string.len(B747BR_vnavProfile)>2 then
      local vnavData=json.decode(B747BR_vnavProfile)
      --print("B747BR_vnavProfile in setDescentVSpeed="..B747BR_vnavProfile)
      local endI = table.getn(vnavData)
      for i = 1, endI, 1 do
        if vnavData[i][4] then
          --if i==1 then break end
          --local altDiff=vnavData[i-1][3]-vnavData[i][3]

          local legDist = getDistance(simDR_latitude, simDR_longitude, vnavData[i][1], vnavData[i][2])
          glideAlt= legDist*vnavData[i][5] +vnavData[i][3]
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
  local early=100
  if B747DR_ap_vnav_target_alt>simDR_pressureAlt1 then
    early=0
  elseif simDR_autopilot_altitude_ft>5000 then
    early=250 
  else
    early=B747BR_fpe
  end
  local vdiff=B747DR_ap_vnav_target_alt-simDR_pressureAlt1-early --to be negative
  local vspeed=vdiff/time
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
