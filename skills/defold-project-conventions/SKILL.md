---
name: defold-project-conventions
description: Use when working in a Defold repository and the task is specifically about preserving that project's folder layout, naming patterns, collection/message conventions, scene flow, shared helper usage, or adding built-product AI QA control to Debug, Development, or QA bundles.
---

# Defold Project Conventions

## Scope

Use this skill when Defold edits require first understanding local conventions. If the repository conventions are already known for the touched files, this skill should only enforce consistency.

## Pre-Flight

- inspect folder structure, collection hierarchy, and script ownership before proposing edits
- identify canonical message names, helper modules, and data flow patterns used in nearby modules
- confirm naming style and subsystem boundaries currently used in the repo
- check for existing local abstractions before creating new utilities

## Operating Procedure

- preserve established architecture unless the task explicitly requests restructuring
- align new files and symbols with existing naming and module patterns
- keep scene, GUI, and system boundaries explicit and consistent with project convention
- flag any mismatch with project patterns before implementing changes
- limit recommendations to the local project's conventions and avoid universal assumptions
- for built-product AI QA work, read
  [`references/runtime-ai-qa.md`](references/runtime-ai-qa.md) and keep generic
  bridge behavior in `defold_helper` while leaving game-specific adapters in the
  consumer project

## Validation

- edits follow local Defold structure and naming standards
- helper or module reuse is prioritized over introducing duplicated patterns
- all convention risks are documented when a requested change conflicts with current practice
- Debug/Development runtime QA and Release exclusion are verified separately
