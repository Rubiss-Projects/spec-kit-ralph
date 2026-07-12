# Data Model: Configurable Ralph Commit Style

## Commit Configuration

Represents the user-authored project policy for Ralph-generated work-unit commit subjects.

The configuration is a nested object keyed by `commit`, with `style`, `scope`, and `issue` as properties of that object.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `style` | enum | no | Allowed values: `legacy`, `conventional`. Missing means legacy behavior. Present but unsupported values are invalid. |
| `scope` | string | conditional | Optional for all styles. When `style` is `conventional`, a missing value resolves to the default scope `ralph`. |
| `issue` | enum | no | Allowed values: `auto` or absent. `auto` enables branch-based issue inference; absence disables issue suffix generation. |

### Validation Rules

- The configuration lives in `.specify/extensions/ralph/ralph-config.yml`.
- The `commit` block is optional.
- `style`, `scope`, and `issue` are valid only as members of the nested `commit` object.
- Unsupported `style` values are a blocking configuration error.
- Flattened keys outside the `commit` block are an invalid configuration shape.
- A missing `scope` must not block commit generation.
- A missing or unsupported `issue` value must resolve to no issue suffix unless the implementation explicitly defines and documents stronger validation.

## Resolved Commit Policy

Represents the normalized commit behavior used by a single Ralph run after config resolution.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `style` | enum | yes | `legacy` or `conventional`, after applying defaults and validation. |
| `scope` | string | yes | For conventional style, either the configured scope or the default scope `ralph`; for legacy style, the value is ignored by subject generation. |
| `issue_mode` | enum | yes | `auto` or `disabled`. |
| `valid` | boolean | yes | `false` when a present config value is unsupported. |
| `validation_message` | string | conditional | Required when `valid` is `false`; explains the blocking configuration error. |

### Lifecycle

| From | Event | To | Side Effects |
|---|---|---|---|
| Unresolved | Script preflight | Resolved | Apply defaults, validate config, and normalize values for the current run. |
| Resolved | Unsupported explicit style detected | Invalid | Stop before creating a commit. |
| Resolved | Valid branch and work-unit context available | Active | Subject generation may proceed. |

## Branch Issue Reference

Represents the optional GitHub issue suffix inferred from the current branch name.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `branch_name` | string | yes | The current active branch used for the Ralph run. |
| `prefix_number` | integer | conditional | Present only when the branch begins with a numeric prefix followed by a separator. |
| `issue_suffix` | string | conditional | Exactly `#<prefix_number>` when inference succeeds. |
| `inferred` | boolean | yes | `true` only when the prefix rule succeeds. |

### Validation Rules

- Only a leading numeric prefix may produce an issue suffix.
- No numeric prefix means no inferred issue suffix and no failure.
- Issue inference is independent of commit style selection.

## Generated Commit Subject

Represents the final Ralph-created commit subject for a completed work unit.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `work_unit_title` | string | yes | Derived from the completed work unit selected by Ralph. |
| `style` | enum | yes | Comes from Resolved Commit Policy. |
| `scope_segment` | string | conditional | Present only for conventional style. |
| `issue_suffix` | string | conditional | Present only when issue auto-linking is enabled and inference succeeds. |
| `subject` | string | yes | Final commit subject string passed to `git commit -m`. |

### Generation Rules

- Legacy style preserves the subject format `feat(<feature-name>): <work-unit title>`.
- Conventional style emits a conventional-commit subject using the resolved scope and work-unit title, with `ralph` as the default scope when none is configured.
- The issue suffix, when present, is appended to both styles.
- No generated subject may be used when the resolved policy is invalid.

## Relationships

- One active project configuration resolves to one Resolved Commit Policy per Ralph run.
- One Commit Configuration object is keyed by `commit` and owns the `style`, `scope`, and `issue` properties together.
- One current branch may produce zero or one Branch Issue Reference.
- One completed work unit produces one Generated Commit Subject using the resolved policy and any inferred issue suffix.
