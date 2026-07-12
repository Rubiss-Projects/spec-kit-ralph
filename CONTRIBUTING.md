# Contributing to Ralph Loop

Thanks for your interest in contributing. Bug reports, feature requests, documentation improvements, and pull requests are welcome.

## Before You Start

- Search existing issues and pull requests to avoid duplicating work.
- For a substantial change, open an issue first so the approach and scope can be discussed.
- Read the relevant feature's `plan.md` under `specs/<feature>/` and the project constitution at `.specify/memory/constitution.md` when your change affects extension behavior or architecture.
- Ralph supports Bash on macOS/Linux and PowerShell on Windows. Changes to orchestration behavior must preserve equivalent behavior across both implementations.

## Making a Change

1. Fork the repository and create a focused branch from the latest `main`:

   ```bash
   git checkout main
   git pull --ff-only
   git checkout -b feat/short-description
   ```

2. Make the smallest coherent change. Add or update regression coverage for behavior changes and update user-facing documentation when applicable.
3. Add a concise entry under `## [Unreleased]` in `CHANGELOG.md` for every user-visible change. Use the existing Keep a Changelog categories, such as `Added`, `Changed`, or `Fixed`. Do not update the version in `extension.yml`; the release workflow owns version bumps.
4. Run both regression suites from the repository root:

   ```bash
   bash tests/regression/bash/test-ralph-loop.sh
   pwsh -NoLogo -NoProfile -File tests/regression/powershell/Test-RalphLoop.ps1
   ```

5. Commit with a clear, imperative message. Include the related issue number when one exists.
6. Push your branch and open a pull request against `main` (not `master`).

## Pull Request Guidelines

- Keep each pull request focused on one feature, fix, or documentation change.
- Explain what changed, why it changed, and any compatibility or design tradeoffs.
- Link related issues and include reproduction steps for bug fixes.
- Report the validation commands you ran and their results. If you could not run a suite, explain why.
- Keep Bash and PowerShell implementations, tests, diagnostics, and documentation in sync when changing shared behavior.
- Confirm that `CHANGELOG.md` and relevant documentation are current and that no credentials, local configuration, or generated artifacts are included.
- Ensure CI passes. A maintainer must review and approve the pull request before it is merged.

## Reporting Issues

Open an issue with a clear description of the bug or proposed feature. For bugs, include your operating system, shell and agent CLI versions, configuration with secrets removed, steps to reproduce, expected behavior, actual behavior, and relevant logs or error output.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
