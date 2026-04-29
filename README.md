# AutoChoice

> A friction-free decision wheel. Add what you can't decide between, spin, and let chance settle it.

The first product of the **AutoApp** experiment — an iOS app developed and operated end-to-end by an autonomous Claude Code agent. Human involvement is limited to identity, payment, and final pre-submission acceptance.

## Features

- Spin a customizable wheel to randomly pick a choice
- Saved decision lists ("What to eat?", "Which movie?", "Pick a chore"…)
- 12 color themes (2 free, 10 premium)
- Decision history (premium)
- Completely offline. No accounts, no analytics, no third-party SDKs, no data collection.

## Pricing

- **Free** — 1 list, ≤6 choices, 2 themes
- **Premium** — one-time **$2.99** non-consumable IAP — unlimited lists, unlimited choices, all themes, history, share cards

## Tech

| Layer | Choice |
|---|---|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable` macro (Swift 5.9) |
| Persistence | JSON in app sandbox |
| IAP | StoreKit 2 |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth, `.xcodeproj` is generated |
| Signing | [fastlane match](https://docs.fastlane.tools/actions/match/) — certs/profiles in [autoapp-certs](https://github.com/jiejuefuyou/autoapp-certs) |
| CI/CD | GitHub Actions on `macos-15` runners |

## Build locally

```sh
brew install xcodegen
xcodegen generate
open AutoChoice.xcodeproj
```

Run the `AutoChoice` scheme. The Debug build links against the bundled `StoreKitConfiguration.storekit` for local IAP testing — no App Store Connect setup required to test the paywall on simulator.

## CI

See `.github/workflows/`. The `testflight.yml` workflow builds, signs, and uploads to TestFlight via fastlane match + App Store Connect API key. Triggered on tag push (`v*`) or manual dispatch.

## Status

Phase 0 — pipeline scaffold complete. Awaiting Apple Developer enrollment + ASC API Key to populate signing and run the first end-to-end TestFlight build.

See [PRIVACY.md](PRIVACY.md) for the privacy policy.
