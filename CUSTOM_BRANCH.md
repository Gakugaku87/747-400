# The custom branch

This branch is `overhaul` with the user's custom acf as the main
`747-400.acf` (and its sound as `fmod/747-400.snd`). The stock acf is on
`overhaul` and `master`. It is made by
`docs/overhaul/tools/update_custom_branch.sh` after each commit on
`overhaul`; do not commit to it by hand.

The custom acf uses 3D objects and textures that are not in the stock
master. They are in the private repository `Gakugaku87/747-400-assets`
(Git LFS): copy its files over this branch's folder, keeping their paths.

The stock acf's exterior textures `Exterior_Fuselage.dds`,
`Exterior_Fuselage_LIT.dds`, `Exterior_Glass.dds`, `Exterior_HStab.dds`
and `Exterior_Fuselage(fornml).png` (in `objects/747_exterior/`) are not
in this branch (2026-11-06). X-Plane loads a .dds in place of the .png of
the same name, so they would be drawn on the custom acf's objects.

The other acf files, `747-400_XP11.acf` and `747-400LCF.acf`, the files
named after them (their sounds in `fmod/`, icons, terrain radar and VR
files, and their icons in the liveries) and the LCF's 3D `objects/LCF/`
are not in this branch either (2026-11-08): `747-400.acf` is the only acf
here.
