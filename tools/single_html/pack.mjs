#!/usr/bin/env node

import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_ZSTD_LEVEL = 19;
const SUPPORTED_COMPRESSION = new Set(["zstd", "none"]);
const FZSTD_LICENSE_BANNER = `/*!
fzstd - MIT License
Copyright (c) 2020 Arjun Barrett

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/`;

class PackError extends Error {
  constructor(message) {
    super(message);
    this.name = "PackError";
  }
}

function usage() {
  return `Usage:
  node pack.mjs <defold-html5-bundle-dir> [options]

Options:
  -o, --output <file>        Output HTML path. Defaults to <exe>.single.html
      --compression <mode>   zstd (default) or none
      --zstd-level <1-19>    Zstandard compression level (default: 19)
      --zstd <command>       Zstandard executable (default: zstd)
      --fzstd <file>         fzstd UMD file; normally resolved from node_modules
      --allow-external       Keep external script/style/image references
  -h, --help                 Show this help

Example:
  npm install --prefix tools/single_html
  node tools/single_html/pack.mjs build/default-web/MyGame \\
    --output build/MyGame.single.html
`;
}

function parseCliArgs(argv) {
  const options = {
    inputDir: null,
    outputFile: null,
    compression: "zstd",
    zstdLevel: DEFAULT_ZSTD_LEVEL,
    zstdBinary: "zstd",
    fzstdFile: null,
    allowExternal: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "-h" || value === "--help") {
      options.help = true;
    } else if (value === "-o" || value === "--output") {
      options.outputFile = requireOptionValue(argv, ++index, value);
    } else if (value === "--compression") {
      options.compression = requireOptionValue(argv, ++index, value);
    } else if (value === "--zstd-level") {
      const raw = requireOptionValue(argv, ++index, value);
      options.zstdLevel = Number(raw);
    } else if (value === "--zstd") {
      options.zstdBinary = requireOptionValue(argv, ++index, value);
    } else if (value === "--fzstd") {
      options.fzstdFile = requireOptionValue(argv, ++index, value);
    } else if (value === "--allow-external") {
      options.allowExternal = true;
    } else if (value.startsWith("-")) {
      throw new PackError(`Unknown option: ${value}`);
    } else if (options.inputDir === null) {
      options.inputDir = value;
    } else {
      throw new PackError(`Unexpected positional argument: ${value}`);
    }
  }

  return options;
}

function requireOptionValue(argv, index, option) {
  if (index >= argv.length || argv[index].startsWith("-")) {
    throw new PackError(`${option} requires a value.`);
  }
  return argv[index];
}

function ensureCompressionOptions(options) {
  if (!SUPPORTED_COMPRESSION.has(options.compression)) {
    throw new PackError(
      `Unsupported compression '${options.compression}'. Use 'zstd' or 'none'.`,
    );
  }
  if (
    !Number.isInteger(options.zstdLevel) ||
    options.zstdLevel < 1 ||
    options.zstdLevel > 19
  ) {
    throw new PackError("--zstd-level must be an integer from 1 through 19.");
  }
}

function isInside(root, candidate) {
  const relative = path.relative(root, candidate);
  return (
    relative === "" ||
    (relative !== ".." &&
      !relative.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(relative))
  );
}

async function assertDirectory(directory) {
  let stat;
  try {
    stat = await fs.stat(directory);
  } catch {
    throw new PackError(`Bundle directory does not exist: ${directory}`);
  }
  if (!stat.isDirectory()) {
    throw new PackError(`Bundle path is not a directory: ${directory}`);
  }
}

async function readRequiredFile(filename, label = "file") {
  try {
    return await fs.readFile(filename);
  } catch (error) {
    if (error && error.code === "ENOENT") {
      throw new PackError(`Missing ${label}: ${filename}`);
    }
    throw error;
  }
}

