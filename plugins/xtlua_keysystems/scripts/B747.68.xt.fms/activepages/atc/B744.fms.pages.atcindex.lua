fmsPages["ATCINDEX"]=createPage("ATCINDEX")
fmsPages["ATCINDEX"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
    return{

"       ATC INDEX        ",
"                        ",	               
"<EMERGENCY   POS REPORT>",
"                        ",
"<REQUEST    WHEN CAN WE>",
"                        ",
"<REPORT                 ",
"                        ",
"<LOG          CLEARANCE>",
"                        ",
"<LOGON/STATUS     VOICE>",
"------------------------",
-- (2026-11-24, the 2026-11-23 review's CDU-12) 6L PRINT FAIL: PRINT LOG
-- and the ATC pages' PRINT show the printer's states alike (FMSPG p.366
-- (8-97), 8.9.2; FCOM p.727, p.761), and the sim has no printer: the
-- table's PRINT FAIL (the FMC has found the printer failed), as on the
-- uplink's, request's, report's and emergency's last pages (estimate; the
-- table has no blank state). From 2026-11-20 (GAP N19-ATC-05) blank, before
-- that <PRINT LOG with no function
"PRINT FAIL              "
    }
end


 
fmsFunctionsDefs["ATCINDEX"]={}
fmsFunctionsDefs["ATCINDEX"]["L1"]={"setpage","ATCEMERGENCYREPORT"}
fmsFunctionsDefs["ATCINDEX"]["L2"]={"setpage","ATCREQUEST"}
fmsFunctionsDefs["ATCINDEX"]["L3"]={"setpage","ATCREPORT"}
fmsFunctionsDefs["ATCINDEX"]["L4"]={"setpage","ATCLOG"}  -- (6-1/6-2 step 12g1: before, the ACARS log)
fmsFunctionsDefs["ATCINDEX"]["L5"]={"setpage","ATCLOGONSTATUS"} 
fmsFunctionsDefs["ATCINDEX"]["R1"]={"setpage","POSREPORT"}
fmsFunctionsDefs["ATCINDEX"]["R2"]={"setpage","WHENCANWE"}
-- (6-1/6-2 step 12g2a) the clearance and voice requests' VERIFY REQUEST
-- (FMSPG p.298-300; before, the ATC REQUEST pages' text)
fmsFunctionsDefs["ATCINDEX"]["R4"]={"atcindexreq","CLEARANCE"}
fmsFunctionsDefs["ATCINDEX"]["R5"]={"atcindexreq","VOICE"}
--[[
fmsFunctionsDefs["ATCINDEX"]["L1"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["L2"]={"setpage",""}

fmsFunctionsDefs["ATCINDEX"]["R4"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["L5"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["L6"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["R1"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["R2"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["R3"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["R4"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["R5"]={"setpage",""}
fmsFunctionsDefs["ATCINDEX"]["R6"]={"setpage",""}
]]

