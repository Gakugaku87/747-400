

fmsPages["CMC"]=createPage("CMC")
fmsPages["CMC"].getPage=function(self,pgNo,fmsID)

  if pgNo==1 then 
      fmsFunctionsDefs["CMC"]["L1"]={"setpage","PLFAULTS"}
      fmsFunctionsDefs["CMC"]["L2"]={"setpage","CONFTEST"}
      fmsFunctionsDefs["CMC"]["L3"]={"setpage","EMANP"}
      fmsFunctionsDefs["CMC"]["L4"]={"setpage","GRDTEST"}
    return {
            
"     CMC-L MENU      1/2",
"                        ",
"<PRESENT LEG FAULTS     ",
"                        ",
"<CONFIDENCE TESTS       ",
"                        ",
"<EICAS MAINT PAGES      ",
"                        ",
"<GROUND TESTS           ",
"                        ",
"                        ", 
"------------------------",
"                   HELP>"
    }
  elseif pgNo==2 then
      --fmsFunctionsDefs["CMC"]["L1"]={"setpage","FAULTS"}
      --fmsFunctionsDefs["CMC"]["L2"]={"setpage","FHISTORY"}
      --fmsFunctionsDefs["CMC"]["L3"]={"setpage","OFUCNTION"}
    return {
            
"     CMC-L MENU      2/2",
"                        ",
"<EXISTING FAULTS        ",
"                        ",
"<FAULT HISTORY          ",
"                        ",
"<OTHER FUNCTIONS        ",
"                        ",
"------------------------",
"                        ",
"                  NOTES>", 
"                        ",
"                   HELP>"
    }
end
end
fmsPages["CMC"].getNumPages=function(self)
  return 2
end


