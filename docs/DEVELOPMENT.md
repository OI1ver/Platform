# Development

Platform is a Swift Package containing a native macOS client and a TypeScript
Cloudflare Worker. macOS 14 is the minimum supported release.

## Requirements

- macOS 14 or later
- Xcode 16 or later and Swift 6
- Node.js 24 and npm
- A Rail Data Marketplace Live Departure Boards subscription for live relay work

## Run the Worker

```sh
cd worker
cp .dev.vars.example .dev.vars
npm install
npm run dev
```

Fill `.dev.vars` with the four development values described by the example.
Never commit the resulting file or paste credentials into issues or logs.

The production relay should bind Cloudflare KV namespaces as `RATE_LIMIT` and
`STALE_CACHE`. Without them, local development uses isolate-local fallbacks.

## Run the app

In another terminal:

```sh
PLATFORM_API_BASE_URL=http://127.0.0.1:8787 swift run Platform
```

Launch-at-login and Sparkle behaviour are available only in a packaged `.app`.

## Test

```sh
swift test
npm --prefix worker test
npm --prefix worker run typecheck
npm --prefix worker audit
```

If Finder metadata in a synced folder interferes with ad-hoc signing, use a
temporary Swift build directory:

```sh
COPYFILE_DISABLE=1 swift test --scratch-path /tmp/platform-spm-tests
```

## Package locally

```sh
PLATFORM_API_BASE_URL=https://example.workers.dev \
PLATFORM_GITHUB_REPOSITORY=OI1ver/Platform \
PLATFORM_VERSION=0.2.4 \
PLATFORM_BUILD=15 \
scripts/package-app.sh
```

Local builds intentionally retain placeholder update configuration unless a
Sparkle public key is also supplied. Official release configuration is
described in [RELEASING.md](RELEASING.md).

## Station catalogue

The bundled catalogue is generated from National Rail's public station service
and filtered to Darwin-supported locations:

```sh
node scripts/update-stations.mjs
```

Commit both generated outputs whenever the catalogue changes.
