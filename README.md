# autoapp-hello

AutoApp Phase 0 — minimal SwiftUI iOS app used to validate the end-to-end pipeline:
**source → CI build (GitHub Actions, macos-15 runner) → fastlane match signing → TestFlight upload.**

This repository is managed by an autonomous Claude Code agent. Human involvement is limited to:
- Apple Developer / App Store Connect identity, payment, banking, tax
- Final pre-submission acceptance for App Store review
- Three-strikes rejection sign-off

## Status

Phase 0 — pipeline validation. Awaiting Apple Developer enrollment approval and App Store Connect API key.

## Companion repo

[autoapp-certs](https://github.com/jiejuefuyou/autoapp-certs) — **private** — fastlane match storage for signing certificates and provisioning profiles.
