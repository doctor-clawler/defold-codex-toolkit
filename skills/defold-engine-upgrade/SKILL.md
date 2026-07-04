---
name: defold-engine-upgrade
description: Use when working in a Defold repository or workspace and the task is specifically about Defold engine upgrades, release notes, Editor or bob.jar version changes, or keeping defold_helper compatibility aligned with an engine version.
---

# Defold Engine Upgrade

## Scope

Use this skill for Defold engine upgrades and compatibility audits. This skill covers Defold Editor, `bob.jar`, build scripts, CI bundle steps, official release notes, and project dependencies that consume `defold_helper`.

Do not use this skill for ordinary gameplay edits unless the task depends on a Defold engine version, API behavior, build flag, editor endpoint, or `defold_helper` compatibility question.

## Safety Rule

Hard rule: do not upgrade every discovered project automatically. Start with an inventory and impact report, then upgrade only the explicit project or batch the user approved.

## Official Sources

- check current official release notes before recommending an engine change
- use `https://defold.com/llms.txt` as the first manual/API index for doc-dependent claims
- verify the local project's actual Defold version source: Editor version, pinned `bob.jar`, build script download URL, CI image, or project-local wrapper
- do not rely on model memory for Defold API, lifecycle, build flag, or editor HTTP behavior

## Inventory

When asked to assess or upgrade a workspace:

- find Defold projects by locating `game.project`
- identify projects that use `defold_helper` through `game.project` dependencies or `require("defold_helper...")`
- inspect build scripts for pinned `bob.jar`, bundle flags, artifact paths, and target platforms
- flag native extensions, HTML5 shells, Android/iOS signing, custom render scripts, and editor-only tooling as upgrade risks
- separate this toolkit's `defold_helper` dependency from the Defold engine itself; they are versioned together for compatibility, but they are not the same package

## Upgrade Procedure

1. Read the target Defold release notes and summarize likely project impact.
2. Record the current project engine source and `defold_helper` dependency tag or commit.
3. If this toolkit has no `defold_helper` release validated for the target engine, validate and release the helper first.
4. Update the project engine source and the `defold_helper` dependency together.
5. Fetch libraries in the Defold project before validating code.
6. Run the smallest reliable compile check, then platform-specific bundle checks where the project supports them.
7. Commit each project's durable upgrade separately after validation.

## Validation

- release notes were checked and named in the report
- project engine source is explicit, not guessed
- `defold_helper` dependency is aligned to a tag or commit intended for the target engine
- `game.project` dependencies fetch successfully
- editor or `bob.jar` compile check passes
- requested platform bundle checks pass or are reported as blocked with the exact blocker
- the final report distinguishes inventory-only work from actual upgraded projects
