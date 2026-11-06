--[[
*****************************************************************************************
*        COPYRIGHT � 2020 Mark Parker/mSparks CC-BY-NC4
*****************************************************************************************
]]
local clock = os.clock
function sleep(n)
  local t0 = clock()
  while clock() - t0 <= n do end
end
netRequestDataref=find_dataref("autoatc/networking/url")
netdataDataref=find_dataref("autoatc/networking/data")
netstatusDataref=find_dataref("autoatc/networking/urlstatus")

function fmsFunctions.initAcars(fmsO,value)
  local currentInit=getFMSData("acarsInitString")
  local initData={}
  initData["reg"]=getFMSData("fltno")
  if initData["reg"]=="*******" then fmsO["notify"]="FLT NO NOT SET" return end
  initData["dep"]=getFMSData("fltdep")
  if initData["dep"]=="****" then fmsO["notify"]="DEPARTURE NOT SET" return end
  initData["dst"]=getFMSData("fltdst")
  if initData["dst"]=="****" then fmsO["notify"]="DESTINATION NOT SET" return end
  initData["crzalt"]=getFMSData("crzalt")
  initData["pln"]=fmsJSON
  local newInit=json.encode(initData)
  if currentInit~= newInit then
    fmsModules["data"]["acarsInitString"]=newInit
    initData["type"]="initData"
    initData["af"]="B744"
    local newInitSend=json.encode(initData)
    print(newInitSend)
    fmsFunctions.acarsSystemSend(fmsO,newInitSend)
  end
  fmsO["pgNo"]=1
  fmsO["targetCustomFMC"]=true
  fmsO["targetPage"]="PREFLIGHT"
  fmsFunctions["acarsLogonATC"](fmsO,fmsModules.data["fltdep"])--auto login
  run_after_time(switchCustomMode, 0.5)
end
function fmsFunctions.acarsDataReady(fmsO)
  if getFMSData("fltno")=="--------" then fmsO["notify"]="FLT NO NOT SET" return false end
  if getFMSData("fltdep")=="****" then fmsO["notify"]="DEPARTURE NOT SET" return false end
  if getFMSData("fltdst")=="****" then fmsO["notify"]="DESTINATION NOT SET" return false end
  return true
