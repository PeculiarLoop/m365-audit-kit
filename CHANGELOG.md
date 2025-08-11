# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/){:target="_blank"} and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). To learn more about the rationale behind this structure, see the Keep a Changelog guidelines which emphasize clarity and ease of consumption for humans and machines.

## [Unreleased]

### Added
- Initial repository scaffold including root-level policies and contribution guidelines.
- Continuous integration workflow for linting and testing across Windows, Linux, and macOS.
- Placeholder module structure under `/src/M365AuditKit`.
- Basic documentation including `README`, `CODE_OF_CONDUCT`, `CONTRIBUTING`, `SECURITY`, and `LICENSE` files.


## [1.0.0] - 2025-08-11

### Added

- Introduced a Windows-only WPF/XAML GUI (virtuALLY) with dark theme and hacker green accents.
- Added unified authentication cmdlet `Connect-M365AuditKit` supporting app-only and delegated flows.
- Added quick audit and investigation cmdlets with normalized output and export helpers.
- Implemented YAML-based rule engine with HIPAA/NIST/CIS mappings.
- Added export helpers for HTML, CSV, JSON and Markdown with dark theme.
- Added Pester tests and GitHub Actions CI.

### Changed

- Structured source tree into `Public`, `Private`, `gui`, `rules`, `docs`, `tests` and `sample_output`.

### Fixed

- Initial release of enhanced audit kit.
