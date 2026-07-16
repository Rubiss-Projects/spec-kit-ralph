# Contract: Ralph Work-Unit Commit Subject Format

## Purpose

Define the observable commit-subject formats Ralph may generate for completed work units.

## Inputs

- Resolved commit style
- Resolved conventional scope, when applicable
- Completed work-unit title
- Conventional commit summary, when applicable
- Optional inferred issue suffix from the current branch

## Legacy Subject Contract

When commit style resolves to `legacy`, Ralph preserves the subject format `feat(<feature-name>): <work-unit title>` exactly.

| Condition | Required Result |
|---|---|
| No issue suffix | `feat(<feature-name>): <work-unit title>` |
| Inferred issue suffix present | `feat(<feature-name>): <work-unit title> #<issue>` |

## Conventional Subject Contract

When commit style resolves to `conventional`, Ralph generates a conventional work-unit commit subject whose payload is a concise summary of the completed change rather than the raw planning title.

| Condition | Required Result |
|---|---|
| Configured scope present | `feat(<scope>): <commit summary>` |
| Configured scope absent | `feat(ralph): <commit summary>` |
| Inferred issue suffix present | Conventional subject followed by a space and `#<issue>` |
| Planning title contains labels such as `US1`, `US-003`, `Phase 6`, or task ranges | Those labels are omitted from `<commit summary>` |

## Examples

| Style | Branch | Result |
|---|---|---|
| Legacy | `069-ctx-list-filter` | `feat(069-ctx-list-filter): US1 Find a target context quickly` |
| Legacy + issue auto | `069-ctx-list-filter` | `feat(069-ctx-list-filter): US1 Find a target context quickly #69` |
| Conventional + explicit scope | `069-ctx-list-filter` | `feat(myapp): add context list filter flag #69` |
| Conventional + default scope | `main` | `feat(ralph): handle empty context match result` |

## Error Contract

| Condition | Required Result |
|---|---|
| Unsupported explicit `commit.style` | Stop before commit creation with a clear configuration error |
| Missing numeric branch prefix with `issue: auto` | Create the commit successfully with no issue suffix |
| Agent-created commit subject violates the configured commit policy | Report `commit-subject-invalid` and feed the defect back to the next iteration for repair |

## Postcondition Validation

When a `commit` block is configured, Ralph validates each new work-unit commit subject created during the current iteration before accepting completion. The validation is intentionally a guardrail: it enforces the configured `feat(...)` prefix, required inferred issue suffix, and absence of obvious planning labels in conventional payloads, but it does not require an exact deterministic commit summary.

If the only postcondition defects are `commit-subject-invalid` diagnostics, Ralph treats them as repairable feedback for the next agent iteration. Broader commit-history, dirty-worktree, or completion-gate defects keep their existing failure behavior.

## Parity Rules

- Bash and PowerShell must produce equivalent subjects for equivalent inputs.
- The issue suffix decision is independent of the selected commit style.
- The subject contract applies only to Ralph-generated completed work-unit commits.
- Conventional subjects must not leak planning-only labels when a cleaner commit summary can be produced from the completed change context.
