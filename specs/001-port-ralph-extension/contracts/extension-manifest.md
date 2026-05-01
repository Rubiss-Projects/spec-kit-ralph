# Contract: Extension Manifest

**File**: `extension.yml`
**Schema Version**: 1.0
**Validates Against**: [Extension API Reference](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-API-REFERENCE.md)

## Complete Manifest

```yaml
schema_version: "1.0"

extension:
  id: "ralph"
  name: "Ralph Loop"
  version: "1.0.0"
  description: "Autonomous implementation loop using AI agent CLI"
  author: "Rubiss"
  repository: "https://github.com/Rubiss-Projects/spec-kit-ralph"
  license: "MIT"

requires:
  speckit_version: ">=0.1.0"
  tools:
    - name: "copilot"
      required: true
    - name: "git"
      required: true

provides:
  commands:
    - name: "speckit.ralph.run"
      file: "commands/run.md"
      description: "Run the ralph autonomous implementation loop"

    - name: "speckit.ralph.iterate"
      file: "commands/iterate.md"
      description: "Execute a single ralph loop iteration (one work unit)"

  config:
    - name: "ralph-config.yml"
      template: "ralph-config.template.yml"
      description: "Ralph loop configuration (model, iterations, agent CLI)"
      required: false

hooks:
  after_tasks:
    command: "speckit.ralph.run"
    optional: true
    prompt: "Run ralph loop to implement tasks?"
    description: "Start autonomous implementation after task generation"

tags:
  - "implementation"
  - "automation"
  - "loop"
  - "copilot"

defaults:
  model: "claude-sonnet-4.6"
  max_iterations: 10
  agent_cli: "copilot"
```

## Validation Checklist

| Rule | Value | Valid |
|------|-------|-------|
| `extension.id` matches `^[a-z0-9-]+$` | `ralph` | YES |
| `extension.version` is semver X.Y.Z | `1.0.0` | YES |
| `provides.commands` has ≥1 entry | 2 entries | YES |
| Command names match `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$` | `speckit.ralph.run`, `speckit.ralph.iterate` | YES |
| Command `file` paths are relative | `commands/run.md`, `commands/iterate.md` | YES |
| `requires.speckit_version` is version specifier | `>=0.1.0` | YES |
| Hook `command` is in `provides.commands` | `speckit.ralph.run` ∈ commands | YES |
