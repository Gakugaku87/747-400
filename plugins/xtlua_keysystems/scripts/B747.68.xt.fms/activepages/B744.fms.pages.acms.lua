fmsPages["ACMS"]=createPage("ACMS")
fmsPages["ACMS"].getPage=function(self,pgNo,fmsID)

  return {
            
"       ACMS INDEX       ",
"                        ",
"<REPORTS                ",
"                        ",
"<DOC DATA        STATUS>",
"                        ",
"<DATA DISPLAY  RT PRINT>",
"                        ",
"                        ",
"                        ",
"                        ", 
"------------------------",
"                  PRINT>"
    }
end    
fmsFunctionsDefs["ACMS"]["L1"]={"setpage","REPORTS"}
fmsFunctionsDefs["ACMS"]["L2"]={"setpage","DOCDATA"}
fmsFunctionsDefs["ACMS"]["L3"]={"setpage","DATDISP"}
-- (2026-11-20, GAP N19-CDU-01) no MAINT> at 1R: the ACMS is the DMU's
-- system on the CDU (ATA31 p.338, 31-35), its main menu (p.358-359:
-- REPORTS, REPROGRAMMING, QAR CONTROL, DATA DISPLAY, ACMS STATUS, HMV
-- TEST SCREENS) has no MAINT; before, 1R opened the FMC's MAINTENANCE
-- INDEX (INIT/REF INDEX's MAINT> on the ground: FCOM p.1239). The page's
-- other prompts are upstream's mock-up (an airline's own: ATA31 p.344)
      
fmsPages["REPORTS"]=createPage("REPORTS")
fmsPages["REPORTS"].getPage=function(self,pgNo,fmsID)
  if pgNo==1 then
      fmsFunctionsDefs["REPORTS"]["L6"]={"setpage","ACMS"}
  return {
            
"      ACMS REPORTS   1/2",
" RPT   STORED THIS FLT  ",
" 01 ENG CRUISE        00",
" 02 CRUSE PERF        00",
" 04 ENG TAKEOFF       00",
" 06 ENG GAS PT AD     00",
" 07 ENG MECH ADV      00",
" 09 ENG DIVERG        00",
" 11 ENG RUN UP        00",
" -----------------------",
"--:RPT LOG    TRIGGER:--", 
" RETURN TO              ",
"<ACMS INDEX       PRINT>"
    }
    
  elseif pgNo==2 then
      fmsFunctionsDefs["DOCDATA"]["L6"]={"setpage","ACMS"}
    return {
"      ACMS REPORTS   2/2",
" RPT   STORED THIS FLT  ",
" 13 APU MES/IDL       00",
" 14 APU SHTDWN        00",
" 15 LOAD              00",
" 19 ECS PERF          00",
" 20 AUTOLAND          00",
" 23 ECS EXCEED        00",
" 41 CREW PRF STAT     00",
" -----------------------",
"--:RPT LOG    TRIGGER:--", 
" RETURN TO              ",
"<ACMS INDEX       PRINT>"
    }
end
end
  
fmsPages["DOCDATA"]=createPage("DOCDATA")
fmsPages["DOCDATA"].getPage=function(self,pgNo,fmsID)
  if pgNo==1 then
      fmsFunctionsDefs["DOCDATA"]["L6"]={"setpage","ACMS"}
  return {
            
"   ACMS DOC DATA     1/2",
"                        ",
"EHRS.1 000111           ",
"                        ",
"EHRS.2 000111           ",
"                        ",
"EHRS.3 000111           ",
"                        ",
"EHRS.4 000111           ",
"                        ",
"ECYC.1 000042           ",
" RETURN TO              ",
"<ACMS INDEX       PRINT>"
    }
    
  elseif pgNo==2 then
      fmsFunctionsDefs["DOCDATA"]["L6"]={"setpage","ACMS"}
    return {
"   ACMS DOC DATA     2/2",
"                        ",
"ECYC.2 000535           ",
"                        ",
"ECYC.3 000513           ",
"                        ",
"ECYC.4 000522           ",
"                        ",
"                        ",
"                        ",
"                        ",
" RETURN TO              ",
"<ACMS INDEX       PRINT>"
    }
end
end
  
fmsPages["DATDISP"]=createPage("DATDISP")
fmsPages["DATDISP"].getPage=function(self,pgNo,fmsID)

  return {
            
"   ACMS DATA DISPLAY    ",
"                        ",
"<ALPHA CALLUPS          ",
"                        ",
"<DISCRETE INPUTS        ",
"                        ",
"<DITS DATA              ",
"                        ",
"                        ",
"                        ",
"                        ", 
"------------------------",
"<RETURN           PRINT>"
    }
end
      fmsFunctionsDefs["DATDISP"]["L1"]={"setpage","ALPHACALL"}
      fmsFunctionsDefs["DATDISP"]["L2"]={"setpage","DISCINP"}
      fmsFunctionsDefs["DATDISP"]["L3"]={"setpage","DITS"}
      fmsFunctionsDefs["DATDISP"]["L6"]={"setpage","ACMS"}
    
fmsPages["ALPHACALL"]=createPage("ALPHACALL")
fmsPages["ALPHACALL"].getPage=function(self,pgNo,fmsID)

  return {
            
"ACMS ALPHA CALLUP       ",
"                        ",
"----   SELECTED DATA    ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
" UNFROZEN NOT RECORDING ",
"<FREEZE    START RECORD>",
" RETURN TO              ",
"<DATA DISPLAY     PRINT>"
    }
end
fmsFunctionsDefs["ALPHACALL"]["L6"]={"setpage","ACMS"}

fmsPages["DISCINP"]=createPage("DISCINP")
fmsPages["DISCINP"].getPage=function(self,pgNo,fmsID)

  return {
            
"  ACMS DISCRETE INPUTS  ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
" RETURN TO              ",
"<DATA DISPLAY     PRINT>"
    }
end    
fmsFunctionsDefs["DISCINP"]["L6"]={"setpage","ACMS"}
        
fmsPages["DITS"]=createPage("DITS")
fmsPages["DITS"].getPage=function(self,pgNo,fmsID)
        
  return {
        
"     ACMS DITS DATA     ",
" PORT/LABEL/SDI         ",
"--/---/--               ",
"                        ",
" P:- SSM:-- SDI:--      ",
" 2        21             ",
"                        ",
"                        ",
"+.       NOT SCALED     ",
" UNFROZEN NOT RECORDING ",
"<FREEZE    START RECORD>",
" RETURN TO              ",
"<DATA DISPLAY     PRINT>"
    }
end
fmsFunctionsDefs["DITS"]["L6"]={"setpage","ACMS"}
