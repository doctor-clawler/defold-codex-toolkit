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
- if the Defold Editor is running and `.internal/editor.port` exists, use the editor build endpoint as a separate compile check before or alongside platform bundles

## Operating Procedure

- map all modified files back to Defold build behavior (`game.project`, bootstrap scripts, collection proxy usage, and output locations)
- avoid introducing assumptions about platform-specific flags that are not present in the local project
- keep build changes orthogonal to gameplay or GUI behavior
- when adding automation, include clear path and artifact output expectations (`bundle`, `build`, `artifacts`, and related outputs)
- prefer existing repo conventions for naming and directory layouts
- when a playable ad or single-file HTML deliverable is requested, build a normal `wasm-web` bundle first and then use `tools/single_html/pack.mjs`; do not use a pthread-only bundle
- when wiring Slack `/build`, prefer the shared contract below instead of inventing a project-specific command surface
- when the running editor exposes `http://127.0.0.1:<PORT>/openapi.json`, inspect it before relying on hard-coded editor HTTP endpoint assumptions
- for editor-resolved compile issues, run `curl -X POST "http://127.0.0.1:$(cat .internal/editor.port)/command/build"` and inspect the returned `success` and `issues`; do not treat this as a replacement for platform-specific bundle/export validation

## Shared Slack `/build` Contract

When a Defold project should support the shared Slack `/build` command, standardize these files in the project root:

- `scripts/build_and_upload_android.sh`
- `scripts/build_android.sh`
- `scripts/upload_android_build_to_slack.sh`

Behavior contract:

- `_ops` or another shared daemon looks only for `scripts/build_and_upload_android.sh`
- if the script is missing, the daemon should return `빌드 스크립트가 없습니다.`
- the project script is responsible for both Android build and Slack upload
- the canonical staged artifact should land at `.local/artifacts/<project-slug>-android.apk`

Recommended environment defaults:

- `BOB_JAR`: shared `bob.jar` path for the workspace
- `ARTIFACT_DIR`: `<repo>/.local/artifacts`
- `SLACK_CHANNEL`: workspace default upload channel, overridable per project or per invocation

Recommended composition:

1. `build_android.sh` runs `bob.jar`, creates the debug keystore if needed, and stages the APK/AAB into `.local/artifacts`.
2. `upload_android_build_to_slack.sh` uploads the staged artifact with the shared Slack sender.
3. `build_and_upload_android.sh` calls the two scripts in sequence and exits non-zero on any failure.

## Validation

- target platform, mode, and config are explicitly named
- output artifacts land in the expected local folders
- no invented Defold build flags or lifecycle behavior is introduced
- the change set is minimal and scoped to build or bundle responsibilities
- shared `/build` projects use the standard script paths so the daemon can discover them without per-project code
- if the editor build endpoint is used, the reported result includes the JSON `success` value and any `issues`

## Single-HTML HTML5 Bundles

The toolkit repository includes `tools/single_html/pack.mjs` for converting an existing Defold `wasm-web` HTML5 bundle into one self-contained HTML file.

Requirements and setup:

- Node.js 18 or newer
- Zstandard CLI 1.5 or newer
- `npm install --prefix tools/single_html`

Example:

```bash
node tools/single_html/pack.mjs \
  "build/default-web/My Game" \
  --output "build/MyGame.single.html"
```

Use `--compression none` only for debugging. The production default is Zstandard compression. Runtime downloads initiated by game code are not captured, so keep required resources in the Defold archive or the HTML template. Validate target-network size limits and SDK requirements separately from the packer's own self-contained-output checks.

Single-HTML validation:

- run `npm test --prefix tools/single_html`
- confirm the source bundle uses `wasm-web`, not pthread-only WebAssembly
- open the output through the intended delivery path and inspect browser console errors
- verify gameplay input and any advertising SDK callbacks separately
