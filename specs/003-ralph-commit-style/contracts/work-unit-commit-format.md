# Contract: Ralph Work-Unit Commit Subject Format

## Purpose

Define the observable commit-subject formats Ralph may generate for completed work units.

## Inputs

- Resolved commit style
- Resolved conventional scope, when applicable
- Completed work-unit title
- Optional inferred issue suffix from the current branch

## Legacy Subject Contract

When commit style resolves to `legacy`, Ralph preserves the subject format `feat(<feature-name>): <work-unit title>` exactly.

| Condition | Required Result |
|---|---|
| No issue suffix | `feat(<feature-name>): <work-unit title>` |
| Inferred issue suffix present | `feat(<feature-name>): <work-unit title> #<issue>` |

## Conventional Subject Contract

When commit style resolves to `conventional`, Ralph generates a conventional work-unit commit subject.

| Condition | Required Result |
|---|---|
| Configured scope present | `feat(<scope>): <work-unit title>` |
| Configured scope absent | `feat(ralph): <work-unit title>` |
| Inferred issue suffix present | Conventional subject followed by a space and `#<issue>` |

## Examples

| Style | Branch | Result |
|---|---|---|
| Legacy | `069-ctx-list-filter` | `feat(069-ctx-list-filter): US1 Find a target context quickly` |
| Legacy + issue auto | `069-ctx-list-filter` | `feat(069-ctx-list-filter): US1 Find a target context quickly #69` |
| Conventional + explicit scope | `069-ctx-list-filter` | `feat(ralph): <work-unit title> #69` |
| Conventional + default scope | `main` | `feat(ralph): <work-unit title>` |

## Error Contract

| Condition | Required Result |
|---|---|
| Unsupported explicit `commit.style` | Stop before commit creation with a clear configuration error |
| Missing numeric branch prefix with `issue: auto` | Create the commit successfully with no issue suffix |

## Parity Rules

- Bash and PowerShell must produce equivalent subjects for equivalent inputs.
- The issue suffix decision is independent of the selected commit style.
- The subject contract applies only to Ralph-generated completed work-unit commits.
