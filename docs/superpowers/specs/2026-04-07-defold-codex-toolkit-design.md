# Defold Codex Toolkit Design

## Goal

Rework this repository into a public GitHub-ready Codex plugin repository named `defold-codex-toolkit`. The repository itself should be the plugin package. Other projects should be able to reuse it by cloning or copying this repository into a local `plugins/defold-codex-toolkit` directory and then referencing that local path from their own `.agents/plugins/marketplace.json`.

This design explicitly does not target automatic publication into any official OpenAI marketplace. The target outcome is a reusable local-path plugin package with clear documentation for project-scoped installation.

## Scope

The repository will be restructured so that the plugin lives at the repository root instead of being nested under `plugins/defold-helper`. The repository will include:

- `.codex-plugin/plugin.json`
- `skills/<skill-name>/SKILL.md` for a small Defold-focused skill set
- `README.md` with installation and reuse guidance in Korean
- `examples/marketplace.json.example` showing project-scoped integration

The repository will not include a repo-root `.agents/plugins/marketplace.json` as a first-class runtime artifact because this repository is the plugin package, not the host project marketplace.

## Architecture

The repository will adopt a root-level plugin layout:

- repository root contains plugin metadata and docs
- `skills/` contains 2 to 4 narrowly scoped Defold-only skills
- `examples/` contains copy-pasteable integration examples for downstream projects

The plugin manifest will use the canonical name `defold-codex-toolkit` and point `skills` to `./skills/`. Skill descriptions will be intentionally narrow so Codex only activates them in Defold repositories or when a task clearly involves Defold-specific build, input, UI, debugging, or project-convention concerns.

## Skill Set

The initial skill set will be:

1. `defold-build-bundle`
   Focused on build, bundle, archive, export, and release-prep tasks in Defold projects.
2. `defold-ui-input`
   Focused on Defold GUI, input focus, touch and mouse handling, coordinate-space separation, and modal routing.
3. `defold-debug-workflow`
   Focused on reproducible debugging of Defold runtime issues, logs, message flow, lifecycle issues, and engine API validation.
4. `defold-project-conventions`
   Focused on reviewing and following project-local Defold architecture, folder layout, naming, messaging, and scene conventions before edits.

Each skill will include a concise frontmatter block and operational guidance that is specific enough to avoid accidental activation in non-Defold repositories.

## Documentation Strategy

`README.md` will be treated as the primary installation document and will be written in Korean, with code and JSON examples kept in English. It will include:

- what this repository is
- what it provides
- directory structure explanation
- installation steps
- project-scoped integration steps
- a `marketplace.json` example
- how Codex sees and uses the plugin
- limitations and non-goals

The README will explicitly state that:

1. publishing this repository on GitHub does not register it in any official OpenAI marketplace
2. downstream users must clone or copy the repository locally first
3. downstream project marketplaces must reference the local filesystem path
4. users may need to restart Codex or refresh plugin discovery after updating marketplace files

## Migration Plan

The existing nested plugin assets under `plugins/defold-helper` will be migrated or rewritten into the new root-level structure. The old nested marketplace-host structure will be removed so the repository reads clearly as a standalone plugin package when viewed on GitHub.

If useful content exists in the current skill or helper script, it may be adapted into the new skill set, but the resulting public structure must remain root-oriented and self-explanatory.

## Validation

Before considering the restructuring complete:

- repository tree should read naturally as a standalone plugin repository
- `.codex-plugin/plugin.json` should be valid and point to `./skills/`
- every shipped skill should have a `SKILL.md` with Defold-specific frontmatter
- `README.md` should be sufficient for a user to install the plugin into another project without extra explanation
- `examples/marketplace.json.example` should match the README instructions and use `./plugins/defold-codex-toolkit`

## Risks And Decisions

- Risk: using descriptions that are too generic could make the skills trigger in non-Defold contexts.
  Decision: keep every skill description explicitly tied to Defold repositories and Defold engine behaviors.
- Risk: keeping both old and new layouts would make the public repository ambiguous.
  Decision: remove the nested plugin-host layout and keep a single root-level plugin structure.
- Risk: readers may assume a GitHub URL is directly installable by Codex.
  Decision: document the local clone or copy plus local path marketplace workflow repeatedly in the README and example file comments.
