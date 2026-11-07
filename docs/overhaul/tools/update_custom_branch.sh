#!/usr/bin/env bash
# Make or update the branch "custom": overhaul with the custom acf as the
# main 747-400.acf (the user's request, 2026-10-24). Run from the
# repository root after each commit on overhaul, then push it:
#   bash docs/overhaul/tools/update_custom_branch.sh
#   git push origin custom
# It never touches the working tree, the index or HEAD (a temporary index
# and git's plumbing), so the local 3D files stay as they are. The tree is
# overhaul's with:
#   747-400.acf       <- 747-400_custom.acf (the stock acf is not there)
#   fmod/747-400.snd  <- fmod/747-400_custom.snd
#   747-400_custom.acf, fmod/747-400_custom.snd removed
#   the stock acf's exterior textures in stock_textures removed (2026-11-06)
#   the other acf files (XP11, LCF) and the files named after them removed
#   (other_acf, 2026-11-08)
#   CUSTOM_BRANCH.md  added (what this branch is)
# The first commit has overhaul as its parent; each update is a merge of
# overhaul into custom with that tree, so the branch only moves forward.
# The 3D files the custom acf needs (those not in the stock master) are in
# the private repository Gakugaku87/747-400-assets.
set -euo pipefail
base=${1:-overhaul}
branch=custom
name=$(git log -1 --format=%an archive/old-master)
mail=$(git log -1 --format=%ae archive/old-master)

base_sha=$(git rev-parse --verify "$base^{commit}")
old=$(git rev-parse -q --verify "refs/heads/$branch" || true)
if [ -n "$old" ] && [ "$(git rev-parse -q --verify "$old^2" || git rev-parse "$old^1")" = "$base_sha" ]; then
    echo "$branch is already up to date with $base ($(git rev-parse --short "$base_sha"))"
    exit 0
fi

idx=$(mktemp)
trap 'rm -f "$idx"' EXIT
export GIT_INDEX_FILE="$idx"
git read-tree "$base_sha"
entry() { git ls-tree "$base_sha" -- "$1" | awk '{print $1 "," $3}'; }
acf=$(entry 747-400_custom.acf)
snd=$(entry fmod/747-400_custom.snd)
[ -n "$acf" ] && [ -n "$snd" ] || { echo "no custom acf or snd in $base" >&2; exit 1; }
git update-index --cacheinfo "$acf,747-400.acf"
git update-index --cacheinfo "$snd,fmod/747-400.snd"
git update-index --force-remove 747-400_custom.acf fmod/747-400_custom.snd
# The stock acf's exterior textures (the user's request, 2026-11-06; they
# are deleted in the working tree here too). X-Plane loads a .dds in place
# of the .png of the same name, and the custom acf's objects name
# Exterior_Fuselage.png, Exterior_Fuselage_LIT.png, Exterior_Glass.png and
# Exterior_HStab.png, so these would be drawn on them. Those PNGs are in
# the assets repository, all but Exterior_Fuselage_LIT.png. No object
# names Exterior_Fuselage(fornml).png.
stock_textures=(
    'objects/747_exterior/Exterior_Fuselage.dds'
    'objects/747_exterior/Exterior_Fuselage_LIT.dds'
    'objects/747_exterior/Exterior_Glass.dds'
    'objects/747_exterior/Exterior_HStab.dds'
    'objects/747_exterior/Exterior_Fuselage(fornml).png'
)
git update-index --force-remove "${stock_textures[@]}"
# The other acf files, the XP11 one and the LCF, and the files named after
# them (the user's requests, 2026-11-08): fmod/*.snd, the icons here and in
# the liveries, terrain_radar_descr, vrconfig. The custom acf as
# 747-400.acf is the only acf at the root. Read from the tree, so the
# icons of liveries added later go too.
mapfile -d '' -t other_acf < <(git ls-tree -r -z --name-only "$base_sha" |
    grep -z -E '(^|/)747-400(_XP11|LCF)[._][^/]*$' || true)
if [ "${#other_acf[@]}" -gt 0 ]; then
    git update-index --force-remove -- "${other_acf[@]}"
fi
note=$(git hash-object -w --stdin <<'EOF'
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

The other acf files, `747-400_XP11.acf` and `747-400LCF.acf`, and the
files named after them (their sounds in `fmod/`, icons, terrain radar and
VR files, and their icons in the liveries) are not in this branch either
(2026-11-08): `747-400.acf` is the only acf here.
EOF
)
git update-index --add --cacheinfo "100644,$note,CUSTOM_BRANCH.md"
tree=$(git write-tree)
unset GIT_INDEX_FILE

short=$(git rev-parse --short "$base_sha")
subject=$(git log -1 --format=%s "$base_sha")
if [ -z "$old" ]; then
    msg="Make the custom acf the main 747-400.acf (custom branch)

The custom branch is $base ($short) with 747-400_custom.acf as
747-400.acf and fmod/747-400_custom.snd as fmod/747-400.snd, made by
docs/overhaul/tools/update_custom_branch.sh (the user's request,
2026-10-24).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
    new=$(git -c user.name="$name" -c user.email="$mail" commit-tree "$tree" -p "$base_sha" -m "$msg")
else
    msg="Merge $base ($short) into custom

$short: $subject

The tree is $base's with the custom acf as 747-400.acf, without the
stock acf's exterior textures and without the other acf files and the
files named after them (docs/overhaul/tools/update_custom_branch.sh).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
    new=$(git -c user.name="$name" -c user.email="$mail" commit-tree "$tree" -p "$old" -p "$base_sha" -m "$msg")
fi
git update-ref "refs/heads/$branch" "$new" ${old:+"$old"}
echo "$branch -> $(git rev-parse --short "$new") (from $base $short)"
