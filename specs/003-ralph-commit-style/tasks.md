# Tasks: Configurable Ralph Commit Style

**Input**: Design documents from `specs/003-ralph-commit-style/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Required by SC-001 through SC-007, the Script Gate, the Compatibility Gate, and the quickstart validation scenarios. Regression tasks appear before implementation tasks in each user-story phase.

**Organization**: Tasks are grouped by user story to preserve independent implementation and validation of default legacy behavior, opt-in conventional formatting, and optional issue auto-linking.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel after stated prerequisites because it touches different files
- **[Story]**: Maps the task to US1, US2, or US3
- Every task names the exact file or files it changes or validates

## Phase 1: Setup — Shared Commit Policy Assets

**Purpose**: Create reusable nested-configuration fixtures and reference inputs shared by all commit-style scenarios.

- [x] T001 Create a legacy-style commit config fixture in `tests/regression/fixtures/ralph-config-legacy.yml`
- [x] T002 [P] Create a conventional-style commit config fixture in `tests/regression/fixtures/ralph-config-conventional.yml`
- [x] T003 [P] Create invalid nested and flattened commit-policy fixtures and document the new fixture set in `tests/regression/fixtures/ralph-config-invalid.yml` and `tests/regression/fixtures/README.md`

**Checkpoint**: Shared config inputs exist for default, conventional, and invalid-style regression scenarios.

---

## Phase 2: Foundational — Shared Commit Policy Plumbing

**Purpose**: Add the cross-platform nested `commit:` block parsing and commit policy resolution that every user story depends on.

**⚠️ CRITICAL**: No user-story work should begin until this phase is complete.

- [x] T004 Implement nested `commit:` block parsing, default resolution, invalid-style validation, invalid flattened-shape detection, and branch-prefix issue inference helpers in `scripts/bash/ralph-loop.sh`
- [x] T005 [P] Implement parity nested `commit:` block parsing, default resolution, invalid-style validation, invalid flattened-shape detection, and branch-prefix issue inference helpers in `scripts/powershell/ralph-loop.ps1`
- [x] T006 Update policy-aware work-unit commit instructions, legacy-default behavior, and invalid-style stop conditions in `commands/iterate.md`

**Checkpoint**: Both orchestrators can resolve one normalized commit policy before any completed work-unit commit is attempted.

---

## Phase 3: User Story 1 — Keep Existing Commit Behavior by Default (Priority: P1) 🎯 MVP

**Goal**: Preserve today's Ralph commit subject exactly when no commit config is present and when `commit.style: legacy` is set explicitly.

**Independent Test**: Run a completed Ralph work unit with no commit config and with `commit.style: legacy`; both scenarios must produce the current legacy subject format unchanged on Bash and PowerShell paths.

### Tests for User Story 1

> Write these tests first and confirm the new cases fail before implementation.

- [x] T007 [P] [US1] Add Bash regression scenarios asserting the exact legacy subject `feat(<feature-name>): <work-unit title>` for no-config behavior and explicit `commit.style: legacy` in `tests/regression/bash/test-ralph-loop.sh`
- [x] T008 [P] [US1] Add equivalent PowerShell regression scenarios asserting the exact legacy subject `feat(<feature-name>): <work-unit title>` for no-config behavior and explicit `commit.style: legacy` in `tests/regression/powershell/Test-RalphLoop.ps1`

### Implementation for User Story 1

- [x] T009 [US1] Wire the resolved legacy-default commit policy into completed work-unit commit creation in `scripts/bash/ralph-loop.sh`
- [x] T010 [US1] Wire the resolved legacy-default commit policy into completed work-unit commit creation in `scripts/powershell/ralph-loop.ps1`
- [x] T011 [US1] Run the US1 independent legacy/no-config parity scenarios in `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`

**Checkpoint**: Existing projects keep their current commit history shape with or without explicit `legacy` style configuration.

---

## Phase 4: User Story 2 — Opt In to Cleaner Conventional Commits (Priority: P2)

**Goal**: Support opt-in conventional commit subjects with configurable or default scope, while rejecting unsupported explicit style values clearly.

**Independent Test**: Configure `commit.style: conventional` with and without a scope, then verify Ralph creates conventional work-unit commit subjects with the expected scope; verify an unsupported explicit style stops before commit creation with a clear error.

### Tests for User Story 2

> Write these tests first and confirm the new cases fail before implementation.

- [x] T012 [P] [US2] Add Bash regression scenarios for explicit-scope conventional commits, default-scope `feat(ralph): ...` conventional commits, unsupported explicit styles, and invalid flattened config shape in `tests/regression/bash/test-ralph-loop.sh`
- [x] T013 [P] [US2] Add equivalent PowerShell regression scenarios for explicit-scope conventional commits, default-scope `feat(ralph): ...` conventional commits, unsupported explicit styles, and invalid flattened config shape in `tests/regression/powershell/Test-RalphLoop.ps1`

### Implementation for User Story 2

- [x] T014 [US2] Implement conventional subject formatting and default-scope `ralph` handling in `scripts/bash/ralph-loop.sh`
- [x] T015 [US2] Implement parity conventional subject formatting and default-scope `ralph` handling in `scripts/powershell/ralph-loop.ps1`
- [x] T016 [US2] Align the public conventional commit contract examples in `commands/iterate.md` and `specs/003-ralph-commit-style/contracts/work-unit-commit-format.md`
- [x] T017 [US2] Run the US2 conventional/default-scope/invalid-style scenarios in `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`

**Checkpoint**: Opt-in conventional commit generation works consistently across both platforms and invalid explicit styles fail fast before commit creation.

---

## Phase 5: User Story 3 — Link Commits Back to the Issue Automatically (Priority: P3)

**Goal**: Append an inferred issue suffix when `commit.issue: auto` is enabled, for both legacy and conventional commit styles, without failing when no numeric branch prefix exists.

**Independent Test**: Run Ralph on numeric-prefix and non-prefix branches with `commit.issue: auto` enabled for both legacy and conventional styles; verify the suffix appears only when inference succeeds and never blocks commit creation when it does not.

### Tests for User Story 3

> Write these tests first and confirm the new cases fail before implementation.

- [x] T018 [P] [US3] Add Bash regression scenarios for numeric-prefix inference, no-prefix fallback, and legacy-plus-issue-auto behavior in `tests/regression/bash/test-ralph-loop.sh`
- [x] T019 [P] [US3] Add equivalent PowerShell regression scenarios for numeric-prefix inference, no-prefix fallback, and legacy-plus-issue-auto behavior in `tests/regression/powershell/Test-RalphLoop.ps1`

### Implementation for User Story 3

- [x] T020 [US3] Implement conditional issue-suffix appending for both legacy and conventional commit styles in `scripts/bash/ralph-loop.sh`
- [x] T021 [US3] Implement parity conditional issue-suffix appending for both legacy and conventional commit styles in `scripts/powershell/ralph-loop.ps1`
- [x] T022 [US3] Update the public config and issue-linking contract guidance in `commands/iterate.md`, `specs/003-ralph-commit-style/contracts/commit-config-schema.md`, and `specs/003-ralph-commit-style/contracts/work-unit-commit-format.md`
- [x] T023 [US3] Run the US3 issue-auto parity scenarios in `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`

**Checkpoint**: Issue auto-linking works for both commit styles, omits the suffix safely when inference fails, and remains consistent across Bash and PowerShell.

---

## Phase 6: Polish & Cross-Cutting Validation

**Purpose**: Finish user-facing documentation, installed-extension compatibility checks, and full validation.

- [x] T024 Update user-facing commit configuration guidance and examples in `README.md` and `ralph-config.template.yml` to require the nested `commit:` block
- [x] T025 [P] Reconcile the runnable validation guide and installed-extension expectations, including exact legacy and default-scope `ralph` examples, in `specs/003-ralph-commit-style/quickstart.md`
- [x] T026 [P] Verify development-extension installation and generated project config behavior using `README.md`, `ralph-config.template.yml`, and `specs/003-ralph-commit-style/quickstart.md`
- [x] T027 Run `bash -n`, PowerShell parser validation, both regression suites, `git diff --check`, and the quickstart validation matrix against `scripts/bash/ralph-loop.sh`, `scripts/powershell/ralph-loop.ps1`, `tests/regression/bash/test-ralph-loop.sh`, `tests/regression/powershell/Test-RalphLoop.ps1`, `README.md`, and `ralph-config.template.yml`

---

## Phase 7: Reopened Work — Enforce Nested `commit:` Config Shape

**Purpose**: Bring runtime behavior and regression coverage into line with the refined spec that requires a nested `commit:` block and rejects flattened commit-policy keys.

- [x] T028 Create fixture coverage for both unsupported nested style values and invalid flattened commit-policy keys in `tests/regression/fixtures/ralph-config-invalid.yml` and `tests/regression/fixtures/README.md`
- [x] T029 Implement explicit invalid flattened-shape detection so Bash and PowerShell reject `commit.style`, `commit.scope`, and `commit.issue` outside the nested `commit:` block in `scripts/bash/ralph-loop.sh` and `scripts/powershell/ralph-loop.ps1`
- [x] T030 Add mirrored Bash and PowerShell regression scenarios proving flattened config keys fail clearly while valid nested `commit:` blocks still work in `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`
- [x] T031 Reconcile quickstart and fixture documentation so user-facing examples consistently show the nested `commit:` block in `specs/003-ralph-commit-style/quickstart.md` and `tests/regression/fixtures/README.md`
- [x] T032 Run the targeted Bash and PowerShell regression selectors plus syntax checks for the reopened nested-config scenarios in `tests/regression/bash/test-ralph-loop.sh`, `tests/regression/powershell/Test-RalphLoop.ps1`, `scripts/bash/ralph-loop.sh`, and `scripts/powershell/ralph-loop.ps1`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 — Setup**: No dependencies; can start immediately.
- **Phase 2 — Foundational**: Depends on Phase 1 and blocks all user stories.
- **Phase 3 — US1**: Depends on Phase 2.
- **Phase 4 — US2**: Depends on Phase 2 and builds on the shared commit policy plumbing.
- **Phase 5 — US3**: Depends on Phase 2 and on the completion of US1 and US2 because it extends their resolved subject behavior.
- **Phase 6 — Polish**: Depends on all selected user stories being complete.
- **Phase 7 — Reopened Work**: Depends on Phase 6 and captures the post-review nested-config enforcement delta before declaring the feature complete again.

### User Story Dependency Graph

```text
Shared Config Fixtures (T001-T003)
  └─> Commit Policy Plumbing (T004-T006)
        ├─> US1 Legacy Default (T007-T011)
        └─> US2 Conventional Scope (T012-T017)
              └─> US3 Issue Auto-Linking (T018-T023)
                    └─> Polish & Validation (T024-T027)
                          └─> Reopened Nested Config Enforcement (T028-T032)
