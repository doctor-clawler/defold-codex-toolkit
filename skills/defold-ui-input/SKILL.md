---
name: defold-ui-input
description: Use when working in a Defold repository and the task is specifically about Defold GUI scripts, GUI scenes, input focus, pointer/touch handling, coordinate conversion, modal routing, or gameplay interaction leakage.
---

# Defold UI And Input

## Scope

Use this skill only for Defold UI and input workflows. If the task is not in a Defold GUI or input context, skip this skill.

## Pre-Flight

- inspect existing `on_input()` handlers, `gui.pick_node`, and input listener ownership in the target scripts
- if touching GUI text nodes, HUD labels, Label components, or `.font` resources, also apply `defold-ui-text-fonts`
- confirm modal, popover, or popup flow and whether focus should be captured or released
- identify which coordinate space the code currently uses (GUI vs world)
- check existing cross-platform patterns for touch versus mouse
- inspect `*.input_binding` action names for mouse left, single-touch, and multi-touch before changing input code

## Operating Procedure

- separate GUI hit tests from world-space interactions unless there is an explicit conversion path
- keep input focus explicit when entering or exiting modal states
- preserve local project conventions for action names and message routing
- avoid inventing input side effects or undocumented Defold API behavior
- prefer Defold input bindings over custom HTML shell bridges for click/tap behavior
- for desktop plus single-touch click/tap, bind `MOUSE_BUTTON_LEFT` / `MOUSE_BUTTON_1`; keep multi-touch on a separate action because sharing the same action overrides single-touch
- prefer deterministic small changes that close one interaction gap at a time

## Validation

- GUI and world coordinate checks are not mixed without explicit conversion
- modal and overlay routes do not leak input unexpectedly to gameplay
- touch and mouse behavior are consistent where requirements overlap
- desktop mouse, single-touch, and multi-touch paths are tested separately when the target platform supports them
- `*.input_binding` does not assign multi-touch to the same action as `MOUSE_BUTTON_LEFT` / `MOUSE_BUTTON_1`
- task result is validated against the local interaction flow, not assumed behavior
