---
name: defold-build-bundle
description: Use when working in a Defold repository and the task is specifically about Defold builds, bundle commands, archive exports, release packaging, or build configuration checks.
---

# Defold Build And Bundle

## Scope

Use this skill only for Defold build pipeline work. If the request is about gameplay code, editor UI implementation only, or non-Defold automation, this skill should not be primary.

## Pre-Flight

- confirm `game.project` exists and read project-specific build settings
- identify target platform, variant, and build entry (`project.main_collection`, archive target, bundle profile)
- inspect existing CI scripts before suggesting any changes
- verify whether the task needs editor-only build steps or command-line or headless flow

## Operating Procedure

- map all modified files back to Defold build behavior (`game.project`, bootstrap scripts, collection proxy usage, and output locations)
- avoid introducing assumptions about platform-specific flags that are not present in the local project
- keep build changes orthogonal to gameplay or GUI behavior
- when adding automation, include clear path and artifact output expectations (`bundle`, `build`, `artifacts`, and related outputs)
- prefer existing repo conventions for naming and directory layouts

## Validation

- target platform, mode, and config are explicitly named
- output artifacts land in the expected local folders
- no invented Defold build flags or lifecycle behavior is introduced
- the change set is minimal and scoped to build or bundle responsibilities
