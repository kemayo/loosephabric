# Releasing LoosePhabric

A release has three parts:

- a notarized build, attached to a GitHub release;
- an entry in the Sparkle appcast;
- release notes.

The appcast and release notes live on the `gh-pages` branch, served from `https://kemayo.github.io/loosephabric/`. These steps assume `gh-pages` is checked out at `../LoosePhabric-pages`.

## 1. Bump the version

In the LoosePhabric target's build settings, change both of these. Each one appears twice in `project.pbxproj`, once for Debug and once for Release.

- `MARKETING_VERSION`: the version users see, e.g. `0.10`.
- `CURRENT_PROJECT_VERSION`: the build number. It **must** be higher than the last release, because Sparkle compares this number, not `MARKETING_VERSION`, to decide whether an update exists.

Commit this as "Bump version to X".

## 2. Build and notarize

1. In Xcode, select Product > Archive.
2. In the Organizer, select Distribute App > Direct Distribution. This signs the build with Developer ID and submits it for notarization.
3. When notarization finishes, export `LoosePhabric.app`.

## 3. Zip the app

```sh
ditto -c -k --sequesterRsrc --keepParent LoosePhabric.app LoosePhabric-vX.zip
```

The file name must be `LoosePhabric-v<MARKETING_VERSION>.zip`. `release.sh` builds the download URL from it.

## 4. Create the GitHub release

Create a release on https://github.com/kemayo/loosephabric/releases:

- **Tag:** `v<MARKETING_VERSION>`, e.g. `v0.10`, on the version-bump commit. The appcast's download URL depends on this exact tag.
- **Asset:** attach the zip.

Publish the release before you push the appcast (step 6). If you don't, the Sparkle update links to a download that does not exist yet.

## 5. Add the appcast entry

From `../LoosePhabric-pages`:

```sh
bin/release.sh path/to/LoosePhabric-vX.zip appcast.xml
```

The script:

- reads the version, build number, and minimum macOS version from the Xcode project in `../LoosePhabric`, so that checkout must be at the release commit;
- signs the zip with Sparkle's `sign_update`;
- inserts a new `<item>` at the top of `appcast.xml`.

It requires:

- **`xcode-select` pointing at Xcode, not the Command Line Tools.** The script runs `xcodebuild`, which needs a full Xcode. Check with `xcode-select -p`. If it shows `/Library/Developer/CommandLineTools`, run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. macOS upgrades and Command Line Tools updates can reset this.
- **Sparkle's tools in DerivedData.** If the script cannot find them, build the project in Xcode once so Swift Package Manager downloads the Sparkle artifacts.
- **The Sparkle EdDSA private key in your login keychain.** `sign_update` reads it from there. Its public key is `SUPublicEDKey` in `LoosePhabric/Info.plist`.

## 6. Add release notes and publish

1. In `releasenotes.html`, add a new `<section>` at the top. Copy the format of the existing sections, and set `data-sparkle-version` to the new `CURRENT_PROJECT_VERSION`. Sparkle uses that attribute to show only the notes that are newer than the installed version.
2. Commit both files on `gh-pages` as "Update for vX release", and push.

GitHub Pages deploys the change in a few minutes. To check it, run `curl -s https://kemayo.github.io/loosephabric/appcast.xml | head -20`, then use "Check for updates now..." in an older copy of the app.
