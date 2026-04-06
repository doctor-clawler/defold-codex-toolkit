# Defold Codex Toolkit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure this repository into a standalone public GitHub-ready Codex plugin package named `defold-codex-toolkit`, with root-level plugin metadata, Defold-specific skills, a project-scoped marketplace example, and a practical Korean README.

**Architecture:** Convert the repository from a nested marketplace host into a root-level plugin package. Keep the runtime artifact set small: one plugin manifest, four narrow Defold-only skills, one integration example, and one installation-focused README. Remove the old nested `plugins/defold-helper` layout so the repository reads clearly as a reusable plugin package.

**Tech Stack:** JSON manifests, Markdown documentation, shell-based repository verification, Git

---

### Task 1: Flatten The Repository Into A Root-Level Plugin Package

**Files:**
- Create: `.codex-plugin/plugin.json`
- Create: `examples/marketplace.json.example`
- Create: `skills/defold-build-bundle/`
- Create: `skills/defold-ui-input/`
- Create: `skills/defold-debug-workflow/`
- Create: `skills/defold-project-conventions/`
- Delete: `.agents/plugins/marketplace.json`
- Delete: `plugins/defold-helper/.codex-plugin/plugin.json`
- Delete: `plugins/defold-helper/scripts/defold-docs.sh`
- Delete: `plugins/defold-helper/skills/defold-implementation/SKILL.md`

- [ ] **Step 1: Replace the nested manifest with the new root manifest**

```json
{
  "name": "defold-codex-toolkit",
  "version": "0.1.0",
  "description": "Defold-specific Codex workflow toolkit for build, UI/input, debugging, and project conventions.",
  "author": {
    "name": "clawler"
  },
  "license": "MIT",
  "skills": "./skills/",
  "interface": {
    "displayName": "Defold Codex Toolkit",
    "shortDescription": "Defold-only workflow skills for Codex",
    "developerName": "clawler",
    "category": "Coding",
    "capabilities": [
      "Interactive",
      "Write"
    ]
  }
}
```

- [ ] **Step 2: Create the project-scoped marketplace example**

```json
{
  "name": "example-project-marketplace",
  "interface": {
    "displayName": "Example Project Marketplace"
  },
  "plugins": [
    {
      "name": "defold-codex-toolkit",
      "source": {
        "source": "local",
        "path": "./plugins/defold-codex-toolkit"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Coding"
    }
  ]
}
```

- [ ] **Step 3: Remove the old marketplace-host layout**

```text
Delete .agents/plugins/marketplace.json
Delete plugins/defold-helper/.codex-plugin/plugin.json
Delete plugins/defold-helper/scripts/defold-docs.sh
Delete plugins/defold-helper/skills/defold-implementation/SKILL.md
Delete now-empty directories under plugins/defold-helper and .agents/plugins
```

- [ ] **Step 4: Verify the top-level tree now reflects a standalone plugin package**

Run: `find . -maxdepth 3 \( -path './.git' -o -path './docs/superpowers' \) -prune -o -print | sort`
Expected: root contains `.codex-plugin`, `skills`, `examples`, `README.md`, `LICENSE`, and no runtime `.agents/plugins/marketplace.json`

- [ ] **Step 5: Commit the structural migration**

```bash
git add .codex-plugin examples .agents plugins
git commit -m "refactor: flatten repository into root plugin package"
```

### Task 2: Write The Defold-Only Skill Set

**Files:**
- Create: `skills/defold-build-bundle/SKILL.md`
- Create: `skills/defold-ui-input/SKILL.md`
- Create: `skills/defold-debug-workflow/SKILL.md`
- Create: `skills/defold-project-conventions/SKILL.md`

- [ ] **Step 1: Add the build and bundle skill**

