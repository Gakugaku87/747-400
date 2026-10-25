fmsPages["EFISCTL152"]=createPage("EFISCTL152")
fmsPages["EFISCTL152"].getPage=function(self,pgNo,fmsID)

    local mapMode=simDR_nd_mode_dial_capt
    local mapCenter=simDR_nd_center_dial_capt
    local baro=simDR_altimeter_baro_inHg
    local baroString=""
    local dh=string.format("%03d",simDR_radio_alt_DH_capt) 
    local mda=string.format("%04d",B747DR_efis_baro_alt_ref_capt)
    if fmsID=="fmsR" then 
        mapMode=simDR_nd_mode_dial_fo 
        mapCenter=simDR_nd_center_dial_fo
        baro=simDR_altimeter_baro_inHg_fo
        if B747DR_efis_baro_ref_fo_sel_dial_pos==1 then 
            baro=baro*33.863892
            baroString=" "..string.format("%04d",baro) 
        else
            baroString=string.format("%02.2f",baro) 
        end
        dh=string.format("%03d",simDR_radio_alt_DH_fo) 
        mda=string.format("%04d",B747DR_efis_baro_alt_ref_fo)
    elseif  B747DR_efis_baro_ref_capt_sel_dial_pos ==1 then 
        baro=baro*33.863892  
        baroString=" "..string.format("%04d",baro) 
    else
        baroString=string.format("%02.2f",baro) 
    end

    local mapSelected="     "
    local plnSelected="     "
    local appSelected="     "
    local vorSelected="     "
    local ctrSelected="     "

    if mapMode==0 then appSelected="<SEL>"
    elseif mapMode==1 then vorSelected="<SEL>"
    elseif mapMode==2 then mapSelected="<SEL>" 
    elseif mapMode==3 then plnSelected="<SEL>"
    end
     
    if mapCenter==1 then ctrSelected ="<SEL>" end  
    local page={
    "      EFIS CONTROL      ",
    "                        ",
    baroString.."        ".. mapSelected .."  MAP>",
    "                        ",
    dh.."          ".. plnSelected .."  PLN>",
    "                        ",
    "<DH RESET    ".. appSelected .."  APP>",
    "                        ",
    mda.."         ".. vorSelected .."  VOR>",
    "                        ",
    "<RANGE INCR  ".. ctrSelected .."  CTR>",
    "             -----------",
    "<RANGE DECR     OPTIONS>"
    }
  return page
end

local ranges = {" 10", " 20", " 40", " 80", "160", "320", "640"}
fmsPages["EFISCTL152"].getSmallPage=function(self,pgNo,fmsID)
    local mode="IN "
    local baromode=B747DR_efis_baro_ref_capt_sel_dial_pos
    local range=ranges[simDR_range_dial_capt+1]
    if fmsID=="fmsR" then 
        baromode=B747DR_efis_baro_ref_fo_sel_dial_pos 
        range=ranges[simDR_range_dial_fo+1]
    end 
    if baromode==1 then mode="HPA" end 
    return {
        "                        ",
        " BARO SET           MODE",
        "      ".. mode .."               ",
        " DH SET                 ",
        "   FT                   ",
        "                        ",
        "                        ",
        " MDA SET                ",
        "    FT                  ",
        "                        ",
        "                        ", 
        range.."NM                   ",
        "                        "
        }
	end
fmsFunctionsDefs["EFISCTL152"]={}
fmsFunctionsDefs["EFISCTL152"]["L1"]={"setdata","BARO"}
fmsFunctionsDefs["EFISCTL152"]["L2"]={"setdata","DH"}
fmsFunctionsDefs["EFISCTL152"]["L3"]={"setdata","DHRESET"}
fmsFunctionsDefs["EFISCTL152"]["L4"]={"setdata","MDA"}
fmsFunctionsDefs["EFISCTL152"]["L5"]={"setdata","RANGEINC"}
fmsFunctionsDefs["EFISCTL152"]["L6"]={"setdata","RANGEDEC"}
fmsFunctionsDefs["EFISCTL152"]["R1"]={"setdata","EFISMAP"}
fmsFunctionsDefs["EFISCTL152"]["R2"]={"setdata","EFISPLN"}
fmsFunctionsDefs["EFISCTL152"]["R3"]={"setdata","EFISAPP"}
fmsFunctionsDefs["EFISCTL152"]["R4"]={"setdata","EFISVOR"}
fmsFunctionsDefs["EFISCTL152"]["R5"]={"setdata","EFISCTR"}
fmsFunctionsDefs["EFISCTL152"]["R6"]={"setpage","EFISOPTIONS152"}


