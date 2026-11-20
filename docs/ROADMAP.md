# Incremental roadmap

## Available in the desktop increment

- Native settings, per-display toolbar/dock with independent pointer-proximity modes, desktop clock and system widget.
- PNG and GIF through AppKit; looping MP4 through AVFoundation; restricted, self-contained HTML through WebKit; WAV waveform from decoded samples.
- Managed imports, previews, per-display assignments, categories, favorites and reversible archive.
- App search and recents, explicit Accessibility authorization for window placement, theme presets and profile import/export.
- Legacy configuration fallback, typed Rust validation and atomic settings writes.

## Remaining work

- Native and real-hardware acceptance, especially Intel High Sierra and multi-display Spaces. Verify pointer tracking, power behavior, media timing and WebKit restrictions on both architectures.
- Flesh out media management with scheduled playlists, and add WAV spectrum and richer playback policies. External assets and JavaScript are intentionally excluded from the current HTML format.
- Add configurable toolbar modules, additional clock/widget styles, workspace actions limited to public APIs, and richer window behavior where the OS permits it.
- Measure CPU, energy and physical memory with Activity Monitor/Instruments; do not claim targets until measured.
- Revisit signing/notarization separately. Release tags require maintainer approval.
