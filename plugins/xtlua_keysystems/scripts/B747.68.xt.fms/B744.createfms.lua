--[[
*****************************************************************************************
*        COPYRIGHT � 2020 Mark Parker/mSparks CC-BY-NC4
*****************************************************************************************
]]

fms={
  id,
  page1=false,
  swipeOut=1,
  currentPage="INDEX",
  targetPage="INDEX",
  targetpgNo=1,
  targetCustomFMC=false,
  inCustomFMC=false,scratchpad="",notify="",pgNo=1
} 


simCMD_FMS_key={}
function fmsClearNotify(notification)
  
  for i =1,55,1 do
    print("do FMS notify".." ".. i .." " ..B747DR_fmc_notifications[i])
    if B747_FMCAlertMsg[i].name==notification then
      fmsModules["fmsL"]["notify"]=""
      fmsModules["fmsC"]["notify"]=""
      fmsModules["fmsR"]["notify"]=""
      B747DR_fmc_notifications[i]=0
      print("do clear FMS notify"..B747_FMCAlertMsg[i].name)
      break
    end
  end
end
local lastKeyDown=""
-- the CDUs' scratchpads and messages and the FMC's messages (6-1/6-2 step
-- 2; B747.68.cdu_model.lua; notes/ATA-34-61-CDU.md §3.1, §3.2, §4.1):
-- each CDU its own scratchpad and entry messages, the FMC's messages on
-- every CDU (FMSPG p.39)
local C = B747_cdu_model
local cduState = {fmsL = C.new(), fmsC = C.new(), fmsR = C.new()}
local fmcMsgs = C.fmc_new()
-- the CDUs' power: the left CDU on the main standby bus, the right on the
-- F/O transfer bus (FCOM p.800, p.804), the centre on the F/O transfer bus
-- (estimate): electrical/display_has_power[8], [7], [6], as the panel's
-- screens; no keys and no drawing without it, the MENU page when it comes
-- (FMSPG p.53)
B747DR_cdu_display_power = find_dataref("laminar/B747/electrical/display_has_power")
local CDU_POWER = {fmsL = 8, fmsC = 6, fmsR = 7}
local cduWasPowered = {}
function cduPowered(fmsModule)
  return (B747DR_cdu_display_power[CDU_POWER[fmsModule]] or 0) > 0
end
-- the FMC's messages from laminar/B747/fms/notification's flags
-- (B744.notifications.lua + 1): the systems set a flag while its condition
-- holds; an event's flag, set once, is posted and cleared so that it can
-- come again. FCOM's advisories among them (p.1435); the rest are alerts
-- (p.1431-1434)
local FMC_EVENT = {["PERF/VNAV UNAVAILABLE"] = true, ["DESTINATION NOT SET"] = true, ["TAKEOFF SPEEDS DELETED"] = true}
local FMC_ADVISORY = {["TAKEOFF SPEEDS DELETED"] = true}
function B747_cdu_sync_fmc_messages(flags)
  for i = 1, 55 do
    local m = B747_FMCAlertMsg[i]
    local name = m.name
    local text = name
    if m.data ~= "" then text = string.gsub(name, "___", m.data) end
    local on = (flags[i] or 0) > 0
    if FMC_EVENT[name] then
      if on then
        C.fmc_post(fmcMsgs, text, not FMC_ADVISORY[name])
        flags[i] = 0
      end
    else
      C.fmc_set(fmcMsgs, text, on, not FMC_ADVISORY[name])
    end
  end
end
function B747_cdu_fmc_alert()
  return C.fmc_alert(fmcMsgs)
end
-- a condition's FMC message by its text, for the messages not among the
-- flags (6-1/6-2 step 6c: LNAV's NOT ON INTERCEPT HEADING, an advisory:
-- FCOM p.1435)
function B747_cdu_fmc_condition(text, on, alert)
  C.fmc_set(fmcMsgs, text, on, alert)
end
-- the scratchpad's keys, by B747.68.cdu_model.lua's names
local SP_KEYS = {space = "SP", slash = "/", ["."] = ".", ["-"] = "+/-", del = "DEL", clear = "CLR"}
-- a CDU's page now: the custom pages at once (no blank half second:
-- CDU-23); X-Plane's after its CDU has turned (switchCustomMode)
local function switchNow(fmsO)
  fmsO.inCustomFMC = fmsO.targetCustomFMC
  fmsO.currentPage = fmsO.targetPage
  fmsO.pgNo = fmsO.targetpgNo
end
-- MENU's <FMC: the FMC's last page on this CDU (FCOM p.1323), kept when
-- MENU leaves the FMC's pages (an FMC function key or <FMC since the last
-- MENU; ACARS, ACMS, CMC, the EFIS and EICAS controls and the sim's
-- pages are not the FMC's); the pages that show X-Plane's CDU come back
-- with their key
local lastFmcPage = {}
local inFmc = {}
local FMC_KEYS = {index = true, fpln = true, clb = true, crz = true, des = true, dir_intc = true,
  legs = true, dep_arr = true, hold = true, navrad = true, prog = true}
