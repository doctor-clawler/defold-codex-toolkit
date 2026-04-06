---
name: defold-debug-workflow
description: Use when working in a Defold repository and the task is specifically about reproducing, isolating, and fixing Defold runtime errors, message-passing failures, lifecycle issues, scene transitions, or engine API behavior mismatches.
---

# Defold Debug Workflow

## Scope

Use this skill only for Defold debugging tasks. General refactoring, feature additions, or non-debug investigation should not start here unless driven by a confirmed runtime symptom.

## Pre-Flight

- isolate the concrete failing scene, script, or lifecycle path
- capture the current symptom (error text, log sequence, reproduction steps, expected vs actual behavior)
- inspect message senders and receivers plus callback order before editing code
- collect local context from scripts and config that touch the fault domain

## Operating Procedure

- reproduce the issue with the smallest deterministic steps
- validate suspected behavior against real Defold patterns in the repository before changing logic
- make the smallest change that confirms or invalidates the hypothesis
- avoid changing unrelated systems while the issue is unresolved
- document what changed and why at each step

## Validation

- original failure mode is still testable after each change
- diagnosis is tied to a named code path, not inferred assumptions
- any lifecycle or engine API check is explicitly grounded in observed repository behavior
- regression risk is assessed after each fix candidate
