# Change Log

All notable changes to this project will be documented in this file (at least to the extent possible, I am not infallible sadly).
This project adheres to [Semantic Versioning](http://semver.org/).

## 2.4.0

### Fixed

- Fixed issues with utf8 handling in conform escript
- Fixed issue in releases with default validators causing parse issues
- No longer colorizing output if run non-interactively
- Fixed handling of build path in umbrellas

### Added

- Syntax highlighting of effective configuration when a tty is attached

## 2.3.4

### Fixed

- Fixed compatibility with OTP 20

## 2.3.3

### Fixed

- #122 - generated config with keyword-like lists is syntactically invalid
- #96 - Print warning instead of failing when generating .conf with unknown types

## 2.2.2

### Fixed

- Bug in release plugin with umbrellas

## 2.2.1

### Added

- Support for getting default values from environment

## 2.2.0

### Added

- New, improved docs

### Changed

- Require Elixir 1.3
- `.conf` files are now generated with env as part of the extension, e.g. `.prod.conf`,
 this change is backwards compatible, as it will fallback to looking for just `.conf`
- Use `pre_configure` hook in Distillery 1.2

### Fixed

- Fixed incorrect documentation
- Fallback to `$CWD/config` if app-specific config doesn't exist for umbrella app (#95)
- Improve readability of `conform.effective` task
- Improve handling of complex types to reduce need for transforms
- Fix loading of modules when in a release
- Fix loading of plugins when debug info is stripped
- Fail nicely if no .conf is present when running conform.effective (#65)
- Fix handling of raw binaries (#75)
- Fix handling of single-element nested lists (#68)
- Fix handling of mixed lists or other odd complex types (#47)
- Fix issue with schema stringification (#85)
- Fix incorrect charlist detection (#107)
- Ensure quoted/unquoted strings are both handled in tests
- Remove hardcoded typing for two-element tuples (#102)


## 2.1.1

- Fixed stringification of guard clauses

## 2.1.0

### Added

- Support for `distillery`

### Fixed

- Compiler warnings with 1.3

## 2.0.0
### Added
- Bundled prod escript, for consumption by third-parties, such as conform_exrm
- Added changelog
### Removed
- conform.release task
