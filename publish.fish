#!/usr/bin/env fish
# Publishes a new version: sets the TOC version, adds the changelog section,
# writes WHATS_NEW.md from it, makes a test build to show what the zip holds,
# then (after you confirm) commits everything and tags v<version>, and asks
# whether to push. GitHub Actions uploads it to CurseForge when the tag arrives.
#
#   ./publish.fish           asks for the version
#   ./publish.fish 1.2.10    uses that version
#
# The same script is in every addon repo; it reads the addon name from pkgmeta.yaml.

cd (path resolve (status dirname)); or exit 1

set -l name (string match -rg '^package-as:\s*(\S+)' < pkgmeta.yaml)
set -l toc $name/$name.toc
if test -z "$name"; or not test -f $toc
    echo "No addon TOC found (check package-as in pkgmeta.yaml)" >&2
    exit 1
end

function tag_exists --argument-names tag
    git rev-parse -q --verify "refs/tags/$tag" >/dev/null
    or git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1
end

function changelog_section --argument-names ver
    # the lines under "## <ver>", without the blank ones
    awk -v h="## $ver" '$0 == h { on = 1; next } on && /^## / { exit } on && NF { print }' CHANGELOG.md
end

# Version ----------------------------------------------------------------------

set -l current (string match -rg '^## Version:\s*(\S+)' < $toc)
set -l last_tag (git describe --tags --abbrev=0 2>/dev/null; or echo none)
echo "$name: TOC version $current, last tag $last_tag, branch "(git branch --show-current)

# the TOC version if it isn't released yet, else the next patch version
set -l suggest $current
if tag_exists v$current
    set -l parts (string split . $current)
    set parts[-1] (math $parts[-1] + 1)
    set suggest (string join . $parts)
end

set -l ver $argv[1]
if test -z "$ver"
    read -P "Version [$suggest]: " ver; or exit 1
    test -n "$ver"; or set ver $suggest
end
if not string match -qr '^\d+(\.\d+)+$' -- $ver
    echo "Not a version: $ver" >&2
    exit 1
end
if tag_exists v$ver
    echo "v$ver is already tagged" >&2
    exit 1
end

if test "$current" != "$ver"
    sed -i "s/^## Version:.*/## Version: $ver/" $toc
    echo "TOC: $current -> $ver"
end

# Changelog --------------------------------------------------------------------

if test -z "$(changelog_section $ver)"
    echo "No '## $ver' section in CHANGELOG.md. Type its lines, an empty line ends:"
    set -l lines
    while read -P "- " line; and test -n "$line"
        set -a lines "- $line"
    end
    if test (count $lines) -eq 0
        echo "No changelog lines, stopping. The TOC version change is left in place." >&2
        exit 1
    end
    # the new section goes right under the "# Changelog" title
    set -l old (cat CHANGELOG.md)
    begin
        echo $old[1]
        echo
        echo "## $ver"
        echo
        printf '%s\n' $lines
        printf '%s\n' $old[2..-1]
    end >CHANGELOG.md
end

# CurseForge's "What's new": the newest changelog section
changelog_section $ver >WHATS_NEW.md

# Confirm ----------------------------------------------------------------------

echo
echo "What's new in $ver:"
cat WHATS_NEW.md
echo
# test build with the packager GitHub uses, without uploading, to show what the zip holds
set -l build (mktemp -d)
echo "Test build..."
if curl -sfL https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh -o $build/release.sh
    and bash $build/release.sh -d -r $build/out >$build/log 2>&1
    echo "The zip will hold:"
    unzip -Z1 $build/out/*.zip | string replace -r '^' '  '
    rm -rf $build
else
    tail -n 20 $build/log 2>/dev/null
    rm -rf $build
    echo "Test build failed (see above). Nothing committed; the file changes are left in place." >&2
    exit 1
end
echo

echo "Changes that go into the commit:"
git status --short
echo
read -P "Commit as \"$ver\" and tag v$ver? [y/N] " answer
if not string match -qi y -- "$answer"
    echo "Nothing committed. The file changes are left in place."
    exit 0
end

git add -A
and git commit -m $ver
and git tag v$ver
or begin
    echo "Stopped: a git step failed (see above)." >&2
    exit 1
end
set -l branch (git branch --show-current)
echo "Committed and tagged v$ver."
read -P "Push now (publishes to CurseForge)? [y/N] " answer
if string match -qi y -- "$answer"
    git push origin $branch v$ver; or exit 1
    echo "Pushed. The upload runs in the repo's Actions tab, then shows up on CurseForge."
else
    echo "Not pushed. To publish later:"
    echo "  git push origin $branch v$ver"
end