local RETURN_KEY = {RTE2 = "legs"}
-- the page's keys: the function keys, the line select keys, NEXT, PREV,
-- EXEC, and the keys passed to X-Plane's CDU on its pages
local function pageKey(fmsModule,key)
  local fmsO=fmsModules[fmsModule]
  if FMC_KEYS[key] then inFmc[fmsModule]=true end
  if key=="index" then
      fmsO.targetCustomFMC=true
      if irsSystem.anyATT() or (simDR_onGround==1 and B747DR_nav_irs_set_pos==1) then
        fmsO.targetPage="POSINIT"
      elseif simDR_onGround==1 then
        fmsO.targetPage="PERFINIT"
      else
        fmsO.targetPage="APPROACH"
      end
      fmsO.targetpgNo=1
      return
  elseif key=="fpln" then --RTE
      fmsO.targetCustomFMC=true
      fmsO.targetPage="RTE1"
      fmsO.targetpgNo=1
      return
  elseif key=="clb" then --DEP ARR
      B747_cdu_deparr_page(fmsO)
      return
  elseif key=="crz" then
      fmsO.targetCustomFMC=true
      fmsO.targetPage="ATCINDEX"
      fmsO.targetpgNo=1
      return
  elseif key=="des" then
      fmsO.targetCustomFMC=true
      fmsO.targetPage="VNAV"
      fmsO.targetpgNo=1
      return
  elseif key=="dir_intc" then
      -- FIX: the FMC's FIX INFO (6-1/6-2 step 7e3b; before: X-Plane's FIX
      -- page)
      B747_cdu_fix_page(fmsO)
      return
  elseif key=="legs" then
      -- the FMC's LEGS pages (6-1/6-2 step 5c)
      fmsO.targetCustomFMC=true
      fmsO.targetPage="LEGS"
      fmsO.targetpgNo=1
      return
  elseif key=="dep_arr" then
      -- HOLD: the FMC's holds (6-1/6-2 step 7b; before: X-Plane's HOLD
      -- page)
      B747_cdu_hold_page(fmsO)
      return
  elseif key=="hold" then --FMC COMM
      fmsO.targetCustomFMC=true
      fmsO.targetPage="FMCCOMM"
      fmsO.targetpgNo=1
      return
  elseif key=="fix" then --menu
      if inFmc[fmsModule] then lastFmcPage[fmsModule]={fmsO.currentPage, fmsO.pgNo} end
      inFmc[fmsModule]=false
      fmsO.targetCustomFMC=true
      fmsO.targetPage="INDEX"
      fmsO.targetpgNo=1
      return
  elseif key=="navrad" then
      fmsO.targetCustomFMC=true
      fmsO.targetPage="NAVRAD"
      fmsO.targetpgNo=1
      return
  elseif key=="prog" then
      fmsO.targetCustomFMC=true
      fmsO.targetPage="PROGRESS"
      fmsO.targetpgNo=1
      return
  end

  if not fmsO.targetCustomFMC then
    if simCMD_FMS_key[fmsModule][key]~=nil then
      simCMD_FMS_key[fmsModule][key]:once()
      print(fmsModule.. " did " .. key)
    end
    return
  end
  local page=fmsO.targetPage
  if hasChild(fmsFunctionsDefs[page],key) then
    print(fmsModule.. " found " .. fmsFunctionsDefs[page][key][1] .. " for " .. key)
    fmsFunctions[ fmsFunctionsDefs[page][key][1] ](fmsO,fmsFunctionsDefs[page][key][2])
    print(fmsModule.. " did " .. key .. " for " .. page)
  elseif key=="next" then
    -- NEXT on the last page: the first (FMSPG p.42)
    local n = fmsPages[page] and fmsPages[page]:getNumPages(fmsModule) or 1
    if fmsO.pgNo < n then fmsO.targetpgNo=fmsO.pgNo+1 else fmsO.targetpgNo=1 end
  elseif key=="prev" and fmsO.pgNo > 1 then
    fmsO.targetpgNo=fmsO.pgNo-1
  elseif key=="exec" then
    simCMD_FMS_key[fmsModule][key]:once()
  else
    fmsO.notify="KEY/FUNCTION INOP"
  end
end
-- MENU's <FMC: the FMC's last page, IDENT the first time (FCOM p.1323)
function B747_cdu_menu_fmc(fmsO)
  local id=fmsO.id
  local last=lastFmcPage[id]
  inFmc[id]=true
  if last==nil then
    fmsO.targetCustomFMC=true
    fmsO.targetPage="IDENT"
    fmsO.targetpgNo=1
  elseif RETURN_KEY[last[1]] then
    pageKey(id, RETURN_KEY[last[1]])
  else
    fmsO.targetCustomFMC=true
    fmsO.targetPage=last[1]
    fmsO.targetpgNo=last[2] or 1
  end
end
function keyDown(fmsModule,key,phase,duration)
  phase=phase or 0
  local fmsO=fmsModules[fmsModule]
  local st=cduState[fmsModule]
  if not cduPowered(fmsModule) then return end
  if phase==0 then
    print(fmsModule.. " do " .. key)
    if(string.len(lastKeyDown) > 2) then
      B747DR_fdr_log_json=lastKeyDown.." then "..fmsModule.. " do " .. key
    else
      B747DR_fdr_log_json=fmsModule.. " do " .. key
    end
    lastKeyDown =  fmsModule.. " did " .. key
  end
  -- the scratchpad's keys on the custom pages, and CLR on a message on any
  -- page (FCOM p.1212-1213; FMSPG p.39-43)
  local k=SP_KEYS[key] or (string.len(key)==1 and key) or nil
  if k and (fmsO.targetCustomFMC or (k=="CLR" and C.message(st, fmcMsgs))) then
    if k=="CLR" and phase==0 and fmsO.targetCustomFMC then
      simCMD_FMS_key[fmsModule]["clear"]:once() -- X-Plane's CDU's message (RTE, LEGS entries)
    end
    st.sp=fmsO.scratchpad
    C.key(st, fmcMsgs, k, phase, duration)
    fmsO.scratchpad=st.sp
    return
  end
  if phase~=0 then return end
  fmsO.notify=""
  pageKey(fmsModule,key)
  st.sp=fmsO.scratchpad
  -- a message the page set (notify): this CDU's (FMSPG p.39)
  if fmsO.notify~="" then
    C.error(st, fmsO.notify)
    fmsO.notify=""
  end
  if fmsO.targetCustomFMC then switchNow(fmsO) else run_after_time(switchCustomMode, 0.5) end