-- (N19-WARN-03) PRESENT LEG FAULTS: the EICAS STATUS messages the EIUs can
-- latch in their non-volatile memory, as the EIUs show them
-- (laminar/B747/CAS/status_nvm, the warning system's), each with ERASE>
-- (LH24 p.64-65; LH_MAN p.75): four a page on 1L-4L, "*STATUS:" above each
-- (shown on EICAS now), its name and ERASE> on the line. The right key
-- erases it from the EIUs and the EICAS: one more on its ERASE counter
-- (laminar/B747/CAS/status_erase_count[slot]), which the warning system
-- reads. 6L <RETURN. Not made (N19-CMC-01, -02): the other flight deck
-- effects, the fault codes (the sources give DRIVE DISC 2's only), the < of
-- the correlated CMCS messages, 5L <ERASE STATUS (what it does: no source),
-- REPORT>, HELP>, the fault records; nothing shown without such a message
-- (estimate). Before: development pages (THROTTLE TESTS, STALL TESTS).
-- notes/ATA-31-warning.md §13.
B747DR_cmc_status_nvm           = find_dataref("laminar/B747/CAS/status_nvm")
B747DR_cmc_status_erase_count   = find_dataref("laminar/B747/CAS/status_erase_count")
-- the latchable STATUS messages: their slot in laminar/B747/CAS/status_status
-- and their name (B747.87.xt.warning.lua's B747_CASstatusMsg, those with a
-- latch class: keep the two the same; tests/warning/cmc_erase_page_test.lua)
local CMC_LATCHABLE = {
  {8, "HYD OVHT SYS 1"}, {9, "HYD OVHT SYS 2"}, {10, "HYD OVHT SYS 3"}, {11, "HYD OVHT SYS 4"},
  {25, "DRIVE DISC 1"}, {26, "DRIVE DISC 2"}, {27, "DRIVE DISC 3"}, {28, "DRIVE DISC 4"},
  {95, "BODY GR STRG SYS"},
}
local CMC_PER_PAGE = 4
local CMC_BLANK = "                        "
local cmc_erase_sent = {}      -- slot -> the last value written to its counter

-- the latchable messages shown now, in slot order (estimate: no source
-- gives the page's order)
local function cmc_faults()
  local list = {}
  for _, m in ipairs(CMC_LATCHABLE) do
    if B747DR_cmc_status_nvm[m[1]] > 0.5 then list[#list + 1] = m end
  end
  return list
end
local function cmc_num_pages(list) return math.max(1, math.ceil(#list / CMC_PER_PAGE)) end

fmsPages["PLFAULTS"]=createPage("PLFAULTS")
fmsPages["PLFAULTS"].latchable=CMC_LATCHABLE
fmsPages["PLFAULTS"].getNumPages=function(self) return cmc_num_pages(cmc_faults()) end
fmsPages["PLFAULTS"].getPage=function(self,pgNo,fmsID)
  local list = cmc_faults()
  local n = cmc_num_pages(list)
  local p = math.min(math.max(pgNo or 1, 1), n)
  local out = {}
  for i = 1, 13 do out[i] = CMC_BLANK end
  out[1] = string.format("  PRESENT LEG FAULTS %d/%d", p, n)
  for k = 1, CMC_PER_PAGE do
    local m = list[(p - 1) * CMC_PER_PAGE + k]
    if m then out[1 + 2 * k] = string.format("%-18s%6s", m[2], "ERASE>") end
  end
  out[13] = "<RETURN                 "
  return out
end
fmsPages["PLFAULTS"].getSmallPage=function(self,pgNo,fmsID)
  local list = cmc_faults()
  local p = math.min(math.max(pgNo or 1, 1), cmc_num_pages(list))
  local out = {}
  for i = 1, 13 do out[i] = CMC_BLANK end
  for k = 1, CMC_PER_PAGE do
    if list[(p - 1) * CMC_PER_PAGE + k] then out[2 * k] = "*STATUS:                " end
  end
  out[10] = "------------------------"
  return out
end

for k = 1, CMC_PER_PAGE do
  fmsFunctionsDefs["PLFAULTS"]["R" .. k]={"cmcerase",k}
end
-- ERASE> next to the k-th message of the page shown
function fmsFunctions.cmcerase(fmsO, k)
  local list = cmc_faults()
  local p = math.min(math.max(fmsO.pgNo or 1, 1), cmc_num_pages(list))
  local m = list[(p - 1) * CMC_PER_PAGE + k]
  if not m then return end
  local slot = m[1]
  local v = math.max(cmc_erase_sent[slot] or 0, B747DR_cmc_status_erase_count[slot]) + 1
  cmc_erase_sent[slot] = v
  B747DR_cmc_status_erase_count[slot] = v
end

fmsFunctionsDefs["PLFAULTS"]["L6"]={"setpage","CMC"}
fmsPages["CONFTEST"]=createPage("CONFTEST")
fmsPages["CONFTEST"].getPage=function(self,pgNo,fmsID) 
    return {
            
"  CONFIDENCE TESTS   1/1",
"                        ",
"<STALL LEFT             ",
"                        ",
"<STALL RIGHT            ",
"                        ",
"<T/O CONFIG WARNING     ",
"                        ",
"<GPWC                   ",
"                        ",
"                        ", 
"------------------------",
"<RETURN            HELP>"
    }
  
end

fmsFunctionsDefs["CONFTEST"]["L6"]={"setpage","CMC"}
fmsPages["EMANP"]=createPage("EMANP")
fmsPages["EMANP"].getPage=function(self,pgNo,fmsID)
  
  if pgNo==1 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTCMC"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTAPU"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTENGFUEL"}
      fmsFunctionsDefs["EMANP"]["L6"]={"setpage","CMC"}
    return {
      
" EICAS MAINT PAGES   1/3",
"                        ",
"<21 ECS                 ",
"                        ",
"<24 ELECTRICAL          ",
"                        ",
"<27 FLT CONT            ",
"                        ",
"<28 FUEL                ",
"                        ",
"<29 HYDRAULIC           ",
"------------------------",
"<RETURN            HELP>"
    }
  elseif pgNo==2 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTCMC"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTAPU"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTENGFUEL"}
      fmsFunctionsDefs["EMANP"]["L6"]={"setpage","CMC"}
    return {
      
" EICAS MAINT PAGES   2/3",
"                        ",
"<31 CONFIGURATIONS      ",
"                        ",
"<31 GEAR                ",
"                        ",
"<49 APU                 ",
"                        ",
"<73 EPCS                ",
"                        ",
"<74 PERFORMANCE         ",
"------------------------",
"<RETURN            HELP>"
    }
  elseif pgNo==3 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTCMC"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTAPU"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTENGFUEL"}
      fmsFunctionsDefs["EMANP"]["L6"]={"setpage","CMC"}
    return {
      
" EICAS MAINT PAGES   3/3",
"                        ",
"<73 ENG EXCD            ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"------------------------",
"<RETURN            HELP>"
    }  
  end
end

fmsPages["EMANP"].getNumPages=function(self)
  return 3
end

fmsPages["GRDTEST"]=createPage("GRDTEST")
fmsPages["GRDTEST"].getPage=function(self,pgNo,fmsID)

  if pgNo==1 then 
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTAC"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTCABPSI"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTECS"}
      --fmsFunctionsDefs["GRDTEST"]["L4"]={"setpage","GTAPFD"}
      --fmsFunctionsDefs["GRDTEST"]["L5"]={"setpage","GTYAW"}
      fmsFunctionsDefs["GRDTEST"]["L6"]={"setpage","CMC"}
    return {
            
"    GROUND TESTS     1/6",
"                        ",
"<21 AIR CONDITIONING    ",
"                        ",
"<21 CABIN PRESURE       ",
"                        ",
"<21 EQUIPMENT COOLING   ",
"                        ",
"<22 AUTOPILOT FLT DIR   ",
"                        ",
"<22 YAW DAMPER          ", 
"------------------------",
"<RETURN            HELP>"
    }
    
  elseif pgNo==2 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTCOMM"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTELEC"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTFIRE"}
      --fmsFunctionsDefs["GRDTEST"]["L4"]={"setpage","GTAIL"}
      --fmsFunctionsDefs["GRDTEST"]["L5"]={"setpage","GTRUDR"}
      fmsFunctionsDefs["GRDTEST"]["L6"]={"setpage","CMC"}
    return {
      
"    GROUND TESTS     2/6",
"                        ",
"<23 COMMUNICATIONS      ",
"                        ",
"<24 ELECTRICAL POWER    ",
"                        ",
"<26 FIRE PROTECTION     ",
"                        ",
"<27 AILERON LOCKOUT     ",
"                        ",
"<27 RUDDER RATIO        ", 
"------------------------",
"<RETURN            HELP>"
    }
    
  elseif pgNo==3 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTFLAP"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTSTALL"}
     --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTFUEL"}
      --fmsFunctionsDefs["GRDTEST"]["L4"]={"setpage","GTHYD"}
      --fmsFunctionsDefs["GRDTEST"]["L5"]={"setpage","GTICE"}
      fmsFunctionsDefs["GRDTEST"]["L6"]={"setpage","CMC"}
    return {
      
"    GROUND TESTS     3/6",
"                        ",
"<27 FLAP CONTROL        ",
"                        ",
"<27 STALL WARNING       ",
"                        ",
"<28 FUEL                ",
"                        ",
"<29 HYDRAULIC POWER     ",
"                        ",
"<30 ICE AND RAIN        ", 
"------------------------",
"<RETURN            HELP>"
    }
    
  elseif pgNo==4 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTWARN"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTREC"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTBRAKE"}
      --fmsFunctionsDefs["GRDTEST"]["L4"]={"setpage","GTPSEU"}
      --fmsFunctionsDefs["GRDTEST"]["L5"]={"setpage","GTBRKTEMP"}
      fmsFunctionsDefs["GRDTEST"]["L6"]={"setpage","CMC"}
    return {
      
"    GROUND TESTS     4/6",
"                        ",
"<31 INDICATING/WARNING  ",
"                        ",
"<31 RECORDING           ",
"                        ",
"<32 BRAKE CONTROL       ",
"                        ",
"<32 PSEU SYSTEM         ",
"                        ",
"<32 BRAKE TEMPERATURE   ", 
"------------------------",
"<RETURN            HELP>"
    }
    
elseif pgNo==5 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTAIRDAT"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTIR"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTNAVRAD"}
      --fmsFunctionsDefs["GRDTEST"]["L4"]={"setpage","GTFM"}
      --fmsFunctionsDefs["GRDTEST"]["L5"]={"setpage","GTPNEU"}
      fmsFunctionsDefs["GRDTEST"]["L6"]={"setpage","CMC"}
    return {
      
"    GROUND TESTS     5/6",
"                        ",
"<34 AIR DATA            ",
"                        ",
"<34 INERTIAL REFERENCE  ",
"                        ",
"<34 NAVIGATION RADIOS   ",
"                        ",
"<34 FLIGHT MANAGEMENT   ",
"                        ",
"<36 PNEUMATICS          ", 
"------------------------",
"<RETURN            HELP>"
    }
    
elseif pgNo==6 then
      --fmsFunctionsDefs["GRDTEST"]["L1"]={"setpage","GTCMC"}
      --fmsFunctionsDefs["GRDTEST"]["L2"]={"setpage","GTAPU"}
      --fmsFunctionsDefs["GRDTEST"]["L3"]={"setpage","GTENGFUEL"}
      fmsFunctionsDefs["GRDTEST"]["L6"]={"setpage","CMC"}
    return {
      
"    GROUND TESTS     6/6",
"                        ",
"<45 CENTRAL MAINTENANCE ",
"                        ",
"<49 APU                 ",
"                        ",
"<73 ENGINE FUEL CONTROL ",
"                        ",
"                        ",
"                        ",
"                        ",
"------------------------",
"<RETURN            HELP>"
    }
  
  end
end

fmsPages["GRDTEST"].getNumPages=function(self)
  return 6
end