```md
---
name: defold-build-bundle
description: Use when working in a Defold repository and the task is specifically about Defold builds, bundles, archives, export targets, release packaging, or build configuration checks.
---

# Defold Build And Bundle

## Focus

Use this skill only for Defold build and packaging work. Confirm the actual Defold project layout, target platform, and build entry points before changing scripts or CI.

## Workflow

- inspect `game.project`, bundle scripts, CI tasks, and output directories first
- identify whether the task is editor build, command-line bundle, archive export, or release packaging
- keep platform-specific assumptions explicit
- avoid inventing Defold CLI flags or output conventions

## Checks

- target platform and variant are named explicitly
- paths and output folders match the repository
- changes do not mix build concerns with gameplay logic
```

- [ ] **Step 2: Add the UI and input skill**

```md
---
name: defold-ui-input
description: Use when working in a Defold repository and the task is specifically about GUI scripts, input focus, pointer or touch handling, coordinate conversion, modal UI, or gameplay input leakage.
---

# Defold UI And Input

## Focus

Use this skill only for Defold GUI and input-routing work. Inspect the local input flow before editing.

## Workflow

- inspect `on_input()` ownership, focus acquisition, and release
- separate GUI-space hit testing from world-space picking
- treat modal overlays and popups as explicit input boundaries
- check touch and mouse behavior together when both matter

## Checks

- no invented input lifecycle behavior
- GUI and world coordinates stay separate unless explicitly converted
- modal UI consumes input deliberately when required
```

- [ ] **Step 3: Add the debugging workflow skill**

```md
---
name: defold-debug-workflow
description: Use when working in a Defold repository and the task is specifically about reproducing, isolating, and fixing Defold runtime, messaging, lifecycle, rendering, or engine API issues.
---

# Defold Debug Workflow

## Focus

Use this skill only for Defold debugging tasks. Prefer a reproducible symptom and the smallest validating check before changing code.

## Workflow

- identify the concrete failing scene, script, system, or message path
- inspect logs, lifecycle callbacks, message senders and receivers, and relevant render or collection state
- validate engine API expectations before assuming generic Lua behavior
- make the smallest change that proves the diagnosis

## Checks

- the failure mode is stated before the fix
- suspected engine behavior is verified against real Defold APIs
- validation covers the original symptom after the change
```

- [ ] **Step 4: Add the project conventions skill**

```md
---
name: defold-project-conventions
description: Use when working in a Defold repository and the task is specifically about understanding or preserving that project's Defold folder layout, messaging conventions, scene composition, naming rules, or shared helpers before editing.
---

# Defold Project Conventions

## Focus

Use this skill when a Defold task requires reading the local project structure before making changes.

## Workflow

- inspect folder layout, shared Lua modules, factories, collections, GUI scripts, and naming patterns first
- preserve project-local architecture unless the task explicitly asks for refactoring
- reuse existing message names, helper modules, and scene boundaries where possible
- call out convention conflicts before editing

## Checks

- edits follow the repository's established Defold structure
- new names match nearby naming patterns
- shared helpers are reused instead of duplicated when appropriate
```

- [ ] **Step 5: Verify all skill descriptions are Defold-specific and non-generic**

Run: `rg -n "^description:" skills/*/SKILL.md`
Expected: every description starts with `Use when working in a Defold repository`

- [ ] **Step 6: Commit the skill set**

```bash
git add skills
git commit -m "feat: add defold codex toolkit skills"
```

### Task 3: Rewrite README For Public Reuse

**Files:**
- Modify: `README.md`
- Reference: `examples/marketplace.json.example`

- [ ] **Step 1: Replace the current README with a Korean installation guide**