end

fmsKeyFunc={}

function create_keypad(fms)
  fmsKeyFunc[fms]={};

  fmsKeyFunc[fms].funcs={
    key_L1_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"],"L1") end end,
    key_L2_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "L2") end end,
    key_L3_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "L3") end end,
    key_L4_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "L4") end end,
    key_L5_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "L5") end end,
    key_L6_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "L6") end end,
    
    key_R1_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R1") end end,
    key_R2_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R2") end end,
    key_R3_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R3") end end,
    key_R4_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R4") end end,
    key_R5_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R5") end end,
    key_R6_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R6") end end,
      
    key_index_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "index") end end,
    key_fpln_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "fpln") end end,
    key_navrad_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "navrad") end end,
    key_clb_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "clb") end end,
    key_crz_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "crz") end end,
    key_des_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "des") end end,
    key_dir_intc_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "dir_intc") end end,
    key_legs_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "legs") end end,
    key_dep_arr_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "dep_arr") end end,
    key_hold_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "hold") end end,
    key_prog_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "prog") end end,
    key_execute_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "exec") end end,
    key_fix_CMDhandler		=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "fix") end end,
    key_prev_pg_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "prev") end end,
    key_next_pg_CMDhandler	=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "next") end end,   
      
    key_0_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "0") end end,
    key_1_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "1") end end,
    key_2_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "2") end end,
    key_3_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "3") end end,
    key_4_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "4") end end,
    key_5_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "5") end end,
    key_6_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "6") end end,
    key_7_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "7") end end,
    key_8_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "8") end end,
    key_9_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "9") end end,
    
    key_period_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], ".") end end,
    key_minus_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "-") end end, 
      
    key_A_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "A") end end,
    key_B_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "B") end end,
    key_C_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "C") end end,
    key_D_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "D") end end,
    key_E_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "E") end end,
    key_F_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "F") end end,
    key_G_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "G") end end,
    key_H_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "H") end end,
    key_I_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "I") end end,
    key_J_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "J") end end,
    key_K_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "K") end end,
    key_L_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "L") end end,
    key_M_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "M") end end,
    key_N_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "N") end end,
    key_O_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "O") end end,
    key_P_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "P") end end,
    key_Q_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "Q") end end,
    key_R_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "R") end end,
    key_S_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "S") end end,
    key_T_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "T") end end,
    key_U_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "U") end end,
    key_V_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "V") end end,
    key_W_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "W") end end,
    key_X_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "X") end end,
    key_Y_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "Y") end end,
    key_Z_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "Z") end end,
      
    key_space_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "space") end end,
    key_del_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "del") end end,
    key_slash_CMDhandler=function (phase, duration) if phase ==0 then keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "slash") end end,
    key_clear_CMDhandler=function (phase, duration) keyDown(fmsKeyFunc[fms]["funcs"]["parent"], "clear", phase, duration) end
  }
  fmsKeyFunc[fms].funcs.parent=fms
end



B747DR_fms={}
B747DR_fms_s={}
B747DR_srcfms={}

