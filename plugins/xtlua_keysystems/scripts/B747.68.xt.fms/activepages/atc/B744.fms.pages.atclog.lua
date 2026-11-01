-- ATC LOG (6-1/6-2 step 12g1; FCOM p.752-754; FMSPG p.357-362): the ATC
-- uplinks and the downlinks sent from here, newest first, five a page
-- (B747.68.atc_log_model.lua through B747_fms_atc_log_entries): the header
-- the time (HHMMZ) and the status, the data line the text's first
-- characters and a caret; the right key opens an uplink's page (a
-- downlink's: none yet, step 12g2 on), the left key with DELETE deletes
-- the entry; 6L <INDEX, 6R ERASE LOG> (blank without a non-pending entry)
-- and then CONFIRM> (erases every non-pending one; leaving the page undoes
-- ERASE LOG). Estimates: no up and down arrows (the CDU's font); the
-- uplink's place in the provider's list as its key. Before: the ACARS
-- log, company messages too
local G = B747_atc_log_model
local confirm = {}
local BLANK = "                        "
local function entries() return G.sorted(B747_fms_atc_log_entries()) end

fmsPages["ATCLOG"]=createPage("ATCLOG")
fmsPages["ATCLOG"].getNumPages=function(self,fmsID) return G.pages(entries()) end
fmsPages["ATCLOG"].getPage=function(self,pgNo,fmsID)
  local list = entries()
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  out[1] = "        ATC LOG         "
  for k, e in ipairs(G.page(list, pgNo)) do out[1 + 2 * k] = G.line(e) end
  local r = ""
  if G.erasable(list) then r = confirm[fmsID] and "CONFIRM>" or "ERASE LOG>" end
  out[13] = "<INDEX" .. string.format("%18s", r)
  return out
end
fmsPages["ATCLOG"].getSmallPage=function(self,pgNo,fmsID)
  local list = entries()
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  out[1] = string.format("%24s", pgNo .. "/" .. G.pages(list) .. " ")
  for k, e in ipairs(G.page(list, pgNo)) do out[2 * k] = G.header(e) end
  out[12] = "------------------------"
  return out
end
fmsPages["ATCLOG"].onLeave=function(self,fmsID) confirm[fmsID] = nil end

fmsFunctionsDefs["ATCLOG"]={}
for k = 1, 5 do
  fmsFunctionsDefs["ATCLOG"]["L" .. k]={"atclog","L" .. k}
  fmsFunctionsDefs["ATCLOG"]["R" .. k]={"atclog","R" .. k}
end
fmsFunctionsDefs["ATCLOG"]["L6"]={"setpage","ATCINDEX"}
fmsFunctionsDefs["ATCLOG"]["R6"]={"atclog","erase"}
function fmsFunctions.atclog(fmsO, value)
  local list = entries()
  if value == "erase" then
    if not G.erasable(list) then return end
    if confirm[fmsO.id] then
      B747_fms_atc_log_erase()
      confirm[fmsO.id] = nil
    else
      confirm[fmsO.id] = true
    end
    return
  end
  local side, k = string.sub(value, 1, 1), tonumber(string.sub(value, 2))
  local e = G.page(list, fmsO.pgNo or 1)[k]
  if not e then return end
  if side == "L" then
    if fmsO["scratchpad"] ~= "DELETE" then return end
    B747_fms_atc_log_delete(e)
    fmsO["scratchpad"] = ""
  elseif e.up then
    acarsSystem.setCurrentMessage(fmsO.id, e.i)
    fmsFunctions.setpage(fmsO, "ATCUPLINK")
  end
end
