local function trimLegWaypoint(value)
  return B747_fms_step.trim(value)
end

local function decodeLegFlightPlan()
  local sources={tostring(fmsFlightPlan or ""),tostring(fmsJSON or "")}
  for index=1,#sources,1 do
    if string.len(sources[index])>2 then
      local decoded,flightPlan=pcall(json.decode,sources[index])
      if decoded and type(flightPlan)=="table" and #flightPlan>0 then
        return flightPlan
      end
    end
  end
  return {}
end

local function routeWaypoint(flightPlan,index)
  if type(flightPlan)~="table" or type(flightPlan[index])~="table" then
    return ""
  end
  return trimLegWaypoint(flightPlan[index][8])
end

local function routeIndexForLegRow(fmsID,row,line,flightPlan)
  local currentIndex=B747_fms_step.current_route_index(flightPlan) or 1
  local pageLine=cleanFMSLine(B747DR_srcfms[fmsID][1])
  local pageNumber=B747_fms_step.page_number(pageLine)
  return B747_fms_step.resolve_leg_row(
    flightPlan,currentIndex,pageNumber,row,line)
end

function B747_getLegStepWaypoint(fmsO,key)
  local row=tonumber(string.sub(tostring(key or ""),2))
  if row==nil or row<1 or row>5 then return "" end
  if B747DR_srcfms[fmsO.id]==nil then return "" end
  local sourceLine=row*2+1
  local line=cleanFMSLine(B747DR_srcfms[fmsO.id][sourceLine])
  local flightPlan=decodeLegFlightPlan()
  local waypoint,routeIndex=routeIndexForLegRow(fmsO.id,row,line,flightPlan)
  return waypoint,routeIndex,flightPlan
end

local function renderLegStep(line,routeIndex,flightPlan,plannedSteps)
  line=string.sub(tostring(line or "")..string.rep(" ",24),1,24)
  local waypoint=routeWaypoint(flightPlan,routeIndex)
  if waypoint=="" or routeIndex==nil then return line end

  local entry=B747_fms_step.entry_at_index(plannedSteps,flightPlan,routeIndex)
  if entry~=nil then
    return string.sub(line,1,18)..string.format("%6s",entry.altitude.."S")
  end

  -- The route JSON does not distinguish a predicted cruise altitude from a
  -- hard constraint at that same altitude. Preserve native fields (including
  -- A/B and window constraints) until the native trajectory is updated too.
  -- Only a waypoint explicitly edited as a planned step gets the S overlay.
  return line
end

fmsPages["LEGS"]=createPage("LEGS")
fmsPages["LEGS"].getPage=function(self,pgNo,fmsID)
  local l1=cleanFMSLine(B747DR_srcfms[fmsID][1])
  local pageNo=B747_fms_step.page_number(l1)
  local plannedStepModification=B747_hasPlannedStepModification()
  if plannedStepModification then
    l1=string.gsub(l1,"ACT","MOD",1)
    if string.find(l1,"MOD",1,true)==nil then
      l1=" MOD RTE 1 LEGS    "..string.sub(l1,20,24)
    end
  end
  local l2="                        "
  local l3=cleanFMSLine(B747DR_srcfms[fmsID][3])
  local l5=cleanFMSLine(B747DR_srcfms[fmsID][5])
  -- The active waypoint occupies R1 on LEGS page 1.  Keep the native line
  -- formatting there, but still route its altitude field through the step
  -- handler so entries such as 330S are stored and reflected on VNAV CRZ.
  fmsFunctionsDefs["LEGS"]["R1"]={"setlegstep","R1"}
  if (pageNo~=nil and pageNo~=1) or string.starts(l5,"***") then
    l2=cleanFMSLine(B747DR_srcfms[fmsID][2])
    l3=cleanFMSLine(B747DR_srcfms[fmsID][3])
  end
  local flightPlan=decodeLegFlightPlan()
  local _,routeIndex1=routeIndexForLegRow(fmsID,1,l3,flightPlan)
  local _,routeIndex2=routeIndexForLegRow(fmsID,2,l5,flightPlan)
  local l7=cleanFMSLine(B747DR_srcfms[fmsID][7])
  local l9=cleanFMSLine(B747DR_srcfms[fmsID][9])
  local l11=cleanFMSLine(B747DR_srcfms[fmsID][11])
  local _,routeIndex3=routeIndexForLegRow(fmsID,3,l7,flightPlan)
  local _,routeIndex4=routeIndexForLegRow(fmsID,4,l9,flightPlan)
  local _,routeIndex5=routeIndexForLegRow(fmsID,5,l11,flightPlan)
  local plannedSteps=B747_getDisplayedPlannedSteps()
  local l13=cleanFMSLine(B747DR_srcfms[fmsID][13])
  if plannedStepModification then
    l13=string.format("%-12s%s","<ERASE",string.sub(l13,13,24))
  end

  local page={
    l1,
    l2,
    renderLegStep(l3,routeIndex1,flightPlan,plannedSteps),
    cleanFMSLine(B747DR_srcfms[fmsID][4]),
    renderLegStep(l5,routeIndex2,flightPlan,plannedSteps),
    cleanFMSLine(B747DR_srcfms[fmsID][6]),
    renderLegStep(l7,routeIndex3,flightPlan,plannedSteps),
    cleanFMSLine(B747DR_srcfms[fmsID][8]),
    renderLegStep(l9,routeIndex4,flightPlan,plannedSteps),
    cleanFMSLine(B747DR_srcfms[fmsID][10]),
    renderLegStep(l11,routeIndex5,flightPlan,plannedSteps),
    cleanFMSLine(B747DR_srcfms[fmsID][12]),
    l13,
  }
  return page
end

fmsFunctionsDefs["LEGS"]["L1"]={"key2fmc","L1"}
fmsFunctionsDefs["LEGS"]["L2"]={"key2fmc","L2"}
fmsFunctionsDefs["LEGS"]["L3"]={"key2fmc","L3"}
fmsFunctionsDefs["LEGS"]["L4"]={"key2fmc","L4"}
fmsFunctionsDefs["LEGS"]["L5"]={"key2fmc","L5"}
fmsFunctionsDefs["LEGS"]["L6"]={"eraselegstepmod","L6"}

fmsFunctionsDefs["LEGS"]["R2"]={"setlegstep","R2"}
fmsFunctionsDefs["LEGS"]["R3"]={"setlegstep","R3"}
fmsFunctionsDefs["LEGS"]["R4"]={"setlegstep","R4"}
fmsFunctionsDefs["LEGS"]["R5"]={"setlegstep","R5"}
fmsFunctionsDefs["LEGS"]["R6"]={"key2fmc","R6"}

fmsFunctionsDefs["LEGS"]["next"]={"key2fmc","next"}
fmsFunctionsDefs["LEGS"]["prev"]={"key2fmc","prev"}
fmsFunctionsDefs["LEGS"]["exec"]={"key2fmc","exec"}