```

### User Story Independence

- **US1 (P1)**: Independently testable after Phase 2 with no config and explicit `legacy` config scenarios.
- **US2 (P2)**: Independently testable after Phase 2 with conventional scope and invalid-style scenarios.
- **US3 (P3)**: Independently testable after US1 and US2 are complete, using numeric-prefix and no-prefix branch scenarios on top of the established legacy and conventional subject behavior.
- **Phase 7 reopened delta**: Independently testable after the original feature is complete by proving flattened keys are rejected and nested examples remain the only documented shape.

### Within Each User Story

- Add Bash and PowerShell regression scenarios first and confirm they fail before implementation.
- Implement Bash and PowerShell behavior in parallel where files do not overlap.
- Update shared public contract text after the runtime behavior is defined.
- Run the story-specific independent scenarios before moving to the next story.

### Requirement Coverage

| Requirement Set | Covered By |
|---|---|
| FR-001, FR-002, FR-012 legacy default preservation | T007-T011 |
| FR-003, FR-004, FR-005 nested config shape and supported style values | T004-T006, T024 |
| FR-006, FR-011 conventional scope behavior and predictable conventional subject formatting | T004-T006, T012-T017 |
| FR-007, FR-008, FR-009, FR-010 issue auto-linking and no-prefix fallback | T018-T023 |
| FR-013 documentation and FR-014 parity | T024-T027, T031-T032 |
| FR-015 invalid explicit style and invalid config shape handling | T028-T032 |

## Parallel Opportunities

### Setup

After T001, T002 and T003 can run in parallel because they create separate fixture files and fixture notes.

### User Story 1

```text
Parallel tests:          T007 (Bash) + T008 (PowerShell)
Parallel implementation: T009 (Bash) + T010 (PowerShell)
Join:                    T011
```

### User Story 2

```text
Parallel tests:          T012 (Bash) + T013 (PowerShell)
Parallel implementation: T014 (Bash) + T015 (PowerShell)
Contract/doc alignment:  T016 after T014 and T015
Join:                    T017
```

### User Story 3

```text
Parallel tests:          T018 (Bash) + T019 (PowerShell)
Parallel implementation: T020 (Bash) + T021 (PowerShell)
Contract/doc alignment:  T022 after T020 and T021
Join:                    T023
```

### Polish

```text
Parallel documentation:  T024 + T025
Installed validation:    T026 after T024 and T025
Final join:              T027 after T026
```

### Reopened Nested Config Enforcement

```text
Parallel implementation: T029 (Bash + PowerShell in one coordinated change)
Parallel tests/docs:     T030 + T031 after T029
Final join:              T032 after T030 and T031
```

## Implementation Strategy

### MVP First — User Story 1

1. Complete Phase 1 to establish shared config fixtures.
2. Complete Phase 2 to resolve commit policy consistently in both orchestrators.
3. Complete Phase 3 and validate the no-config and explicit `legacy` scenarios.
4. Stop and verify Ralph still produces the current legacy commit subject unchanged.

### Incremental Delivery

1. **Foundation**: Shared fixtures plus policy resolution and validation.
2. **US1**: Preserve existing commit behavior (MVP).
3. **US2**: Add opt-in conventional commit formatting with configurable/default scope.
4. **US3**: Add optional issue auto-linking across both styles.
5. **Polish**: Finalize docs, installed-extension behavior, and full regression coverage.
6. **Reopened delta**: Enforce nested-only config validity and close the flattened-key gap.

### Parallel Team Strategy

With multiple developers:

1. One developer completes Phase 1 and coordinates the shared fixture contract.
2. After Phase 2, one developer can take Bash tasks while another takes PowerShell parity tasks within the same story.
3. Documentation and quickstart work can proceed in parallel during Phase 6 after runtime behavior stabilizes.

## Notes

- `[P]` means parallel only after the listed prerequisite tasks complete and only when no file overlaps remain.
- `commands/iterate.md` is intentionally updated in foundational and story tasks because it defines the public agent contract for generated commit subjects.
- Keep the legacy subject truly unchanged for no-config projects; new behavior must be opt-in except for explicit invalid-style failures.
- Do not introduce new runtime dependencies for config parsing or issue inference.
- Phase 7 exists because the refined spec now makes nested `commit:` shape enforcement normative; the current implementation parses nested config but does not yet clearly reject flattened keys across both platforms.