function setDREFs(fmsO,cduid,fmsid,keyid,fmskeyid)
  
  B747DR_fms[fmsO.id]={}
  B747DR_fms[fmsO.id][1] 		= find_dataref("laminar/B747/"..fmsid.."/Line01_L", "string")
  B747DR_fms[fmsO.id][2]                = find_dataref("laminar/B747/"..fmsid.."/Line02_L", "string")
  B747DR_fms[fmsO.id][3]                = find_dataref("laminar/B747/"..fmsid.."/Line03_L", "string")
  B747DR_fms[fmsO.id][4]                = find_dataref("laminar/B747/"..fmsid.."/Line04_L", "string")
  B747DR_fms[fmsO.id][5]                = find_dataref("laminar/B747/"..fmsid.."/Line05_L", "string")
  B747DR_fms[fmsO.id][6]                = find_dataref("laminar/B747/"..fmsid.."/Line06_L", "string")
  B747DR_fms[fmsO.id][7]                = find_dataref("laminar/B747/"..fmsid.."/Line07_L", "string")
  B747DR_fms[fmsO.id][8]                = find_dataref("laminar/B747/"..fmsid.."/Line08_L", "string")
  B747DR_fms[fmsO.id][9]                = find_dataref("laminar/B747/"..fmsid.."/Line09_L", "string")
  B747DR_fms[fmsO.id][10]                = find_dataref("laminar/B747/"..fmsid.."/Line10_L", "string")
  B747DR_fms[fmsO.id][11]                = find_dataref("laminar/B747/"..fmsid.."/Line11_L", "string")
  B747DR_fms[fmsO.id][12]                = find_dataref("laminar/B747/"..fmsid.."/Line12_L", "string")
  B747DR_fms[fmsO.id][13]                = find_dataref("laminar/B747/"..fmsid.."/Line13_L", "string")
  B747DR_fms[fmsO.id][14]                = find_dataref("laminar/B747/"..fmsid.."/Line14_L", "string")
  B747DR_fms_s[fmsO.id]={}
  B747DR_fms_s[fmsO.id][1]                 = find_dataref("laminar/B747/"..fmsid.."/Line01_S", "string")
  B747DR_fms_s[fmsO.id][2]                = find_dataref("laminar/B747/"..fmsid.."/Line02_S", "string")
  B747DR_fms_s[fmsO.id][3]                = find_dataref("laminar/B747/"..fmsid.."/Line03_S", "string")
  B747DR_fms_s[fmsO.id][4]                = find_dataref("laminar/B747/"..fmsid.."/Line04_S", "string")
  B747DR_fms_s[fmsO.id][5]                = find_dataref("laminar/B747/"..fmsid.."/Line05_S", "string")
  B747DR_fms_s[fmsO.id][6]                = find_dataref("laminar/B747/"..fmsid.."/Line06_S", "string")
  B747DR_fms_s[fmsO.id][7]                = find_dataref("laminar/B747/"..fmsid.."/Line07_S", "string")
  B747DR_fms_s[fmsO.id][8]                = find_dataref("laminar/B747/"..fmsid.."/Line08_S", "string")
  B747DR_fms_s[fmsO.id][9]                = find_dataref("laminar/B747/"..fmsid.."/Line09_S", "string")
  B747DR_fms_s[fmsO.id][10]                = find_dataref("laminar/B747/"..fmsid.."/Line10_S", "string")
  B747DR_fms_s[fmsO.id][11]                = find_dataref("laminar/B747/"..fmsid.."/Line11_S", "string")
  B747DR_fms_s[fmsO.id][12]                = find_dataref("laminar/B747/"..fmsid.."/Line12_S", "string")
  B747DR_fms_s[fmsO.id][13]                = find_dataref("laminar/B747/"..fmsid.."/Line13_S", "string")
  B747DR_fms_s[fmsO.id][14]                = find_dataref("laminar/B747/"..fmsid.."/Line14_S", "string")
  B747DR_srcfms[fmsO.id]={}
  B747DR_srcfms[fmsO.id][1]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line0")
  B747DR_srcfms[fmsO.id][2]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line1")
  B747DR_srcfms[fmsO.id][3]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line2")
  B747DR_srcfms[fmsO.id][4]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line3")
  B747DR_srcfms[fmsO.id][5]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line4")
  B747DR_srcfms[fmsO.id][6]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line5")
  B747DR_srcfms[fmsO.id][7]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line6")
  B747DR_srcfms[fmsO.id][8]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line7")
  B747DR_srcfms[fmsO.id][9]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line8")
  B747DR_srcfms[fmsO.id][10]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line9")
  B747DR_srcfms[fmsO.id][11]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line10")
  B747DR_srcfms[fmsO.id][12]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line11")
  B747DR_srcfms[fmsO.id][13]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line12")
  B747DR_srcfms[fmsO.id][14]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line13")
  B747DR_srcfms[fmsO.id][15]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line14")
  B747DR_srcfms[fmsO.id][16]=find_dataref("sim/cockpit2/radios/indicators/fms_".. cduid .."_text_line15")
  if keyid~=nil then
  simCMD_FMS_key[fmsO.id]={}
  simCMD_FMS_key[fmsO.id]["L1"]            = find_command(keyid.."ls_1l")
  simCMD_FMS_key[fmsO.id]["L2"]            = find_command(keyid.."ls_2l")
  simCMD_FMS_key[fmsO.id]["L3"]            = find_command(keyid.."ls_3l")
  simCMD_FMS_key[fmsO.id]["L4"]            = find_command(keyid.."ls_4l")
  simCMD_FMS_key[fmsO.id]["L5"]            = find_command(keyid.."ls_5l")
  simCMD_FMS_key[fmsO.id]["L6"]            = find_command(keyid.."ls_6l")

  simCMD_FMS_key[fmsO.id]["R1"]            = find_command(keyid.."ls_1r")
  simCMD_FMS_key[fmsO.id]["R2"]            = find_command(keyid.."ls_2r")
  simCMD_FMS_key[fmsO.id]["R3"]            = find_command(keyid.."ls_3r")
  simCMD_FMS_key[fmsO.id]["R4"]            = find_command(keyid.."ls_4r")
  simCMD_FMS_key[fmsO.id]["R5"]            = find_command(keyid.."ls_5r")
  simCMD_FMS_key[fmsO.id]["R6"]            = find_command(keyid.."ls_6r")

  simCMD_FMS_key[fmsO.id]["index"]        = find_command(keyid.."index")
  simCMD_FMS_key[fmsO.id]["fpln"]         = find_command(keyid.."fpln")
  simCMD_FMS_key[fmsO.id]["clb"]          = find_command(keyid.."clb")
  simCMD_FMS_key[fmsO.id]["crz"]          = find_command(keyid.."crz")
  simCMD_FMS_key[fmsO.id]["des"]          = find_command(keyid.."des")

  simCMD_FMS_key[fmsO.id]["dir_intc"]     = find_command(keyid.."dir_intc")
  simCMD_FMS_key[fmsO.id]["legs"]         = find_command(keyid.."legs")
  simCMD_FMS_key[fmsO.id]["dep_arr"]      = find_command(keyid.."dep_arr")
  simCMD_FMS_key[fmsO.id]["hold"]         = find_command(keyid.."hold")
  simCMD_FMS_key[fmsO.id]["prog"]         = find_command(keyid.."prog")
  simCMD_FMS_key[fmsO.id]["exec"]         = find_command(keyid.."exec")
 
  simCMD_FMS_key[fmsO.id]["fix"]          = find_command(keyid.."fix")

  simCMD_FMS_key[fmsO.id]["prev"]             = find_command(keyid.."prev")
  simCMD_FMS_key[fmsO.id]["next"]             = find_command(keyid.."next")

  simCMD_FMS_key[fmsO.id]["0"]            = find_command(keyid.."key_0")
  simCMD_FMS_key[fmsO.id]["1"]            = find_command(keyid.."key_1")
  simCMD_FMS_key[fmsO.id]["2"]            = find_command(keyid.."key_2")
  simCMD_FMS_key[fmsO.id]["3"]            = find_command(keyid.."key_3")
  simCMD_FMS_key[fmsO.id]["4"]            = find_command(keyid.."key_4")
  simCMD_FMS_key[fmsO.id]["5"]            = find_command(keyid.."key_5")
  simCMD_FMS_key[fmsO.id]["6"]            = find_command(keyid.."key_6")
  simCMD_FMS_key[fmsO.id]["7"]            = find_command(keyid.."key_7")
  simCMD_FMS_key[fmsO.id]["8"]            = find_command(keyid.."key_8")
  simCMD_FMS_key[fmsO.id]["9"]            = find_command(keyid.."key_9")

  simCMD_FMS_key[fmsO.id]["."]       = find_command(keyid.."key_period")
  simCMD_FMS_key[fmsO.id]["-"]        = find_command(keyid.."key_minus")
  simCMD_FMS_key[fmsO.id]["A"]		= find_command(keyid.."key_A")
  simCMD_FMS_key[fmsO.id]["B"]          = find_command(keyid.."key_B")
  simCMD_FMS_key[fmsO.id]["C"]            = find_command(keyid.."key_C")
  simCMD_FMS_key[fmsO.id]["D"]            = find_command(keyid.."key_D")
  simCMD_FMS_key[fmsO.id]["E"]            = find_command(keyid.."key_E")
  simCMD_FMS_key[fmsO.id]["F"]            = find_command(keyid.."key_F")
  simCMD_FMS_key[fmsO.id]["G"]            = find_command(keyid.."key_G")
  simCMD_FMS_key[fmsO.id]["H"]            = find_command(keyid.."key_H")
  simCMD_FMS_key[fmsO.id]["I"]            = find_command(keyid.."key_I")
  simCMD_FMS_key[fmsO.id]["J"]            = find_command(keyid.."key_J")
  simCMD_FMS_key[fmsO.id]["K"]            = find_command(keyid.."key_K")
  simCMD_FMS_key[fmsO.id]["L"]            = find_command(keyid.."key_L")
  simCMD_FMS_key[fmsO.id]["M"]            = find_command(keyid.."key_M")
  simCMD_FMS_key[fmsO.id]["N"]            = find_command(keyid.."key_N")
  simCMD_FMS_key[fmsO.id]["O"]            = find_command(keyid.."key_O")	
  simCMD_FMS_key[fmsO.id]["P"]            = find_command(keyid.."key_P")
  simCMD_FMS_key[fmsO.id]["Q"]            = find_command(keyid.."key_Q")
  simCMD_FMS_key[fmsO.id]["R"]            = find_command(keyid.."key_R")
  simCMD_FMS_key[fmsO.id]["S"]            = find_command(keyid.."key_S")
  simCMD_FMS_key[fmsO.id]["T"]            = find_command(keyid.."key_T")
  simCMD_FMS_key[fmsO.id]["U"]            = find_command(keyid.."key_U")
  simCMD_FMS_key[fmsO.id]["V"]            = find_command(keyid.."key_V")
  simCMD_FMS_key[fmsO.id]["W"]            = find_command(keyid.."key_W")
  simCMD_FMS_key[fmsO.id]["X"]            = find_command(keyid.."key_X")
  simCMD_FMS_key[fmsO.id]["Y"]            = find_command(keyid.."key_Y")
  simCMD_FMS_key[fmsO.id]["Z"]            = find_command(keyid.."key_Z")
  simCMD_FMS_key[fmsO.id]["space"]        = find_command(keyid.."key_space")
  if fmsO.id=="fmsR" then  
    simCMD_FMS_key[fmsO.id]["navrad"]        = find_command("sim/FMS2/navrad")
  else
    simCMD_FMS_key[fmsO.id]["navrad"]        = find_command("sim/FMS/navrad")
  end
  simCMD_FMS_key[fmsO.id]["del"]       = find_command(keyid.."key_delete")
  simCMD_FMS_key[fmsO.id]["slash"]        = find_command(keyid.."key_slash")
  simCMD_FMS_key[fmsO.id]["clear"]        = find_command(keyid.."key_clear")
  end
  create_keypad(fmsO.id)
