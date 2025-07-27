# Contributing to M365 Audit Kit

Thank you for your interest in contributing! This project adheres to the Contributor Covenant code of conduct. By participating in this project you agree to abide by the Code of Conduct.

## Reporting Bugs

Please search existing issues before opening a new bug report. When reporting a bug include steps to reproduce, expected vs. actual behaviour, and any relevant error output. **Do not** include tenant identifiers, secrets, or sensitive data in issues or pull requests.

## Feature Requests and Improvements

We welcome suggestions and enhancements. For major changes, open an issue to discuss the proposal first. Once consensus is reached, submit a pull request from your feature branch.

## Development Environment

- Use **PowerShell 7.2+** and ensure the required modules (`Microsoft.Graph`, `ExchangeOnlineManagement`, `PSScriptAnalyzer`, `Pester`, `platyPS`) are installed.
- Run `Invoke-ScriptAnalyzer` locally; warnings are acceptable but errors must be addressed.
- Write **Pester** tests for new functions with ≥80 % line coverage. Name test files `*.Tests.ps1` and use `Describe`/`Context`/`It` blocks.
- Provide comment‑based help for every public function and update the external Markdown help via platyPS.

## Commit and Pull Request Guidelines

- Follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g., `feat:`, `fix:`, `docs:`, `chore:`).
- Create feature branches off the latest main branch (e.g., `pr-<issue-number>-<description>`).
- Reference the related issue number in your pull request description.
- Each PR should include associated tests and documentation updates. Update `CHANGELOG.md` using [Keep a Changelog](https://keepachangelog.com/) format.

## Security and Privacy

Never commit secrets, certificates, tenant IDs, user data, or electronic protected health information (ePHI). See `SECURITY.md` for information on reporting vulnerabilities. Contributions that expose sensitive data will be rejected.

## License Agreement

By submitting a contribution, you agree that it will be licensed under the MIT License in the repository. Ensure that any reused code complies with permissive licences (MIT, Apache‑2.0, BSD‑3) and include notices in `THIRD_PARTY_NOTICES.md`.
