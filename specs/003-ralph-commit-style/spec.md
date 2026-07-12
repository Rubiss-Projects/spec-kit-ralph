# Feature Specification: Configurable Ralph Commit Style

**Feature Branch**: `003-issue-30`

**Created**: 2026-07-12

**Status**: Draft

**Input**: GitHub issue [#30](https://github.com/Rubiss-Projects/spec-kit-ralph/issues/30) - "Add configurable Ralph commit style with scope and issue auto-linking"

## Clarifications

### Session 2026-07-12

- Q: Should automatic issue linking apply only to conventional commits or to both supported commit styles? → A: Apply issue auto-linking to both `legacy` and `conventional` commit styles.
- Q: How should Ralph handle an invalid `commit.style` value? → A: Stop with a clear configuration error.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep Existing Commit Behavior by Default (Priority: P1)

As a Ralph user with an existing project, I want commit behavior to remain unchanged unless I opt in so that upgrading does not alter my current workflow or history format.

**Why this priority**: Backward compatibility is the primary requirement because Ralph already creates commits for completed work units in active projects.

**Independent Test**: Run a completed Ralph work unit in a project with no commit configuration and verify the resulting commit message matches the current legacy format exactly.

**Acceptance Scenarios**:

1. **Given** a project with no commit configuration, **When** Ralph creates a commit for a completed work unit, **Then** the commit message uses the current legacy format with no behavior change.
2. **Given** a project with `commit.style` set to `legacy`, **When** Ralph creates a commit for a completed work unit, **Then** the commit message uses the same legacy format as today.

---

### User Story 2 - Opt In to Cleaner Conventional Commits (Priority: P2)

As a Ralph user who prefers cleaner history, I want to opt in to a conventional commit style with a configurable scope so that Ralph's commits are easier to scan and align with repository conventions.

**Why this priority**: This is the new user-facing capability that improves readability while remaining optional.

**Independent Test**: Configure Ralph to use conventional commits with a chosen scope, complete a work unit, and verify the commit subject follows the configured style and scope.

**Acceptance Scenarios**:

1. **Given** a project with `commit.style` set to `conventional`, **When** Ralph creates a commit for a completed work unit, **Then** the commit subject uses conventional commit formatting instead of the legacy format.
2. **Given** a project with `commit.style` set to `conventional` and `commit.scope` set to a custom value, **When** Ralph creates a commit, **Then** the configured scope appears in the commit subject.
3. **Given** a project with `commit.style` set to `conventional`, **When** Ralph creates multiple completed work-unit commits, **Then** the formatting remains consistent across those commits.
4. **Given** a project with an unsupported `commit.style` value, **When** Ralph prepares to create a completed work-unit commit, **Then** it stops with a clear configuration error instead of creating a commit with an unintended format.

---

### User Story 3 - Link Commits Back to the Issue Automatically (Priority: P3)

As a maintainer reviewing Ralph-generated history, I want commit messages to include the related GitHub issue number automatically when it can be inferred so that repository history is easier to trace back to the feature request.

**Why this priority**: Automatic issue linking improves traceability, but it is secondary to preserving compatibility and enabling configurable style.

**Independent Test**: Run Ralph on branches with and without a numeric issue prefix and verify that the issue reference is appended only when it can be inferred successfully.

**Acceptance Scenarios**:

1. **Given** a project with issue auto-linking enabled and a branch name that starts with a numeric issue prefix, **When** Ralph creates a completed work-unit commit, **Then** the commit subject ends with the matching `#<issue>` reference.
2. **Given** a project with issue auto-linking enabled and a branch name without a parseable numeric issue prefix, **When** Ralph creates a completed work-unit commit, **Then** the commit succeeds without an appended issue reference.
3. **Given** a project with issue auto-linking enabled, **When** Ralph creates a commit from a branch whose numeric prefix differs from the configured commit scope, **Then** the scope uses the configured value and the issue reference uses the inferred branch issue number.
4. **Given** a project with issue auto-linking enabled and `commit.style` set to `legacy`, **When** Ralph creates a completed work-unit commit, **Then** the legacy commit subject still appends the inferred `#<issue>` reference when available.

### Edge Cases

- A project enables conventional commit style but does not provide a custom scope.
- A branch starts with digits that are not followed by the expected separator pattern.
- A branch has no numeric prefix at all.
- A project has an invalid or unrecognized commit-style value; commit creation must stop with a clear configuration error.
- A project enables issue auto-linking while using the legacy commit style; linking behavior remains the same as in conventional style.
- A work unit title already contains digits or punctuation that could make the final commit subject harder to parse.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Ralph MUST continue using the current legacy commit subject format `feat(<feature-name>): <work-unit title>` when no commit configuration is provided.
- **FR-002**: Ralph MUST support an explicit `legacy` commit style that preserves the commit subject format `feat(<feature-name>): <work-unit title>`.
- **FR-003**: Ralph MUST support an explicit `conventional` commit style for completed work-unit commits.
- **FR-004**: When conventional commit style is enabled, Ralph MUST allow users to define the commit scope through project configuration.
- **FR-005**: When conventional commit style is enabled and no custom scope is provided, Ralph MUST use `ralph` as the default scope value.
- **FR-006**: Ralph MUST support optional automatic issue linking for generated commit messages in both `legacy` and `conventional` commit styles.
- **FR-007**: When automatic issue linking is enabled and the current branch starts with a numeric issue prefix, Ralph MUST append the matching `#<issue>` reference to the generated commit subject.
- **FR-008**: When automatic issue linking is enabled and no parseable numeric issue prefix is present, Ralph MUST still create the commit successfully without an issue reference.
- **FR-009**: Failure to infer an issue number MUST NOT cause the iteration or commit step to fail.
- **FR-010**: The legacy and conventional commit styles MUST produce consistent, predictable commit subjects for completed work units.
- **FR-011**: Existing projects without the new commit configuration MUST behave exactly as they do today.
- **FR-012**: Ralph MUST document the available commit-style options, scope behavior, and automatic issue-linking behavior in user-facing configuration guidance.
- **FR-013**: Ralph MUST apply the same commit-style and issue-linking rules across every supported orchestration path.
- **FR-014**: When `commit.style` is present but unsupported, Ralph MUST treat it as a clear configuration error and MUST NOT create a commit until the configuration is corrected.

### Key Entities

- **Commit Style Setting**: The project-level choice that determines whether Ralph uses the legacy commit format or the conventional commit format.
- **Commit Scope Setting**: The configurable label used inside a conventional commit subject to describe the area the change belongs to.
- **Issue Linking Setting**: The project-level choice that determines whether Ralph attempts to append an inferred GitHub issue reference.
- **Branch Issue Prefix**: The leading numeric identifier in the current branch name that may be used to infer the related GitHub issue number.
- **Generated Commit Subject**: The final Ralph-created commit message subject for a completed work unit.

### Scope Boundaries

- This feature changes how Ralph formats commit messages; it does not change when Ralph decides a work unit is complete.
- This feature does not require users to rename existing branches to use the new styles.
- This feature does not require an issue reference when no numeric branch prefix can be inferred.
- This feature does not alter task selection, memory handoff, or completion validation behavior outside the generated commit subject.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of tested projects with no commit configuration, Ralph-generated commit subjects for completed work units match the legacy format `feat(<feature-name>): <work-unit title>` exactly.
- **SC-002**: In 100% of tested projects configured for the conventional style, Ralph-generated commit subjects follow the conventional format and include either the configured scope or the default scope `ralph`.
- **SC-003**: In 100% of tested branches with a numeric issue prefix and issue auto-linking enabled, Ralph-generated commit subjects end with the matching `#<issue>` reference.
- **SC-004**: In 100% of tested branches without a parseable numeric issue prefix, commit creation still succeeds and no incorrect issue reference is appended.
- **SC-005**: User-facing configuration documentation explains the available commit styles, scope behavior, and issue auto-linking behavior well enough that 4 of 5 representative users can choose the intended option without additional clarification.
- **SC-006**: Equivalent commit-style scenarios produce the same observable results across the Bash and PowerShell orchestration paths.

## Assumptions

- Ralph continues to generate commits only for completed work units and not for incomplete or bookkeeping-only work.
- The preserved legacy commit subject format is `feat(<feature-name>): <work-unit title>`.
- The current branch name is the only source used for automatic issue-number inference in this feature.
- Automatic issue linking is optional and may be enabled independently of whether users prefer legacy or conventional commit formatting.
- Existing repositories may already rely on the current commit format, so backward compatibility takes precedence over changing defaults.
