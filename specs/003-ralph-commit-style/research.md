# Research: Configurable Ralph Commit Style

## Decision 1: Keep the public config optional and legacy-first

**Decision**: Add an optional `commit` block to Ralph's project configuration with `style`, `scope`, and `issue` keys, while preserving today's legacy work-unit commit subject exactly when the block is absent.

**Rationale**: Backward compatibility is the highest-priority requirement. Existing projects must not change behavior merely by upgrading the extension.

**Alternatives considered**: Make conventional commits the default; move commit options into launcher flags; add a separate config file. These either break existing history expectations, scatter policy across invocation paths, or add needless configuration surface.

## Decision 2: Resolve commit policy in the orchestrator preflight, not only in agent prose

**Decision**: Both orchestration scripts will resolve and validate the effective commit policy before agent execution, then expose one normalized policy to the iteration contract used by every agent CLI path.

**Rationale**: The current system has multiple execution paths (Copilot registered command, Copilot skills mode, Codex prompt mode, Claude prompt mode). Preflight resolution prevents path-specific drift and allows invalid config to fail clearly before any unintended commit is created.

**Alternatives considered**: Let the agent read config ad hoc; validate only in `commands/iterate.md`; resolve policy only after work is complete. These approaches weaken determinism, make invalid-config handling inconsistent, or surface errors too late.

## Decision 3: Reuse the existing dependency-free config-reading approach

**Decision**: Keep the current lightweight line-based config loading strategy and extend it to consume the new `commit` keys from the existing YAML file without introducing a third-party YAML parser.

**Rationale**: The repository intentionally relies on dependency-free Bash and PowerShell scripts. The new commit policy is small, extension-owned, and compatible with the existing trimmed key/value parsing model.

**Alternatives considered**: Introduce a YAML parser dependency; flatten the config keys at the top level; create platform-specific parsing implementations with different semantics. These increase runtime complexity, reduce readability, or create parity risk.

## Decision 4: Infer issue references only from a leading numeric branch prefix

**Decision**: `issue: auto` will infer an issue number only when the current branch begins with a numeric prefix followed by a separator (for example `069-feature-name` → `#69`). When no such prefix exists, Ralph omits the issue reference and continues successfully.

**Rationale**: This matches the issue proposal, aligns with existing branch-numbering conventions, and provides deterministic traceability without guessing from arbitrary branch text.

**Alternatives considered**: Parse numbers anywhere in the branch name; require an explicit issue field; query GitHub for linked issues. These either increase false positives, expand configuration burden, or add network/runtime dependencies.

## Decision 5: Apply issue auto-linking to both supported commit styles

**Decision**: When issue auto-linking is enabled, the inferred `#<issue>` suffix applies to both `legacy` and `conventional` Ralph work-unit commit subjects.

**Rationale**: This matches the clarification outcome and keeps traceability independent of the selected formatting style.

**Alternatives considered**: Apply linking only to conventional commits; add per-style issue-linking switches. Those introduce surprising asymmetry or unnecessary configuration complexity.

## Decision 6: Treat unsupported `commit.style` values as a preflight error

**Decision**: Missing `commit.style` defaults to legacy behavior, but a present unsupported style value stops the run with a clear configuration error and creates no commit.

**Rationale**: Failing fast prevents silent fallback to the wrong history format and makes misconfiguration immediately visible.

**Alternatives considered**: Silently fall back to legacy; ignore the invalid key and continue; remember the last valid style. These would hide operator error and make commit history less predictable.

## Decision 7: Keep commit-subject construction as a documented public contract

**Decision**: Document the generated subject formats and examples in explicit contract artifacts, then align `commands/iterate.md`, README guidance, and regression assertions with those contracts.

**Rationale**: The commit subject is a user-visible output and must remain consistent across platforms and future releases.

**Alternatives considered**: Leave the format implicit in agent instructions; document only the config shape. These make regressions harder to detect and reduce clarity for users adopting the feature.
