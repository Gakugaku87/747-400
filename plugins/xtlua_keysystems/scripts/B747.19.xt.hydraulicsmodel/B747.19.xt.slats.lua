-- Leading-edge flaps ("slats"): X-Plane's two slat ratios are the flap
-- control units' group A (inboard and midspan) and group B (outboard)
-- (B747.45.xt.fcu.lua, 4-1: their sequencing, drives and the reverse thrust
-- retraction). Before, they followed the flap lever here at 8.5 s, without
-- power, and group A came in with the speedbrake lever up and any engine
-- in reverse.
function B747_slats()
    local a, b = B747DR_fcu_slat[0], B747DR_fcu_slat[1]
    if simDR_innerslats_ratio ~= a then simDR_innerslats_ratio = a end
    if simDR_outerslats_ratio ~= b then simDR_outerslats_ratio = b end
end