B747CMD_fms1_ls_key_L1              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/L1", "FMS1 Line Select Key 1-Left", fmsKeyFunc[fmsO.id]["funcs"]["key_L1_CMDhandler"])
  B747CMD_fms1_ls_key_L2            = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/L2", "FMS1 Line Select Key 2-Left", fmsKeyFunc[fmsO.id]["funcs"]["key_L2_CMDhandler"])
  B747CMD_fms1_ls_key_L3            = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/L3", "FMS1 Line Select Key 3-Left", fmsKeyFunc[fmsO.id]["funcs"]["key_L3_CMDhandler"])
B747CMD_fms1_ls_key_L4              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/L4", "FMS1 Line Select Key 4-Left", fmsKeyFunc[fmsO.id]["funcs"]["key_L4_CMDhandler"])
B747CMD_fms1_ls_key_L5              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/L5", "FMS1 Line Select Key 5-Left", fmsKeyFunc[fmsO.id]["funcs"]["key_L5_CMDhandler"])
B747CMD_fms1_ls_key_L6              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/L6", "FMS1 Line Select Key 6-Left", fmsKeyFunc[fmsO.id]["funcs"]["key_L6_CMDhandler"])

B747CMD_fms1_ls_key_R1              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/R1", "FMS1 Line Select Key 1-Right", fmsKeyFunc[fmsO.id]["funcs"]["key_R1_CMDhandler"])
B747CMD_fms1_ls_key_R2              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/R2", "FMS1 Line Select Key 2-Right", fmsKeyFunc[fmsO.id]["funcs"]["key_R2_CMDhandler"])
B747CMD_fms1_ls_key_R3              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/R3", "FMS1 Line Select Key 3-Right", fmsKeyFunc[fmsO.id]["funcs"]["key_R3_CMDhandler"])
B747CMD_fms1_ls_key_R4              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/R4", "FMS1 Line Select Key 4-Right", fmsKeyFunc[fmsO.id]["funcs"]["key_R4_CMDhandler"])
B747CMD_fms1_ls_key_R5              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/R5", "FMS1 Line Select Key 5-Right", fmsKeyFunc[fmsO.id]["funcs"]["key_R5_CMDhandler"])
B747CMD_fms1_ls_key_R6              = deferred_command("laminar/B747/".. fmskeyid .. "/ls_key/R6", "FMS1 Line Select Key 6-Right", fmsKeyFunc[fmsO.id]["funcs"]["key_R6_CMDhandler"])


