# AGENTS.md — The Name of the Wind: The Kingkiller Chronicle

Unofficial, **non-commercial** fan game based on Patrick Rothfuss's
*The Kingkiller Chronicle* — 2D top-down narrative RPG / life sim built in
**Godot 4.7**. Repo: `sleuthy-sloth/name-of-the-wind-fan-game`.
All creative content must be original or properly licensed (see CONTRIBUTING.md).

## Mandatory session start

1. `holographic_memory_search("Name of the Wind status")` — recall project state.
2. `git log --oneline -5` — see where HEAD actually is.
3. Read `docs/development.md` — run/test instructions and current architecture.

Then resume from `.swarm/plan.json` if present.

## Memory protocol (holographic memory MCP store)

- **After every completed task/milestone**: push a short fact with
  `holographic_memory_add`, category `project`, tag `name-of-the-wind`.
- **Session end, even mid-task**: push progress + exact next step so the next
  session can resume cleanly.
- **Stale facts**: correct/supersede them instead of duplicating; keep facts
  under ~500 characters; never store secrets.

## Gotchas

- The project directory path contains spaces (`The Name of The Wind`) —
  **always quote paths** in shell commands.
- Godot binary lives at `/Applications/Godot.app/Contents/MacOS/Godot`.
- After adding/renaming `class_name` scripts, run
  `"…/Godot" --headless --path "<quoted project path>" --import --quit`
  before headless tests, or global script classes won't resolve.
- Headless test suites must print a final `*: PASS` line (e.g.
  `ENGINE_SHELL_TEST: PASS`) and exit non-zero on failure.
