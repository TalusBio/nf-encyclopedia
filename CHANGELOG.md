# nf-encyclopedia Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2022-07-19
### Changed
- Removed email argument in favor of using the default `nextflow run -N <email>`.
- Removed `debug` and `echo` statements from modules.

## [0.4.1] - 2022-07-12
### Fixed
- Updated GitHub Actions release workflow.

## [0.4.0] - 2022-07-12
### Added
- This changelog!
- Completely reworked pipeline since last release. Note that we were just using the `main` branch as our release version, but I prefer occasional manual releases for stability.
