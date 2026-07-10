# Test fixtures for ralph-loop regression tests

## tasks-mixed.md
A tasks.md with a mix of complete and incomplete items.

## tasks-all-done.md
A tasks.md where all items are complete.

## tasks-empty.md
A tasks.md with no task items at all.

## ralph-config-valid.yml
A valid ralph config file for config loading tests.

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
