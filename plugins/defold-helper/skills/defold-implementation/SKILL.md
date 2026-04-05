---
name: defold-implementation
description: Use when working in a Defold repository and the task touches gameplay scripts, GUI, input routing, scene flow, or engine-specific behavior that must follow real Defold APIs.
---

# Defold Implementation

## Overview

Treat existing project patterns as the first source of truth and Defold docs as the engine source of truth. Be skeptical of generic Lua assumptions, especially around input delivery, GUI picking, coordinate spaces, and scene transitions.

## Before Editing

Inspect the local project first:

- relevant scripts and GUI scripts
- input focus acquisition and release
- message flow between HUD, gameplay, and scenes
- collection proxy usage
- camera or screen-to-world conversion helpers
- any existing button, popup, drag, or selection pattern worth reusing

## Risk Areas

Call out whether the task touches:

- input focus or input consumption order
- GUI-space vs world-space interaction
- modal popups or overlays
- drag and drop
- touch and mouse parity
- collection proxy transitions
- camera-dependent picking

## Docs Lookup

Only consult docs when engine behavior is uncertain. Use the latest official Defold docs source:

- `https://defold.com/llms-full.txt`

If the helper script is available, prefer targeted lookups over broad reads:

- `scripts/defold-docs.sh fetch`
- `scripts/defold-docs.sh search "gui.pick_node"`
- `scripts/defold-docs.sh context 1200`

Do not pretend version-specific docs exist when only the latest source is available.

## Implementation Rules

- Never assume `on_input()` is delivered automatically
- Never mix GUI hit tests with world hit tests without explicit conversion
- Let modal UI consume input deliberately so gameplay taps do not leak through
- Reuse validated local patterns before inventing helpers
- Keep GUI scripts focused on intent and messaging, not broad gameplay ownership
- Make the smallest Defold-correct change that solves the task

## Validation Checklist

- input focus correctness
- GUI/world coordinate separation
- popup or modal input blocking when relevant
- touch and mouse handling when relevant
- no invented Defold APIs, messages, or lifecycle behavior

## Response Format

For Defold implementation tasks, answer with:

1. Architecture snapshot
2. Risk assessment
3. Plan
4. Changes
5. Validation checklist