function detectExecutableName(indexHtml, filenames) {
  const loadMatch = indexHtml.match(
    /EngineLoader\.load\s*\(\s*["'][^"']+["']\s*,\s*["']([^"']+)["']\s*\)/,
  );
  if (loadMatch) {
    return loadMatch[1];
  }

  const candidates = filenames
    .filter((name) => name.endsWith("_wasm.js") && !name.endsWith("_pthread_wasm.js"))
    .map((name) => name.slice(0, -"_wasm.js".length));

  if (candidates.length === 1) {
    return candidates[0];
  }
  throw new PackError(
    "Could not determine the Defold executable name from index.html or *_wasm.js.",
  );
}

function classifyReference(reference) {
  const value = reference.trim();
  if (
    value === "" ||
    value.startsWith("#") ||
    /^(?:data|blob|javascript|mailto|tel):/i.test(value)
  ) {
    return "embedded";
  }
  if (/^(?:https?:)?\/\//i.test(value) || /^[a-z][a-z0-9+.-]*:/i.test(value)) {
    return "external";
  }
  return "local";
}

function stripQueryAndHash(reference) {
  return reference.split("#", 1)[0].split("?", 1)[0];
}

function resolveLocalReference(bundleRoot, baseDirectory, reference) {
  let clean = stripQueryAndHash(reference.trim()).replaceAll("\\", "/");
  try {
    clean = decodeURIComponent(clean);
  } catch {
    throw new PackError(`Invalid URL encoding in local reference: ${reference}`);
  }

  const resolved = clean.startsWith("/")
    ? path.resolve(bundleRoot, `.${clean}`)
    : path.resolve(baseDirectory, clean);
  if (!isInside(bundleRoot, resolved)) {
    throw new PackError(`Local reference escapes the bundle directory: ${reference}`);
  }
  return resolved;
}

function mimeType(filename) {
  const extension = path.extname(filename).toLowerCase();
  const types = {
    ".avif": "image/avif",
    ".bmp": "image/bmp",
    ".css": "text/css",
    ".gif": "image/gif",
    ".ico": "image/x-icon",
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".js": "text/javascript",
    ".json": "application/json",
    ".mp3": "audio/mpeg",
    ".mp4": "video/mp4",
    ".ogg": "audio/ogg",
    ".otf": "font/otf",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".ttf": "font/ttf",
    ".wav": "audio/wav",
    ".webm": "video/webm",
    ".webp": "image/webp",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
  };
  return types[extension] ?? "application/octet-stream";
}

async function fileToDataUri(filename) {
  const data = await readRequiredFile(filename, "referenced asset");
  return `data:${mimeType(filename)};base64,${data.toString("base64")}`;
}

async function replaceAsync(input, expression, replacer) {
  const matches = Array.from(input.matchAll(expression));
  if (matches.length === 0) {
    return input;
  }
  const replacements = await Promise.all(matches.map((match) => replacer(...match)));
  let output = "";
  let cursor = 0;
  for (let index = 0; index < matches.length; index += 1) {
    const match = matches[index];
    output += input.slice(cursor, match.index) + replacements[index];
    cursor = match.index + match[0].length;
  }
  return output + input.slice(cursor);
}

function getAttribute(attributes, name) {
  const expression = new RegExp(
    `(?:^|\\s)${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`,
    "i",
  );
  const match = attributes.match(expression);
  return match ? match[1] ?? match[2] ?? match[3] : null;
}

function escapeInlineScript(source) {
  return source.replace(/<\/script/gi, "<\\/script");
}

