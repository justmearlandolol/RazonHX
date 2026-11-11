# RazonHX — Master Development Prompt v1.0

## 1. Project Identity

Build **RazonHX**, a native, lightweight, highly customizable desktop environment and wallpaper application for macOS.

RazonHX is inspired by Seelen UI, but must have its own architecture, implementation, visual identity, and features.

**Product name:** RazonHX  
**Tagline:** Redefine Your Desktop.  
**Category:** macOS Desktop Customization Environment  
**Primary platform:** macOS High Sierra 10.13  
**CPU support:** Intel x86_64 and Apple Silicon arm64  
**Primary priority:** Low memory usage and native performance.

Use the supplied RazonHX logo as the official branding reference. The logo consists of a geometric six-point star with a small crown above it, using mint/cyan neon colors.

Do not redesign the logo into an unrelated symbol.

## 2. Development Philosophy

This project will use a vibe-coding workflow.

Act as a senior macOS engineer and software architect.

Your responsibilities:

- Plan the implementation before coding.
- Inspect the existing repository before modifying files.
- Build features incrementally.
- Keep the architecture modular.
- Prioritize backward compatibility.
- Avoid unnecessary dependencies.
- Avoid overengineering.
- Keep memory consumption low.
- Never delete working functionality to implement a new feature.
- Never introduce fake functionality or placeholder interactions in completed features.
- Test implementations instead of assuming they work.

Do not stop after generating a project plan. Implement the actual application incrementally.

If a requirement is technically impossible on the target macOS version, explain the limitation and implement the closest supported alternative.

## 3. Final Technology Stack

### Core Engine
- Rust
- Cargo
- Modular Rust library architecture
- JSON configuration management

### Native UI
- Swift
- Swift 5 language compatibility
- AppKit
- Core Animation
- Core Graphics

### Communication
- C ABI / FFI bridge between Swift and Rust
- Opaque pointers for engine state
- C-compatible data structures
- Event-driven communication

### Build System
- Xcode
- Cargo
- GitHub Actions
- macOS application bundle (.app)

### Important restrictions
- Do not use SwiftUI.
- Do not use Electron.
- Do not use Tauri.
- Do not embed Chromium.
- Do not use unnecessary external UI frameworks.
- Prefer native macOS APIs.

## 4. Platform Compatibility

Build two separate application targets.

### Intel Build
- Architecture: x86_64
- Minimum deployment target: macOS 10.13
- Must support macOS High Sierra.
- Use only APIs available on macOS 10.13.

### Apple Silicon Build
- Architecture: arm64
- Minimum deployment target: macOS 11.0.
- Support Apple Silicon Macs.

Important: macOS High Sierra does not support Apple Silicon. Do not claim that High Sierra runs on M1/M2/M3/M4 machines.

Use shared source code wherever possible, with platform-specific implementations when required.

Use availability checks for APIs introduced after macOS 10.13.

Avoid modern Swift APIs unavailable on High Sierra.

## 5. Core Feature — RazonHX Wallpaper Engine

This is one of the most important features.

RazonHX must allow users to turn different media formats into desktop wallpapers.

### Supported formats

**HTML**
- Render local HTML files as desktop wallpapers.
- Use WKWebView.
- Support CSS animations.
- Support local JavaScript where explicitly enabled.
- Allow custom HTML wallpaper projects.
- Provide a sandboxed rendering environment.
- Disable unrestricted access to local files and external network resources by default.

**MP4**
- Play video wallpapers.
- Use AVFoundation.
- Support playback controls.
- Support looping.
- Support mute and volume settings.
- Support pause/resume.
- Provide automatic playback management.

**WAV**
WAV is an audio-only format, not a visual image or video.

Implement an audio-reactive wallpaper mode:
- Play WAV audio.
- Display an animated audio visualizer.
- Provide waveform and spectrum visualizations.
- Allow users to customize visualizer colors.
- Support looping and volume control.