-- FUNCTION KEYS ------------------------------------------------------------------------
B747CMD_fms1_func_key_index         = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/index", "FMS1 Function Key INDEX",fmsKeyFunc[fmsO.id]["funcs"]["key_index_CMDhandler"])
B747CMD_fms1_func_key_fpln          = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/fpln", "FMS1 Function Key FPLN", fmsKeyFunc[fmsO.id]["funcs"]["key_fpln_CMDhandler"])
B747CMD_fms1_func_key_navrad        = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/navrad", "FMS1 Function Key FPLN", fmsKeyFunc[fmsO.id]["funcs"]["key_navrad_CMDhandler"])
B747CMD_fms1_func_key_clb           = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/clb", "FMS1 Function Key CLB", fmsKeyFunc[fmsO.id]["funcs"]["key_clb_CMDhandler"])
B747CMD_fms1_func_key_crz           = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/crz", "FMS1 Function Key CRZ", fmsKeyFunc[fmsO.id]["funcs"]["key_crz_CMDhandler"])
B747CMD_fms1_func_key_des           = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/des", "FMS1 Function Key DES", fmsKeyFunc[fmsO.id]["funcs"]["key_des_CMDhandler"])
B747CMD_fms1_func_key_dir_intc      = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/dir_intc", "FMS1 Function Key DIR/INTC",fmsKeyFunc[fmsO.id]["funcs"]["key_dir_intc_CMDhandler"])
B747CMD_fms1_func_key_legs          = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/legs", "FMS1 Function Key LEGS", fmsKeyFunc[fmsO.id]["funcs"]["key_legs_CMDhandler"])
B747CMD_fms1_func_key_dep_arr       = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/dep_arr", "FMS1 Function Key DEP/ARR", fmsKeyFunc[fmsO.id]["funcs"]["key_dep_arr_CMDhandler"])
B747CMD_fms1_func_key_hold          = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/hold", "FMS1 Function Key HOLD", fmsKeyFunc[fmsO.id]["funcs"]["key_hold_CMDhandler"])
B747CMD_fms1_func_key_prog          = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/prog", "FMS1 Function Key PROG", fmsKeyFunc[fmsO.id]["funcs"]["key_prog_CMDhandler"])
B747CMD_fms1_key_execute            = deferred_command("laminar/B747/".. fmskeyid .. "/key/execute", "FMS1 KEY EXEC", fmsKeyFunc[fmsO.id]["funcs"]["key_execute_CMDhandler"])
B747CMD_fms1_func_key_fix           = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/fix", "FMS1 Function Key FIX", fmsKeyFunc[fmsO.id]["funcs"]["key_fix_CMDhandler"])
B747CMD_fms1_func_key_prev_pg       = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/prev_pg", "FMS1 Function Key PREV PAGE", fmsKeyFunc[fmsO.id]["funcs"]["key_prev_pg_CMDhandler"])
B747CMD_fms1_func_key_next_pg       = deferred_command("laminar/B747/".. fmskeyid .. "/func_key/next_pg", "FMS1 Function Key NEXT PAGE", fmsKeyFunc[fmsO.id]["funcs"]["key_next_pg_CMDhandler"])


-- ALPHA-NUMERIC KEYS -------------------------------------------------------------------
B747CMD_fms1_alphanum_key_0         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/0", "FMS1 Alpha/Numeric Key 0", fmsKeyFunc[fmsO.id]["funcs"]["key_0_CMDhandler"])
B747CMD_fms1_alphanum_key_1         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/1", "FMS1 Alpha/Numeric Key 1", fmsKeyFunc[fmsO.id]["funcs"]["key_1_CMDhandler"])
B747CMD_fms1_alphanum_key_2         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/2", "FMS1 Alpha/Numeric Key 2", fmsKeyFunc[fmsO.id]["funcs"]["key_2_CMDhandler"])
B747CMD_fms1_alphanum_key_3         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/3", "FMS1 Alpha/Numeric Key 3", fmsKeyFunc[fmsO.id]["funcs"]["key_3_CMDhandler"])
B747CMD_fms1_alphanum_key_4         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/4", "FMS1 Alpha/Numeric Key 4", fmsKeyFunc[fmsO.id]["funcs"]["key_4_CMDhandler"])
B747CMD_fms1_alphanum_key_5         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/5", "FMS1 Alpha/Numeric Key 5", fmsKeyFunc[fmsO.id]["funcs"]["key_5_CMDhandler"])
B747CMD_fms1_alphanum_key_6         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/6", "FMS1 Alpha/Numeric Key 6", fmsKeyFunc[fmsO.id]["funcs"]["key_6_CMDhandler"])
B747CMD_fms1_alphanum_key_7         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/7", "FMS1 Alpha/Numeric Key 7", fmsKeyFunc[fmsO.id]["funcs"]["key_7_CMDhandler"])
B747CMD_fms1_alphanum_key_8         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/8", "FMS1 Alpha/Numeric Key 8", fmsKeyFunc[fmsO.id]["funcs"]["key_8_CMDhandler"])
B747CMD_fms1_alphanum_key_9         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/9", "FMS1 Alpha/Numeric Key 9", fmsKeyFunc[fmsO.id]["funcs"]["key_9_CMDhandler"])

