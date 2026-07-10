# Contract: Ralph Memory Schema

## Location and Ownership

- **Canonical template**: `templates/ralph-memory.md` relative to the installed extension root
- **Feature instance**: `specs/{feature}/ralph-memory.md`
- **Owner**: Orchestrator initializes and validates; the iteration agent updates valid content
- **Primary purpose**: Compact durable knowledge for the next fresh Ralph context
- **Not allowed**: Chronological iteration entries, task completion state, or a duplicate progress log

## Canonical Template

```markdown
# Ralph Memory

Feature: {{FEATURE_NAME}}
Started: {{STARTED_AT}}

## Codebase Patterns

## Decisions

## Gotchas

## Reusable Commands

## Do Not Repeat

## Current Handoff
```

The template is UTF-8 without a byte-order mark and uses LF line endings. Initialization replaces only the two declared tokens:

| Token | Rendered Value |
|---|---|
| `{{FEATURE_NAME}}` | Exact active feature identity provided to the orchestrator |
| `{{STARTED_AT}}` | UTC timestamp in `YYYY-MM-DDTHH:MM:SSZ` form |

The shared template is the only initialization source. Scripts must not contain a second full Markdown template or silently fall back to one.

## Structural Contract

The feature instance contains:

1. Exactly one H1: `# Ralph Memory`
2. Exactly one non-empty `Feature:` field matching the active feature
3. Exactly one non-empty, parseable `Started:` field
4. Exactly these H2 headings, once each and in this order:
   1. `## Codebase Patterns`
   2. `## Decisions`
   3. `## Gotchas`
   4. `## Reusable Commands`
   5. `## Do Not Repeat`
   6. `## Current Handoff`
5. No unresolved `{{...}}` template token

Additional H2 headings are invalid. H3-or-deeper headings, lists, paragraphs, and code blocks are allowed inside a canonical H2 section.

Empty durable-knowledge sections are valid; Ralph must not fabricate entries to fill them. Immediately after first initialization, `Current Handoff` may be empty. After any active iteration with work remaining, it contains only concise, actionable next-iteration information.

## Completion Contract

Before the final substantive work-unit commit, `Current Handoff` is replaced—not appended—with exactly:

```markdown
## Current Handoff

- Feature complete; no handoff required.
```

No other paragraph, list item, nested heading, or stale work instruction may remain in that section when completion is reported.

## Update Contract

- Preserve every still-valid entry.
- Update or remove superseded entries instead of appending contradictory history.
- Put reusable repository knowledge in the matching durable section.
- Put failed approaches and their reason under `Do Not Repeat`.
- Keep `Current Handoff` limited to the next work unit or the exact terminal marker.
- Never add iteration numbers, timestamps, file-change inventories, or commit records; those belong in `progress.md`.

## Initialization Contract

1. Verify the shared template exists and satisfies this contract.
2. If the feature instance is missing, render to a temporary/create-new target and publish it without overwriting a concurrently created file.
3. If the feature instance exists, do not write to it during initialization.
4. Validate the resulting/existing instance before work selection.
5. Preserve an existing file byte-for-byte on every validation failure.

## Validation Result

Validation returns a success class or an aggregate ordered list of defects. Diagnostic categories are stable across Bash and PowerShell:

| Category | Meaning |
|---|---|
| `template-unavailable` | Shared template is missing, unreadable, or structurally invalid. |
| `title-invalid` | Required H1 is missing, duplicated, or changed. |
| `feature-invalid` | Feature metadata is missing, blank, duplicated, or does not match the active feature. |
| `started-invalid` | Started metadata is missing, blank, duplicated, or unparsable. |
| `section-missing` | A canonical H2 is absent. |
| `section-duplicate` | A canonical H2 occurs more than once. |
| `section-unexpected` | An unknown H2 is present. |
| `section-order` | Canonical H2 headings are not in template order. |
| `token-unresolved` | A template token remains in the feature instance. |
| `handoff-invalid` | Completion requires the terminal marker but the section is empty, stale, or contains extra content. |

All applicable defects are printed before exit. Validation stops work selection with exit code 1 and performs no automatic normalization, backup rewrite, commit, or history mutation.

## Cross-Platform Parity

Bash and PowerShell must agree on:

- rendered metadata values apart from the instant of timestamp capture;
- H1/H2 names and order;
- valid versus invalid classification;
- complete versus active handoff classification;
- diagnostic categories;
- preservation of invalid input bytes.

Tests compare normalized semantics for newly rendered files and exact bytes for invalid-file preservation.
