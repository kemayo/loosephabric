#!/usr/bin/env bash

# This is to generate https://github.com/kemayo/loosephabric/appcast.xml
# For the URLs to line up, you *have* to create the release as `v[whatever-your-version-in-xcode-is]`

# ditto -c -k --sequesterRsrc --keepParent LoosePhabric.app LoosePhabric-v1.zip

# set -x
set -eu

die () {
    echo >&2 "$@"
    exit 1
}

BASEURL="https://github.com/kemayo/loosephabric"

# Called as ./release.sh releases/AppName-v1.0.zip ../LoosePhabric-pages/appcast.xml
[ "$#" -eq 2 ] || die "$0 ZIPFILE APPCAST"

ZIPFILE=$1
APPCASTFILE=$2

[ -f "$ZIPFILE" ] || die "$ZIPFILE doesn't exist"
[ -f "$APPCASTFILE" ] || die "$APPCASTFILE doesn't exist"

BUILDSETTINGS=$(xcodebuild -project ../LoosePhabric/LoosePhabric.xcodeproj -scheme LoosePhabric -showBuildSettings 2>/dev/null)

DERIVED=$(realpath $(echo "$BUILDSETTINGS" | grep -m 1 "\bSYMROOT" | sed -nr 's/^.+ = (.+)$/\1/p')/../../)

SPARKLE=$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin

[ -d $SPARKLE ] || die "Couldn't find Sparkle bin in $SPARKLE"

# $SPARKLE/generate_appcast \
# 	--link https://github.com/kemayo/loosephabric/releases \
# 	--download-url-prefix https://github.com/kemayo/loosephabric/releases/download \
# 	-o releases/appcast.xml \
# 	releases/

# I based this on https://github.com/lwouis/alt-tab-macos/blob/master/scripts/update_appcast.sh

version=$(echo "$BUILDSETTINGS" | grep -m 1 "\bMARKETING_VERSION =" | sed -nr 's/^.+ = (.+)$/\1/p')
minimumSystemVersion=$(echo "$BUILDSETTINGS" | grep -m 1 "\bMACOSX_DEPLOYMENT_TARGET =" | sed -nr 's/^.+ = (.+)$/\1/p')
date="$(date +'%a, %d %b %Y %H:%M:%S %z')"

signature=$($SPARKLE/sign_update $ZIPFILE)

echo "Signed release: $signature"

echo "
    <item>
      <title>Version $version</title>
      <pubDate>$date</pubDate>
      <sparkle:minimumSystemVersion>$minimumSystemVersion</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$BASEURL/releases/tag/v$version</sparkle:releaseNotesLink>
      <enclosure
        url=\"$BASEURL/releases/download/v$version/$(basename $ZIPFILE)\"
        sparkle:version=\"$version\"
        sparkle:shortVersionString=\"$version\"
        $signature
        type=\"application/octet-stream\"/>
    </item>
" > /tmp/loosephabric-appcast-ITEM.txt

sed -i '' -e "/<\/language>/r /tmp/loosephabric-appcast-ITEM.txt" $APPCASTFILE

echo "Now upload $APPCASTFILE to https://kemayo.github.io/loosephabric/appcast.xml"

