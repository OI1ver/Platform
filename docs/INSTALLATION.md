# Installing Platform

Platform is an unsigned technical beta for macOS 14 or later. It is not
distributed through the Mac App Store and is not yet notarised by Apple.

## Install

1. Download `Platform-macOS-universal-0.2.4.zip` from the
   [latest GitHub release](https://github.com/OI1ver/Platform/releases/latest).
2. Open the ZIP and move `Platform.app` to your Applications folder.
3. In Finder, control-click `Platform.app` and choose **Open**.
4. Confirm **Open** in the macOS warning.
5. Platform appears as a train icon in the menu bar and does not add a Dock icon.

You should only need the control-click flow on first launch. Do not disable
Gatekeeper globally and do not run commands copied from unofficial download
sites.

## Verify the download

Each release publishes a SHA-256 checksum. In Terminal, run:

```sh
shasum -a 256 ~/Downloads/Platform-macOS-universal-0.2.4.zip
```

The result must exactly match the checksum in that release's notes.

## Updates

Use **Check for Updates…** from Platform's menu. Update archives are signed with
Sparkle's EdDSA signing independently of the app's unsigned Apple code
signature.

Development builds made before the GitHub update feed was configured cannot
update themselves and must be replaced manually once.

## Uninstall

Quit Platform, then move it from Applications to the Bin. Platform stores
preferences locally and an anonymous installation identifier in Keychain. You
may remove the related Keychain item separately in Keychain Access if desired.
