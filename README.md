# Defold Helper Marketplace

Standalone Codex marketplace repository for the `defold-helper` plugin.

This repository packages:

- a repo-root marketplace manifest at `.agents/plugins/marketplace.json`
- the `defold-helper` plugin under `plugins/defold-helper`
- a Defold-specific skill for safer input, GUI, and scene work
- a lightweight helper script for targeted lookups against the latest official `llms-full.txt`

## What The Plugin Does

`defold-helper` is a Codex plugin focused on Defold implementation work. It pushes the agent to:

- inspect local project architecture before editing
- separate GUI-space and world-space interaction correctly
- treat input focus and modal routing explicitly
- avoid invented Defold APIs
- consult the latest official `https://defold.com/llms-full.txt` only when engine behavior is uncertain

The plugin does not claim version-specific Defold documentation support. It intentionally uses the latest official `llms-full.txt` as the current source of truth.

## Repository Layout

```text
.agents/plugins/marketplace.json
plugins/defold-helper/.codex-plugin/plugin.json
plugins/defold-helper/skills/defold-implementation/SKILL.md
plugins/defold-helper/scripts/defold-docs.sh
```

## Local Use

Clone this repository somewhere on disk, then point Codex at the repo marketplace.

Expected marketplace path:

```text
<repo-root>/.agents/plugins/marketplace.json
```

The plugin entry uses this source path:

```text
./plugins/defold-helper
```

## Helper Script

The helper script lives at:

`plugins/defold-helper/scripts/defold-docs.sh`

Commands:

```bash
plugins/defold-helper/scripts/defold-docs.sh fetch
plugins/defold-helper/scripts/defold-docs.sh search "gui.pick_node"
plugins/defold-helper/scripts/defold-docs.sh context 40123 8
```

It caches the latest `llms-full.txt` under `~/.cache/defold-helper/`.

## Publishing Notes

This repository is ready for use as a repo marketplace. It is not the same thing as publishing into the official OpenAI Codex plugin directory. If official self-serve directory publishing becomes available later, this repo can be used as the source package.
