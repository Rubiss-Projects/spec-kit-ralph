# Test fixtures for ralph-loop regression tests

## tasks-mixed.md
A tasks.md with a mix of complete and incomplete items.

## tasks-all-done.md
A tasks.md where all items are complete.

## tasks-empty.md
A tasks.md with no task items at all.

## ralph-config-valid.yml
A valid ralph config file for config loading tests.

## ralph-config-legacy.yml
A config fixture with an explicit `commit.style: legacy` setting. Used by US1
regression scenarios to verify that the legacy commit subject format is preserved
when the style is set explicitly.

## ralph-config-conventional.yml
A config fixture with `commit.style: conventional`, an explicit `commit.scope`,
and `commit.issue: auto` enabled. Used by US2 and US3 regression scenarios to
verify conventional subject formatting and issue auto-linking.

## ralph-config-invalid.yml
A config fixture with an unsupported `commit.style` value (`squash`). Used by
US2 regression scenarios to verify that Ralph stops with a clear configuration
error before creating any commit when an unsupported style is present.

## ralph-memory-valid-active.md
A canonical active memory file with a nonterminal handoff.

## ralph-memory-valid-complete.md
A canonical completed memory file with the exact terminal marker.

## ralph-memory-malformed.md
A byte-stable aggregate failure fixture with invalid title and metadata,
missing, duplicate, unexpected, and out-of-order sections, plus an unresolved
template token.

Memory fixtures use `test-feature` and a fixed UTC timestamp so Bash and
PowerShell can compare semantic results deterministically. Runtime rendering
replaces only `{{FEATURE_NAME}}` and `{{STARTED_AT}}` in
`templates/ralph-memory.md`.

The malformed fixture exercises `title-invalid`, `feature-invalid`,
`started-invalid`, `section-missing`, `section-duplicate`,
`section-unexpected`, `section-order`, and `token-unresolved`. Tests that
reject it must compare its bytes before and after validation.
