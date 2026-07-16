# Contract: Ralph Commit Configuration Schema

## Purpose

Define the public project configuration shape for Ralph-generated work-unit commit subjects.

The commit policy is represented as a single nested YAML mapping under the `commit:` key.

## Config Location

Project configuration lives at:

```text
.specify/extensions/ralph/ralph-config.yml
```

The repository source and extension manifest use the canonical config source at:

```text
ralph-config.yml
```

## Contract Shape

```yaml
commit:
  style: "legacy"      # legacy | conventional
  scope: "ralph"       # optional; used for conventional style
  issue: "auto"        # optional; infers #<issue> from branch prefix
```

Ralph reads `style`, `scope`, and `issue` only from inside this nested `commit:` block.

## Invalid Shapes

The following top-level commit-policy forms are unsupported and invalid:

```yaml
commit.style: conventional
commit.scope: ralph
commit.issue: auto
style: conventional
scope: ralph
issue: auto
```

## Field Semantics

| Field | Allowed Values | Required | Meaning |
|---|---|---|---|
| `commit.style` | `legacy`, `conventional` | no | Selects commit-subject format. Missing means preserve today's legacy behavior. |
| `commit.scope` | short string | no | Conventional scope label. Ignored by legacy formatting. Missing means use the default scope `ralph`. |
| `commit.issue` | `auto` | no | Enables branch-prefix issue inference. Missing disables issue suffix generation. |

## Resolution Rules

1. If the `commit` block is absent, Ralph uses legacy behavior.
2. If `commit.style` is present and unsupported, Ralph stops with a clear configuration error and creates no commit.
3. If `commit.style` is `conventional` and `commit.scope` is absent, Ralph uses the default scope `ralph`.
4. If `commit.issue` is `auto`, Ralph attempts issue inference from the current branch prefix.
5. If issue inference fails, Ralph omits the issue suffix and still creates the commit successfully.
6. If `style`, `scope`, or `issue` appear outside the nested `commit:` block, Ralph treats the config shape as invalid.
7. When any nested commit policy is configured, Ralph validates new agent-created work-unit commit subjects against the resolved policy before accepting completion.

## Compatibility Rules

- Existing projects without `commit` configuration must behave exactly as they do today.
- The configuration is optional across all supported orchestration paths.
- The same effective policy must be observed by Bash and PowerShell launch paths.
- The nested `commit:` block shape is authoritative; equivalent top-level commit-policy keys are not supported.
- Runtime subject validation is a guardrail for configured policy; it does not force an exact deterministic conventional summary.
