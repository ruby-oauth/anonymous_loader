# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.1.2] - 2026-06-22

- TAG: [v0.1.2][0.1.2t]
- COVERAGE: 96.33% -- 105/109 lines in 2 files
- BRANCH COVERAGE: 81.58% -- 31/38 branches in 2 files
- 88.89% documented

### Added

- Added support for JRuby 10.1 and TruffleRuby 34.0.

### Changed

- Retemplated project metadata and CI/development automation with `kettle-jem` v7.0.0.

## [0.1.1] - 2026-06-18

- TAG: [v0.1.1][0.1.1t]
- COVERAGE: 96.33% -- 105/109 lines in 2 files
- BRANCH COVERAGE: 81.58% -- 31/38 branches in 2 files
- 88.89% documented

### Fixed

- Fixed `$LOAD_PATH` version validation when the requested Ruby file and the
  adjacent version file live at different directory depths.

## [0.1.0] - 2026-06-18

- TAG: [v0.1.0][0.1.0t]
- COVERAGE: 96.33% -- 105/109 lines in 2 files
- BRANCH COVERAGE: 81.58% -- 31/38 branches in 2 files
- 88.89% documented
- Initial release

### Added

- Added the initial anonymous namespace loader API with explicit path,
  RubyGems metadata, and `$LOAD_PATH` resolution strategies.

[Unreleased]: https://github.com/ruby-oauth/anonymous_loader/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/ruby-oauth/anonymous_loader/compare/v0.1.1...v0.1.2
[0.1.2t]: https://github.com/ruby-oauth/anonymous_loader/releases/tag/v0.1.2
[0.1.1]: https://github.com/ruby-oauth/anonymous_loader/compare/v0.1.0...v0.1.1
[0.1.1t]: https://github.com/ruby-oauth/anonymous_loader/releases/tag/v0.1.1
[0.1.0]: https://github.com/ruby-oauth/anonymous_loader/compare/eb9b54b0b8a62d8982ed17605a22ed259ac48b24...v0.1.0
[0.1.0t]: https://github.com/ruby-oauth/anonymous_loader/releases/tag/v0.1.0
