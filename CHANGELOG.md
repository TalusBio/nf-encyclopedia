# nf-encyclopedia Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]
### Changed
- Updated EncyclopeDIA parameters to match GUI defaults.
- Retries should automatically occur when MSconvert hangs
- The library file used for the EncyclopeDIA global step is now the DLIB/ELIB
  the files were searched against. This has not affect on workflows that were
  not using a chromatogram library.

### Added
- Added full support for MSstats
- Support for Walnut (Pecan).

### Removed
- The aggregate option, which was problematic because only one library can be specified.

## [0.5.0] - 2022-08-26
### Changed
- Parameters updated to be more user-friendly.
- Scripts are now in the `bin` directory, instead of the Docker containers.
- Used logic from nf-core to scale resources on retries.
- Now using the email argument again to get a custom message.
- Removed the use of `storeDir`

### Added
- Reports for pipeline runs.
- Created a public nf-encyclopedia Docker image for everything except msconvert.
- A nearly complete system test using small mzML files.

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