**GIF**
- Support animated GIF wallpapers.
- Preserve animation.
- Support looping.
- Provide playback controls.

**PNG**
- Support static PNG wallpapers.
- Support scaling and cropping.
- Support fill, fit, stretch, and center positioning.

### Wallpaper Management

Create a complete wallpaper manager with:

- Drag and drop imports.
- File browser.
- Wallpaper preview.
- Favorites.
- Recently used wallpapers.
- Wallpaper categories.
- Wallpaper playlists.
- Custom wallpaper names.
- Delete and restore functionality where appropriate.
- Apply and remove wallpaper.
- Automatic wallpaper startup.
- Per-display wallpaper selection where supported.

### Performance requirements

- Avoid unnecessary video decoding.
- Pause animated wallpapers when appropriate.
- Stop rendering when the wallpaper is not visible.
- Avoid unnecessary frame updates.
- Release media resources when wallpapers are changed.
- Use efficient image caching.
- Prevent memory leaks.

Never load every wallpaper into memory simultaneously.

## 6. Core Feature — Full Desktop Customization

RazonHX must give users extensive control over their desktop appearance.

Create native floating desktop panels and customization tools.

Do not attempt to directly replace or modify protected Apple system components.

Use supported macOS APIs, native windows, and user-authorized integrations.

### RazonBar

Customizable floating top toolbar.

Features:
- Custom position.
- Custom height.
- Background opacity.
- Background blur where supported.
- Rounded corners.
- Border and accent color.
- Custom modules.
- Date and time.
- Battery indicator.
- Wi-Fi indicator.
- Volume indicator.
- Workspace indicator.
- Application indicator.
- Quick settings.

Allow users to enable, disable, reorder, and customize toolbar modules.

### RazonClock

A customizable desktop clock.

Features:
- Digital clock.
- Date display.
- 12-hour and 24-hour formats.
- Custom fonts.
- Custom colors.
- Custom alignment.
- Custom positioning.
- Transparency.
- Clock widgets.
- Optional seconds display.
- Multiple clock styles.

Provide a standalone floating clock and an integrated RazonBar clock.

Do not claim to replace Apple's native system clock unless using a supported and explicitly implemented integration.

### RazonDock

Create a customizable floating application dock.

Features:
- Dock position.
- Icon size.
- Icon spacing.
- Rounded corners.
- Background opacity.
- Background blur.
- Dock outline.
- Application shortcuts.
- Running application indicators.
- Favorites.
- Auto-hide.
- Custom animations.

### Desktop Appearance

Features:
- Accent colors.
- Background colors.
- Text colors.
- Transparency.
- Rounded corners.
- Border customization.
- Blur intensity where supported.
- Light and dark presets.
- Custom theme creation.

## 7. Additional Seelen UI-Inspired Features

Implement the following modules independently.

### RazonLauncher
- Application launcher.
- Search installed applications.
- Quick search.
- Keyboard shortcuts.
- Recently used applications.

### RazonWindow
- Window snapping.
- Basic window positioning.
- Window arrangement presets.
- Always-on-top utilities where supported.
- Require Accessibility permissions when necessary.

### RazonWorkspace
- Workspace indicator.
- Desktop switching shortcuts.
- Workspace customization where supported by macOS.

### RazonWidgets
- CPU usage.
- RAM usage.
- Battery information.
- Network information.
- Date and time.
- Custom desktop widgets.

### RazonThemes
- Theme presets.
- Custom accent colors.
- Theme import/export.
- Theme switching.
- Wallpaper and theme combinations.

### RazonProfiles
- Save desktop configurations.
- Import configurations.
- Export configurations.
- Create multiple profiles.
- Switch profiles quickly.

### RazonModules
- Central module manager.
- Enable and disable modules.
- Reorder modules.
- Configure individual modules.
- Load optional modules only when needed.

## 8. RazonHX Settings UI

Create a centralized native settings application.