B747CMD_fms1_key_period             = deferred_command("laminar/B747/".. fmskeyid .. "/key/period", "FMS1 Key '.'", fmsKeyFunc[fmsO.id]["funcs"]["key_period_CMDhandler"])
B747CMD_fms1_key_minus              = deferred_command("laminar/B747/".. fmskeyid .. "/key/minus", "FMS1 Key '+/-'", fmsKeyFunc[fmsO.id]["funcs"]["key_minus_CMDhandler"])

B747CMD_fms1_alphanum_key_A         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/A", "FMS1 Alpha/Numeric Key A", fmsKeyFunc[fmsO.id]["funcs"]["key_A_CMDhandler"])
B747CMD_fms1_alphanum_key_B         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/B", "FMS1 Alpha/Numeric Key B", fmsKeyFunc[fmsO.id]["funcs"]["key_B_CMDhandler"])
B747CMD_fms1_alphanum_key_C         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/C", "FMS1 Alpha/Numeric Key C", fmsKeyFunc[fmsO.id]["funcs"]["key_C_CMDhandler"])
B747CMD_fms1_alphanum_key_D         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/D", "FMS1 Alpha/Numeric Key D", fmsKeyFunc[fmsO.id]["funcs"]["key_D_CMDhandler"])
B747CMD_fms1_alphanum_key_E         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/E", "FMS1 Alpha/Numeric Key E", fmsKeyFunc[fmsO.id]["funcs"]["key_E_CMDhandler"])
B747CMD_fms1_alphanum_key_F         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/F", "FMS1 Alpha/Numeric Key F", fmsKeyFunc[fmsO.id]["funcs"]["key_F_CMDhandler"])
B747CMD_fms1_alphanum_key_G         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/G", "FMS1 Alpha/Numeric Key G", fmsKeyFunc[fmsO.id]["funcs"]["key_G_CMDhandler"])
B747CMD_fms1_alphanum_key_H         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/H", "FMS1 Alpha/Numeric Key H", fmsKeyFunc[fmsO.id]["funcs"]["key_H_CMDhandler"])
B747CMD_fms1_alphanum_key_I         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/I", "FMS1 Alpha/Numeric Key I", fmsKeyFunc[fmsO.id]["funcs"]["key_I_CMDhandler"])
B747CMD_fms1_alphanum_key_J         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/J", "FMS1 Alpha/Numeric Key J", fmsKeyFunc[fmsO.id]["funcs"]["key_J_CMDhandler"])
B747CMD_fms1_alphanum_key_K         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/K", "FMS1 Alpha/Numeric Key K", fmsKeyFunc[fmsO.id]["funcs"]["key_K_CMDhandler"])
B747CMD_fms1_alphanum_key_L         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/L", "FMS1 Alpha/Numeric Key L", fmsKeyFunc[fmsO.id]["funcs"]["key_L_CMDhandler"])
B747CMD_fms1_alphanum_key_M         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/M", "FMS1 Alpha/Numeric Key M", fmsKeyFunc[fmsO.id]["funcs"]["key_M_CMDhandler"])
B747CMD_fms1_alphanum_key_N         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/N", "FMS1 Alpha/Numeric Key N", fmsKeyFunc[fmsO.id]["funcs"]["key_N_CMDhandler"])
B747CMD_fms1_alphanum_key_O         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/O", "FMS1 Alpha/Numeric Key O", fmsKeyFunc[fmsO.id]["funcs"]["key_O_CMDhandler"])
B747CMD_fms1_alphanum_key_P         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/P", "FMS1 Alpha/Numeric Key P", fmsKeyFunc[fmsO.id]["funcs"]["key_P_CMDhandler"])
B747CMD_fms1_alphanum_key_Q         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/Q", "FMS1 Alpha/Numeric Key Q", fmsKeyFunc[fmsO.id]["funcs"]["key_Q_CMDhandler"])
B747CMD_fms1_alphanum_key_R         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/R", "FMS1 Alpha/Numeric Key R", fmsKeyFunc[fmsO.id]["funcs"]["key_R_CMDhandler"])
B747CMD_fms1_alphanum_key_S         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/S", "FMS1 Alpha/Numeric Key S", fmsKeyFunc[fmsO.id]["funcs"]["key_S_CMDhandler"])
B747CMD_fms1_alphanum_key_T         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/T", "FMS1 Alpha/Numeric Key T", fmsKeyFunc[fmsO.id]["funcs"]["key_T_CMDhandler"])
B747CMD_fms1_alphanum_key_U         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/U", "FMS1 Alpha/Numeric Key U", fmsKeyFunc[fmsO.id]["funcs"]["key_U_CMDhandler"])
B747CMD_fms1_alphanum_key_V         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/V", "FMS1 Alpha/Numeric Key V", fmsKeyFunc[fmsO.id]["funcs"]["key_V_CMDhandler"])
B747CMD_fms1_alphanum_key_W         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/W", "FMS1 Alpha/Numeric Key W", fmsKeyFunc[fmsO.id]["funcs"]["key_W_CMDhandler"])
B747CMD_fms1_alphanum_key_X         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/X", "FMS1 Alpha/Numeric Key X", fmsKeyFunc[fmsO.id]["funcs"]["key_X_CMDhandler"])
B747CMD_fms1_alphanum_key_Y         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/Y", "FMS1 Alpha/Numeric Key Y", fmsKeyFunc[fmsO.id]["funcs"]["key_Y_CMDhandler"])
B747CMD_fms1_alphanum_key_Z         = deferred_command("laminar/B747/".. fmskeyid .. "/alphanum_key/Z", "FMS1 Alpha/Numeric Key Z", fmsKeyFunc[fmsO.id]["funcs"]["key_Z_CMDhandler"])

