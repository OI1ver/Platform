# Contributing

Thanks for helping improve Platform. Bug reports, focused feature proposals,
documentation improvements and pull requests are welcome.

## Before opening an issue

- Search existing issues and releases first.
- Use the bug or feature form and include the macOS and Platform versions.
- Remove station/service identifiers if they are not needed to reproduce the problem.
- Report security or privacy problems privately through [SECURITY.md](SECURITY.md).

## Pull requests

1. Fork the repository and create a focused branch.
2. Follow [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) to run the app and tests.
3. Add or update tests for behaviour changes.
4. Explain visible changes and attach a screenshot where useful.
5. Keep unrelated formatting or refactors out of the change.

Run before submitting:

```sh
swift test
npm --prefix worker test
npm --prefix worker run typecheck
npm --prefix worker audit
```

Never include Rail Data Marketplace credentials, real authentication headers,
Sparkle private keys or user data in commits, fixtures, logs or issue reports.
Use synthetic service IDs and responses in tests.

The dark departure-board UI is the project's visual source of truth. Preserve
its fixed board dimensions, font roles, status wording and accessibility
semantics unless a change is accompanied by an approved design update.
