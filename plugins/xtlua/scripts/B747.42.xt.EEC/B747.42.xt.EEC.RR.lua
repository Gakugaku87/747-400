--[[
****************************************************************************************
* Program Script Name	:	B747.42.xt.EEC.RR.lua
* Author Name			:	Marauder28
*                   (with SIGNIFICANT contributions from @kudosi for aeronautic formulas)
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2021-01-11	0.01a				      Start of Dev
*	  2021-12-11	0.1				        Initial Release
*
*
*
*****************************************************************************************
]]

-- (2026-11-25, the RB211's rebuild: GAP_ANALYSIS.md §8, notes/ATA-70-80.md
-- §40) the RB211's thrust and EPR by difference from the PW4056's
-- (B747.42.rr_model.lua). The EEC (B747.42.xt.eec_thrust.lua) runs on the
-- PW4056's scale for it, with the P&W's ratings and its own takeoff table;
-- this file shows the RB211's own EPR (the reference, the maximum, the
-- command and the engine's), N3 X-Plane's N2 and N2 (IP) shown only (below,
-- N2_display_RR), N1 on the TCDS's scale (N1_TCDS) and EGT as before.
-- Gone with the rebuild: the upstream's takeoff EPR (take_off_EPR_RR: its
-- thrust estimate through the EPR cubic, whose top at 1.71 left the takeoff
-- thrust free), the climb EPR (in_flight_EPR_RR: a design climb rate's
-- thrust), the cruise table's lookups (P85M_epr_RR), the go-around formula,
-- the EPR shown from thrust / density ratio, the 0.97 floor and its PID
dofile("B747.42.rr_model.lua")
local RRM = B747_rr_model

-- (2026-11-25, the user's 「RRのN1」: GAP_ANALYSIS.md N19-ENG-23) the N1
-- shown on the TCDS's scale, 100 % LP = 3,900 rpm (TCDS_RB211 p.10). The
-- upstream's N1 (N1_display_RR, with its idle, start and ground shaping)
-- counts 3,600 rpm as 100 % and stays so inside; shown = it x 3,600 /
-- 3,900. The limits are the TCDS's on that scale (p.18: LP 110.5 % at
-- take-off, 5 min; 91 % in reverse, 40 s). Before, the upstream's N1 shown
-- itself, 8.3 % over: 111.0 % at FAOR on a 30 C day (s432) for 102.5 %,
-- just under its 111.5 % red line, which then held the takeoff thrust
-- (TCDS: 119.7 % on that scale)
local N1_TCDS = 3600 / 3900

-- the engine (G or H) from the simconfig's string
local function rr_variant()
  return RRM.variant(simConfigData["data"].PLANE.engines)
end

--This function calculates the target position of the throttle target on the Upper EICAS
--(2026-11-25) the EEC's command for the lever (B747.42.xt.eec_thrust.lua, on the
--PW4056's scale) shown as the RB211's EPR. Before, 0.95 to 0.99 x the max line
--along the lever
function throttle_resolver_angle_RR(engine_in)
  return RRM.display(B747_eec_command(engine_in), simDR_epr_mach)
end

  --The N1 the display shows at minimum idle. The idle selection (minimum or
  --approach idle) and X-Plane's idle setting are B747.42.xt.eec_thrust.lua's
  --(FCOM p.877-878).
