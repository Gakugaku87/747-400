#!/usr/bin/env bash
# Make a release of the branch "custom" with only what flight needs (the
# user's request, 2026-11-11: without the test tools and the git files,
# and without the liveries, which are all for the stock acf). Run from the
# repository root after update_custom_branch.sh, then push the tag and
# make the GitHub release from it:
#   bash docs/overhaul/tools/make_release.sh custom-YYYY.MM.DD
#   git push origin refs/tags/custom-YYYY.MM.DD
#   GitHub: Releases -> Draft a new release -> the tag, a title, the notes
# The package is the "Source code (zip)" GitHub adds to the release (its
# folder is 747-400-<tag>). It never touches the working tree, the index or
# HEAD (a temporary index and git's plumbing): the tree is custom's with
# the paths below removed, in a commit whose parent is custom, with an
# annotated tag on it (no branch). The custom acf's 3D files that are not
# in the stock master are not in it either: they stay in the private
# repository Gakugaku87/747-400-assets (unknown sources).
set -euo pipefail
tag=${1:?usage: make_release.sh <tag> [branch]}
base=${2:-custom}
name=$(git log -1 --format=%an archive/old-master)
mail=$(git log -1 --format=%ae archive/old-master)

base_sha=$(git rev-parse --verify "$base^{commit}")
if git rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
    echo "the tag $tag is already there" >&2
    exit 1
fi

# What flight does not need (2026-11-11). Kept on purpose: LICENSE and the
# READMEs (the license and the credits, which CC BY-NC-SA 4.0 asks to keep
# with the copies), simbrief/ (the FMC's SimBrief folder), the plugins'
# json/LICENSE files, the built plugins.
drop_re='^(tests|docs|documentation|crt dev|\.github|\.vscode|liveries)/'
drop_re+='|^plugins/b747_fms_bridge/src/'
drop_re+='|^(\.gitattributes|\.gitignore|CLAUDE\.md|CUSTOM_BRANCH\.md|add\.sh|build\.sh|test\.lua|missfont\.log|747-400\.acf\.empty_panel)$'
drop_re+='|(^|/)\.DS_Store$'
drop_re+='|(^|/)[^/]*xtlua_debugging\.txt$'
drop_re+='|^fmod/readme\.md$'
# the editors' files: GIMP and Photoshop sources, the particle editor's
# backups, a temporary file, a script, and Wavefront exports no object or
# acf names (each .obj there starts with mtllib)
drop_re+='|\.(xcf|psd|pss~|pss_autosave|tmp)$'
drop_re+='|^objects/747_exterior/((fuse|test)\.(obj|mtl)|makedds\.sh)$'

idx=$(mktemp)
trap 'rm -f "$idx" "$idx.drop"' EXIT
export GIT_INDEX_FILE="$idx"
git read-tree "$base_sha"
# the paths go through stdin: some 1,200 of them pass Windows' limit on a
# command line
git ls-tree -r -z --name-only "$base_sha" | { grep -z -i -E "$drop_re" || true; } > "$idx.drop"
n_drop=$(tr -cd '\0' < "$idx.drop" | wc -c)
[ "$n_drop" -gt 0 ] || { echo "nothing to remove from $base" >&2; exit 1; }
git update-index -z --force-remove --stdin < "$idx.drop"
tree=$(git write-tree)
read -r files bytes < <(git ls-tree -r -l "$tree" | awk '{n++; s += $4} END {print n, s}')
mb=$((bytes / 1048576))
short=$(git rev-parse --short "$base_sha")
commit=$(git -c user.name="$name" -c user.email="$mail" commit-tree "$tree" -p "$base_sha" -m "Release $tag: the $base branch ($short) with only what flight needs

Made by docs/overhaul/tools/make_release.sh: $base without the test tools,
the development documents, the git files, the liveries (all for the stock
acf), the plugin sources and the editors' files ($n_drop files);
nothing else changed. $files files, $mb MB. The custom acf's 3D files that
are not in the stock master are not here (private).")
git -c user.name="$name" -c user.email="$mail" tag -a "$tag" "$commit" \
    -m "747-400 $tag: the $base branch $short with only what flight needs ($files files). The custom acf's private 3D set is not included."
echo "$tag -> $(git rev-parse --short "$commit") (from $base $short): $files files, $mb MB, $n_drop removed"
echo "next: git push origin refs/tags/$tag, then the release on GitHub"
