// test/syntaxHighlight.test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { loadPragmaLibrary } = require("./loadPragmaLibrary.js");

const SyntaxHighlight = loadPragmaLibrary(path.join(__dirname, "..", "src", "code", "syntaxHighlight.js"));
const MarkdownParser = loadPragmaLibrary(path.join(__dirname, "..", "src", "code", "markdownParser.js"));
const doc = MarkdownParser.parse(fs.readFileSync(path.join(__dirname, "..", "ejemplo-markdown-completo.md"), "utf8"));

function run(name, fn) {
  try {
    fn();
    console.log("PASS", name);
  } catch (e) {
    console.error("FAIL", name, "-", e.message);
    process.exitCode = 1;
  }
}

function findCode(blocks, out) {
  blocks.forEach((b) => {
    if (b.type === "code" && b.lang) out.push(b);
    if (b.blocks) findCode(b.blocks, out);
    if (b.items) b.items.forEach((it) => it.blocks && findCode(it.blocks, out));
    if (b.children) findCode(b.children, out);
  });
}
const codeBlocks = [];
findCode(doc.blocks, codeBlocks);
const seenLangs = {};
codeBlocks.forEach((c) => (seenLangs[c.lang] = c));

["java", "python", "javascript", "sql", "bash", "yaml", "json", "hcl", "diff"].forEach((lang) => {
  run("round-trips " + lang + " without losing/duplicating characters", () => {
    const block = seenLangs[lang];
    assert.ok(block, "no " + lang + " code block found in the demo document");
    const tokens = SyntaxHighlight.highlight(block.content, lang);
    assert.strictEqual(tokens.map((t) => t.text).join(""), block.content);
  });
});

run("classifies at least keyword/string/comment/number across all languages", () => {
  const seenClasses = new Set();
  Object.keys(seenLangs).forEach((lang) => {
    SyntaxHighlight.highlight(seenLangs[lang].content, lang).forEach((t) => seenClasses.add(t.cls));
  });
  ["keyword", "string", "comment", "number"].forEach((cls) => assert.ok(seenClasses.has(cls), "class " + cls + " never produced"));
});

run("yaml distinguishes a quoted string from a bare number", () => {
  const tokens = SyntaxHighlight.highlight('version: "3.9"', "yaml");
  const versionValue = tokens.find((t) => t.text === '"3.9"');
  assert.strictEqual(versionValue.cls, "string");
});

run("unrecognized language falls back to a single plain token", () => {
  const tokens = SyntaxHighlight.highlight("some text", "not-a-real-language");
  assert.deepStrictEqual(tokens, [{ text: "some text", cls: "plain" }]);
});