function engine_idle_control_RR(altitude_ft_in)
    return -1.45E-08 * altitude_ft_in^2 + 0.00121 * altitude_ft_in + 21.9
  end

  local last_thrust_n = {0.0, 0.0, 0.0, 0.0}
  local N1_engine_start = {0.0, 0.0, 0.0, 0.0}
  local last_N1 = {0.0, 0.0, 0.0, 0.0}
  function N1_display_RR(altitude_ft_in, thrust_N_in, engine_in)
    local N1_corrected_rpm = 0.0
    local N1_pct = 0.0
    local N1_actual = 0.0
    local N1_corrected_thrust_calibrated_N = 0.0
    local N1_corrected_thrust_n = 0.0
    local N1_low_idle = 0.0
    local N1_idle_capture = 0.0
    local N1_zero_thrust = 0.0

    if N1_engine_start[engine_in] == nil then N1_engine_start[engine_in] = 0.0 end
    if last_N1[engine_in] == nil then last_N1[engine_in] = 0.0 end
    --(2026-11-25) engine 0's (the tables count from 1); EPR_display_RR set it before
    if last_thrust_n[engine_in] == nil then last_thrust_n[engine_in] = 0.0 end

    if simDR_engine_running[engine_in] == 0 and thrust_N_in >= 0.0  and simDR_engine_starter_status[engine_in] == 0 then
      thrust_N_in = last_thrust_n[engine_in]-25
    end

    if simDR_engine_running[engine_in] == 1 and last_thrust_n[engine_in] < thrust_N_in and last_thrust_n[engine_in] < 3500 then
      thrust_N_in = last_thrust_n[engine_in]
    end

    if thrust_N_in < 0.0 and simDR_engine_running[engine_in] == 1 then
      thrust_N_in = 0.0
    end
    N1_corrected_thrust_n = thrust_N_in / (1000 * sigma_density_ratio)
    --N1_corrected_thrust_n = thrust_N_in / (1000 * pressure_ratio)

    --N1_corrected_thrust_calibrated_N = (-0.4795 * mach^2 + 0.5903 * mach + 0.925) * N1_corrected_thrust_n  --Sigma version 2
    N1_corrected_thrust_calibrated_N = N1_corrected_thrust_n  --no calibration needed

    N1_corrected_rpm = (0.0136 * mach^2 - 0.00905 * mach - 0.0107) * N1_corrected_thrust_calibrated_N^2 + (-5.84 * mach^2 + 0.512 * mach + 13.5) * N1_corrected_thrust_calibrated_N
      + (-508 * mach^2 + 1792.2 * mach + 1065.4)
    
    --N1_corrected_rpm = (0.0136 * mach^2 - 0.00905 * mach - 0.0107) * N1_corrected_thrust_calibrated_N^2 + (-5.84 * mach^2 + 0.512 * mach + 13.5) * N1_corrected_thrust_calibrated_N
    --  + (-508 * mach^2 + 1792.2 * mach + B747_rescale(0.0, 0.0, 750.0, 1065.4, simDR_rpm[engine_in]))  -- + 1065.4)

    N1_pct = N1_corrected_rpm / 3600 * 100 * math.sqrt(temperature_K / 288.15)

    --Engine Idle Logic (Minimum / Approach)
    N1_low_idle = engine_idle_control_RR(altitude_ft_in)
    N1_idle_capture = -43.988 * mach^2 + 63.256 * mach + 28.896 + 0.7
    N1_zero_thrust = (-508 * mach^2 + 1792.2 * mach + 1065.4) / 3600 * 100 * math.sqrt(temperature_K / 288.15)


    --Use slightly different formulas depending on ground versus air to prevent display anomalies
    if simDR_onGround == 0 then
      if N1_pct < N1_idle_capture then
        N1_actual = math.max((N1_idle_capture - N1_low_idle) / (N1_idle_capture - N1_zero_thrust) * (N1_pct - N1_zero_thrust) + N1_low_idle, N1_low_idle)
      else
        N1_actual = N1_pct
      end
    else
      if N1_pct < 51 then
        N1_actual = (51 - N1_low_idle) / (51 - N1_idle_capture) * (N1_pct - N1_idle_capture) + N1_low_idle
      else
        N1_actual = N1_pct
      end
    end

    if N1_actual < N1_low_idle and N1_corrected_rpm >= 1065.4 and simDR_engine_running[engine_in] == 1 then
      
      N1_actual = B747_animate_value(last_N1[engine_in],N1_low_idle,0,115,0.1) 
      --print(" pin N1_actual 2 "..N1_actual)
    elseif simDR_engine_running[engine_in] == 0 then
      N1_actual = B747_animate_value(last_N1[engine_in],simDR_N1[engine_in],0,115,0.1) 
      --print(" pin N1_actual 1 "..N1_actual.. " n1 "..simDR_N1[engine_in])
    end

    --Handle display of an engine startup
    if simDR_engine_running[engine_in] == 0 and simDR_engine_starter_status[engine_in] == 1 and last_thrust_n[engine_in] <= -37500 then
      if last_thrust_n[engine_in] < -50000 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] + 125
      elseif last_thrust_n[engine_in] < -40000 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] + 50  --+ 1000
      elseif last_thrust_n[engine_in] < -30000 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] + 5  --+ 500
      end
    elseif simDR_engine_running[engine_in] == 1 and last_thrust_n[engine_in] <= thrust_N_in and last_thrust_n[engine_in] < 3500 then
      last_thrust_n[engine_in] = last_thrust_n[engine_in] + 50  --+ 100
    --Handle display of an engine shutdown
    elseif simDR_engine_running[engine_in] == 0 and simDR_engine_starter_status[engine_in] == 0 and simDR_N1[engine_in] < 10 then
      thrust_N_in = last_thrust_n[engine_in]
      if N1_actual >= 20 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] - 75
      elseif N1_actual > 10 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] - 50
      elseif N1_actual > 0 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] - 25
      else
        last_thrust_n[engine_in] = -75000
      end
    else
      last_thrust_n[engine_in] = thrust_N_in
    end

    --Because of the way the N1 formula calculates based on thrust, this sends the correct value to the N2 & N3 functions during startup
    if simDR_engine_running[engine_in] == 0 and simDR_engine_starter_status[engine_in] == 1 or N1_pct < 51 then
      if (simDR_engine_running[engine_in] == 0 and simDR_engine_starter_status[engine_in] == 0) then
        if N1_engine_start[engine_in] > N1_actual then
          N1_engine_start[engine_in] = N1_engine_start[engine_in] - 0.1
        end
      else
        N1_engine_start[engine_in] = N1_pct
      end
      --print("<<<*** STARTUP ***>>>")
    elseif simDR_engine_running[engine_in] == 1 and N1_actual < N1_engine_start[engine_in] and N1_actual < N1_low_idle then
      N1_engine_start[engine_in] = N1_engine_start[engine_in] + 0.05
      --print("<<<### EXTENDED STARTUP ###>>> -- N1_engine_start = ", N1_engine_start[engine_in])
    end

    --Try to keep REVERSER N1 at or below 91% per the engine TCDS
    --(2026-11-25) on the TCDS's scale (p.18: 91 % of 3,900 rpm, 40 s); before,
    --the upstream's N1 at 91, 84 % of the TCDS's
    if simDR_onGround == 1 and math.max(simDR_reverser_on[0], simDR_reverser_on[1], simDR_reverser_on[2], simDR_reverser_on[3]) == 1 then
      if N1_actual * N1_TCDS > 91.0 then
        B747_setMaxThrust( simDR_thrust_max - 250)
      end
    elseif simDR_onGround == 1 and math.max(simDR_reverser_deploy_ratio[0], simDR_reverser_deploy_ratio[1], simDR_reverser_deploy_ratio[2], simDR_reverser_deploy_ratio[3]) > 0.0
      and math.max(simDR_reverser_deploy_ratio[0], simDR_reverser_deploy_ratio[1], simDR_reverser_deploy_ratio[2], simDR_reverser_deploy_ratio[3]) < 0.1
      and simDR_thrust_max ~= engine_max_thrust_n then
        B747_setMaxThrust(engine_max_thrust_n)
    end

    if B747DR_log_level >= 2 then
      print("----- N1 Display ----- "..engine_in)
      print("N1 Corrected Thrust = ", N1_corrected_thrust_n)
      print("N1 Calibrated Thrust = ", N1_corrected_thrust_calibrated_N)
      print("N1 Corrected RPM = ", N1_corrected_rpm)
      print("N1% = ", N1_pct)
      print("N1_idle = ", N1_low_idle)
      print("N1 Idle Capture = ", N1_idle_capture)
      print("N1 Actual = ", N1_actual)
      print("ENGINE RUNNING = ", simDR_engine_running[engine_in])
      print("Last Thrust In = ", last_thrust_n[engine_in])
      print("Last N1 = ", last_N1[engine_in])
      print("N1 Engine Start = ", N1_engine_start[engine_in])
    end

    last_N1[engine_in] = N1_actual

    return N1_actual
  end

  --(2026-11-25, the user's 「XP内のN2をN3として扱ってN2はプラグイン活用して表示だけ」:
  --GAP_ANALYSIS.md §8) the RB211's three spools on X-Plane's two. X-Plane's
  --N2, the spool its starter, fuel, windmilling and failures turn, is the
  --RB211's HP, N3: its gearbox drives the IDG, the pumps and the starter
  --(LH24 p.66 gives the RB211's IDG underspeed in N3), and what reads X-Plane's
  --N2 (the start, the IDG, the pumps' power, the alerts) sees it so. 1:1
  --(estimate: no source has the RB211's HP against X-Plane's; X-Plane's N2 is
  --69.7 % at ground idle and 98-99 % on a takeoff, under TCDS_RB211 p.18-19's
  --99.2 %). The IP, N2, only shown: between the upstream's N1 (3,600 rpm as
  --100 %: the share was fitted on it; the shown N1 is on the TCDS's scale
  --since the same day) and N3, N1 + IP_SHARE (N3 - N1) (estimate: near what
  --the upstream's IP formula
  --showed - 49.9 against 49.0 at idle with N1 26.8 and N3 68.7, 89.3 against
  --87.0 in the cruise with 84.2 and 93.4, 101.5 against 101.0 on the takeoff
  --with 105.7 and 98.1, s427-s429 2026-11-25 - and under N3 in a start,
  --where the shown N1 runs ahead of X-Plane's: the formula alone showed the IP
  --at 45 % with N3 at 21, s429). What reads the shown N2 as the core's speed
  --takes N3 for the RB211 (B747.42.xt.EEC.lua's start-up hold, the bleed, the
  --cargo heat, the oil pressure's band, the vibration). Before, the shown N2
  --followed X-Plane's N2 10 s behind (its local started at 0 and always took
  --that branch: the IP formula never ran) and N3 was a cubic of the shown N1
  local IP_SHARE = 0.55
  local last_N2 = {0.0, 0.0, 0.0, 0.0}
  function N2_display_RR(engine_N1_in, engine_N3_in, engine_in)
    local target = engine_N1_in + IP_SHARE * (engine_N3_in - engine_N1_in)
    if last_N2[engine_in] == nil then last_N2[engine_in] = 0.0 end
    local N2_display = B747_animate_value(last_N2[engine_in], math.max(0, target), 0, 115, 10)
    last_N2[engine_in] = N2_display

    return N2_display
  end

  local last_N3 = {0.0, 0.0, 0.0, 0.0}
  function N3_display_RR(engine_N1_in, engine_in)
    if last_N3[engine_in] == nil then last_N3[engine_in] = 0.0 end
    local N3_display = B747_animate_value(last_N3[engine_in], simDR_N2[engine_in], 0, 115, 10)
    last_N3[engine_in] = N3_display

    return N3_display
  end

  --(2026-11-25) the EPR shown: the RB211's (B747_rr_model.epr) from the engine's
  --net thrust, the ambient pressure and the Mach. Before, the upstream's cubic
  --on thrust / density ratio (its top 1.713 near 255 kN standing, falling
  --beyond), 0.97 at least and the max line at most with the flaps out
  function EPR_display_RR(altitude_ft_in, thrust_N_in, engine_in)
      return RRM.epr(thrust_N_in / 1000, simDR_epr_ambient_pa / 101325, simDR_epr_mach, rr_variant())
  end

  function EGT_display_RR(engine_in)
    local EGT_display = 0.0
  
    if simDR_engn_EGT_c[engine_in] <= simDR_temperature then
      EGT_display = simDR_temperature
    else
      EGT_display = B747_rescale(0.0, 0.0, 960, 785, simDR_engn_EGT_c[engine_in])--simDR_engn_EGT_c[engine_in]
    end
  
    if B747DR_log_level >= 2 then
      print("EGT = "..engine_in.." ".. EGT_display)
    end
  
    return EGT_display
  end

  local orig_thrust_n = 0.0
  function RR(altitude_ft_in)
    local EPR_target_bug = {}
    local display_EPR_ref = {}
    local N1_display = {}
    local N2_display = {}
    local N3_display = {}
    local EGT_display = {}
    --Setup engine factors based on engine type
    if string.match(simConfigData["data"].PLANE.engines, "524G") then
      engine_max_thrust_n = 258000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(258000)  --252970  --(56870 lbf)
        simDR_reverser_max = 0.75
      end
      simDR_compressor_area = 3.54136  --(86.3-inch fan -- 38.12 sq. ft)
    elseif string.match(simConfigData["data"].PLANE.engines, "524H") and not string.match(simConfigData["data"].PLANE.engines, "524H8T") then  -- 524H8T below (ENG-30)
      engine_max_thrust_n = 270000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(270000)  --264450  --(59450 lbf)
        simDR_reverser_max = 0.75
      end
      simDR_compressor_area = 3.54136  --(86.3-inch fan -- 38.12 sq. ft)
    elseif string.match(simConfigData["data"].PLANE.engines, "524H8T")  then
      engine_max_thrust_n = 270000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust( 270000 ) --264450  --(59450 lbf)
        simDR_reverser_max = 0.75
      end
      simDR_compressor_area = 3.54136  --(86.3-inch fan -- 38.12 sq. ft)
    else  --Assume 524G if all else fails
      engine_max_thrust_n = 258000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(258000)  --252970  --(56870 lbf)
        simDR_reverser_max = 0.75
      end
      simDR_compressor_area = 3.54136  --(86.3-inch fan -- 48.19 sq. ft)
    end

    --(2026-11-25) as the P&W's (ENG-7): the upstream's takeoff, climb, cruise and
    --go-around branches are gone; kept the rated thrust stored for the boost's
    --reset
    if string.match(B747DR_ref_thr_limit_mode, "TO") or B747DR_ref_thr_limit_mode == "" then
      --Store original max engine output
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        orig_thrust_n = simDR_thrust_max
      end
    end

    --(2026-11-25) the reference thrust limit for the FMC's mode
    --(B747_eec_reference: the P&W's tables, the RB211's takeoff table; the
    --PW4056's scale) shown as the RB211's EPR: the A/T's target, the EICAS's
    --reference and the CDU's THRUST LIM (it reads the target bug); the cursor
    --at idle in VNAV's idle descent with anti-ice (B747_eec_cursor). Before,
    --the upstream's branches, the cruise table's EPR and 0.9 in a descent's
    --THR REF or IDLE (the P&W's dropped in step 9g4)
    local mach = simDR_epr_mach
    local _, idleCursor = B747_eec_cursor()
    for i = 0, 3 do
      local ref = B747_eec_reference(i)
      EPR_target_bug[i] = RRM.display(ref, mach)
      display_EPR_ref[i] = math.min(RRM.display(idleCursor and B747_eec_idle(i) or ref, mach), 1.90)
    end

    --Handle minor engine thrust differences where calculated (requested) thrust is less than the defined XP engine model can produce
    --Boost engine output as necessary: an engine at full throttle still short of the EEC's target
    --(2026-11-25: the EEC's, as the P&W's; before, the shown EPR 0.045 under the bug at full throttle)
    if B747_eec_thrust_short() then
                      B747_setMaxThrust(B747_eec_boosted_max(simDR_thrust_max, engine_max_thrust_n))  -- (2026-11-11 review) with a top
    elseif simDR_thrust_max > orig_thrust_n and simDR_onGround == 0 and B747DR_radio_altitude > 1500 then  --slowly reset max engine thrust to normal
      if simDR_thrust_max > orig_thrust_n + 10 then
        B747_setMaxThrust(simDR_thrust_max - 10)
      else
        B747_setMaxThrust(simDR_thrust_max - 1)
      end
    end

    --After manipulating simDR_thrust_max, ensure that it doesn't go below the max output
    --(2026-11-25) except in reverse on the ground, where N1_display_RR lowers it to
    --keep the reverse N1 to the TCDS's 91 % (it resets it as the reversers stow).
    --Before, this undid that every frame: at full reverse the N1 went to 103 % on
    --the TCDS's scale (s433's first run)
    local reversing = simDR_onGround == 1 and math.max(simDR_reverser_on[0], simDR_reverser_on[1], simDR_reverser_on[2], simDR_reverser_on[3]) == 1
    if simDR_thrust_max < engine_max_thrust_n and not reversing then
      B747_setMaxThrust(engine_max_thrust_n)
    end

    for i = 0, 3 do
      simDR_EPR_target_bug[i] = EPR_target_bug[i]
      B747DR_display_EPR_ref[i] = display_EPR_ref[i]
      --the EEC's maximum rated EPR, not the FMC's reference (as the P&W's)
      B747DR_display_EPR_max[i] = math.min(RRM.display(B747_eec_max(i), mach), 1.90)
      B747DR_display_EPR[i] = math.max(math.min(EPR_display_RR(altitude_ft_in, simDR_thrust_n[i], i), 1.90), 0.0)

      --(2026-11-25) the upstream's N1 (3,600 rpm as 100 %) shown on the TCDS's
      local n1_upstream = N1_display_RR(altitude_ft_in, simDR_thrust_n[i], i)
      N1_display[i] = string.format("%4.1f", math.min(n1_upstream * N1_TCDS, 112.5))
      B747DR_display_N1[i] = math.max(N1_display[i], 0.0)

      --(2026-11-25) N3 first (X-Plane's N2), then N2 (the IP) between the
      --upstream's N1 and N3
      N3_display[i] = string.format("%4.1f", math.min(N3_display_RR(B747DR_display_N1[i], i), 102.5))
      B747DR_display_N3[i] = math.max(N3_display[i], 0.0)

      N2_display[i] = string.format("%3.0f", math.min(N2_display_RR(math.max(n1_upstream, 0), B747DR_display_N3[i], i), 111.5))
      B747DR_display_N2[i] = math.max(N2_display[i], 0.0)
      EGT_display[i] = EGT_display_RR(i)
      B747DR_display_EGT[i] = egt_thermal_profile(EGT_display[i],i,B747DR_display_EGT[i])--math.max(EGT_display[i], 0.0)
      B747DR_throttle_resolver_angle[i] = throttle_resolver_angle_RR(i)

    end

    --Manage Thrust
    throttle_management()
  end
