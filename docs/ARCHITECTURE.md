# Architecture / Phase 1

## Implementation plan

1. Inspect the empty repository, brief, supplied artwork, toolchains and targets.
2. Establish the requested module directories, Xcode targets and engine boundary.
3. Implement config defaults, validation, atomic persistence and state events in Rust.
4. Implement an opaque, main-thread C ABI with explicit string ownership and errors.
5. Own that handle in Swift; provide a minimal native app, settings and recovery UI.
6. Test platform-neutral core and native bridge; verify and package bundles in CI.
7. Document the gaps before proceeding to wallpaper rendering in a separate increment.

## Data flow

```text
AppKit control -> Swift Codable config -> C ABI -> validate -> atomic disk save
                                                         -> commit engine state
                                                         -> bounded event queue
Swift drains events after mutations -> NotificationCenter -> refresh settings
```

JSON crosses the bridge only at startup/settings changes. No rendering loop or periodic serialization exists. Main-thread confinement is enforced by the Swift wrapper. The opaque pointer is single-owner, must not be used concurrently, and is destroyed on wrapper deinit. Each Rust-allocated UTF-8 string (including errors) is freed with the matching ABI function. Expected errors and Rust panics become nonzero statuses; invalid/dangling C pointers remain caller errors and cannot be made safe by panic catching.

## Persistence

Schema version 1 is deliberately strict. Unknown fields and future schema versions fail with useful errors instead of discarding user data. Reads are bounded to 64 KiB, including if a file grows during a read. First launch creates defaults; existing malformed files block startup until repaired or moved by the user. No automatic destructive recovery occurs.

Writes use a same-directory temporary file (`create_new`, private 0600 on Unix), file sync and atomic rename. Memory and notifications change only after persistence succeeds. Directory sync is best-effort after a successful rename. Reset is an explicit UI action, requires confirmation, and first makes a uniquely named config backup. User media is never touched. Configuration is intended for a trusted per-user Application Support folder, not an adversarial shared folder. Multiple simultaneous app processes editing the same config are not supported; no cross-process file lock or file watcher is implemented.

## Native shell

The app uses native AppKit controls and a behind-window visual-effect view with a dark tinted surface, rounded cards and mint accent. No external UI framework. Settings are not system preferences: colors/opacity customize this app only. The menu bar item is an additional native control, not a replacement for Apple's menu bar. A hidden settings window remains reopenable through that item or application reopen. There is no login-item integration yet.

Reserved directories contain `.gitkeep` files, not pretend implementations. Planned sidebar sections are plain, labeled text rather than dead buttons. Future sections should be made interactive only once their settings affect real behavior.

## Memory policy

One app process, no helper daemon, no idle timers, no eagerly loaded wallpaper library. The only image loaded at present is the official logo/icon. Rust event queue is capped at 32 notifications. AppKit owns native rendering. This is not a measured 30–50 MB claim: profile the actual macOS app before making footprint statements.

Future HTML support will necessarily use WebKit's OS-managed content processes, an exception to the preference for a single main process. Budget those separately and do not claim a single-process WKWebView renderer.

## Build choices

Two separate Xcode native targets share Swift sources and use one Rust static library per architecture. SDK/Xcode 16.4, Swift language mode 5 and Rust 1.85.1 are pinned for compatibility; the developer/build machine is modern, the target OS can be older. CI never pretends to boot High Sierra on a modern hosted runner. A plain Python generator keeps Xcode source membership reproducible with no generator dependencies.
