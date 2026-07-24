import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";
import zlib from "node:zlib";

import {
  PackError,
  createRequestRuntimeJs,
  packBundle,
  patchDmloader,
} from "../pack.mjs";

async function createSyntheticBundle(options = {}) {
  const root = await mkdtemp(path.join(os.tmpdir(), "defold-single-html-"));
  await mkdir(path.join(root, "archive"), { recursive: true });

  const executableName = options.executableName ?? "SampleGame";
  const engineStart = options.omitEngineStart
    ? ""
    : `EngineLoader.load("canvas", "${executableName}");`;

  await writeFile(
    path.join(root, "index.html"),
    `<!doctype html>
<html>
<head>
  <link rel="preload" as="fetch" href="archive/archive_files.json">
  <link rel="stylesheet" href="loader.css">
  <style>.inline-image { background-image: url('inline.png'); }</style>
</head>
<body style="background-image: url('body.png')">
  <canvas id="canvas"></canvas>
  <img src="logo.png" alt="logo">
  <script id="engine-loader" type="text/javascript" src="dmloader.js"></script>
  <script>
    var warning = window.location.href.startsWith("file://");
    if (!warning) { ${engineStart} }
  </script>
</body>
</html>`,
    "utf8",
  );

  await writeFile(
    path.join(root, "dmloader.js"),
    `var CUSTOM_PARAMETERS = {};
var Module = { isWASMPthreadSupported: true };
var EngineLoader = {
  stream_wasm: true,
  loadAndRunScriptAsync: function(src) {
    var request = new XMLHttpRequest();
    request.responseType = "text";
    request.onload = function() {
      var response = request.response;
      const script = document.createElement('script');
      script.src = src;
      script.type = "text/javascript";
      document.body.appendChild(script);
    };
    request.open("GET", src, true);
    request.send();
  },
  load: function(canvasId, exeName) {
    var manifest = new XMLHttpRequest();
    manifest.responseType = "text";
    manifest.onload = function() {
      document.body.dataset.archiveLoaded = JSON.parse(manifest.response).total_size;
    };
    manifest.open("GET", "archive/archive_files.json", true);
    manifest.send();

    var wasm = new XMLHttpRequest();
    wasm.responseType = "arraybuffer";
    wasm.onload = function() {
      document.body.dataset.wasmBytes = wasm.response.byteLength;
    };
    wasm.open("GET", exeName + ".wasm", true);
    wasm.send();

    this.loadAndRunScriptAsync(exeName + "_wasm.js");
  }
};
if (XMLHttpRequest.DONE === 4) { /* current Defold-style constant use */ }
`,
    "utf8",
  );

  await writeFile(
    path.join(root, `${executableName}_wasm.js`),
    "document.body.dataset.engineLoaded = 'yes';\n",
  );
  await writeFile(path.join(root, `${executableName}.wasm`), Buffer.from([0, 97, 115, 109]));
  await writeFile(
    path.join(root, "archive", "archive_files.json"),
    JSON.stringify({
      content: [
        {
          name: "game.arcd",
          size: 4,
          pieces: [{ name: "game0.arcd", offset: 0 }],
        },
      ],
      total_size: 4,
    }),
  );
  await writeFile(path.join(root, "archive", "game0.arcd"), Buffer.from([1, 2, 3, 4]));
  await writeFile(
    path.join(root, "loader.css"),
    `@import "nested.css" screen; .css-image { background: url("css.png"); }`,
    "utf8",
  );

  await writeFile(
    path.join(root, "nested.css"),
    `.nested-image { background: url("nested.png"); }`,
    "utf8",
  );

  const tinyPng = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    "base64",
  );
  for (const filename of ["inline.png", "body.png", "logo.png", "css.png", "nested.png"]) {
    await writeFile(path.join(root, filename), tinyPng);
  }

  return { root, executableName };
}

test("patchDmloader replaces network loading and dynamic script src", () => {
  const source = `
var x = new XMLHttpRequest();
const script = document.createElement('script');
script.src = src;
document.body.appendChild(script);
`;
  const output = patchDmloader(source);
  assert.match(output, /new DefoldSingleHtmlRequest\(\)/);
  assert.match(output, /script\.text = response/);
  assert.doesNotMatch(output, /script\.src\s*=\s*src/);
});

