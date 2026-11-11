# Incremental roadmap

## Phase 1 — Foundation (this increment)

- [x] Requested modular structure, original logo and independent visual styling.
- [x] Separate Xcode targets, native lifecycle and settings shell.
- [x] Rust config/state, opaque C ABI, explicit ownership and internal events.
- [x] Persistent functional General/Appearance settings and recovery controls.
- [x] Rust/native bridge tests, bundle metadata verification and automated packaging.
- [ ] Interactive AppKit acceptance and Intel High Sierra real-hardware validation.

## Phase 2 — Wallpaper engine (next)

Implement in order: PNG → GIF → MP4 → restricted local HTML → WAV visualizer → library manager. Each increment must include validation, real previews, per-display lifecycle, resource cleanup and tests before its sidebar section becomes active. Do not eagerly decode every imported file. Verify GIF frame timing, video observer/loop cleanup, HTML path traversal/subresource/network restrictions and real WAV waveform/spectrum data. Library features include drag/drop, names, categories, favorites, recents, playlists and reversible deletion.

## Phase 3 — Desktop customization

RazonBar, RazonDock, RazonClock, actual native theme application. Implement module state in Rust, panels/rendering in Swift. Only expose supported/native system indicators with genuine measurements.

## Phase 4 — Settings expansion

Desktop, Wallpaper, Toolbar, Dock and Clock interfaces bound to the actual native renderers. Expand the versioned schema with deliberate migration tests; do not silently default away existing settings.

## Phase 5 — Additional modules

Launcher, Accessibility-authorized window utilities, supported workspace integrations, genuine system widgets, themes, profiles and central lazy module manager. No private Space APIs or claims to replace protected system components.

## Phase 6 — Optimization

Measure CPU, energy and physical memory on real Intel hardware and Apple Silicon. Add visibility/power-driven playback suspension and bounded caches as renderers arrive. Test repeated media switching and permission failures. Document measurements rather than guaranteeing brief targets.

## Phase 7 — Release

Architecture-specific packages are automated now. Before a stable release, finish acceptance, High Sierra testing, media security review and performance profiling. Signing/notarization remains optional and secrets-backed. Create a version tag only with the maintainer's release approval.
