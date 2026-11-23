--[[
****************************************************************************************
* Program Script Name	:	B747.42.xt.EEC.GE.lua
* Author Name			:	Marauder28
*                   (with SIGNIFICANT contributions from @kudosi for aeronautic formulas)
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2021-01-11	0.01a				      Start of Dev
*	  2021-05-27	0.1					      Initial Release
*   2021-06-16  0.2               Added Engine Idle Control
*	  2021-12-11	0.3				        New Throttle Resolver Angle formula, various bug fixes
*
*****************************************************************************************
]]

--This function calculates the target position of the throttle target on the Upper EICAS
--(the EEC's command for the lever, B747.42.xt.eec_thrust.lua)
function throttle_resolver_angle_GE(engine_in)
  return B747_eec_command(engine_in)
end

--The N1 the display shows at minimum idle. The idle selection (minimum or
--approach idle) and X-Plane's idle setting are B747.42.xt.eec_thrust.lua's
--(FCOM p.877-878).
function engine_idle_control_GE(altitude_ft_in)
  local N1_low_idle = 25.9
  if simDR_onGround == 0 then
    N1_low_idle = -1.45E-08 * altitude_ft_in^2 + 0.00121 * altitude_ft_in + 25.9
  end
  return N1_low_idle
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

function take_off_N1_GE(altitude_ft_in)
  local N1_corrected = 0.0
  local N1_actual = 0.0
  local temperature_K = 0.0
  local temperature_ratio = 0.0

  --locals to hold returned values from take_off_thrust_corrected() function
  local TOGA_corrected_thrust_lbf = 0.0
  local TOGA_actual_thrust_N = 0.0

  --For Takeoff, use actual Sim temperature instead of atmosphere() temperature_K
  --If a derate temperature is entered in the THRUST LIM page of the FMC, use that instead
  --if fmsModules["data"]["thrustsel"] ~= "  " then
  --  temperature_K = tonumber(fmsModules["data"]["thrustsel"]) + 273.15
  --else
    temperature_K = simDR_temperature + 273.15
  --end

  temperature_ratio = temperature_K / 288.15

  --get take_off_thrust_corrected() data
  TOGA_corrected_thrust_lbf, _, TOGA_actual_thrust_N = take_off_thrust_corrected(altitude_ft_in, temperature_K)

  --Mach should always be 0 for purposes of this calculation
  --(2026-11-10) local, as in the P&W's and the RB211's: it set the module's
  --mach to 0, and GE() calls this every frame (its takeoff_thrust_n1 starts
  --at 0 each call), so the N1 shown in the air came from the corrected
  --thrust's polynomial at Mach 0: about 10 % low in the cruise (FL390,
  --M.86: 82.7 for 93.5; notes/ATA-70-80.md §15)
  local mach = 0.0

  N1_corrected = (-1.4446E-12 * mach^2 + 1.2102E-12 * mach + 4.8911E-13) * TOGA_corrected_thrust_lbf^3 + (1.1197E-07 * mach^2 - 7.8717E-08 * mach - 6.498200000000002E-08)
                  * TOGA_corrected_thrust_lbf^2 + (-0.0027 * mach^2 + 0.0011 * mach + 0.0036) * TOGA_corrected_thrust_lbf + (36.93 * mach + 20.96)

  N1_actual = string.format("%4.1f", N1_corrected * math.sqrt(temperature_ratio))

  if B747DR_log_level >= 1 then
    print("\t\t\t\t\t<<<--- TAKEOFF N1 (GE) --->>>")
    print("Altitude IN = ", altitude_ft_in)
    print("Temperature K = ", temperature_K)
    print("Temperature Ratio = ", temperature_ratio)
    print("Mach = ", mach)
    print("TOGA Corrected Thrust = ", TOGA_corrected_thrust_lbf)
    print("N1 Corrected = ", N1_corrected)
    print("N1 Actual = ", N1_actual)
  end

  return N1_actual, TOGA_actual_thrust_N
end

-- (2026-11-24, ENG-7) in_flight_N1_GE, the upstream's climb and cruise N1,
-- is gone with GE()'s branches that called it (their results were
-- overwritten every frame)