test("packs a current-style Defold bundle into one self-contained HTML", async () => {
  const { root, executableName } = await createSyntheticBundle();
  const outputFile = path.join(root, "out", "playable.html");

  const result = await packBundle({
    inputDir: root,
    outputFile,
    compression: "none",
  });

  assert.equal(result.executableName, executableName);
  assert.equal(result.resourceCount, 4);
  assert.equal(result.compression, "none");

  const output = await readFile(outputFile, "utf8");
  assert.match(output, /DefoldSingleHtmlRequest/);
  assert.match(output, /SampleGame_wasm\.js/);
  assert.match(output, /archive\/archive_files\.json/);
  assert.match(output, /archive\/game0\.arcd/);
  assert.match(output, /EngineLoader\.stream_wasm = false/);
  assert.match(output, /Module\.isWASMPthreadSupported = false/);
  assert.match(output, /script\.text = response/);
  assert.match(output, /data:image\/png;base64,/);
  assert.match(output, /data-inlined-from="loader\.css"/);
  assert.match(output, /@media screen/);
  assert.doesNotMatch(output, /src="dmloader\.js"/);
  assert.doesNotMatch(output, /href="loader\.css"/);
  assert.doesNotMatch(output, /url\(["']?(?:inline|body|css)\.png/);
  assert.doesNotMatch(output, /window\.location\.href\.startsWith\("file:\/\/"\)/);
  assert.doesNotMatch(output, /rel="preload"/);
});

test(
  "zstd mode emits standards-compliant frames",
  { skip: typeof zlib.zstdDecompressSync !== "function" },
  async () => {
    const { root, executableName } = await createSyntheticBundle();
    const outputFile = path.join(root, "playable-zstd.html");
    const fzstdStub = path.join(root, "fzstd-stub.js");
    await writeFile(
      fzstdStub,
      "window.fzstd = { decompress: function() { throw new Error('test stub'); } };",
      "utf8",
    );

    await packBundle({
      inputDir: root,
      outputFile,
      compression: "zstd",
      fzstdFile: fzstdStub,
    });

    const output = await readFile(outputFile, "utf8");
    const match = output.match(/var FILES = (\{.*?\});\n  var ALIASES =/s);
    assert.ok(match, "embedded file table should be present");
    const files = JSON.parse(match[1]);
    const entry = files[`${executableName}.wasm`];
    assert.equal(entry[1], "zstd");
    assert.deepEqual(
      Array.from(zlib.zstdDecompressSync(Buffer.from(entry[2], "base64"))),
      [0, 97, 115, 109],
    );
  },
);

test("generated scripts execute end-to-end without network access", async () => {
  const { root } = await createSyntheticBundle();
  const outputFile = path.join(root, "vm-playable.html");
  await packBundle({ inputDir: root, outputFile, compression: "none" });
  const output = await readFile(outputFile, "utf8");

  const context = {
    URL,
    Uint8Array,
    ArrayBuffer,
    TextDecoder,
    Blob,
    atob,
    setTimeout,
    clearTimeout,
    console,
    location: { href: pathToFileUrlForTest(outputFile), protocol: "file:" },
  };
  context.window = context;
  context.globalThis = context;
  context.document = {
    body: {
      dataset: {},
      appendChild(node) {
        if (node.text) vm.runInContext(node.text, context);
      },
    },
    createElement() {
      return {};
    },
  };
  vm.createContext(context);

  for (const match of output.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script\s*>/gi)) {
    vm.runInContext(match[1], context);
  }
  await new Promise((resolve) => setTimeout(resolve, 30));

  assert.equal(context.document.body.dataset.archiveLoaded, 4);
  assert.equal(context.document.body.dataset.wasmBytes, 4);
  assert.equal(context.document.body.dataset.engineLoaded, "yes");
});

function pathToFileUrlForTest(filename) {
  return `file://${filename.replaceAll("\\", "/")}`;
}

test("embedded request runtime serves text, JSON, and ArrayBuffer", async () => {
  const encoded = {
    "archive/hello.txt": [5, "none", Buffer.from("hello").toString("base64")],
    "archive/data.json": [7, "none", Buffer.from('{"x":1}').toString("base64")],
    "Game.wasm": [4, "none", Buffer.from([0, 97, 115, 109]).toString("base64")],
  };
  const context = {
    URL,
    Uint8Array,
    ArrayBuffer,
    TextDecoder,
    Blob,
    atob,
    setTimeout,
    clearTimeout,
  };
  context.window = context;
  context.globalThis = context;
  vm.createContext(context);
  vm.runInContext(createRequestRuntimeJs(encoded), context);

  const request = (url, responseType) =>
    new Promise((resolve, reject) => {
      const xhr = new context.DefoldSingleHtmlRequest();
      xhr.responseType = responseType;
      xhr.onload = () => resolve(xhr);
      xhr.onerror = reject;
      xhr.open("GET", url, true);
      xhr.send();
    });

  const text = await request("https://cdn.example/game/archive/hello.txt?cache=1", "text");
  assert.equal(text.status, 200);
  assert.equal(text.response, "hello");
  assert.equal(text.getResponseHeader("Content-Length"), "5");

  const json = await request("/data.json", "json");
  assert.equal(json.response.x, 1);

  const wasm = await request("Game.wasm", "arraybuffer");
  assert.deepEqual(Array.from(new Uint8Array(wasm.response)), [0, 97, 115, 109]);
});

test("rejects a pthread-only bundle with an actionable error", async () => {
  const { root, executableName } = await createSyntheticBundle();
  await writeFile(path.join(root, `${executableName}_pthread_wasm.js`), "pthread");
  await writeFile(path.join(root, `${executableName}_pthread.wasm`), Buffer.from([0]));
  const { rm } = await import("node:fs/promises");
  await rm(path.join(root, `${executableName}_wasm.js`));
  await rm(path.join(root, `${executableName}.wasm`));

  await assert.rejects(
    packBundle({ inputDir: root, compression: "none" }),
    (error) =>
      error instanceof PackError &&
      /non-pthread wasm-web bundle/.test(error.message),
  );
});

test("rejects unresolved local assets instead of silently producing a broken file", async () => {
  const { root } = await createSyntheticBundle();
  const indexPath = path.join(root, "index.html");
  const index = await readFile(indexPath, "utf8");
  await writeFile(indexPath, index.replace("logo.png", "missing.png"), "utf8");

  await assert.rejects(
    packBundle({ inputDir: root, compression: "none" }),
    (error) => error instanceof PackError && /referenced asset/.test(error.message),
  );
});
