local function trimLegWaypoint(value)
  return B747_fms_step.trim(value)
end

local function legWaypointFromLine(line)
  local left=string.sub(tostring(line or ""),1,12)
  local flightPlanText=tostring(fmsFlightPlan or "")
  if string.len(flightPlanText)>2 then
    local decoded,flightPlan=pcall(json.decode,flightPlanText)
    if decoded and type(flightPlan)=="table" then
      for i=1,table.getn(flightPlan),1 do
        local waypoint=trimLegWaypoint(flightPlan[i][8])
        if waypoint~="" and string.upper(waypoint)~="LATLON"
          and string.find(left,waypoint,1,true)~=nil then
          return waypoint
        end
      end
    end
  end

  local waypoint=string.match(left,"[%w][%w%./%-]*")
  return trimLegWaypoint(waypoint)
end

function B747_getLegStepWaypoint(fmsO,key)
  local row=tonumber(string.sub(tostring(key or ""),2))
  if row==nil or row<1 or row>5 then return "" end
  if B747DR_srcfms[fmsO.id]==nil then return "" end
  local sourceLine=row*2+1
  return legWaypointFromLine(cleanFMSLine(B747DR_srcfms[fmsO.id][sourceLine]))
end

local function renderLegStep(line)
  line=string.sub(tostring(line or "")..string.rep(" ",24),1,24)
  local waypoint=legWaypointFromLine(line)
  local programmedWaypoint=trimLegWaypoint(fmsModules["data"].stepatwpt)
  local stepTo=validStepAltitude(fmsModules["data"].stepto)
  if waypoint~="" and waypoint==programmedWaypoint and stepTo~=nil then
    return string.sub(line,1,18)..string.format("%6s",stepTo.."S")
  end
  return line
end

fmsPages["LEGS"]=createPage("LEGS")
fmsPages["LEGS"].getPage=function(self,pgNo,fmsID)
  local l1=cleanFMSLine(B747DR_srcfms[fmsID][1])
  local pageNo=tonumber(string.sub(l1,21,22))
  l1=" ACT RTE 1 LEGS    "..string.sub(l1,20,24)
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

  local page={
    l1,
    l2,
    renderLegStep(l3),
    cleanFMSLine(B747DR_srcfms[fmsID][4]),
    renderLegStep(l5),
    cleanFMSLine(B747DR_srcfms[fmsID][6]),
    renderLegStep(cleanFMSLine(B747DR_srcfms[fmsID][7])),
    cleanFMSLine(B747DR_srcfms[fmsID][8]),
    renderLegStep(cleanFMSLine(B747DR_srcfms[fmsID][9])),
    cleanFMSLine(B747DR_srcfms[fmsID][10]),
    renderLegStep(cleanFMSLine(B747DR_srcfms[fmsID][11])),
    cleanFMSLine(B747DR_srcfms[fmsID][12]),
    cleanFMSLine(B747DR_srcfms[fmsID][13]),
  }
  return page
end

fmsFunctionsDefs["LEGS"]["L1"]={"key2fmc","L1"}
fmsFunctionsDefs["LEGS"]["L2"]={"key2fmc","L2"}
fmsFunctionsDefs["LEGS"]["L3"]={"key2fmc","L3"}
fmsFunctionsDefs["LEGS"]["L4"]={"key2fmc","L4"}
fmsFunctionsDefs["LEGS"]["L5"]={"key2fmc","L5"}
fmsFunctionsDefs["LEGS"]["L6"]={"key2fmc","L6"}

fmsFunctionsDefs["LEGS"]["R2"]={"setlegstep","R2"}
fmsFunctionsDefs["LEGS"]["R3"]={"setlegstep","R3"}
fmsFunctionsDefs["LEGS"]["R4"]={"setlegstep","R4"}
fmsFunctionsDefs["LEGS"]["R5"]={"setlegstep","R5"}
fmsFunctionsDefs["LEGS"]["R6"]={"key2fmc","R6"}

fmsFunctionsDefs["LEGS"]["next"]={"key2fmc","next"}
fmsFunctionsDefs["LEGS"]["prev"]={"key2fmc","prev"}
fmsFunctionsDefs["LEGS"]["exec"]={"key2fmc","exec"}
