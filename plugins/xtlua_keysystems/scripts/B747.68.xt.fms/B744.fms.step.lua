local step = {}

function step.trim(value)
  value=tostring(value or "")
  value=string.gsub(value,"^%s+","")
  value=string.gsub(value,"%s+$","")
  return value
end

function step.fixed_width(value,width)
  value=tostring(value or "")
  width=math.max(0,math.floor(tonumber(width) or 0))
  if string.len(value)>width then
    value=string.sub(value,1,width)
  end
  return value..string.rep(" ",width-string.len(value))
end

function step.altitude_token(entry)
  entry=string.upper(step.trim(entry))
  if string.len(entry)<2 or string.sub(entry,-1)~="S" then return nil end

  local altitude=string.sub(entry,1,-2)
  if string.sub(altitude,1,1)=="/" then
    altitude=string.sub(altitude,2)
  end
  if altitude=="" then return nil end
  return altitude
end

function step.altitude_feet(value)
  value=string.upper(step.trim(value))
  local altitude=nil
  if string.match(value,"^FL%d+$")~=nil then
    altitude=tonumber(string.sub(value,3))*100
  elseif string.match(value,"^%d+$")~=nil then
    altitude=tonumber(value)
    if altitude~=nil and altitude<1000 then altitude=altitude*100 end
  end
  return altitude
end

local function route_waypoint(flight_plan,index)
  if type(flight_plan)~="table" or type(flight_plan[index])~="table" then
    return ""
  end
  return step.trim(flight_plan[index][8])
end

function step.current_route_index(flight_plan)
  if type(flight_plan)~="table" then return nil end
  for index=1,#flight_plan,1 do
    if type(flight_plan[index])=="table" and flight_plan[index][10]==true then
      return index
    end
  end
  return nil
end

function step.resolve_route_index(entry,flight_plan,minimum_index)
  if type(entry)~="table" or type(flight_plan)~="table" then return nil end
  local waypoint=step.trim(entry.waypoint)
  if waypoint=="" then return nil end

  local stored_index=math.floor(tonumber(entry.routeIndex) or 0)
  if stored_index>0 and route_waypoint(flight_plan,stored_index)==waypoint then
    return stored_index
  end

  local first_index=math.max(1,math.floor(tonumber(minimum_index) or 1))
  for index=first_index,#flight_plan,1 do
    if route_waypoint(flight_plan,index)==waypoint then return index end
  end
  if first_index>1 then
    for index=1,first_index-1,1 do
      if route_waypoint(flight_plan,index)==waypoint then return index end
    end
  end
  return nil
end

function step.normalize_list(entries)
  local normalized={}
  if type(entries)~="table" then return normalized end

  for index=1,#entries,1 do
    local entry=entries[index]
    if type(entry)=="table" then
      local waypoint=step.trim(entry.waypoint)
      local altitude=string.upper(step.trim(entry.altitude))
      local altitude_feet=step.altitude_feet(altitude)
      if waypoint~="" and altitude_feet~=nil then
        normalized[#normalized+1]={
          waypoint=waypoint,
          altitude=string.format("FL%03d",altitude_feet/100),
          routeIndex=math.max(0,math.floor(tonumber(entry.routeIndex) or 0))
        }
      end
    end
  end
  return normalized
end

function step.lists_equal(left_entries,right_entries,flight_plan)
  local left=step.sorted(left_entries,flight_plan)
  local right=step.sorted(right_entries,flight_plan)
  if #left~=#right then return false end

  for index=1,#left,1 do
    local left_route_index=step.resolve_route_index(left[index],flight_plan)
      or math.floor(tonumber(left[index].routeIndex) or 0)
    local right_route_index=step.resolve_route_index(right[index],flight_plan)
      or math.floor(tonumber(right[index].routeIndex) or 0)
    if left[index].waypoint~=right[index].waypoint
      or left[index].altitude~=right[index].altitude
      or left_route_index~=right_route_index then
      return false
    end
  end
  return true
end

function step.find(entries,waypoint,route_index)
  waypoint=step.trim(waypoint)
  route_index=math.floor(tonumber(route_index) or 0)
  if type(entries)~="table" then return nil,nil end

  for index=1,#entries,1 do
    local entry=entries[index]
    if type(entry)=="table" and step.trim(entry.waypoint)==waypoint then
      local entry_route_index=math.floor(tonumber(entry.routeIndex) or 0)
      if route_index==0 or entry_route_index==0 or entry_route_index==route_index then
        return entry,index
      end
    end
  end
  return nil,nil
