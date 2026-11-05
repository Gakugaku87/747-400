-- The ACARS WEATHER REQUEST page (an operator's page: no Boeing source).
-- (2026-11-05 review 4) The request's own airport (the FMC's wxapt): ORIGIN
-- and DESTINATION pick it, AIRPORT takes an ICAO identifier, METAR and TAF
-- ask for its weather. Before, these were the ATC logon's facility (atc): a
-- weather request logged ATC on there, an entry not of four letters logged
-- it off (ATC COMM gone).
fmsPages["ACARSWEATHER"]=createPage("ACARSWEATHER")
fmsPages["ACARSWEATHER"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
    local dep="     "
    local dst="     "
    local apt=fmsModules.data["wxapt"]
    if apt==fmsModules.data["fltdep"] then dep="<"..fmsModules.data["fltdep"] end
    if apt==fmsModules.data["fltdst"] then dst=fmsModules.data["fltdst"]..">" end

    return {
        " ACARS WEATHER REQUEST  ",
        "                         ",
        dep.."               "..dst,
        "                         ",
        "                    ".. apt ..">",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "                         ",
        "<MESSAGES          METAR>",
        "                         ",
        "<ACARS               TAF>",
        "                         "
        }
end

fmsPages["ACARSWEATHER"].getSmallPage=function(self,pgNo,fmsID)
    local dep="     "
    local dst="     "
    local apt=fmsModules.data["wxapt"]
    if apt~=fmsModules.data["fltdep"] then dep="<"..fmsModules.data["fltdep"] end
    if apt~=fmsModules.data["fltdst"] then dst=fmsModules.data["fltdst"]..">" end

    return {
        "                        ",
        "ORIGIN        DESTINATION",
        dep.."               "..dst,
        "                  AIRPORT",
        "                        ",
        "                        ",
        "                        ",
        "                        ",
        "                        ",
        "RECEIVED          REQUEST",
        "                        ",
        "RETURN TO         REQUEST",
        "                        ",
        "                        "
        }
end
fmsFunctionsDefs["ACARSWEATHER"]["L1"]={"setdata","wxdep"}
fmsFunctionsDefs["ACARSWEATHER"]["R1"]={"setdata","wxdst"}
fmsFunctionsDefs["ACARSWEATHER"]["L5"]={"setpage","VIEWUPACARS"}
fmsFunctionsDefs["ACARSWEATHER"]["L6"]={"setpage","ACARS"}
fmsFunctionsDefs["ACARSWEATHER"]["R2"]={"setdata","wxapt"}
fmsFunctionsDefs["ACARSWEATHER"]["R5"]={"setdata","metarreq"}
fmsFunctionsDefs["ACARSWEATHER"]["R6"]={"setdata","tafreq"}