Design inspiration:
- Seelen UI.
- macOS High Sierra.
- Dark glassmorphism.
- Mint/cyan neon accent.
- Rounded native panels.
- Minimal interface.

Primary color:
#62F5D0

Background:
#17191B

Secondary background:
#24282B

Text:
#E8F5F2

Settings sidebar:

1. Home
2. General
3. Appearance
4. Desktop
5. Wallpaper
6. Toolbar
7. Dock
8. Clock & Date
9. Launcher
10. Window Manager
11. Widgets
12. Themes
13. Profiles
14. Modules
15. Advanced
16. About RazonHX

Each section must have its own functional configuration interface.

Use native AppKit controls wherever practical.

## 9. Rust Core Architecture

Rust handles:

- Configuration management.
- Theme management.
- Wallpaper metadata.
- Module state.
- Application state.
- Resource management.
- File validation.
- Internal event handling.

Swift handles:

- Native windows.
- Menus.
- Settings interface.
- Floating panels.
- Desktop components.
- Native graphics and animations.
- macOS integrations.

Communication:

Swift AppKit
    |
    v
RazonHXBridge.h
    |
    v
Rust C ABI
    |
    v
RazonHX Core

Avoid excessive serialization.

Do not communicate through JSON on every animation frame.

## 10. Recommended Project Structure

Use this modular repository structure:

RazonHX/
|
|-- RazonHX.xcodeproj/
|
|-- Sources/
|   |
|   |-- App/
|   |   |-- RazonHXApp.swift
|   |   |-- AppDelegate.swift
|   |
|   |-- Interface/
|   |   |-- RazonBar/
|   |   |-- RazonDock/
|   |   |-- RazonClock/
|   |   |-- RazonLauncher/
|   |   |-- RazonSettings/
|   |
|   |-- Modules/
|   |   |-- Wallpaper/
|   |   |-- Themes/
|   |   |-- Widgets/
|   |   |-- Profiles/
|   |   |-- Window/
|   |   |-- Workspace/
|   |
|   |-- Components/
|   |   |-- Views/
|   |   |-- Panels/
|   |   |-- Animations/
|   |   |-- Controls/
|   |
|   |-- Bridge/
|       |-- RazonHXBridge.h
|       |-- RazonHXBridge.swift
|
|-- razon-core/
|   |
|   |-- Cargo.toml
|   |-- src/
|       |-- lib.rs
|       |-- config/
|       |-- engine/
|       |-- events/
|       |-- modules/
|       |-- themes/
|       |-- wallpaper/
|       |-- system/
|       |-- ffi/
|
|-- Resources/
|   |-- Assets.xcassets/
|   |-- Icons/
|   |-- Wallpapers/
|   |-- Themes/
|   |-- Logo/
|
|-- Config/
|   |-- default.json
|
|-- Tests/
|   |-- SwiftTests/
|   |-- RustTests/
|
|-- .github/
|   |-- workflows/
|       |-- build.yml
|
|-- README.md
|-- LICENSE
|-- .gitignore

Adjust the structure when technically necessary, but preserve modular boundaries.

## 11. Memory Optimization

Memory efficiency is the highest engineering priority.

Requirements:

- Use one main application process wherever practical.
- Avoid unnecessary helper processes.
- Use lazy module initialization.
- Avoid continuous polling.
- Prefer event-driven updates.
- Avoid retaining unused image buffers.
- Release video resources when playback stops.
- Use bounded caches.
- Avoid loading unused assets.
- Use native rendering.
- Avoid unnecessary background timers.
- Profile actual memory consumption.

Initial experimental targets:

- Idle memory: approximately 30–50 MB.
- Normal usage: approximately 50–90 MB.
- Heavy usage: approximately 90–130 MB.

These are engineering targets, not guaranteed benchmarks.

Measure memory footprint and real RAM behavior on actual Intel hardware.

Do not sacrifice stability to achieve an arbitrary memory target.

## 12. GitHub Actions — Automatic Builds