B747CMD_fms1_key_space              = deferred_command("laminar/B747/".. fmskeyid .. "/key/space", "FMS1 KEY SP",fmsKeyFunc[fmsO.id]["funcs"]["key_space_CMDhandler"])
B747CMD_fms1_key_del                = deferred_command("laminar/B747/".. fmskeyid .. "/key/del", "FMS1 KEY DEL", fmsKeyFunc[fmsO.id]["funcs"]["key_del_CMDhandler"])
B747CMD_fms1_key_slash              = deferred_command("laminar/B747/".. fmskeyid .. "/key/slash", "FMS1 Key '/'", fmsKeyFunc[fmsO.id]["funcs"]["key_slash_CMDhandler"])
B747CMD_fms1_key_clear              = deferred_command("laminar/B747/".. fmskeyid .. "/key/clear", "FMS1 KEY CLR", fmsKeyFunc[fmsO.id]["funcs"]["key_clear_CMDhandler"])
end  


local BLANK = "                        "
local pageError = {}
local lastNativeMsg = {}
-- the keys the FMC typed into X-Plane's CDU last (custom2fmc, key2fmc):
-- the text, how many keys, when and the frames since; its scratchpad
-- shows them going in for a moment, and keeps the text when its page
-- does not take it
local nativeSent = {}
function B747_cdu_native_sent(id, text, keys)
  nativeSent[id] = {text = text or "", keys = keys or 1, t = simDRTime, frames = 0}
end
function fms:B747_fms_display()
    local thisID=self.id
    local st=cduState[thisID]
    -- no drawing without power; the MENU page when power comes (FMSPG p.53)
    local powered=cduPowered(thisID)
    if powered and cduWasPowered[thisID]==false then
      self.targetCustomFMC=true
      self.targetPage="INDEX"
      self.targetpgNo=1
      switchNow(self)
    end
    cduWasPowered[thisID]=powered
    if not powered then return end
    -- a message a page set while drawing (notify): this CDU's
    if self.notify~=nil and self.notify~="" then
      C.error(st, self.notify)
      self.notify=""
    end
    if self.currentPage=="FMC" then
      self.inCustomFMC = false
    end
    if self.targetPage=="FMC" then
      self.targetCustomFMC= false
    end
    if self.inCustomFMC~=self.targetCustomFMC or self.currentPage~=self.targetPage or self.pgNo~=self.targetpgNo then
      for i=1,14,1 do
      B747DR_fms[thisID][i]=BLANK
      B747DR_fms_s[thisID][i]=BLANK
      end
      return
    end

    local inCustomFMC=self.inCustomFMC
    local page=self.currentPage

    if B747DR_srcfms[thisID][14]=="[NAV DATA OUT OF DATE  ]" then simCMD_FMS_key[thisID]["clear"]:once() return end
    -- X-Plane's CDU's scratchpad message (its pages' entries) as this CDU's,
    -- not the keys the FMC types into it while they go in, nor the text it
    -- typed (its line has brackets always: "[                      ]")
    local native=B747DR_srcfms[thisID][14]
    if type(native)~="string" then native="" end
    local nativeMsg=string.match(native,"%[%s*(.-)%s*%]") or string.match(native,"^%s*(.-)%s*$")
    local sent=nativeSent[thisID]
    if sent then
      sent.frames=sent.frames+1
      if sent.frames>=sent.keys+5 and simDRTime-sent.t>=0.3 then
        nativeSent[thisID]=nil
        if nativeMsg==sent.text or nativeMsg=="DELETE" then lastNativeMsg[thisID]=native end
      end
    end
    if nativeSent[thisID]==nil then
      if nativeMsg~="" then
        if native~=lastNativeMsg[thisID] then
          lastNativeMsg[thisID]=native
          if inCustomFMC then C.error(st, nativeMsg) end
        end
      else
        lastNativeMsg[thisID]=nil
      end
    end
    if not inCustomFMC then
      for i=1,13,1 do
	      B747DR_fms[thisID][i]=cleanFMSLine(B747DR_srcfms[thisID][i])
	      B747DR_fms_s[thisID][i]=BLANK
      end
      B747DR_fms[thisID][14]=C.message(st, fmcMsgs) or cleanFMSLine(native)
      B747DR_fms_s[thisID][14]=BLANK
    else
      -- the page drawn under pcall: an error blanks it and goes to the log
      -- once, the other CDUs and modules go on (CDU-09)
      local ok,fmsPage,fmsPagesmall=pcall(function()
        local n=fmsPages[page]:getNumPages(thisID)
        if self.pgNo>n then self.pgNo=n self.targetpgNo=n end
        if self.pgNo<1 then self.pgNo=1 self.targetpgNo=1 end
        return fmsPages[page]:getPage(self.pgNo,thisID), fmsPages[page]:getSmallPage(self.pgNo,thisID)
      end)
      if not ok then
        if not pageError[page] then
          pageError[page]=true
          print("CDU page "..tostring(page).." error: "..tostring(fmsPage))
        end
        fmsPage,fmsPagesmall={},{}
      end
      for i=1,13,1 do
	      B747DR_fms[thisID][i]=fmsPage[i] or BLANK
	      B747DR_fms_s[thisID][i]=fmsPagesmall[i] or BLANK
      end
      st.sp=self.scratchpad or ""
      B747DR_fms[thisID][14]=C.line(st, fmcMsgs)
    end
end
