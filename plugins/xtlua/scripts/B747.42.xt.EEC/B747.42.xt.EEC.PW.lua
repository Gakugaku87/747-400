--[[
****************************************************************************************
* Program Script Name	:	B747.42.xt.EEC.PW.lua
* Author Name			:	Marauder28
*                   (with SIGNIFICANT contributions from @kudosi for aeronautic formulas)
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2021-01-11	0.01a				      Start of Dev
*	  2021-08-13	0.1				        Initial Release
*	  2021-12-11	0.2				        New Throttle Resolver Angle formula, various bug fixes
*
*
*****************************************************************************************
]]

dofile("B747.42.epr_model.lua")
simDR_epr_ambient_pa = find_dataref("sim/weather/aircraft/barometer_current_pas")
simDR_epr_mach = find_dataref("sim/flightmodel/misc/machno")

--This function calculates the target position of the throttle target on the Upper EICAS
--(the EEC's command for the lever, B747.42.xt.eec_thrust.lua)
function throttle_resolver_angle_PW(engine_in)
  return B747_eec_command(engine_in)
end

  --The N1 the display shows at minimum idle. The idle selection (minimum or
  --approach idle) and X-Plane's idle setting are B747.42.xt.eec_thrust.lua's
  --(FCOM p.877-878).
function engine_idle_control_PW(altitude_ft_in)
    return -1.45E-08 * altitude_ft_in^2 + 0.00121 * altitude_ft_in + 25.9
  end
  
  
  
  --[[function take_off_thrust_assumed(altitude_ft_in, temperature_K_in)
    local TOGA_corrected_thrust_lbf = 0.0
    local TOGA_actual_thrust_lbf = 0.0
    local TOGA_actual_thrust_N = 0.0
    local approximate_max_TO_thrust_lbf = 0
    local temperature_K = 0.0
  
    temperature_K = fmsModules["data"]["thrustsel"] + 274.15
  
    if temperature_K_in > corner_temperature_K then
        TOGA_corrected_thrust_lbf = (-1.79545 * (temperature_K / corner_temperature_K) + 2.7874) * (-0.0000546 * altitude_ft_in^2 + 1.37 * altitude_ft_in + approximate_max_TO_thrust_lbf)
    else
        TOGA_corrected_thrust_lbf = (-0.0000546 * altitude_ft_in^2 + 1.37 * altitude_ft_in + approximate_max_TO_thrust_lbf)
    end
  
    TOGA_actual_thrust_lbf = TOGA_corrected_thrust_lbf * pressure_ratio
    TOGA_actual_thrust_N = TOGA_actual_thrust_lbf * lbf_to_N
  
    if B747DR_log_level >= 1 then
      print("\t\t\t\t\t<<<--- Assumed Temp Takeoff Calcs --->>>")
      print("Altitude IN = ", altitude_ft_in)
      print("Temperature K IN = ", temperature_K_in)
      print("Approximate Takeoff Thrust Required = ", approximate_max_TO_thrust_lbf)
      print("TOGA Corrected LBF = ", TOGA_corrected_thrust_lbf)
      print("TOGA Actual LBF = ", TOGA_actual_thrust_lbf)
      print("TOGA Actual N = ", TOGA_actual_thrust_N)
    end
  
    return TOGA_corrected_thrust_lbf  --, TOGA_actual_thrust_lbf, TOGA_actual_thrust_N
  end]]
  
  --(2026-11-24, ENG-7) take_off_EPR_PW and in_flight_EPR_PW, the upstream's
  --takeoff and climb EPR, are gone with PW()'s branches that called them
  --(their results were overwritten every frame)

  local last_thrust_n = {0.0, 0.0, 0.0, 0.0}
  local last_N1 = {0.0, 0.0, 0.0, 0.0}
  function N1_display_PW(altitude_ft_in, thrust_N_in, engine_in)
    local N1_corrected_rpm = 0.0
    local N1_pct = 0.0
    local N1_actual = 0.0
    local N1_corrected_thrust_calibrated_N = 0.0
    local N1_corrected_thrust_n = 0.0
    local N1_low_idle = 0.0
    local N1_idle_capture = 0.0
    local N1_zero_thrust = 0.0
    if last_N1[engine_in] == nil then last_N1[engine_in] = 0.0 end
    --Handle display of an engine shutdown
    --[[if simDR_engine_running[engine_in] == 0 then
      thrust_N_in = last_thrust_n[engine_in]
      if last_thrust_n[engine_in] > 0 then
        last_thrust_n[engine_in] = last_thrust_n[engine_in] - 100
      elseif last_thrust_n[engine_in] < 0 then
        last_thrust_n[engine_in] = 0.0
      end
    else
      last_thrust_n[engine_in] = thrust_N_in
    end]]
    last_thrust_n[engine_in] = thrust_N_in
    if thrust_N_in < 0.0 then
      thrust_N_in = 0.0
    end

    N1_corrected_thrust_n = thrust_N_in / (1000 * sigma_density_ratio)
    --N1_corrected_thrust_n = thrust_N_in / (1000 * pressure_ratio)

    --N1_corrected_thrust_calibrated_N = (-0.4795 * mach^2 + 0.5903 * mach + 0.925) * N1_corrected_thrust_n  --Sigma version 2
    N1_corrected_thrust_calibrated_N = (-0.0811 * mach^2 + 0.2349 * mach + 0.919) * N1_corrected_thrust_n  --Sigma version 2

    --N1_corrected_rpm = (0.0136 * mach^2 - 0.00905 * mach - 0.0107) * N1_corrected_thrust_calibrated_N^2 + (-5.84 * mach^2 + 0.512 * mach + 13.5) * N1_corrected_thrust_calibrated_N
    --  + (-508 * mach^2 + 1792.2 * mach + 1065.4)

    N1_corrected_rpm = (0.0136 * mach^2 - 0.00905 * mach - 0.0107) * N1_corrected_thrust_calibrated_N^2 + (-5.84 * mach^2 + 0.512 * mach + 13.5) * N1_corrected_thrust_calibrated_N
      + (-508 * mach^2 + 1792.2 * mach + B747_rescale(0.0, 0.0, 750.0, 1065.4, simDR_rpm[engine_in]))

    N1_pct = N1_corrected_rpm / 3600 * 100 * math.sqrt(temperature_K / 288.15)

    --(ENG-33, 2026-11-03) from 60 to 70 % over to the N1 from the EPR
    --(B747_epr_model.n1: the FCOM's Alt Mode %N1, the TAT once). The
    --regression above (thrust / density ratio, then the temperature again)
    --rose without end at high corrected thrust: 106 % and N2 110 % on a
    --30 C sea level takeoff, 122 % at max EPR at 10,600 ft; the EEC's N2
    --limit then held the thrust under max EPR with RPM LIM (the full run's
    --s10). Below 60 % it stays (the idle logic below works on it)
    local N1_epr = B747_epr_model.n1(B747_epr_model.epr(thrust_N_in / 1000, simDR_epr_ambient_pa / 101325, simDR_epr_mach), simDR_epr_mach, simDR_TAT)
    local w = math.max(0, math.min(1, (N1_pct - 60) / 10))
    N1_pct = N1_pct + w * (N1_epr - N1_pct)

    --Engine Idle Logic (Minimum / Approach)
    N1_low_idle = engine_idle_control_PW(altitude_ft_in)
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

    if N1_actual < N1_low_idle and N1_corrected_rpm >= 1065.4  and simDR_engine_running[engine_in] == 1 then 
      -- N1_actual = N1_low_idle
      N1_actual = B747_animate_value(last_N1[engine_in],N1_low_idle,0,115,0.1) 
      --print(" pin N1_actual 2 "..N1_actual)
    elseif simDR_engine_running[engine_in] == 0 then
      N1_actual = B747_animate_value(last_N1[engine_in],simDR_N1[engine_in],0,115,0.1) 
      --print(" pin N1_actual 1 "..N1_actual.. " n1 "..simDR_N1[engine_in])
    end

    --During Startup / Shutdown track the XP N1 value if the formulas aren't reasonable
    if N1_actual < simDR_N1[engine_in] then
      N1_actual = B747_animate_value(last_N1[engine_in],simDR_N1[engine_in],0,115,0.1) 
    end

    if B747DR_log_level >= 1 then
      print("----- N1 Display -----")
      print("N1 Corrected Thrust = ", N1_corrected_thrust_n)
      print("N1 Calibrated Thrust = ", N1_corrected_thrust_calibrated_N)
      print("N1 Corrected RPM = ", N1_corrected_rpm)
      print("N1% = ", N1_pct)
      print("N1_idle = ", N1_low_idle)
      print("N1 Idle Capture = ", N1_idle_capture)
      print("N1 Actual = ", N1_actual)
      print("ENGINE RUNNING = ", simDR_engine_running[engine_in])
      print("Last Thrust In = ", last_thrust_n[engine_in])
    end
    last_N1[engine_in] = N1_actual
    return N1_actual
  end
  local last_N2 = {0.0, 0.0, 0.0, 0.0}
  --(2026-11-20, GAP_ANALYSIS.md N19-ENG-02) N2 from the N1 shown: through
  --the PW4056's IDLE N2 63.0 % at the shown N1 of a ground idle (27.2 %:
  --PW_PPM p.7), 100 % at a sea level takeoff's 101.6 % N1 (X-Plane's own N2
  --there, s109: estimate) and its N2 red line 105.5 % at the N1 red line
  --111.4 % (PW_PPM p.7, TCDS E24NE p.3: estimate that the two meet there).
  --Before, the cubic (0.000798 N1^2 - 0.154 N1 + 10.2) x N1 x 3600 / 9900:
  --103.1 % at the takeoff, 119 % at the N1 red line, over the N2 red line
  --(red N2 and the EEC's 104 % limit on a cold day's takeoff)
  local N2_A, N2_B, N2_C = 51.57, 0.3996, 0.000759
  function N2_display_PW(engine_N1_in, engine_in)
    local N2_display = 0.0
    N2_display = N2_A + N2_B * engine_N1_in + N2_C * engine_N1_in^2
  
    if last_N2[engine_in] == nil then last_N2[engine_in] = 0.0 end
    if (simDR_engine_running[engine_in] == 0 or simDR_N2[engine_in]<35) then
      N2_display = B747_animate_value(last_N2[engine_in],simDR_N2[engine_in],0,115,0.1) 
    elseif N2_display < simDR_N2[engine_in] then --and N2_display < 30.0 then
      N2_display = B747_animate_value(last_N2[engine_in],simDR_N2[engine_in],0,115,0.1)
    else
      N2_display = B747_animate_value(last_N2[engine_in],N2_display,0,115,10)
    end

    if B747DR_log_level >= 1 then
      print("----- N2 Display -----")
      print("N1 in, N2 = ", engine_N1_in, N2_display)
    end
    last_N2[engine_in] = N2_display
    return N2_display
  end
  
  --The EPR shown: the EPR model (B747.42.epr_model.lua, ENG-33, 2026-10-30) from
  --the engine's net thrust, the ambient pressure and the Mach (it replaced the
  --previous regression on thrust / density ratio). A stopped engine's display
  --follows its last thrust (N1_display_PW keeps it).
  function EPR_display_PW(altitude_ft_in, thrust_N_in, engine_in)
      if last_thrust_n[engine_in] == nil then
        last_thrust_n[engine_in] = 0.0
      end
      if simDR_engine_running[engine_in] == 0 then
        thrust_N_in = last_thrust_n[engine_in]
      end
      return B747_epr_model.epr(thrust_N_in / 1000, simDR_epr_ambient_pa / 101325, simDR_epr_mach)
  end

  --(2026-11-10, ENG-33) the EGT shown is the EGT model's (B747.42.egt_model.lua,
  --B747_egt in B747.42.xt.egt.lua) from the engine's state and the EPR shown.
  --Before, EGT_display_PW: X-Plane's EGT x 654/960 (about 250 C in the
  --cruise: X-Plane's tops out near the acf's 460 C), then egt_thermal_profile

  local orig_thrust_n = 0.0
  function PW(altitude_ft_in)
    local EPR_display = {}
    local N1_display = {}
    local N2_display = {}
    local EPR_target_bug = {}
    local display_EPR_ref = {}
    --Setup engine factors based on engine type
    if string.match(simConfigData["data"].PLANE.engines, "4056") then
      engine_max_thrust_n = 254000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(254000)  --252437  --(56750 lbf)
      end
      simDR_compressor_area = 4.47727  --(94-inch fan -- 48.19 sq. ft)
    elseif string.match(simConfigData["data"].PLANE.engines, "4060") then
      engine_max_thrust_n = 267000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(267000)  --266893  --(60000 lbf)
      end
      simDR_compressor_area = 4.47727  --(94-inch fan -- 48.19 sq. ft)
    elseif string.match(simConfigData["data"].PLANE.engines, "4062")  then
      engine_max_thrust_n = 276000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(276000)  --275790  --(62000 lbf)
      end
      simDR_compressor_area = 4.47727  --(94-inch fan -- 48.19 sq. ft)
    else  --Assume PW4056 if all else fails
      engine_max_thrust_n = 254000
      simDR_throttle_max = 1.0
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        B747_setMaxThrust(254000)  --252437  --(56750 lbf)
      end
      simDR_compressor_area = 4.47727  --(94-inch fan -- 48.19 sq. ft)
    end

    --(2026-11-24, ENG-7 of the 2026-11-23 review) the upstream's takeoff,
    --climb, cruise and go-around branches are gone (with take_off_EPR_PW
    --and in_flight_EPR_PW): since the FMC's step 9g3 the reference below
    --and the EEC's maximum overwrote everything they set (the takeoff's old
    --cubic, a design climb rate's thrust, the M.85 cruise table, a fitted
    --go-around formula), and in the cruise they built and sorted two tables
    --every frame. Kept: the rated thrust stored for the boost's reset.
    --laminar/B747/engines/thrustref_throttle, which only they wrote and
    --nothing reads, stays as it is
    if string.match(B747DR_ref_thr_limit_mode, "TO") or B747DR_ref_thr_limit_mode == "" then
      --Store original max engine output
      if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
        orig_thrust_n = simDR_thrust_max
      end
    end

    --(the FMC's step 9g3) the reference thrust limit for the FMC's mode
    --(B747_eec_reference: the PI tables, the derates, the assumed temperature)
    --for the A/T's target and the EICAS's reference (the upstream's branches
    --for them are gone: above)
    --(step 9g4) the cursor at idle in VNAV's idle descent with anti-ice
    --(B747_eec_cursor, ATA34_2 p.652)
    local _, idleCursor = B747_eec_cursor()
    for i = 0, 3 do
      local ref = B747_eec_reference(i)
      EPR_target_bug[i] = ref
      display_EPR_ref[i] = math.min(idleCursor and B747_eec_idle(i) or ref, 1.71)
    end

    --Handle minor engine thrust differences where calculated (requested) thrust is less than the defined XP engine model can produce
    --Boost engine output as necessary: an engine at full throttle still short of the EEC's target
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
    if simDR_thrust_max < engine_max_thrust_n then
      B747_setMaxThrust(engine_max_thrust_n)
    end
  
    for i = 0, 3 do
      --(step 9g4) the reference always: the EICAS's digits and the A/T's
      --THR REF (before, 0.90 in a descent's THR REF or IDLE: ATHR-17)
      simDR_EPR_target_bug[i] = EPR_target_bug[i]
      B747DR_display_EPR_ref[i] = display_EPR_ref[i]
      B747DR_display_EPR_max[i] = math.min(B747_eec_max(i), 1.71)  --the EEC's maximum rated EPR, not the FMC's reference
     -- EPR_display[i] = string.format("%3.2f", math.min(EPR_display_PW(altitude_ft_in, simDR_thrust_n[i], i), 1.71)) 
      EPR_display[i] = math.min(EPR_display_PW(altitude_ft_in, simDR_thrust_n[i], i), 1.71) --use i as a reference for engine number
      B747DR_display_EPR[i] = math.max(EPR_display[i], 0.0)

      N1_display[i] = string.format("%4.1f", math.min(N1_display_PW(altitude_ft_in, simDR_thrust_n[i], i), 111.5))
      B747DR_display_N1[i] = math.max(N1_display[i], 0.0)

      local n2 = N2_display_PW(B747DR_display_N1[i], i)
      B747_eec_set_n2(i, n2)  --the EEC's overspeed protection, before the display's rounding
      N2_display[i] = string.format("%3.0f", math.min(n2, 111.5))
      B747DR_display_N2[i] = math.max(N2_display[i], 0.0)

      --(2026-11-10) the EGT model, from the EPR just shown (B747.42.xt.egt.lua)
      B747DR_display_EGT[i] = B747_egt(i, "PW")

      B747DR_throttle_resolver_angle[i] = throttle_resolver_angle_PW(i)

    end
    --Manage Thrust
    throttle_management()
  end