```md
# Defold Codex Toolkit

Defold 프로젝트에서 재사용할 수 있도록 정리한 공개 GitHub용 Codex plugin 저장소입니다.

## 프로젝트 소개

이 저장소는 Defold 작업에 맞춘 Codex skill 묶음을 제공합니다. 공개 GitHub 레포지토리로 관리할 수 있지만, 이것만 GitHub에 올린다고 해서 OpenAI 공식 공용 marketplace에 자동 등록되지는 않습니다.

## 제공 기능

- Defold build and bundle 작업 가이드
- Defold GUI and input 작업 가이드
- Defold debugging workflow 가이드
- Defold project conventions 점검 가이드

## 디렉터리 구조

```text
.codex-plugin/plugin.json
skills/...
examples/marketplace.json.example
README.md
```

## 설치 방법

1. 이 저장소를 원하는 위치에 clone 또는 copy 합니다.
2. 다른 프로젝트에서 사용할 경우, 그 프로젝트 안의 `plugins/defold-codex-toolkit` 경로에 이 저장소를 둡니다.
3. 프로젝트의 `.agents/plugins/marketplace.json`에서 `./plugins/defold-codex-toolkit` 로컬 경로를 참조하도록 설정합니다.
4. Codex를 재시작하거나 plugin discovery를 갱신합니다.

## 프로젝트 한정 사용 방법

이 plugin은 GitHub URL 직접 설치 방식이 아니라 로컬 path 참조 방식으로 연결합니다.

## marketplace.json 예시

`examples/marketplace.json.example` 참고

## Codex에서 사용되는 방식

Codex는 `.codex-plugin/plugin.json`을 읽고 `skills/` 아래의 Defold 전용 skill들을 발견합니다.

## 주의사항 / 제한사항

- GitHub URL만 입력해서 바로 설치되는 구조가 아닙니다.
- 먼저 로컬에 clone 또는 copy 해야 합니다.
- 프로젝트별 marketplace가 그 로컬 경로를 참조해야 합니다.
```

- [ ] **Step 2: Make the README explicit about non-goals**

```md
이 저장소의 목적은 공개 GitHub plugin package를 제공하는 것입니다. OpenAI 공식 공용 marketplace 자동 등록은 범위에 포함되지 않습니다.
```

- [ ] **Step 3: Link the README example directly to the bundled example file**

```md
프로젝트 루트의 `.agents/plugins/marketplace.json`에는 아래 예시와 같은 entry를 추가하면 됩니다.
자세한 JSON은 `examples/marketplace.json.example` 파일을 그대로 복사해서 시작하는 것을 권장합니다.
```

- [ ] **Step 4: Verify the README covers every required section from the approved spec**

Run: `rg -n "프로젝트 소개|제공 기능|디렉터리 구조|설치 방법|프로젝트 한정 사용 방법|marketplace.json 예시|Codex에서 사용되는 방식|주의사항 / 제한사항" README.md`
Expected: every required section is present exactly once

- [ ] **Step 5: Commit the rewritten README**

```bash
git add README.md examples/marketplace.json.example
git commit -m "docs: add public reuse guide for defold codex toolkit"
```

### Task 4: Final Verification Against The Spec

**Files:**
- Verify: `docs/superpowers/specs/2026-04-07-defold-codex-toolkit-design.md`
- Verify: `.codex-plugin/plugin.json`
- Verify: `skills/*/SKILL.md`
- Verify: `examples/marketplace.json.example`
- Verify: `README.md`

- [ ] **Step 1: Validate both JSON files parse successfully**

Run: `python3 -m json.tool .codex-plugin/plugin.json >/dev/null && python3 -m json.tool examples/marketplace.json.example >/dev/null`
Expected: exit code 0

- [ ] **Step 2: Verify the root structure matches the intended public package layout**

Run: `find . -maxdepth 2 \( -path './.git' -o -path './docs/superpowers' \) -prune -o -print | sort`
Expected: `.codex-plugin`, `skills`, `examples`, `README.md`, `LICENSE`, and no nested runtime plugin package under `plugins/defold-helper`

- [ ] **Step 3: Check spec coverage against the shipped files**

Run: `sed -n '1,220p' docs/superpowers/specs/2026-04-07-defold-codex-toolkit-design.md`
Expected: every required artifact from the spec exists in the repository after the migration

- [ ] **Step 4: Inspect the final diff before reporting completion**

Run: `git status --short && git diff --stat`
Expected: the change set is limited to the root plugin package migration, skill files, example file, README rewrite, and process docs

- [ ] **Step 5: Commit the verified final state**

```bash
git add .codex-plugin skills examples README.md .agents plugins docs/superpowers/plans/2026-04-07-defold-codex-toolkit.md
git commit -m "feat: publish defold codex toolkit plugin package"
```
