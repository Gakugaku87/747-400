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

return step
