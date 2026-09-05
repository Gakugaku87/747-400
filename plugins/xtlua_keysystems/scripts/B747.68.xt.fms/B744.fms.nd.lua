local M={}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

function M.selected_plan_waypoint(route,displayData)
  if type(route)~="table" or type(displayData)~="table" then return nil end
  local index=tonumber(displayData[1])
  if index==nil or index<1 or index~=math.floor(index) then return nil end
  local entry=route[index]
  if type(entry)~="table" then return nil end

  local waypoint=trim(entry[8])
  local normalized=string.lower(waypoint)
  if waypoint=="" or normalized=="latlon" or normalized=="latlong" then
    return "-----",index
  end
  return waypoint,index
end

function M.display_waypoint(activeWaypoint,route,displayData,mode)
  -- FCOM 10.10.65-68: PLAN changes the map centre, not the active waypoint
  -- information at the top. Its identifier, ETA and distance must all refer
  -- to the same active leg, independently of the CDU STEP selection.
  return activeWaypoint
end

return M
