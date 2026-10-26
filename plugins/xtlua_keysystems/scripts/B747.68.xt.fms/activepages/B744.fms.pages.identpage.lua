fmsPages["IDENT"]=createPage("IDENT")
--dofile("activepages/version.lua")

fmsPages["IDENT"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
	-- NAV DATA and ACTIVE from the FMC's navigation database (6-1/6-2 step 4;
	-- FCOM p.1283-1284): the AIRAC cycle (the data have no part number:
	-- estimate) and its dates; one database, no inactive line (estimate)
	local navId,active="          ","             "
	local cycle,first=B747_navdb.cycle_info(B747_fmc_navdb)
	if B747_fmc_navdb.ready and cycle and first then
		navId=string.format("%-10s","AIRAC "..cycle)
		active=B747_navdb.date_range(first)
	end
	local codata=string.gsub(fmsModules["data"].codata,"%s+$","")
    return{

 "       IDENT            ",
 "                        ",
 string.format("%-11s %12s",simConfigData["data"].PLANE.model,simConfigData["data"].PLANE.engines),
 "                        ",
 navId.." "..active,
 "                        ",
 string.format("%-24s",simConfigData["data"].FMC.INIT.drag_ff),
 "                        ",
 simConfigData["data"].FMC.INIT.op_program.."       ",
 "                        ",
 string.format("%24s",codata),
 "------------------------",
 "<INDEX         POS INIT>"
    }
end

fmsPages["IDENT"]["templateSmall"]={
"                        ",
" MODEL           ENGINES",
"                        ",
" NAV DATA         ACTIVE",
"                        ",
" DRAG/FF                ",
"                        ",
" OP PROGRAM             ",
"                        ",
"                 CO DATA",
"                        ",
"                        ",
"                        "
}


  
  
fmsFunctionsDefs["IDENT"]={}
fmsFunctionsDefs["IDENT"]={}
fmsFunctionsDefs["IDENT"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["IDENT"]["R5"]={"setdata","codata"}
fmsFunctionsDefs["IDENT"]["R6"]={"setpage","POSINIT"}