end

function step.upsert(entries,waypoint,altitude,route_index)
  local updated=step.normalize_list(entries)
  waypoint=step.trim(waypoint)
  local altitude_feet=step.altitude_feet(altitude)
  route_index=math.max(0,math.floor(tonumber(route_index) or 0))
  if waypoint=="" or altitude_feet==nil then return updated end

  local replacement={
    waypoint=waypoint,
    altitude=string.format("FL%03d",altitude_feet/100),
    routeIndex=route_index
  }
  local _,existing_index=step.find(updated,waypoint,route_index)
  if existing_index~=nil then
    updated[existing_index]=replacement
  else
    updated[#updated+1]=replacement
  end
  return updated
end

function step.remove(entries,waypoint,route_index)
  local updated={}
  local normalized=step.normalize_list(entries)
  waypoint=step.trim(waypoint)
  route_index=math.floor(tonumber(route_index) or 0)

  for index=1,#normalized,1 do
    local entry=normalized[index]
    local same_waypoint=entry.waypoint==waypoint
    local entry_route_index=math.floor(tonumber(entry.routeIndex) or 0)
    local same_route=route_index==0 or entry_route_index==0 or entry_route_index==route_index
    if not (same_waypoint and same_route) then
      updated[#updated+1]=entry
    end
  end
  return updated
end

function step.sorted(entries,flight_plan)
  local sorted=step.normalize_list(entries)
  table.sort(sorted,function(left,right)
    local left_index=step.resolve_route_index(left,flight_plan) or math.huge
    local right_index=step.resolve_route_index(right,flight_plan) or math.huge
    if left_index==right_index then return left.waypoint<right.waypoint end
    return left_index<right_index
  end)
  return sorted
end

function step.entry_at_index(entries,flight_plan,route_index)
  route_index=math.floor(tonumber(route_index) or 0)
  if route_index<=0 then return nil end
  local sorted=step.sorted(entries,flight_plan)
  for index=1,#sorted,1 do
    if step.resolve_route_index(sorted[index],flight_plan)==route_index then
      return sorted[index]
    end
  end
  return nil
end

function step.planned_altitude_for_index(entries,flight_plan,route_index,base_altitude)
  route_index=math.floor(tonumber(route_index) or 0)
  local planned_altitude=tonumber(base_altitude)
  if planned_altitude==nil or route_index<=0 then return planned_altitude end

  local sorted=step.sorted(entries,flight_plan)
  for index=1,#sorted,1 do
    local entry_route_index=step.resolve_route_index(sorted[index],flight_plan)
    local entry_altitude=step.altitude_feet(sorted[index].altitude)
    if entry_route_index~=nil and entry_route_index<=route_index and entry_altitude~=nil then
      planned_altitude=entry_altitude
    end
  end
  return planned_altitude
end

function step.valid_climb_sequence(entries,flight_plan,base_altitude,minimum_index)
  local previous_altitude=tonumber(base_altitude)
  if previous_altitude==nil then return false end
  minimum_index=math.max(1,math.floor(tonumber(minimum_index) or 1))

  local sorted=step.sorted(entries,flight_plan)
  for index=1,#sorted,1 do
    local route_index=step.resolve_route_index(sorted[index],flight_plan)
    if route_index==nil or route_index>=minimum_index then
      local altitude=step.altitude_feet(sorted[index].altitude)
      if altitude==nil or altitude<=previous_altitude then return false end
      previous_altitude=altitude
    end
  end
  return true
end

function step.next_entry(entries,flight_plan,current_index,current_altitude)
  current_index=math.max(1,math.floor(tonumber(current_index) or 1))
  current_altitude=tonumber(current_altitude) or 0

  local sorted=step.sorted(entries,flight_plan)
  for index=1,#sorted,1 do
    local entry=sorted[index]
    local entry_route_index=step.resolve_route_index(entry,flight_plan,current_index)
    local entry_altitude=step.altitude_feet(entry.altitude)
    if entry_route_index~=nil and entry_route_index>=current_index
      and entry_altitude~=nil and entry_altitude>current_altitude+50 then
      return entry,entry_route_index
    end
  end
  return nil,nil
end

return step
