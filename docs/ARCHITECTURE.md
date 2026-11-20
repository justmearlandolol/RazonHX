# Architecture

## Data flow

```text
AppKit control -> Swift Codable config -> C ABI -> validate -> atomic disk save
                                                         -> commit engine state
                                                         -> bounded event queue
Swift drains events after mutations -> NotificationCenter -> refresh settings and affected desktop modules
```

JSON crosses the bridge only at startup, settings changes and display/Space refreshes. Animation and pointer events never serialize configuration. Main-thread confinement is enforced by the Swift wrapper. The opaque pointer is single-owner, must not be used concurrently, and is destroyed on wrapper deinit. Each Rust-allocated UTF-8 string (including errors) is freed with the matching ABI function. Expected errors and Rust panics become nonzero statuses; invalid/dangling C pointers remain caller errors and cannot be made safe by panic catching.

## Persistence

Schema version 1 is deliberately strict. Unknown fields and future schema versions fail with useful errors instead of discarding user data. Legacy version-1 files omit the new `desktop` object; the Rust decoder supplies bundled defaults without changing the saved General or Appearance values. Reads are bounded to 64 KiB, including if a file grows during a read. First launch creates defaults; existing malformed files block startup until repaired or moved by the user. No automatic destructive recovery occurs.

Writes use a same-directory temporary file (`create_new`, private 0600 on Unix), file sync and atomic rename. Memory and notifications change only after persistence succeeds. Directory sync is best-effort after a successful rename. Reset is an explicit UI action, requires confirmation, and first makes a uniquely named config backup. User media is never touched. Configuration is intended for a trusted per-user Application Support folder, not an adversarial shared folder. Multiple simultaneous app processes editing the same config are not supported; no cross-process file lock or file watcher is implemented.

## Native shell

The app uses native AppKit controls and a behind-window visual-effect view with a dark tinted surface, rounded cards and mint accent. No external UI framework. Settings are not system preferences: colors/opacity customize this app only. The menu bar item is an additional native control, not a replacement for Apple's menu bar. A hidden settings window remains reopenable through that item or application reopen. There is no login-item integration yet.

## Desktop lifecycle

`DesktopController` reads config snapshots and updates the affected modules rather than recreating the entire desktop on unrelated changes. It observes display configuration, Spaces, app activation and screen sleep/session notifications. Wallpaper and widgets use desktop-level, click-through panels. Dock and toolbar use nonactivating panels. Global and local mouse movement monitors exist only while at least one panel is in **On overlay** mode. A wider exit range than entry range prevents flicker near the boundary; hidden panels are ordered out, not made transparent over another app’s controls.

## Media and integrations

The Rust model validates settings ranges and library/display references. Swift validates imported media and copies it to a managed directory. Only applied files and the current silent preview are decoded. Animated media honors the playback toggle and sleep/session state. Inline HTML uses a nonpersistent `WKWebView` with scripting disabled, a blocking content rule, a restrictive content security policy, and only the initial inline navigation allowed. WebKit uses OS-managed content processes. WAV visualization reads a bounded PCM buffer at the playback position.

Window placement uses AX only after user authorization. Battery, CPU, memory and interface data come from macOS. Weather is opt-in and uses coordinates the user enters; it does not use location services. Native acceptance and profiling are still required before making High Sierra or memory-footprint guarantees.

## Build choices

Two separate Xcode native targets share Swift sources and use one Rust static library per architecture. SDK/Xcode 16.4, Swift language mode 5 and Rust 1.85.1 are pinned for compatibility; the developer/build machine is modern, the target OS can be older. CI never pretends to boot High Sierra on a modern hosted runner. A plain Python generator keeps Xcode source membership reproducible with no generator dependencies.