registerFMCCommand("sim/instruments/EFIS_wxr","")
registerFMCCommand("sim/instruments/EFIS_copilot_wxr","")
registerFMCCommand("sim/instruments/EFIS_tcas","")


fmsPages["EFISOPTIONS152"]=createPage("EFISOPTIONS152")
-- the 109's CDU-152 (FCOM p.1065): WXR, POS, MTRS, FPV, WPT, STA, ARPT, DATA,
-- VOR and ADF for that CDU's side (5-2 step 5c: before, TERR and TFC as the
-- 405's and CDU-161's, WXR the Captain's, POS and DATA dead)
fmsPages["EFISOPTIONS152"].getPage=function(self,pgNo,fmsID)
    local fo=fmsID=="fmsR"
    local function sel(on) return on and "<SEL>" or "     " end
    local function pick(capt, f) if fo then return f==1 end return capt==1 end
    local s1=fo and simDR_EFIS_1_sel_fo or simDR_EFIS_1_sel_pilot
    local s2=fo and simDR_EFIS_2_sel_fo or simDR_EFIS_2_sel_pilot
    return {
        "      EFIS OPTIONS      ",
        "                        ",
        "<WXR  "..sel(pick(B747DR_nd_wxr, simDR_EFIS_wxr_copilot)).."  "..sel(pick(B747DR_nd_capt_wpt, B747DR_nd_fo_wpt)).."  WPT>",
        "                        ",
        "<POS  "..sel(pick(B747DR_nd_capt_pos, B747DR_nd_fo_pos)).."  "..sel(pick(B747DR_nd_capt_vor_ndb, B747DR_nd_fo_vor_ndb)).."  STA>",
        "                        ",
        "<MTRS "..sel(pick(B747DR_efis_meters_capt_selected, B747DR_efis_meters_fo_selected)).."  "..sel(pick(B747DR_nd_capt_apt, B747DR_nd_fo_apt)).." ARPT>",
        "                        ",
        "<FPV  "..sel(pick(B747DR_efis_fpv_capt_selected, B747DR_efis_fpv_fo_selected)).."  "..sel(pick(B747DR_nd_capt_data, B747DR_nd_fo_data)).." DATA>",
        "                        ",
        "<VOR  "..sel(s1==2 and s2==2).."  "..sel(s1==0 and s2==0).."  ADF>",
        "------------------------",
        "                CONTROL>"
        }
end
fmsFunctionsDefs["EFISOPTIONS152"]={}
fmsFunctionsDefs["EFISOPTIONS152"]["L1"]={"setdata","WXR"}
fmsFunctionsDefs["EFISOPTIONS152"]["L2"]={"setdata","POS"}
fmsFunctionsDefs["EFISOPTIONS152"]["L3"]={"setdata","MTRS"}
fmsFunctionsDefs["EFISOPTIONS152"]["L4"]={"setdata","FPV"}
fmsFunctionsDefs["EFISOPTIONS152"]["L5"]={"setdata","VORDISP"}
fmsFunctionsDefs["EFISOPTIONS152"]["R1"]={"setdata","WPT"}
fmsFunctionsDefs["EFISOPTIONS152"]["R2"]={"setdata","STA"}
fmsFunctionsDefs["EFISOPTIONS152"]["R3"]={"setdata","ARPT"}
fmsFunctionsDefs["EFISOPTIONS152"]["R4"]={"setdata","DATA"}
fmsFunctionsDefs["EFISOPTIONS152"]["R5"]={"setdata","ADFDISP"}
fmsFunctionsDefs["EFISOPTIONS152"]["R6"]={"setpage","EFISCTL152"}
