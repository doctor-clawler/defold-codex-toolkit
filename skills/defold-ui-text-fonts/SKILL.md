---
name: defold-ui-text-fonts
description: Use when working in a Defold repository and the task involves GUI text nodes, Label components, HUD copy, localization, non-ASCII text, font resources, glyph coverage, or broken text such as boxes, tofu, question marks, missing characters, or ~~ placeholders.
---

# Defold UI Text And Fonts

## Scope

Use this skill for Defold UI text rendering and font coverage work. It applies when editing GUI text nodes, Label components, HUD labels, localization strings, or `.font` resources.

## Baseline

Defold fonts render Label components and GUI text nodes. A font resource includes printable ASCII by default; Hangul, CJK, emoji, symbols, and other non-ASCII glyphs must be intentionally covered by the selected source font and font resource settings. Runtime fonts can generate glyphs on demand, but text is only safe to show after the needed glyphs are resolved.

Reference: https://defold.com/manuals/font/

## Pre-Flight

- inspect every UI string touched and classify it as ASCII-only, localized, or dynamic
- identify which `.font` resource each GUI text node or Label component actually uses
- inspect the font source file (`.ttf`, `.otf`, `.fnt`) and the Editor `Characters` / `.font` `extra_characters`, `all_chars`, cache, and runtime generation settings
- for Label components, confirm the Material matches the font type: bitmap, distance field, or BMFont
- if runtime fonts are used, inspect `game.project` `font.runtime_generation`, App Manifest text layout settings, and any language-specific font collection wiring
- never assume the built-in/default font can render Korean, CJK, emoji, or project-specific symbols
- check for existing symptoms such as `~~`, boxes, tofu, `?`, blank labels, missing units, or partial numbers

## Operating Procedure

- preserve the requested language unless the user explicitly asks for ASCII copy or the project has an ASCII-only UI convention
- if UI copy contains Korean or other non-ASCII text, wire a project-local font asset with those glyphs instead of relying on the default font
- include all dynamic text characters: digits, punctuation, spaces, units, suffixes, separators, and every localized word that can appear at runtime
- prefer explicit `Characters` / `extra_characters` coverage for known UI strings; use `all_chars` only when bundle size and texture memory tradeoffs are acceptable
- keep font assets local to the project and verify their license before adding them
- for runtime fonts, call `font.prewarm_text(font_collection, text, callback)` for dynamic or localized strings and only reveal/update text after the callback succeeds
- when using split language fonts, add the needed `.ttf` to the font collection before prewarming; `font.add_font()` does not by itself render every glyph
- keep font fixes scoped to GUI, Label, and font resources unless the text source itself is wrong

## Validation

- search changed UI files for non-ASCII strings and confirm each one maps to a font with matching glyph coverage
- build the target platform and visually inspect the affected screen after the relevant state change, not only the initial screen
- for Label components, inspect both the font and material resource if text is blank, blurry, or unexpectedly missing
- verify dynamic values with representative examples such as `Height: 1m`, Korean labels, punctuation, and max-width values
- check logs for font cache, missing glyph, and `Out of available cache cells` errors
- if visual verification is not possible, report the remaining font-rendering risk explicitly