All application builds must be automated through GitHub Actions.

Do not require the user to manually compile every release.

Create:

.github/workflows/build.yml

Requirements:

- Trigger on push to main.
- Trigger on pull requests.
- Trigger on version tags such as v1.0.0.
- Build Intel x86_64.
- Build Apple Silicon arm64.
- Run Rust tests.
- Run Swift tests where supported.
- Compile the native macOS application.
- Package the resulting .app.
- Upload build artifacts.
- Publish release assets when a version tag is pushed.

### Build matrix

Intel:
- Target: x86_64-apple-darwin.
- Deployment target: macOS 10.13.
- Test on a real High Sierra machine.

Apple Silicon:
- Target: aarch64-apple-darwin.
- Deployment target: macOS 11.0.

Use supported GitHub-hosted macOS runners.

Pin the Xcode version and Rust toolchain where practical.

Do not assume that building successfully on a modern macOS runner guarantees compatibility with High Sierra.

Validate the final Intel binary on macOS 10.13.

### Build outputs

Generate:

- RazonHX-Intel.zip
- RazonHX-AppleSilicon.zip

Each archive should contain a correctly structured macOS application bundle.

Optionally generate signed and notarized releases for supported distribution targets.

Never hardcode signing certificates, private keys, or credentials in source code.

Use GitHub Actions Secrets when signing is configured.

For unsigned development builds, document Gatekeeper and installation considerations.

## 13. Development Roadmap

Build in the following order.

Phase 1 — Foundation:
- Xcode project.
- Rust core.
- C ABI bridge.
- Configuration manager.
- Basic application lifecycle.

Phase 2 — Wallpaper Engine:
- PNG.
- GIF.
- MP4.
- HTML.
- WAV audio visualizer.
- Wallpaper manager.

Phase 3 — Desktop Customization:
- RazonBar.
- RazonDock.
- RazonClock.
- Theme engine.

Phase 4 — Settings:
- General.
- Appearance.
- Toolbar.
- Dock.
- Wallpaper.
- Clock.

Phase 5 — Additional Modules:
- Launcher.
- Widgets.
- Window utilities.
- Workspace.
- Profiles.

Phase 6 — Optimization:
- Memory profiling.
- CPU profiling.
- Resource cleanup.
- Compatibility testing.

Phase 7 — Release:
- GitHub Actions.
- Intel package.
- Apple Silicon package.
- Documentation.
- Versioned releases.

## 14. Quality Requirements

- Every implemented feature must work.
- No fake settings.
- No dead buttons.
- No hardcoded demonstration data presented as live system data.
- No unnecessary dependencies.
- No unsafe file access.
- Validate imported files.
- Handle corrupted media gracefully.
- Handle missing permissions gracefully.
- Provide useful error messages.
- Preserve user settings across restarts.
- Do not overwrite user configuration unexpectedly.
- Maintain clean code and documentation.

## 15. Initial Development Instructions

Before implementation:

1. Inspect the repository.
2. Check the installed Rust and Xcode toolchains.
3. Verify the macOS deployment targets.
4. Create the project structure.
5. Establish the Swift-to-Rust bridge.
6. Build a minimal working application.
7. Verify the application bundle.
8. Set up GitHub Actions.
9. Test the Intel deployment configuration.
10. Document known platform limitations.

Then begin implementing Phase 1.

Do not attempt to implement every module in one enormous code change.

Work incrementally, compile frequently, and fix errors before moving to the next feature.

## Final Goal

Deliver RazonHX as a real, native, memory-efficient macOS desktop customization application.

The final application should combine:

- An animated wallpaper engine.
- Full customizable desktop overlays.
- Custom toolbar and clock.
- Custom dock.
- Application launcher.
- Themes and profiles.
- Modular desktop widgets.
- Native macOS integration.
- Automated GitHub Actions builds.

The result must be a working application, not merely a UI mockup or prototype.

**RazonHX — Redefine Your Desktop.**