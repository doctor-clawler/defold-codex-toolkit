---
name: defold-ui-input
description: Use when working in a Defold repository and the task is specifically about Defold GUI scripts, input focus, pointer/touch handling, coordinate conversion, modal routing, or gameplay interaction leakage.
---

# Defold UI And Input

## Scope

Use this skill only for Defold UI and input workflows. If the task is not in a Defold GUI or input context, skip this skill.

## Pre-Flight

- inspect existing `on_input()` handlers, `gui.pick_node`, and input listener ownership in the target scripts
- confirm modal, popover, or popup flow and whether focus should be captured or released
- identify which coordinate space the code currently uses (GUI vs world)
- check existing cross-platform patterns for touch versus mouse

## Operating Procedure

- separate GUI hit tests from world-space interactions unless there is an explicit conversion path
- keep input focus explicit when entering or exiting modal states
- preserve local project conventions for action names and message routing
- avoid inventing input side effects or undocumented Defold API behavior
- prefer deterministic small changes that close one interaction gap at a time

## Validation

- GUI and world coordinate checks are not mixed without explicit conversion
- modal and overlay routes do not leak input unexpectedly to gameplay
- touch and mouse behavior are consistent where requirements overlap
- task result is validated against the local interaction flow, not assumed behavior
