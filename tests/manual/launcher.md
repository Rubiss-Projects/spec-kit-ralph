# Visible terminal launch acceptance scenarios

These scenarios exercise the agent command in `commands/run.md`. Automated
orchestrator tests cannot prove that a host agent opened a visible UI or sent
Enter in its terminal canvas. Run the applicable scenarios in an agent host
with the extension installed; do not use an actual paid agent for a failure
scenario when a local stub will do.

| Scenario | Expected result |
|----------|-----------------|
| In-app canvas supports launch-and-execute | One orchestrator command runs; fresh feature/iteration output is observed; startup is confirmed with the canvas location. |
| Canvas open returns an idle shell | Launcher sends the fully resolved command and executes it. It cannot report success from the open result or prompt alone. |
| Canvas open already runs the command | Launcher does not send a second command. |
| Native macOS, Windows, or Linux terminal | Command runs in the repository root, output remains visible, and startup evidence is read from that session or its fresh temporary log. |
| Repository path or CLI path contains spaces | Child receives each path as one argument and runs in the correct repository. |
| No in-app terminal and no graphical/native terminal | Launcher reports failure and provides the direct command. No hidden orchestrator is started as a fallback. |
| Terminal process opens but command is never executed | Launcher reports unverified startup within 30 seconds, never success. |
| Script exits with a prerequisite or memory validation error | Launcher reports the observed error and terminal location; it does not report successful startup. |
| Already-complete, clean feature | Fresh output contains `All tasks are already complete!` and a standalone `<promise>COMPLETE</promise>` (exit 0 when available). Launcher reports already-complete success without waiting for an iteration header or `Ralph Loop Summary`, which this path does not emit. |
| Startup output cannot be read after dispatch | Launcher reports unverified startup and asks the user to inspect/stop the existing run before retrying. No automatic duplicate dispatch occurs. |
| An old terminal/log contains a Ralph header | That output is not accepted as evidence for the new dispatch. |
| Model response takes longer than 30 seconds | The earlier orchestrator feature/iteration header is sufficient startup evidence; launcher does not wait for the model response or loop completion. |

Record the host, OS/terminal, dispatched command, fresh startup output or
observed failure, and number of dispatched orchestrator processes. A successful
window-open result without fresh orchestrator output fails acceptance.
