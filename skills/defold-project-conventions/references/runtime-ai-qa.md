# Built-Product Runtime AI QA

Use this contract when an AI agent must control and observe a built Defold game
product. Defold Editor HTTP commands, editor console access, and source-level
tests are separate verification surfaces.

## Ownership

Keep transport-neutral command registration, bounded serialization, request
validation, state snapshots, log cursors, metrics, and assertion helpers in
`defold_helper`. Keep game-specific collection URLs, GUI node IDs, gameplay
state, input mappings, and assertions in the consuming project.

Use a small project adapter to connect the shared helper to a platform-appropriate
private test transport. Do not bake desktop, mobile, or HTML5 transport details
into otherwise reusable gameplay helpers.

## Capability contract

Provide discoverable, versioned equivalents of:

- `qa.capabilities`
- `qa.get_state`
- `qa.input`
- `qa.wait`
- `qa.screenshot`
- `qa.logs`
- `qa.metrics`
- `qa.assert`

Route `qa.input` through the same action/message path used by real keyboard,
pointer, touch, or gamepad input. Name state-changing setup commands as fixtures;
do not use forced victory, teleport, or direct resource mutation as a substitute
for real-input coverage.

## Build and security contract

- Include or enable the bridge only in an explicit Debug, Development, or QA
  bundle configuration.
- Keep it default-off and require explicit per-run enablement plus an ephemeral
  token.
- Use only a local/private test transport; never expose a public endpoint or
  embed reusable credentials.
- Bound request size, response size, command time, and retained logs.
- Serialize engine-facing work through normal Defold update/message boundaries.
- Make the release gate prove that the Release/Store bundle has no reachable
  bridge and cannot enable one at runtime.

## Verification

1. Build and launch the actual bundle independently of the Defold Editor.
2. Connect to the runtime bridge and read `qa.capabilities`.
3. Drive a representative flow through the real input adapter.
4. Compare structured state, logs, metrics, and assertions around the flow.
5. Capture screenshots and inspect key UX checkpoints visually.
6. Build the Release/Store bundle and verify the bridge is absent or
   unreachable.

Structured runtime evidence does not close visual QA. Retain screenshot or
Computer Use checks for clipping, focus, animation, layout, and platform input.