local last_thrust_n = {0.0, 0.0, 0.0, 0.0}
local last_N1 = {0.0, 0.0, 0.0, 0.0}
-- (2026-11-24, PNL-5) the EEC's own command, last frame's, for the display's
-- idle pin below (it read laminar/B747/engines/TRA, which now carries the
-- EICAS's command: at least the idle N1 the display is pinned to)
local eec_cmd_ge = {[0] = 0, 0, 0, 0}
-- (2026-11-10) the N1 shown in the air for a thrust (N) at this frame's air
-- data (the corrected thrust's polynomial below, no state): N1_display_GE's,
-- and the EEC's thrust control takes its slope against the thrust from it
-- (B747.42.xt.eec_thrust.lua). B747_ge_n1_from_xp(engine): the display is
-- X-Plane's N1 instead (the takeoff), the EEC then uses its tables. Local
-- state: a table in a global turns into XTLua's namespace
local ge_n1_from_xp = {[0] = true, true, true, true}
function B747_ge_n1_from_xp(engine) return ge_n1_from_xp[engine] ~= false end
-- (2026-11-10, ENG-33) the formula fitted to the FCOM's CF6-80C2B1F %N1
-- (B747.42.ge_n1_model.lua, notes/ATA-70-80.md §17); before, the upstream's
-- cubic in the corrected thrust, 1.5 % high in the cruise and up to 14 % in
-- the high climbs (its N1 for a thrust: the climbs at the max climb N1 came
-- out about 9 % slow, s253)
dofile("B747.42.ge_n1_model.lua")
-- (2026-11-11 review) the air data as the P&W's EPR model has them
-- (B747.42.xt.EEC.PW.lua's simDR_epr_*): the static pressure's ratio and
-- the Mach. Before, atmosphere()'s: the ISA pressure at the captain's
-- altimeter (with QNH 990 at 3,000 ft, about 635 ft low; frozen with a
-- static failure) and the captain's TAS over the speed of sound (a pitot
-- failure took the N1 shown for a thrust with it, and the EEC's control)
function B747_ge_n1_of_thrust(thrust_N)
    local delta = math.max(0.1, simDR_epr_ambient_pa / 101325)
    return B747_ge_n1_model.n1(math.max(0, thrust_N), delta, simDR_epr_mach, temperature_ratio)
end

-- the idle N1 the display is pinned to with the lever's command under it
-- (engine_idle_control_GE, the upstream's). (2026-11-11 review) In the air,
-- where the display is the N1 model's, not under the model's N1 at no
-- thrust (by the Mach and the air: X-Plane's idle thrust is about 0 there):
-- the display goes on smoothly as the lever leaves idle. Before, the
-- upstream's idle under it at low altitude (5,000 ft and 250 kt: 31.6 %
-- against 35.6 %): a 4 to 8 % jump up, and the commands between the two
-- gave throttle 0 (about 10 % of the lever's travel). High up the
-- upstream's stays the higher (FL350: 50.5 against 43.9; no source for
-- the idle N1). Not the model's at the thrust then: the pin's 10 s lag
-- would come into the EEC's control on every reduction
function B747_ge_idle_pin(engine, altitude_ft)
    local idle = engine_idle_control_GE(altitude_ft)
    if not ge_n1_from_xp[engine] then idle = math.max(idle, B747_ge_n1_of_thrust(0)) end
    return idle
end

function N1_display_GE(altitude_ft_in, thrust_N_in, n1_factor_in, engine_in)
    local N1_corrected = 0.0
    local N1_actual = 0.0
    local corrected_thrust_N = 0.0
    local corrected_thrust_lbf = 0.0
    local actual_thrust_lbf = 0.0
    local N1_low_idle = 0.0
    if last_N1[engine_in] == nil then last_N1[engine_in] = 0.0 end
    if last_thrust_n[engine_in] == nil then
      last_thrust_n[engine_in] = 0.0
    end

    --Handle display of an engine shutdown
    --[[if simDR_engine_running[engine_in] == 0 then
      thrust_N_in = last_thrust_n[engine_in]
      n1_factor_in = 1.0
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

    if n1_factor_in == 0 or n1_factor_in == nil then
      --Failsafe incase n1_factor_in is 0 or nil
      n1_factor_in = 105.0
      takeoff_TOGA_n1 = n1_factor_in
    end

    corrected_thrust_N = thrust_N_in / pressure_ratio
    corrected_thrust_lbf = corrected_thrust_N / lbf_to_N

    actual_thrust_lbf = corrected_thrust_lbf * pressure_ratio

    N1_actual = B747_ge_n1_of_thrust(thrust_N_in)

    --Keep the N1 display steady during TO until we manage thrust or 2000 AGL unmanaged
    ge_n1_from_xp[engine_in] = false
    if (string.match(B747DR_ref_thr_limit_mode, "TO") or (simDR_onGround == 1 and B747DR_ref_thr_limit_mode == "GA"))
      or ((B747DR_ref_thr_limit_mode == "NONE" or B747DR_ref_thr_limit_mode == "") and B747DR_radio_altitude < 2000) then
        N1_actual = simDR_N1[engine_in] * n1_factor_in
        ge_n1_from_xp[engine_in] = true
    end

    --Engine Idle Logic (Minimum / Approach)
    N1_low_idle = B747_ge_idle_pin(engine_in, altitude_ft_in)
    if simDR_reverser_on[engine_in] ==0 and eec_cmd_ge[engine_in] < tonumber(N1_low_idle) and simDR_engine_running[engine_in] == 1 then
     -- N1_actual = N1_low_idle
      N1_actual = B747_animate_value(last_N1[engine_in],N1_low_idle,0,115,0.1) 
      --print(" pin N1_actual 2 "..N1_actual)
    elseif simDR_engine_running[engine_in] == 0 then
      N1_actual = B747_animate_value(last_N1[engine_in],simDR_N1[engine_in],0,115,0.1) 
      --print(" pin N1_actual 1 "..N1_actual.. " n1 "..simDR_N1[engine_in])
    end

    if B747DR_log_level >= 1 then
      print("\t\t\t\t\t<<<--- N1 DISPLAY (GE) --->>>".."\t\tEngine # "..engine_in + 1)
      print("Altitude IN = ", altitude_ft_in)
      print("Thrust IN = ", thrust_N_in)
      print("Pressure Ratio = ", pressure_ratio)
      print("Temperature K = ", temperature_K)
      print("Temperature Ratio = ", temperature_ratio)
      print("Mach = ", mach)
      print("N1_low_idle = ", N1_low_idle)
      print("Corrected Thrust LBF = ", corrected_thrust_lbf)
      print("Actual Thrust LBF = ", actual_thrust_lbf)
      print("TO Factor = ", n1_factor_in)
      print("N1 Actual = ", N1_actual)
      print("Last Thrust In = ", last_thrust_n[engine_in])
    end
    last_N1[engine_in] = N1_actual
    return N1_actual
end
local last_N2 = {0.0, 0.0, 0.0, 0.0}
function N2_display_GE(engine_N1_in, engine_in)
  local N2_display = 0.0

  --N2_display = (3.47E-04 * engine_N1_in^2 - 8.24E-02 * engine_N1_in + 7.71) * engine_N1_in * (3280 / 9827)  --have to multiply by the 100% rotation speed of N1 / 100% rotation speed of N2
  N2_display = (7.85E-04 * engine_N1_in^2 - 0.162 * engine_N1_in + 11.1) * engine_N1_in * (3280 / 9827)  --have to multiply by the 100% rotation speed of N1 / 100% rotation speed of N2

  --[[--When the XP N2 dataref drops below 35.0, use that instead of the N2 formula due to scaling inefficiencies with N1 as an input
  if simDR_N2[engine_in] < 35.0  then
    N2_display = simDR_N2[engine_in]
  elseif N2_display < 48.0 then
    N2_display = B747_rescale(35.0, 35.0, 65.0, 48.0, simDR_N2[engine_in])
  end]]--
  if last_N2[engine_in] == nil then last_N2[engine_in] = 0.0 end
  -- (2026-11-04) a flight that starts with the engines running: the display
  -- starts at the running N2 (before, it rose from 0 with its 10 s lag, and
  -- the bleed air, which reads it, stayed empty for the first 15 s: no packs,
  -- >CARGO DET AIR). A real start never gets here with the display at 0
  if last_N2[engine_in] < 1 and simDR_engine_running[engine_in] == 1 and simDR_N2[engine_in] > 50 then
    last_N2[engine_in] = simDR_N2[engine_in]
  end
    if (simDR_engine_running[engine_in] == 0 or simDR_N2[engine_in]<35) then
      N2_display = B747_animate_value(last_N2[engine_in],simDR_N2[engine_in],0,115,0.1) 
    elseif N2_display < simDR_N2[engine_in] then --and N2_display < 30.0 then
      N2_display = B747_animate_value(last_N2[engine_in],simDR_N2[engine_in],0,115,0.1)
    else
      N2_display = B747_animate_value(last_N2[engine_in],N2_display,0,115,10)
    end
  if B747DR_log_level >= 1 then
    print("N1 in, N2, test = ", engine_N1_in, N2_display)
  end
  last_N2[engine_in] = N2_display
  return N2_display
end

--(2026-11-10, ENG-33) the EGT shown is the EGT model's (B747.42.egt_model.lua,
--B747_egt in B747.42.xt.egt.lua) from the engine's state and the N1 shown.
--Before, EGT_display_GE: X-Plane's EGT 1:1, then egt_thermal_profile

local takeoff_TOGA_n1 = 0.0
local orig_thrust_n = 0.0
local N1_target_bug={}
local display_N1_ref={}
function GE(altitude_ft_in)
  local N1_display = {}
  local N2_display = {}


  --Setup engine factors based on engine type
	if string.match(simConfigData["data"].PLANE.engines, "B1F") and not string.match(simConfigData["data"].PLANE.engines, "B1F1") then  -- B1F1 below (ENG-30)
    engine_max_thrust_n = 258000
    simDR_throttle_max = 1.0
    if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
      B747_setMaxThrust(258000)  --254260  --(57160 lbf)
    end
    simDR_compressor_area = 4.38251 --(93-inch fan -- 47.17 sq. ft)
	elseif string.match(simConfigData["data"].PLANE.engines, "B5F") then
    engine_max_thrust_n = 276000
    simDR_throttle_max = 1.0
    if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
      B747_setMaxThrust(276000)  --267028  --(60030 lbf)
    end
    simDR_compressor_area = 4.38251 --(93-inch fan -- 47.17 sq. ft)
	elseif string.match(simConfigData["data"].PLANE.engines, "B1F1")  then
    engine_max_thrust_n = 276000
    simDR_throttle_max = 1.0
    if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
      B747_setMaxThrust(276000)  --267028  --(60030 lbf)
    end
    simDR_compressor_area = 4.38251 --(93-inch fan -- 47.17 sq. ft)
  else  --Assume CF6-802C-B1F if all else fails
    engine_max_thrust_n = 258000
    simDR_throttle_max = 1.0
    if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
      B747_setMaxThrust(258000)  --254260  --(57160 lbf)
    end
    simDR_compressor_area = 4.38251 --(93-inch fan -- 47.17 sq. ft)
	end

  --(2026-11-24, ENG-7 of the 2026-11-23 review) the upstream's takeoff,
  --climb, cruise and go-around branches are gone (with in_flight_N1_GE):
  --since the FMC's step 9g3 the reference below and the EEC's maximum
  --overwrote everything they set, and in the climb and the cruise they
  --worked out a design climb rate's thrust every frame. Kept as they were:
  --takeoff_TOGA_n1, the factor of the N1 shown on the takeoff
  --(N1_display_GE; the review's ENG-4, not changed here), from the takeoff
  --N1 worked out every frame (the takeoff branch's test always held: its
  --takeoff_thrust_n1 started at 0) and taken without a takeoff derate, in
  --GA (and NONE) whatever the derate; the rated thrust stored for the
  --boost's reset. laminar/B747/engines/thrustref_throttle, which only they
  --wrote and nothing reads, stays as it is
  local takeoff_thrust_n1 = take_off_N1_GE(altitude_ft_in)
  if B747DR_toderate == 0 then
    takeoff_TOGA_n1 = takeoff_thrust_n1
  end
  if string.match(B747DR_ref_thr_limit_mode, "TO") or B747DR_ref_thr_limit_mode == "" then
    --Store original max engine output
    if orig_thrust_n == 0.0 or B747DR_newsimconfig_data == 1 then
      orig_thrust_n = simDR_thrust_max
    end
  elseif B747DR_ref_thr_limit_mode == "GA" or B747DR_ref_thr_limit_mode == "NONE" then
    takeoff_TOGA_n1 = takeoff_thrust_n1
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

  --(the FMC's step 9g3) the reference thrust limit for the FMC's mode
  --(B747_eec_reference: the PI tables, the derates, the assumed temperature)
  --for the A/T's target and the EICAS's reference (the upstream's branches
  --for them are gone: above)
  --(step 9g4) the cursor at idle in VNAV's idle descent with anti-ice
  --(B747_eec_cursor, ATA34_2 p.652)
  local _, idleCursor = B747_eec_cursor()
  for i = 0, 3 do
    local ref = B747_eec_reference(i)
    N1_target_bug[i] = ref
    display_N1_ref[i] = math.min(idleCursor and B747_eec_idle(i) or ref, 117.5)
  end

  for i = 0, 3 do
    --(step 9g4) the reference always (before, 25 in a descent's THR REF:
    --ATHR-17)
    simDR_N1_target_bug[i] = N1_target_bug[i]
    B747DR_display_N1_ref[i] = display_N1_ref[i]
    B747DR_display_N1_max[i] = B747_eec_max(i)  --the EEC's maximum rated N1, not the FMC's reference
  end
	for i = 0, 3 do
    --takeoff_TOGA_n1 (max TO) is used as a factor to compute N1 for TO based on the simDR_N1 to prevent N1 display loss during TO -- in flight it is calculated based on Newtons
    N1_display[i] = string.format("%4.1f", math.min(N1_display_GE(altitude_ft_in, simDR_thrust_n[i], takeoff_TOGA_n1 / 100, i), 118.0))  --use i as a reference for engine number
    B747DR_display_N1[i] = math.max(N1_display[i], 0.0)

    local n2 = N2_display_GE(N1_display[i], i)  --use N1 as input for calcs
    B747_eec_set_n2(i, n2)  --the EEC's overspeed protection, before the display's rounding
    N2_display[i] = string.format("%4.1f", math.min(n2, 112.5))
    B747DR_display_N2[i] = math.max(N2_display[i], 0.0)

    --(2026-11-10) the EGT model, from the N1 just shown (B747.42.xt.egt.lua)
    B747DR_display_GE_EGT[i] = B747_egt(i, "GE")

    --(2026-11-24, PNL-5) the EICAS's command N1: the EEC's command, a running
    --engine's at least the idle N1 the display is pinned to (FCOM p.873: the
    --command N1 equals the actual N1 once stable). The EEC's own idle end
    --commands 25 %, under any idle, so that its control comes back to
    --X-Plane's idle (B747.42.xt.eec_thrust.lua): the mark stood 0.9 % under
    --the idle bar's end on the ground, 10-25 % under it in the air. The
    --display's pin still tests the EEC's own command
    local cmd = throttle_resolver_angle_GE(i)
    eec_cmd_ge[i] = cmd
    if simDR_engine_running[i] == 1 and simDR_reverser_on[i] == 0 then
      cmd = math.max(cmd, B747_ge_idle_pin(i, altitude_ft_in))
    end
    B747DR_throttle_resolver_angle[i] = cmd
	end

  if B747DR_log_level >= 1 then
    print("Takeoff TOGA = ", takeoff_TOGA_n1)
  end
  --Manage Thrust
  throttle_management()
  --thrust_ref_control_N1()
end