async function rewriteCssUrls(
  css,
  bundleRoot,
  baseDirectory,
  allowExternal,
  importStack = new Set(),
) {
  let transformed = await replaceAsync(
    css,
    /@import\s+(?:url\(\s*)?(?:(["'])([^"']+)\1|([^\s);]+))\s*\)?\s*([^;]*);/gi,
    async (whole, quote, quotedReference, bareReference, mediaQuery) => {
      const reference = quotedReference ?? bareReference;
      const classification = classifyReference(reference);
      if (classification === "embedded") {
        return whole;
      }
      if (classification === "external") {
        if (allowExternal) {
          return whole;
        }
        throw new PackError(`External CSS import is not self-contained: ${reference}`);
      }

      const filename = resolveLocalReference(bundleRoot, baseDirectory, reference);
      const canonical = path.resolve(filename);
      if (importStack.has(canonical)) {
        throw new PackError(`Circular CSS import detected: ${reference}`);
      }
      const nestedStack = new Set(importStack);
      nestedStack.add(canonical);
      const importedCss = (await readRequiredFile(filename, "imported stylesheet")).toString(
        "utf8",
      );
      const rewritten = await rewriteCssUrls(
        importedCss,
        bundleRoot,
        path.dirname(filename),
        allowExternal,
        nestedStack,
      );
      const media = mediaQuery.trim();
      return media ? `@media ${media} {${rewritten}}` : rewritten;
    },
  );

  transformed = await replaceAsync(
    transformed,
    /url\(\s*(["']?)([^"')]+)\1\s*\)/gi,
    async (whole, quote, reference) => {
      const classification = classifyReference(reference);
      if (classification === "embedded") {
        return whole;
      }
      if (classification === "external") {
        if (allowExternal) {
          return whole;
        }
        throw new PackError(`External CSS resource is not self-contained: ${reference}`);
      }
      const filename = resolveLocalReference(bundleRoot, baseDirectory, reference);
      return `url(${await fileToDataUri(filename)})`;
    },
  );

  return transformed;
}

async function transformHtmlAssets(html, bundleRoot, allowExternal) {
  let transformed = html;

  transformed = transformed.replace(
    /<link\b(?=[^>]*\brel\s*=\s*["'][^"']*(?:preload|prefetch|preconnect|dns-prefetch|modulepreload)[^"']*["'])[^>]*>\s*/gi,
    "",
  );

  transformed = await replaceAsync(
    transformed,
    /<link\b([^>]*)>/gi,
    async (whole, attributes) => {
      const href = getAttribute(attributes, "href");
      const rel = (getAttribute(attributes, "rel") ?? "").toLowerCase();
      if (!href) {
        return whole;
      }
      const classification = classifyReference(href);
      if (rel.split(/\s+/).includes("stylesheet")) {
        if (classification === "external") {
          if (allowExternal) {
            return whole;
          }
          throw new PackError(`External stylesheet is not self-contained: ${href}`);
        }
        if (classification !== "local") {
          return whole;
        }
        const filename = resolveLocalReference(bundleRoot, bundleRoot, href);
        const css = (await readRequiredFile(filename, "stylesheet")).toString("utf8");
        const rewritten = await rewriteCssUrls(
          css,
          bundleRoot,
          path.dirname(filename),
          allowExternal,
        );
        return `<style data-inlined-from="${escapeHtmlAttribute(href)}">${rewritten}</style>`;
      }

      if (classification === "local" && /(?:icon|apple-touch-icon)/.test(rel)) {
        const filename = resolveLocalReference(bundleRoot, bundleRoot, href);
        return whole.replace(href, await fileToDataUri(filename));
      }
      if (classification === "external" && !allowExternal) {
        throw new PackError(`External link resource is not self-contained: ${href}`);
      }
      return whole;
    },
  );

  transformed = await replaceAsync(
    transformed,
    /<style\b([^>]*)>([\s\S]*?)<\/style\s*>/gi,
    async (whole, attributes, css) =>
      `<style${attributes}>${await rewriteCssUrls(
        css,
        bundleRoot,
        bundleRoot,
        allowExternal,
      )}</style>`,
  );

  transformed = await replaceAsync(
    transformed,
    /<(img|source|audio|video|track|input|object)\b([^>]*)>/gi,
    async (whole, tagName, attributes) => {
      let rewrittenAttributes = await replaceAsync(
        attributes,
        /\b(src|poster|data)\s*=\s*(["'])([^"']+)\2/gi,
        async (attributeWhole, attribute, quote, reference) => {
          const classification = classifyReference(reference);
          if (classification === "embedded") {
            return attributeWhole;
          }
          if (classification === "external") {
            if (allowExternal) {
              return attributeWhole;
            }
            throw new PackError(
              `External ${attribute} resource is not self-contained: ${reference}`,
            );
          }
          const filename = resolveLocalReference(bundleRoot, bundleRoot, reference);
          return `${attribute}=${quote}${await fileToDataUri(filename)}${quote}`;
        },
      );

      rewrittenAttributes = await replaceAsync(
        rewrittenAttributes,
        /\bsrcset\s*=\s*(["'])([^"']+)\1/gi,
        async (attributeWhole, quote, srcset) => {
          const entries = srcset.split(",").map((entry) => entry.trim()).filter(Boolean);
          const rewritten = [];
          for (const entry of entries) {
            const [reference, ...descriptor] = entry.split(/\s+/);
            const classification = classifyReference(reference);
            if (classification === "external") {
              if (!allowExternal) {
                throw new PackError(
                  `External srcset resource is not self-contained: ${reference}`,
                );
              }
              rewritten.push(entry);
            } else if (classification === "local") {
              const filename = resolveLocalReference(bundleRoot, bundleRoot, reference);
              rewritten.push([await fileToDataUri(filename), ...descriptor].join(" "));
            } else {
              rewritten.push(entry);
            }
          }
          return `srcset=${quote}${rewritten.join(", ")}${quote}`;
        },
      );

      return `<${tagName}${rewrittenAttributes}>`;
    },
  );

  transformed = await replaceAsync(
    transformed,
    /<([a-z][a-z0-9:-]*)\b([^>]*)>/gi,
    async (whole, tagName, attributes) => {
      const rewrittenAttributes = await replaceAsync(
        attributes,
        /\bstyle\s*=\s*(["'])([\s\S]*?)\1/gi,
        async (attributeWhole, quote, css) =>
          `style=${quote}${await rewriteCssUrls(
            css,
            bundleRoot,
            bundleRoot,
            allowExternal,
          )}${quote}`,
      );
      return `<${tagName}${rewrittenAttributes}>`;
    },
  );

  return transformed;
}

function escapeHtmlAttribute(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function patchDmloader(source) {
  let patched = source;
  const xhrMatches = patched.match(/\bXMLHttpRequest\b/g)?.length ?? 0;
  if (xhrMatches === 0) {
    throw new PackError(
      "dmloader.js does not contain XMLHttpRequest; its format may be unsupported.",
    );
  }
  patched = patched.replace(/\bXMLHttpRequest\b/g, "DefoldSingleHtmlRequest");

  const beforeScriptPatch = patched;
  patched = patched.replace(
    /([A-Za-z_$][\w$]*)\.src\s*=\s*src\s*;/,
    '$1.text = response + "\\n//# sourceURL=" + src;',
  );
  if (patched === beforeScriptPatch) {
    throw new PackError(
      "Could not patch dynamic engine-script loading in dmloader.js; its format may be unsupported.",
    );
  }
  return patched;
}

async function runZstd(data, binary, level) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, ["-q", `-${level}`, "-c"], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    const stdout = [];
    const stderr = [];
    child.stdout.on("data", (chunk) => stdout.push(chunk));
    child.stderr.on("data", (chunk) => stderr.push(chunk));
    child.on("error", (error) => {
      if (error.code === "ENOENT") {
        reject(
          new PackError(
            `Could not run '${binary}'. Install Zstandard or use --compression none.`,
          ),
        );
      } else {
        reject(error);
      }
    });
    child.on("close", (code) => {
      if (code === 0) {
        resolve(Buffer.concat(stdout));
      } else {
        reject(
          new PackError(
            `Zstandard failed with exit code ${code}: ${Buffer.concat(stderr).toString("utf8").trim()}`,
          ),
        );
      }
    });
    child.stdin.on("error", reject);
    child.stdin.end(data);
  });
}

async function encodeResource(data, options) {
  if (options.compression === "none") {
    return [data.byteLength, "none", data.toString("base64")];
  }
  const compressed = await runZstd(data, options.zstdBinary, options.zstdLevel);
  return [data.byteLength, "zstd", compressed.toString("base64")];
}

function buildAliases(resourceNames) {
  const aliases = {};
  const basenames = new Map();
  for (const name of resourceNames) {
    if (name.startsWith("archive/")) {
      aliases[name.slice("archive/".length)] = name;
    }
    const basename = path.posix.basename(name);
    const existing = basenames.get(basename);
    basenames.set(basename, existing === undefined ? name : null);
  }
  for (const [basename, canonical] of basenames) {
    if (canonical !== null && basename !== canonical) {
      aliases[basename] = canonical;
    }
  }
  return aliases;
}

export function createRequestRuntimeJs(encodedResources) {
  const names = Object.keys(encodedResources).sort();
  const ordered = {};
  for (const name of names) {
    ordered[name] = encodedResources[name];
  }
  const aliases = buildAliases(names);
  const resourcesJson = JSON.stringify(ordered).replaceAll("<", "\\u003c");
  const aliasesJson = JSON.stringify(aliases).replaceAll("<", "\\u003c");

  return `
(function(global) {
  "use strict";
  var FILES = ${resourcesJson};
  var ALIASES = ${aliasesJson};

  function normalize(url) {
    var value = String(url || "").replace(/\\\\/g, "/");
    try {
      value = new URL(value, (global.location && global.location.href) || "file:///").pathname;
    } catch (_) {
      value = value.split("#", 1)[0].split("?", 1)[0];
    }
    try { value = decodeURIComponent(value); } catch (_) {}
    return value.replace(/^\\/+/, "").replace(/^\\.\\//, "");
  }

  function findEntry(url) {
    var key = normalize(url);
    if (Object.prototype.hasOwnProperty.call(FILES, key)) return FILES[key];
    if (Object.prototype.hasOwnProperty.call(ALIASES, key)) return FILES[ALIASES[key]];
    var basename = key.slice(key.lastIndexOf("/") + 1);
    if (Object.prototype.hasOwnProperty.call(FILES, basename)) return FILES[basename];
    if (Object.prototype.hasOwnProperty.call(ALIASES, basename)) {
      return FILES[ALIASES[basename]];
    }
    return null;
  }

  function decodeBase64(value) {
    var binary = global.atob(value);
    var bytes = new Uint8Array(binary.length);
    for (var index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  }

  function decodeEntry(entry) {
    if (typeof entry[2] !== "string") {
      throw new Error("Embedded resource has already been consumed.");
    }
    var bytes = decodeBase64(entry[2]);
    if (entry[1] === "zstd") {
      if (!global.fzstd || typeof global.fzstd.decompress !== "function") {
        throw new Error("fzstd runtime is missing from the single-file bundle.");
      }
      bytes = global.fzstd.decompress(bytes, new Uint8Array(entry[0]));
    }
    if (bytes.byteLength !== entry[0]) {
      throw new Error("Decoded resource has an unexpected size.");
    }
    entry[2] = null; // Release the Base64 source as soon as the loader owns a copy.
    return bytes;
  }

  function bytesToText(bytes) {
    if (typeof global.TextDecoder === "function") {
      return new global.TextDecoder("utf-8").decode(bytes);
    }
    var binary = "";
    var chunk = 0x8000;
    for (var offset = 0; offset < bytes.length; offset += chunk) {
      binary += String.fromCharCode.apply(null, bytes.subarray(offset, offset + chunk));
    }
    try { return decodeURIComponent(escape(binary)); } catch (_) { return binary; }
  }

  function DefoldSingleHtmlRequest() {
    this.readyState = 0;
    this.status = 0;
    this.statusText = "";
    this.responseType = "";
    this.response = null;
    this.responseText = "";
    this.responseURL = "";
    this.method = "GET";
    this.url = "";
    this.async = true;
    this._entry = null;
  }

  DefoldSingleHtmlRequest.UNSENT = 0;
  DefoldSingleHtmlRequest.OPENED = 1;
  DefoldSingleHtmlRequest.HEADERS_RECEIVED = 2;
  DefoldSingleHtmlRequest.LOADING = 3;
  DefoldSingleHtmlRequest.DONE = 4;

  DefoldSingleHtmlRequest.prototype.open = function(method, url, async) {
    this.method = String(method || "GET").toUpperCase();
    this.url = String(url || "");
    this.async = async !== false;
    this.readyState = DefoldSingleHtmlRequest.OPENED;
    if (typeof this.onreadystatechange === "function") this.onreadystatechange();
  };

  DefoldSingleHtmlRequest.prototype.send = function() {
    var self = this;
    var execute = function() {
      try {
        var entry = findEntry(self.url);
        if (!entry) throw new Error("Embedded resource not found: " + self.url);
        self._entry = entry;
        var bytes = self.method === "HEAD" ? new Uint8Array(0) : decodeEntry(entry);
        self.readyState = DefoldSingleHtmlRequest.HEADERS_RECEIVED;
        self.status = 200;
        self.statusText = "OK";
        self.responseURL = self.url;
        if (typeof self.onreadystatechange === "function") self.onreadystatechange();

        self.readyState = DefoldSingleHtmlRequest.LOADING;
        if (typeof self.onprogress === "function") {
          self.onprogress({
            lengthComputable: true,
            loaded: self.method === "HEAD" ? 0 : entry[0],
            total: entry[0]
          });
        }

        if (self.method === "HEAD") {
          self.response = "";
          self.responseText = "";
        } else if (self.responseType === "arraybuffer") {
          self.response = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
        } else if (self.responseType === "blob") {
          self.response = new Blob([bytes]);
        } else {
          var text = bytesToText(bytes);
          self.responseText = text;
          self.response = self.responseType === "json" ? JSON.parse(text) : text;
        }

        self.readyState = DefoldSingleHtmlRequest.DONE;
        if (typeof self.onreadystatechange === "function") self.onreadystatechange();
        if (typeof self.onload === "function") self.onload({ target: self });
      } catch (error) {
        self.readyState = DefoldSingleHtmlRequest.DONE;
        self.status = 404;
        self.statusText = "Not Found";
        if (typeof self.onreadystatechange === "function") self.onreadystatechange();
        if (typeof self.onerror === "function") self.onerror(error);
      }
    };
    if (this.async) global.setTimeout(execute, 0); else execute();
  };

  DefoldSingleHtmlRequest.prototype.abort = function() {};
  DefoldSingleHtmlRequest.prototype.setRequestHeader = function() {};
  DefoldSingleHtmlRequest.prototype.overrideMimeType = function() {};
  DefoldSingleHtmlRequest.prototype.getAllResponseHeaders = function() {
    return this._entry ? "content-length: " + this._entry[0] + "\\r\\n" : "";
  };
  DefoldSingleHtmlRequest.prototype.getResponseHeader = function(name) {
    if (this._entry && String(name).toLowerCase() === "content-length") {
      return String(this._entry[0]);
    }
    return null;
  };

  global.DefoldSingleHtmlRequest = DefoldSingleHtmlRequest;
})(typeof window !== "undefined" ? window : globalThis);
`;
}

async function resolveFzstdSource(options) {
  const candidates = [];
  if (options.fzstdFile) {
    candidates.push(path.resolve(options.fzstdFile));
  }
  candidates.push(path.join(TOOL_DIR, "node_modules", "fzstd", "umd", "index.js"));
  candidates.push(
    path.resolve(process.cwd(), "node_modules", "fzstd", "umd", "index.js"),
  );

  for (const candidate of candidates) {
    try {
      return await fs.readFile(candidate, "utf8");
    } catch (error) {
      if (!error || error.code !== "ENOENT") {
        throw error;
      }
    }
  }
  throw new PackError(
    "fzstd was not found. Run 'npm install --prefix tools/single_html' or pass --fzstd <file>.",
  );
}

async function collectCoreResources(bundleRoot, executableName) {
  const resources = new Map();
  const add = async (relative, label) => {
    const normalized = relative.replaceAll("\\", "/").replace(/^\.\//, "");
    const absolute = path.resolve(bundleRoot, normalized);
    if (!isInside(bundleRoot, absolute)) {
      throw new PackError(`Resource path escapes the bundle directory: ${relative}`);
    }
    resources.set(normalized, await readRequiredFile(absolute, label));
  };

  const wasmJs = `${executableName}_wasm.js`;
  const wasm = `${executableName}.wasm`;
  const pthreadWasmJs = `${executableName}_pthread_wasm.js`;
  const pthreadWasm = `${executableName}_pthread.wasm`;

  const entries = new Set(await fs.readdir(bundleRoot));
  if (
    (!entries.has(wasmJs) || !entries.has(wasm)) &&
    (entries.has(pthreadWasmJs) || entries.has(pthreadWasm))
  ) {
    throw new PackError(
      "This tool currently requires a non-pthread wasm-web bundle. Rebuild without wasm_pthread-web.",
    );
  }

  await add(wasmJs, "Defold wasm loader");
  await add(wasm, "Defold WebAssembly binary");
  await add("archive/archive_files.json", "Defold archive manifest");

  let manifest;
  try {
    manifest = JSON.parse(resources.get("archive/archive_files.json").toString("utf8"));
  } catch (error) {
    throw new PackError(`Invalid archive/archive_files.json: ${error.message}`);
  }
  if (!manifest || !Array.isArray(manifest.content)) {
    throw new PackError("archive/archive_files.json has no content array.");
  }

  for (const file of manifest.content) {
    if (!file || !Array.isArray(file.pieces)) {
      throw new PackError("archive/archive_files.json contains an invalid file entry.");
    }
    for (const piece of file.pieces) {
      if (!piece || typeof piece.name !== "string" || piece.name === "") {
        throw new PackError("archive/archive_files.json contains an invalid piece name.");
      }
      await add(`archive/${piece.name}`, `archive piece '${piece.name}'`);
    }
  }

  return resources;
}

async function inlineScripts(
  html,
  bundleRoot,
  patchedDmloader,
  requestRuntime,
  fzstdSource,
  allowExternal,
) {
  let dmloaderCount = 0;
  const transformed = await replaceAsync(
    html,
    /<script\b([^>]*)>\s*<\/script\s*>/gi,
    async (whole, attributes) => {
      const source = getAttribute(attributes, "src");
      if (!source) {
        return whole;
      }
      const classification = classifyReference(source);
      if (classification === "external") {
        if (allowExternal) {
          return whole;
        }
        throw new PackError(`External script is not self-contained: ${source}`);
      }
      if (classification !== "local") {
        return whole;
      }

      const sourcePath = stripQueryAndHash(source).replaceAll("\\", "/");
      if (path.posix.basename(sourcePath).toLowerCase() === "dmloader.js") {
        dmloaderCount += 1;
        const fzstdTag = fzstdSource
          ? `<script id="defold-single-html-fzstd">${FZSTD_LICENSE_BANNER}\n${escapeInlineScript(fzstdSource)}</script>\n`
          : "";
        return `${fzstdTag}<script id="defold-single-html-runtime">${escapeInlineScript(requestRuntime)}</script>\n<script id="engine-loader" type="text/javascript">${escapeInlineScript(patchedDmloader)}</script>\n<script id="defold-single-html-engine-options">EngineLoader.stream_wasm = false; Module.isWASMPthreadSupported = false;</script>`;
      }

      const filename = resolveLocalReference(bundleRoot, bundleRoot, source);
      const script = (await readRequiredFile(filename, "script")).toString("utf8");
      return `<script data-inlined-from="${escapeHtmlAttribute(source)}">${escapeInlineScript(script)}</script>`;
    },
  );
  if (dmloaderCount !== 1) {
    throw new PackError(
      `Expected exactly one dmloader.js script tag in index.html; found ${dmloaderCount}.`,
    );
  }
  return transformed;
}

function removeFileProtocolGuard(html) {
  return html
    .replace(
      /window\.location\.href\.startsWith\(\s*["']file:\/\/["']\s*\)/g,
      "false",
    )
    .replace(
      /window\.location\.protocol\s*={2,3}\s*["']file:["']/g,
      "false",
    );
}

function assertNoUnresolvedLocalReferences(html, allowExternal) {
  const checks = [
    [/<script\b[^>]*\bsrc\s*=\s*["']([^"']+)["']/gi, "script"],
    [/<link\b[^>]*\brel\s*=\s*["'][^"']*stylesheet[^"']*["'][^>]*\bhref\s*=\s*["']([^"']+)["']/gi, "stylesheet"],
    [/<(?:img|source|audio|video|track|input|object)\b[^>]*\b(?:src|poster|data)\s*=\s*["']([^"']+)["']/gi, "asset"],
    [/<style\b[^>]*>[\s\S]*?url\(\s*["']?([^"')]+)["']?\s*\)[\s\S]*?<\/style\s*>/gi, "CSS resource"],
  ];
  for (const [expression, type] of checks) {
    for (const match of html.matchAll(expression)) {
      const classification = classifyReference(match[1]);
      if (classification === "local" || (classification === "external" && !allowExternal)) {
        throw new PackError(`Unresolved ${type} reference remains in output: ${match[1]}`);
      }
    }
  }
}

export async function packBundle(rawOptions) {
  const options = {
    compression: "zstd",
    zstdLevel: DEFAULT_ZSTD_LEVEL,
    zstdBinary: "zstd",
    fzstdFile: null,
    allowExternal: false,
    ...rawOptions,
  };
  ensureCompressionOptions(options);
  if (!options.inputDir) {
    throw new PackError("A Defold HTML5 bundle directory is required.");
  }

  const bundleRoot = path.resolve(options.inputDir);
  await assertDirectory(bundleRoot);
  const indexPath = path.join(bundleRoot, "index.html");
  const dmloaderPath = path.join(bundleRoot, "dmloader.js");
  const indexHtml = (await readRequiredFile(indexPath, "index.html")).toString("utf8");
  const dmloader = (await readRequiredFile(dmloaderPath, "dmloader.js")).toString("utf8");
  const executableName = detectExecutableName(indexHtml, await fs.readdir(bundleRoot));

  const resources = await collectCoreResources(bundleRoot, executableName);
  const encodedResources = {};
  let rawBytes = 0;
  let encodedBytes = 0;
  for (const [name, data] of Array.from(resources.entries()).sort(([left], [right]) =>
    left.localeCompare(right),
  )) {
    const encoded = await encodeResource(data, options);
    encodedResources[name] = encoded;
    rawBytes += data.byteLength;
    encodedBytes += encoded[2].length;
  }

  const requestRuntime = createRequestRuntimeJs(encodedResources);
  const patchedDmloader = patchDmloader(dmloader);
  const fzstdSource =
    options.compression === "zstd" ? await resolveFzstdSource(options) : "";

  let outputHtml = removeFileProtocolGuard(indexHtml);
  outputHtml = await transformHtmlAssets(outputHtml, bundleRoot, options.allowExternal);
  outputHtml = await inlineScripts(
    outputHtml,
    bundleRoot,
    patchedDmloader,
    requestRuntime,
    fzstdSource,
    options.allowExternal,
  );
  assertNoUnresolvedLocalReferences(outputHtml, options.allowExternal);

  const outputFile = path.resolve(
    options.outputFile ?? path.join(bundleRoot, `${executableName}.single.html`),
  );
  await fs.mkdir(path.dirname(outputFile), { recursive: true });
  await fs.writeFile(outputFile, outputHtml, "utf8");
  const outputStat = await fs.stat(outputFile);

  return {
    executableName,
    outputFile,
    outputBytes: outputStat.size,
    resourceCount: resources.size,
    rawResourceBytes: rawBytes,
    encodedResourceCharacters: encodedBytes,
    compression: options.compression,
  };
}

async function main() {
  try {
    const options = parseCliArgs(process.argv.slice(2));
    if (options.help) {
      process.stdout.write(usage());
      return;
    }
    if (!options.inputDir) {
      throw new PackError(`A bundle directory is required.\n\n${usage()}`);
    }
    const result = await packBundle(options);
    process.stdout.write(
      [
        `Created ${result.outputFile}`,
        `Executable: ${result.executableName}`,
        `Embedded resources: ${result.resourceCount}`,
        `Compression: ${result.compression}`,
        `Output size: ${result.outputBytes} bytes`,
      ].join("\n") + "\n",
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`single-html: ${message}\n`);
    process.exitCode = 1;
  }
}

const entryPoint = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : "";
if (import.meta.url === entryPoint) {
  await main();
}

export { PackError, parseCliArgs, patchDmloader };
