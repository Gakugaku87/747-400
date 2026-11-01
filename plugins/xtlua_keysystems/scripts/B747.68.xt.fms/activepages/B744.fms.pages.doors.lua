
--THIS SCRIPT WAS MADE BY CRAZYTIMTIMTIM, with some help from mSparks43 and Marauder28

registerFMCCommand("sim/flight_controls/door_open_1","OPEN DOOR 1")
registerFMCCommand("sim/flight_controls/door_close_1","CLOSE DOOR 1")
registerFMCCommand("sim/flight_controls/door_open_2","OPEN DOOR 2")
registerFMCCommand("sim/flight_controls/door_close_2","CLOSE DOOR 2")
registerFMCCommand("sim/flight_controls/door_open_10","OPEN DOOR 10")
registerFMCCommand("sim/flight_controls/door_close_10","CLOSE DOOR 10")
registerFMCCommand("laminar/B747/door/mode_auto_all","ARM DOORS")
registerFMCCommand("laminar/B747/door/mode_manual_all","DISARM DOORS")

simDR_doors = find_dataref("sim/cockpit2/switches/door_open")
-- (7-3) the plug doors (entry L1, upper deck L) open on the ground only:
-- the cabin's pressure holds them shut and the upper deck door's flight
-- lock locks it in the air (FCOM p.529, p.534; ATA38_51_52_56 p.342).
-- Before, the page opened them in flight. The flight deck door any time
B747DR_doors_pseu_gnd = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
local DOORS_GND_ONLY = "OPEN ON GROUND ONLY     "
-- (7-3) the entry and upper deck doors' modes (the safety module: 1
-- AUTOMATIC, 0 MANUAL), all at once on L4: ARM and DISARM as the doors'
-- mode select levers read (FCOM p.473-474); the 3D has no levers
B747DR_doors_page_mode = find_dataref("laminar/B747/door/mode")
local function doors_modes()
  local n = 0
  for i = 0, 11 do
    if B747DR_doors_page_mode[i] > 0.5 then n = n + 1 end
  end
  return n
end

fmsPages["DOORS"]=createPage("DOORS")
fmsPages["DOORS"].getPage=function(self,pgNo,fmsID)
  if pgNo == 1 then

    local lineA = "<OPEN                    "
    local lineB = "<OPEN                    "
    local lineC = "<OPEN                    "
    local ground = B747DR_doors_pseu_gnd > 0.5
    if simDR_doors[1] > 0 then
      lineA = "<CLOSE                   "
      fmsFunctionsDefs["DOORS"]["L1"]={"doCMD","sim/flight_controls/door_close_2"}
    elseif ground then
      lineA = "<OPEN                    "
      fmsFunctionsDefs["DOORS"]["L1"]={"doCMD","sim/flight_controls/door_open_2"}
    else
      lineA = DOORS_GND_ONLY
      fmsFunctionsDefs["DOORS"]["L1"]=nil
    end

    if simDR_doors[0] > 0 then
      lineB = "<CLOSE                   "
      fmsFunctionsDefs["DOORS"]["L2"]={"doCMD","sim/flight_controls/door_close_1"}
    elseif ground then
      lineB = "<OPEN                    "
      fmsFunctionsDefs["DOORS"]["L2"]={"doCMD","sim/flight_controls/door_open_1"}
    else
      lineB = DOORS_GND_ONLY
      fmsFunctionsDefs["DOORS"]["L2"]=nil
    end
    if simDR_doors[9] > 0  then
      lineC = "<CLOSE                   "
      fmsFunctionsDefs["DOORS"]["L3"]={"doCMD","sim/flight_controls/door_close_10"}
      else
      lineC = "<OPEN                    "
      fmsFunctionsDefs["DOORS"]["L3"]={"doCMD","sim/flight_controls/door_open_10"}
    end
    local lineD = "<ARM                    "
    if doors_modes() == 12 then
      lineD = "<DISARM                 "
      fmsFunctionsDefs["DOORS"]["L4"]={"doCMD","laminar/B747/door/mode_manual_all"}
    else
      fmsFunctionsDefs["DOORS"]["L4"]={"doCMD","laminar/B747/door/mode_auto_all"}
    end
    return {
      "     DOOR CONTROL       ",
      "                        ",
      lineA,
      "                        ",
      lineB,
      "                        ",
      lineC,
      "                        ",
      lineD,
      "                        ",
      "INOP                    ",
      "------------------------",
      "<INDEX       GND HANDLE>"
    }

  elseif pgNo == 2 then

    fmsFunctionsDefs["DOORS"]["L1"]=nil
    fmsFunctionsDefs["DOORS"]["L2"]=nil
    fmsFunctionsDefs["DOORS"]["L3"]=nil
    fmsFunctionsDefs["DOORS"]["L4"]=nil
    return {
      "     Door Control       ",
      "                        ",
      "INOP                    ",
      "                        ",
      "INOP                    ",
      "                        ",
      "INOP                    ",
      "                        ",
      "INOP                    ",
      "                        ",
      "INOP                    ",
      "------------------------",
      "<INDEX       GND HANDLE>"
    }

  elseif pgNo == 3 then

    fmsFunctionsDefs["DOORS"]["L1"]=nil
    fmsFunctionsDefs["DOORS"]["L2"]=nil
    fmsFunctionsDefs["DOORS"]["L3"]=nil
    fmsFunctionsDefs["DOORS"]["L4"]=nil
    return {
      "     Door Control       ",
      "                        ",
      "INOP                    ",
      "                        ",
      "INOP                    ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "------------------------",
      "<INDEX       GND HANDLE>"
    }

  end
end

fmsPages["DOORS"].getSmallPage=function(self,pgNo,fmsID)

  if pgNo == 1 then

    local lineC = "                        "
    local lineD = "                        "
    local lineE = "                        "
    if simDR_doors[1] > 0 then
      lineC = "                 (OPENED)"
    else
      lineC = "                 (CLOSED)"
    end

    if simDR_doors[0] > 0 then
      lineD = "                 (OPENED)"
    else
      lineD = "                 (CLOSED)"
    end
    if simDR_doors[9] > 0 then
      lineE = "                 (OPENED)"
    else
      lineE = "                 (CLOSED)"
    end
    local n = doors_modes()
    local lineF = "                  (MIXED)"
    if n == 12 then
      lineF = "                  (ARMED)"
    elseif n == 0 then
      lineF = "               (DISARMED)"
    end
    return{
      "                     1/3",
      "FWD L                   ",
      lineC,
      "Upper L                 ",
      lineD,
      "Cockpit                 ",
      lineE,
      "ENTRY/UPPER DECK DOORS  ",
      lineF,
      "FWD WING L              ",
      "                        ",
      "                        ",
      "                        "
    }

  elseif pgNo == 2 then

    return{
      "                     2/3",
      "FWD WING R              ",
      "                        ",
      "WING L                  ",
      "                        ",
      "WING R                  ",
      "                        ",
      "AFT WING L              ",
      "                        ",
      "AFT WING R              ",
      "                        ",
      "                        ",
      "                        "
    }

  elseif pgNo == 3 then
    return{

      "                     3/3",
      "AFT L                   ",
      "                        ",
      "AFT R                   ",
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

  end
end

fmsFunctionsDefs["DOORS"]["L6"]={"setpage","INDEX"}
fmsFunctionsDefs["DOORS"]["R6"]={"setpage","GNDHNDL"}

fmsPages["DOORS"].getNumPages=function(self)
  return 3
end
