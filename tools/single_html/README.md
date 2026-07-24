# Defold single-HTML packer

`pack.mjs` converts an existing Defold HTML5 bundle into one self-contained HTML file suitable for playable-ad delivery and other single-file hosting environments.

It embeds:

- the Defold WebAssembly binary and generated engine JavaScript;
- `archive/archive_files.json` and every archive piece referenced by it;
- `dmloader.js`, local scripts, stylesheets, images, fonts, audio, and video referenced by `index.html`;
- a small in-memory `XMLHttpRequest` replacement used by Defold's loader.

Core Defold files are Zstandard-compressed and Base64-encoded by default. The browser-side decompressor is provided by [`fzstd`](https://github.com/101arrowz/fzstd).

## Requirements

- Node.js 18 or newer;
- Zstandard CLI 1.5 or newer (`zstd` on `PATH`);
- a Defold `wasm-web` HTML5 bundle containing `index.html`, `dmloader.js`, `<exe>_wasm.js`, `<exe>.wasm`, and `archive/`.

Install the one JavaScript dependency once:

```bash
npm install --prefix tools/single_html
```

## Usage

First create a normal HTML5 bundle in Defold. Point the packer at the directory that directly contains `index.html`:

```bash
node tools/single_html/pack.mjs \
  "build/default-web/My Game" \
  --output "build/MyGame.single.html"
```

The default output is `<bundle-dir>/<executable-name>.single.html` when `--output` is omitted.

Useful options:

```text
--compression zstd|none  zstd is the production default; none is useful for debugging
--zstd-level 1..19       compression level, default 19
--zstd <command>         custom zstd executable path
--fzstd <file>           custom fzstd UMD build
--allow-external         preserve external script/style/image references
```

The resulting file can be opened directly with a `file://` URL. Defold's streaming WebAssembly path and pthread selection are disabled because all engine files are served from the embedded resource table.

## Limitations

- Build for `wasm-web`, not a pthread-only architecture. A bundle that contains a normal `wasm-web` engine and pthread files is packed using the normal engine.
- Runtime downloads initiated by game code are not captured. Include those resources in the Defold archive or embed them explicitly in the HTML template.
- The packer validates local references in the generated HTML, but advertising-network size limits and SDK requirements must still be checked on target devices.

## Tests

```bash
npm test --prefix tools/single_html
```