end
-- (6-1/6-2 step 12e) a logon through the ATC logon (B747_fms_atc_logon_to:
-- LOGON/STATUS's state, the FMC's messages); a facility of four letters, else
-- a logoff. Before, the request went at once, needing the departure and
-- the destination (DEPARTURE and DESTINATION NOT SET, not Boeing's)
function fmsFunctions.acarsLogonATC(fmsO,value)
  B747_fms_atc_logon_to(fmsO,str_trim(value or ""))
end


function fmsFunctions.acarsSendATCMessage(fmsO,message,requresResponse)
  if not(fmsFunctions.acarsDataReady(fmsO)) then return end
  local atcLogon={}
  if fmsModules["data"]["atc"]=="****" then return end
	atcLogon["type"]="cpdlc"
  atcLogon["msg"]=message
  atcLogon["RR"]=requresResponse
  local newInitSend=json.encode(atcLogon)
  fmsFunctions.acarsSystemSendATC(fmsO,newInitSend)
end


function fmsFunctions.acarsRespondATC(fmsO,value) --value=message being replied to, if, message starts WILCO = accepted, UNABLE = rejected, other=RESPONDED
  if not(fmsFunctions.acarsDataReady(fmsO)) then return end
  local atcLogon={}
  print("inacarsRespondATC "..value)
  if fmsModules["data"]["atc"]=="****" then fmsO["notify"]="NO LOGON" return end
  if string.len(fmsO["scratchpad"])>0 then
    local msg=acarsSystem.messages[value]
    
    local replyingTo=json.encode(msg)
    print("inacarsRespondATC msg"..replyingTo)
    atcLogon["type"]="cpdlc"
    atcLogon["msg"]=fmsO["scratchpad"]
    atcLogon["RR"]="N"
    atcLogon["status"]="SENDING"
    atcLogon["RT"]=msg["srcID"]
    local newInitSend=json.encode(atcLogon)
    print("newInitSend "..newInitSend)
    fmsFunctions.acarsSystemSendATC(fmsO,newInitSend)
    acarsSystem.messages[value]["REPLIED"]=true
    fmsO["scratchpad"] = ""
  else
    fmsO["notify"]="NO MESSAGE"
  end
end

-- an information request (the WEATHER page's METAR and TAF) for the
-- airport `to` (2026-11-05 review 4: before, always the ATC logon's
-- facility)
function fmsFunctions.acarsATCRequest(fmsO,value,to)
  local atcReq={}
	atcReq["type"]="inforeq"
  atcReq["msg"]=value
  atcReq["to"]=to
  local newInitSend=json.encode(atcReq)
  fmsFunctions.acarsSystemSendATC(fmsO,newInitSend)
end
fmsPages["ACARSMSGS"]=createPage("ACARSMSGS")
fmsPages["ACARSMSGS"]["template"]={

"    ACARS-MSGS MENU     ",
"                        ",
"<FLT DSPTCH        MISC>",
"                        ",
"<UPLINK           DNLNK>",
"                        ",
"<PRINT UNDELIVERED MSGS ",
"                        ",
"                        ",
"                        ",
"                        ", 
"                        ",
"<RETURN                 "
}
fmsPages["ACARSMSGS"]["templateSmall"]={
"                        ",
"--------SEND MSG--------",
"                        ",
"-------STORED MSG-------",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ", 
"                        ",
"                        "
}
fmsFunctionsDefs["ACARSMSGS"]["L2"]={"setpage","VIEWUPACARS"}
fmsFunctionsDefs["ACARSMSGS"]["L6"]={"setpage","ACARS"} --go to last page or acars
fmsFunctionsDefs["ACARSMSGS"]["R1"]={"setpage","VIEWMISCACARS"}
fmsFunctionsDefs["ACARSMSGS"]["R2"]={"setpage","VIEWDOWNACARS"}

fmsFunctionsDefs["ACARSMSGS"]["L6"]={"setpage","ACARS"}

fmsPages["VIEWMISCACARS"]=createPage("VIEWMISCACARS")

acarsSystem={}
acarsSystem.messages={}
-- (2026-11-06 review) a message's field read safely, as the log page's fld
-- below. A message in acarsSystem.messages is XTLua's namespace table, and
-- reading a field it lacks overflowed the stack in the draw, leaving the
-- page blank: for example a provider's telex without a title, or an uplink
-- without rr.
function acars_msg_field(m, k)
  if type(m) ~= "table" then return nil end
  local v = rawget(m, "values")
  if type(v) == "table" then return v[k] end
  return rawget(m, k)
end
acarsSystem.messageSendQueue={}
acarsSystem.sentMessage=0
--print("have this many "..table.getn(acarsSystem.messages.values).." acars messages")
dofile("acars/autoatcProvider.lua")
dofile("acars/autoatcHoppieProvider.lua")
function fmsFunctions.acarsSystemSend(fmsO,value)
  if acarsSystem.provider.online() then
    local msgToSend=value
    local tMSG={}
    if string.len(msgToSend) <5 then 
      tMSG["adr"]=getFMSData("acarsAddress")
       if tMSG["adr"]=="*******" then fmsO["notify"]="EMPTY ADDRESS" return end
      msgToSend=fmsO["scratchpad"]
      tMSG["type"]="cpdlc"
      tMSG["msg"]=msgToSend
      fmsO["scratchpad"]=""
    else
      tMSG=json.decode(value)
    end
    if string.len(msgToSend) <5 then fmsO["notify"]="EMPTY MESSAGE" return end
    
    
    acarsSystem.provider.sendCompany(json.encode(tMSG),fmsO)
    fmsO["targetCustomFMC"]=true
    run_after_time(switchCustomMode, 0.5)
    --fmsO["currentPage"]="ACARS" 
    --local tMSG=json.encode({type="msg",msg="Test Message",time="12:00 UTC"})
    --print(tMSG)
    --local rMSG=json.decode(tMSG)
    --print(rMSG["msg"])
  else
    fmsO["notify"]="ACARS NO COMM"
  end
  --print("setpage" .. value)
end
function fmsFunctions.acarsSystemSendATC(fmsO,value)

  if acarsSystem.provider.online() then
    local msgToSend=value
    local tMSG={}
    if string.len(msgToSend) <5 then 
      tMSG["to"]=getFMSData("acarsAddress")
      if tMSG["to"]=="*******" then fmsO["notify"]="EMPTY ADDRESS" return end
      msgToSend=fmsO["scratchpad"] 
      tMSG["type"]="cpdlc"
      tMSG["msg"]=msgToSend
      fmsO["scratchpad"]=""
    else
      tMSG=json.decode(value)
    end
    if string.len(msgToSend) <5 then fmsO["notify"]="EMPTY MESSAGE" return end
    print("sendATC "..value)
    acarsSystem.provider.sendATC(json.encode(tMSG))
    --fmsO["targetCustomFMC"]=true
    --run_after_time(switchCustomMode, 0.5)
    --fmsO["currentPage"]="ACARS" 
    --local tMSG=json.encode({type="msg",msg="Test Message",time="12:00 UTC"})
    --print(tMSG)
    --local rMSG=json.decode(tMSG)
    --print(rMSG["msg"])
  else
    fmsO["notify"]="ACARS NO COMM"
  end
  --print("setpage" .. value)
end


acarsSystem.getMiscMessages=function(pgNo)
    

     
    retVal={}
    retVal.template={
      "   ACARS-MISC MSGS      ",
      "                        ",
      "                        ", -- --"<Test Message           ",
      "                        ",
      "                        ", -- --"<2nd Test Message       ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      " ADDRESS                ",
      "<"..fmsModules["data"]["acarsAddress"] .."           SEND>",
      "                        ",
      "<RETURN                 "
      } 
      numPages=math.ceil(table.getn(acarsSystem.messages.values)/4)
      if numPages<1 then numPages=1 end
    retVal.templateSmall={
      "                     "..pgNo.."/"..numPages.." ",
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
      "                        ",
      "                        "
      }
    line = 3
    startNo=table.getn(acarsSystem.messages.values)
    
    if pgNo>1 then startNo=table.getn(acarsSystem.messages.values)-((pgNo-1)*4) end
    endNo=startNo-3
    if endNo <1 then endNo=1 end
    for i = startNo,endNo , -1 do
      retVal.template[line]="<"..(acars_msg_field(acarsSystem.messages[i],"title") or "")
      retVal.templateSmall[line+1]="            "..(acars_msg_field(acarsSystem.messages[i],"time") or "")
      fmsFunctionsDefs["VIEWMISCACARS"]["L"..(startNo-i+1)]={"showmessage",i}
      line = line+2
      
    end  
    return retVal
end

fmsPages["VIEWUPACARS"]=createPage("VIEWUPACARS")
-- (2026-11-05 review 4) L1-L4: the message on that line of the pressing
-- CDU's page (fmsFunctions.showupmsg); before, bound to messages at each
-- draw: a shorter last page, or the other CDU on another page, left the
-- bindings of another page (its empty lines opened other messages)
for k = 1, 4 do fmsFunctionsDefs["VIEWUPACARS"]["L"..k]={"showupmsg",k} end


acarsSystem.getUpMessages=function(pgNo)
    retVal={}
    retVal.template={
      "  ACARS-UPLINK MSG      ",
      "                        ",
      "                        ", -- --"<Test Message           ",
      "                        ",
      "                        ", -- --"<2nd Test Message       ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "<RETURN                 "
      } 
      numPages=math.ceil(table.getn(acarsSystem.messages.values)/4)
      if numPages<1 then numPages=1 end
    retVal.templateSmall={
      "                    "..pgNo.."/"..numPages.."  ",
      " MSG TITLE          STAT",
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
      "                        "
      }
    line = 3
    startNo=table.getn(acarsSystem.messages.values)
    
    if pgNo>1 then startNo=table.getn(acarsSystem.messages.values)-((pgNo-1)*4) end
    endNo=startNo-3
    --print("startNo "..startNo.." endNo "..endNo)
    if endNo <1 then endNo=1 end
    for i = startNo,endNo , -1 do
      local m=acarsSystem.messages[i]
      local ln="<"..(acars_msg_field(m,"title") or "")
      --local msg=acarsSystem.messages[i]
      --local encodedMSG=json.encode(msg)
      --print("rendering "..encodedMSG)
      local padding=21-string.len(ln)
      if padding<0 then padding=0 end
     --[[ if acarsSystem.messages[i]["rr"]~=nil and acarsSystem.messages[i]["rr"]=="N" then
        local padding=10-string.len(ln)
        if padding<0 then padding=0 end
        if not acarsSystem.messages[i]["REPLIED"] then
          retVal.template[line]=string.sub(ln,1,10) .. string.format("%"..padding.."s","").." REPLY REQUIRED"
        else
          retVal.template[line]=string.sub(ln,1,10) .. string.format("%"..padding.."s","").."     REPLY SENT"
        end
      else]]--

        if acars_msg_field(m,"rr")~="N" and not acars_msg_field(m,"REPLIED") then
          retVal.template[line]=string.sub(ln,1,21) .. string.format("%"..padding.."s","").."  RR"
        elseif not acars_msg_field(m,"read") then
          retVal.template[line]=string.sub(ln,1,21) .. string.format("%"..padding.."s","").." NEW"
        else
          retVal.template[line]=string.sub(ln,1,21) .. string.format("%"..padding.."s","").." OLD"
        end
      --end
      retVal.templateSmall[line+1]="            "..(acars_msg_field(m,"time") or "")
      line = line+2
      
    end  
    return retVal
end

fmsPages["VIEWDOWNACARS"]=createPage("VIEWDOWNACARS")

acarsSystem.getDownMessages=function(pgNo)
  retVal={}
  retVal.template={
    "  ACARS-DOWNLINK MSG    ",
    "                        ",
    "                        ", -- --"<Test Message           ",
    "                        ",
    "                        ", -- --"<2nd Test Message       ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "<RETURN                 "
    } 
    numPages=math.ceil(table.getn(acarsSystem.messageSendQueue.values)/4)
    if numPages<1 then numPages=1 end
  retVal.templateSmall={
    "                    "..pgNo.."/"..numPages.."  ",
    " MSG TITLE          STAT",
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
    "                        "
    }
  line = 3
  startNo=table.getn(acarsSystem.messageSendQueue.values)
  
  if pgNo>1 then startNo=table.getn(acarsSystem.messageSendQueue.values)-((pgNo-1)*4) end
  endNo=startNo-3
  --print("startNo "..startNo.." endNo "..endNo)
  if endNo <1 then endNo=1 end
  local sMessage={}
  for i = startNo,endNo , -1 do
    --print(i.."="..acarsSystem.messageSendQueue[i])
    sMessage=json.decode(acarsSystem.messageSendQueue[i])
    local ln=""
    local status="        "
    if sMessage["status"]~=nil then status=sMessage["status"] end
    retVal.templateSmall[line]=" "..sMessage["time"].."z     "..status --RESPONSE RCVD"
    if sMessage["type"]=="cpdlc" then
      ln=sMessage["msg"].." ("..sMessage["to"] ..")"
    elseif sMessage["type"]=="initData" then
      ln="REQUEST "..sMessage["dep"].."-"..sMessage["dst"]
    elseif sMessage["type"]=="inforeq" then
      ln=sMessage["msg"].." ("..sMessage["to"] ..")"
    end
    local padding=24-string.len(ln)
    if padding<0 then padding=0 end
    retVal.template[line+1]=string.sub(ln,1,24) .. string.format("%"..padding.."s","")
    line = line+2
    
  end  
  return retVal
end

fmsPages["VIEWACARSLOG"]=createPage("VIEWACARSLOG")
acarsSystem.getLogMessages=function(pgNo)
  local onRecieved=table.getn(acarsSystem.messages.values)
  local onSent=table.getn(acarsSystem.messageSendQueue.values)
  
  local retVal={}
  local sMessage={}
  --print("getLogMessages")
  local currentPage=1
  while currentPage <= pgNo do
    retVal={}
    local rmID=1
    while (onRecieved>0 or onSent>0) and rmID<6 do
      local rID=0
      local sID=0
      --print("onRecieved "..onRecieved.." onSent "..onSent)
      
      if onRecieved>0 then
        rID=acarsSystem.messages[onRecieved]["messageID"]
      end
      if onSent>0 then
        sMessage=json.decode(acarsSystem.messageSendQueue[onSent])
        sID=sMessage["messageID"]
      end
      if sID==nil then print("got bad sID!!") end
      --print("rID "..rID.." sID "..sID.." "..acarsSystem.messageSendQueue[onSent])
      if rID>sID then
        retVal[rmID]=acarsSystem.messages[onRecieved]
        retVal[rmID]["ud"]="U"
        fmsFunctionsDefs["VIEWACARSLOG"]["R"..(rmID)]={"showmessage",onRecieved}
        --print("use received message".." rmID "..rmID.. " rID "..onRecieved)
        rmID=rmID+1
        onRecieved=onRecieved-1
      else
        if sMessage["msg"]~=nil then
          retVal[rmID]=sMessage
          retVal[rmID]["ud"]="D"
          rmID=rmID+1
          onSent=onSent-1
          --print("use sent message")
        else
          onSent=onSent-1
          --print("skip sent message")
        end
      end
    end
    currentPage=currentPage+1
  end
  return retVal
end

acarsSystem.getMessageLog=function(pgNo)
  
  retVal={}
  retVal.template={
    "        ATC LOG         ",
    "                        ",
    "                        ", -- --"<Test Message           ",
    "                        ",
    "                        ", -- --"<2nd Test Message       ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "------------------------",
    "<INDEX        ERASE LOG>"
    
    } 
    --numPages=math.ceil(table.getn(acarsSystem.messages.values)/5)+math.ceil(table.getn(acarsSystem.messageSendQueue.values)/5)
    numPages=math.ceil((table.getn(acarsSystem.messages.values)+table.getn(acarsSystem.messageSendQueue.values))/5)
    if numPages<1 then numPages=1 end
  retVal.templateSmall={
    "                    "..pgNo.."/"..numPages.."  ",
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
    "                        ",
    "                        "
    }

    local messageLog=acarsSystem.getLogMessages(pgNo)
    -- (6-1/6-2 step 12f) a message's fields read safely: a received one is
    -- XTLua's namespace table, which cannot read a missing key (an ATC
    -- uplink without "rr" blanked the page)
    local function fld(m, k)
      local v = rawget(m, "values")
      if type(v) == "table" then return v[k] end
      return rawget(m, k)
    end
    line = 2
    for i=1,table.getn(messageLog) do
      local mi=messageLog[i]
      local mtime=fld(mi,"time") or ""
      --print("M "..i.." "..messageLog[i]["ud"])
      local ln=""
      if fld(mi,"ud")=="U" then
        if fld(mi,"rr")~="N" then
          if not fld(mi,"REPLIED") then
            retVal.templateSmall[line]=" "..mtime.."z    REPLY REQUIRED"
          else
            retVal.templateSmall[line]=" "..mtime.."z        REPLY SENT"
          end
        else
          if not fld(mi,"read") then
            retVal.templateSmall[line]=" "..mtime.."z               NEW"
          else
            retVal.templateSmall[line]=" "..mtime.."z               OLD"
          end
        end
        ln="  "..(fld(mi,"title") or fld(mi,"msg") or "")
        
      else
        --messageLog[i]["status"]
        local status="             "
        if fld(mi,"status")~=nil then status=fld(mi,"status") end
        retVal.templateSmall[line]=" "..mtime.."z     "..status --RESPONSE RCVD"
        --print("T "..messageLog[i]["msg"])
        ln="  "..(fld(mi,"msg") or "")
      end
      retVal.templateSmall[line+1]=(fld(mi,"ud") or " ").."                       "
      ln=string.sub(ln,1,21)
      local padding=21-string.len(ln)
      if padding<=0 then 
        padding=0 
        ln=ln..".."
      else
        ln=ln.."  "
      end
      retVal.template[line+1]=ln .. string.format("%"..padding.."s","").." >"
      line = line+2
    end
    return retVal
end

dofile("acars/acars.pages.lua")
----

