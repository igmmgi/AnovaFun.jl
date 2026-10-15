# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - Unreleased

### Changed

- **Breaking:** CairoMakie is no longer a dependency. Load a Makie backend yourself (`using CairoMakie` or `using GLMakie`) to display or save plots.
- Faster package load, as CairoMakie is no longer loaded with AnovaFun.
- Updated `show` methods for result types.
- Widened `CSV` compat to `0.10, 1.1`.

### Added

- README note on loading a Makie backend.
- This changelog.

## [0.3.0] - 2026-03-12

- Fixed a bug in `fstat`.
- Refactored plotting code and settings.

## [0.2.0] - 2026-03-10

- Added `DataFrame` methods for the t-test functions.

Earlier and intermediate releases: see the [git history](https://github.com/igmmgi/AnovaFun.jl/commits/main).
