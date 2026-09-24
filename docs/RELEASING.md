# Releasing Platform

Official releases are universal `arm64`/`x86_64` ZIP archives, ad-hoc signed for
macOS 14+, and published through GitHub with a signed Sparkle appcast.

## Version source

`release/version.env` is the canonical marketing version and build number. A
release tag must exactly equal `v$PLATFORM_VERSION`. Increment the build number
for every distributed binary, including rebuilds of the same marketing version.

## GitHub configuration

The repository requires:

- Actions variable `PLATFORM_API_BASE_URL`: the production HTTPS relay origin
- Actions secret `SPARKLE_PRIVATE_KEY`: exported Sparkle EdDSA private key
- Actions secret `SPARKLE_PUBLIC_KEY`: corresponding public key

Keep the private key in a protected password manager or Keychain as well. It
must never enter Git history, workflow logs or a release asset.

## Release checklist

1. Update `release/version.env` and `CHANGELOG.md`.
2. Run all Swift and Worker checks.
3. Package locally against the production relay and run `scripts/verify-release.sh`.
4. Scan the staged Git history for credentials and local environment files.
5. Create and push the annotated `vX.Y.Z` tag.
6. Let the Release workflow build, sign the update archive, create the appcast
   and publish the GitHub release.
7. Download the published archive, compare its checksum and run the verifier again.
8. Smoke-test onboarding, all board modes, service details, settings, About,
   Quit and Check for Updates.

The workflow reads the build from `release/version.env`; it does not use the
repository's Actions run number.

## Historical binary releases

Versions before 0.2.4 have preserved installers but no retained source
snapshots. Their tags point to the repository's metadata-only archive commit.
Never retag them onto the modern source tree. See
[HISTORICAL_RELEASES.md](HISTORICAL_RELEASES.md).

## Apple distribution

Platform is not intended for the Mac App Store. Developer ID signing and
notarisation remain disabled until explicitly adopted; Sparkle's EdDSA
signature still protects the integrity of update archives.
