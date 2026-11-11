# Compatibility and verification

## Targets, not unverified promises

- Intel: x86_64, deployment target 10.13 (High Sierra).
- Apple Silicon: arm64, deployment target 11.0 (Big Sur).
- High Sierra never runs on an Apple Silicon Mac.
- Rust 1.85.1 is pinned to retain the older Darwin deployment baseline. Review the standard library's minimum OS before upgrading.
- Swift is compiled in Swift 5 language mode with Xcode 16.4. Foundation/AppKit APIs used by this increment are available on 10.13. No SwiftUI, SF Symbols, system switches, or macOS 11-only appearance APIs are used.
- Xcode's Swift standard-library embedding/back-deployment and final loader behavior must be checked on actual 10.13. Modern-runner tests alone do not prove this.

## CI verification

Supported hosted images: `macos-15-intel` (Intel) and `macos-15` (Apple Silicon). Both explicitly select Xcode 16.4. CI asserts the actual CPU, runs native Rust tests and Swift bridge tests and native AppKit control-action smoke tests, builds the app, verifies bundle resources and deployment metadata, then archives with `ditto` preserving bundle structure. Linux independently tests/lints Rust. Version tags release both artifacts only after every test/build job succeeds.

No signing or notarization credentials exist in source. CI's `CODE_SIGNING_ALLOWED=NO` is intentional. Download artifacts only from a trusted run/commit. Notarization is optional future release work and does not make an app inherently High Sierra compatible.

## Required manual acceptance (not performed in the Linux coding environment)

Run on a real Intel Mac booted into macOS 10.13, then on a supported Apple Silicon Mac:

- [ ] Extract the matching archive; confirm `.app/Contents` structure.
- [ ] Launch through Finder with the appropriate Gatekeeper approval.
- [ ] Confirm no missing Swift libraries, dyld errors or newer-API crashes.
- [ ] First launch writes valid JSON to Application Support.
- [ ] Change all general/appearance controls; verify visual changes and disk contents.
- [ ] Relaunch and confirm persistent values and open-on-launch behavior.
- [ ] Close settings; reopen via menu bar and Dock; test quit-on-close mode.
- [ ] Reveal config; reset with Cancel; confirm nothing changed.
- [ ] Confirm reset creates a backup and restores defaults.
- [ ] Test malformed JSON, unknown schema and unwritable config; ensure no silent overwrite.
- [ ] Resize the window, scroll long content, and test keyboard/tab navigation.
- [ ] Record idle CPU, physical footprint and energy use with Activity Monitor/Instruments.
- [ ] Repeat open/change/close cycles and examine allocations for growth.

Keep this list unchecked until measured on the actual OS. Memory targets in the brief are experimental, not benchmarks. No Accessibility, screen recording or network permission is requested by Phase 1.

## Future native limitations

Use desktop-level windows and supported APIs, never replace protected Apple components. Window utilities need explicitly granted Accessibility permission. Public macOS APIs do not provide arbitrary private Space creation/assignment or programmatic Space switching equivalent to private CGS APIs. Offer supported/user-authorized alternatives; do not simulate functionality with fake workspace data. Blur is native material-based rather than a guaranteed linear blur-radius knob. WAV is audio-only and needs a genuine visualization renderer. HTML imports need a strict resource/network policy before they are considered complete; a navigation delegate alone is not a network sandbox.
