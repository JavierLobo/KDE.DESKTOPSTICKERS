// test/markdownParser.block.test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { loadPragmaLibrary } = require("./loadPragmaLibrary.js");

const MarkdownParser = loadPragmaLibrary(path.join(__dirname, "..", "src", "code", "markdownParser.js"));
const docPath = path.join(__dirname, "..", "ejemplo-markdown-completo.md");
const doc = MarkdownParser.parse(fs.readFileSync(docPath, "utf8"));

function run(name, fn) {
  try {
    fn();
    console.log("PASS", name);
  } catch (e) {
    console.error("FAIL", name, "-", e.message);
    process.exitCode = 1;
  }
}

function countTypes(blocks, counts) {
  blocks.forEach((b) => {
    counts[b.type] = (counts[b.type] || 0) + 1;
    if (b.blocks) countTypes(b.blocks, counts);
    if (b.items) b.items.forEach((it) => it.blocks && countTypes(it.blocks, counts));
    if (b.children) countTypes(b.children, counts);
  });
  return counts;
}
const counts = countTypes(doc.blocks, {});

run("finds every numbered section heading", () => {
  const slugs = [];
  (function walk(blocks) {
    blocks.forEach((b) => {
      if (b.type === "heading") slugs.push(b.slug);
      if (b.blocks) walk(b.blocks);
      if (b.items) b.items.forEach((it) => it.blocks && walk(it.blocks));
    });
  })(doc.blocks);
  for (let n = 1; n <= 19; n++) {
    assert.ok(slugs.some((s) => s.startsWith(n + "-")), "missing heading slug starting with " + n + "-");
  }
  assert.ok(slugs.includes("encabezado-h1-alternativo-setext"), "setext H1 not parsed");
  assert.ok(slugs.includes("encabezado-h2-alternativo-setext"), "setext H2 not parsed");
});

run("nested 4-backtick fence closes correctly (the original bug)", () => {
  function findCode(blocks, out) {
    blocks.forEach((b) => {
      if (b.type === "code") out.push(b);
      if (b.blocks) findCode(b.blocks, out);
      if (b.items) b.items.forEach((it) => it.blocks && findCode(it.blocks, out));
      if (b.children) findCode(b.children, out);
    });
  }
  const codes = [];
  findCode(doc.blocks, codes);
  const nested = codes.find((c) => c.lang === "markdown" && c.content.includes("```python"));
  assert.ok(nested, "nested backtick code block not found");
  assert.strictEqual(nested.content, '```python\nprint("un bloque dentro de otro")\n```');
});

run("all 5 GitHub callouts detected with marker stripped", () => {
  function findCallouts(blocks, out) {
    blocks.forEach((b) => {
      if (b.type === "blockquote" && b.calloutType) out.push(b);
      if (b.blocks) findCallouts(b.blocks, out);
      if (b.items) b.items.forEach((it) => it.blocks && findCallouts(it.blocks, out));
    });
  }
  const callouts = [];
  findCallouts(doc.blocks, callouts);
  const types = callouts.map((c) => c.calloutType);
  ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"].forEach((t) => assert.ok(types.includes(t), "missing callout " + t));
  const note = callouts.find((c) => c.calloutType === "NOTE");
  assert.strictEqual(JSON.stringify(note.blocks[0].inline).includes("[!NOTE]"), false, "marker text leaked into content");
});

run("table alignment and escaped pipe", () => {
  function findTables(blocks, out) {
    blocks.forEach((b) => {
      if (b.type === "table") out.push(b);
      if (b.blocks) findTables(b.blocks, out);
      if (b.items) b.items.forEach((it) => it.blocks && findTables(it.blocks, out));
    });
  }
  const tables = [];
  findTables(doc.blocks, tables);
  const aligned = tables.find((t) => JSON.stringify(t.align) === JSON.stringify(["left", "center", "right"]));
  assert.ok(aligned, "7.2 alignment table not found with correct align array");
  const withPipe = tables.find((t) => t.rows.some((r) => r.some((cell) => cell.some((run) => run.type === "code" && run.text === "|"))));
  assert.ok(withPipe, "escaped pipe \\| not preserved as literal | inside a code span");
});

run("task list items and definition list parsed", () => {
  assert.strictEqual(counts.deflist, 1);
  function findTasks(blocks, out) {
    blocks.forEach((b) => {
      if (b.type === "list") b.items.forEach((it) => it.task && out.push(it.task));
      if (b.blocks) findTasks(b.blocks, out);
      if (b.items) b.items.forEach((it) => it.blocks && findTasks(it.blocks, out));
    });
  }
  const tasks = [];
  findTasks(doc.blocks, tasks);
  assert.strictEqual(tasks.length, 8, "expected 8 task list items across the document");
  assert.strictEqual(tasks.filter((t) => t.checked).length, 3);
});

run("footnote definitions collected separately from the flow", () => {
  assert.deepStrictEqual(Object.keys(doc.footnotes).sort(), ["1", "nota"]);
  const idx = MarkdownParser.findTopLevelBlockIndexForFootnoteRef(doc.blocks, "1");
  assert.notStrictEqual(idx, -1);
  assert.strictEqual(doc.blocks[idx].type, "paragraph");
});

run("html_block subset: 2 <details>, 1 <div align>, raw <table> becomes a table node", () => {
  assert.strictEqual(counts.html_block, 3);
  function findTables(blocks, out) {
    blocks.forEach((b) => {
      if (b.type === "table") out.push(b);
      if (b.blocks) findTables(b.blocks, out);
      if (b.items) b.items.forEach((it) => it.blocks && findTables(it.blocks, out));
      if (b.children) findTables(b.children, out);
    });
  }
  const tables = [];
  findTables(doc.blocks, tables);
  assert.ok(tables.some((t) => JSON.stringify(t.head).includes("HTML")), "raw <table> not converted to a table node");
});

run("math blocks parsed, no stray '=' line misread as a setext heading", () => {
  assert.strictEqual(counts.math_block, 2);
  const headingTexts = [];
  (function walk(blocks) {
    blocks.forEach((b) => {
      if (b.type === "heading") headingTexts.push(JSON.stringify(b.inline));
      if (b.blocks) walk(b.blocks);
      if (b.items) b.items.forEach((it) => it.blocks && walk(it.blocks));
    });
  })(doc.blocks);
  assert.ok(!headingTexts.some((t) => t.includes("bmatrix")), "a line inside a $$ block leaked out as a heading");
});

run("reference-style, implicit-reference, and relative links all resolve", () => {
  function findLinks(node, out) {
    if (Array.isArray(node)) return node.forEach((n) => findLinks(n, out));
    if (!node || typeof node !== "object") return;
    if (node.type === "link" || node.type === "image") out.push(node);
    Object.keys(node).forEach((k) => findLinks(node[k], out));
  }
  const links = [];
  findLinks(doc.blocks, links);
  assert.ok(links.some((l) => l.href === "https://example.com/pagina"), "explicit reference link didn't resolve");
  assert.ok(links.some((l) => l.href === "https://example.com/otra"), "implicit [ref2][] reference didn't resolve");
  assert.ok(links.some((l) => l.href === "./docs/otro.md"), "relative link missing");
  assert.ok(links.some((l) => l.href === "#7-tablas"), "internal anchor link missing");
});

run("front matter is null for this document (it only appears inside a demo code fence)", () => {
  assert.strictEqual(doc.frontMatter, null);
});

run("loose list (blank line between items) stays one list node with multiple items", () => {
  function findLists(blocks, out) {
    blocks.forEach((b) => {
      if (b.type === "list") out.push(b);
      if (b.blocks) findLists(b.blocks, out);
      if (b.items) b.items.forEach((it) => it.blocks && findLists(it.blocks, out));
    });
  }
  const lists = [];
  findLists(doc.blocks, lists);
  // Section 4.6's list has 2 items, and the first item has multiple blocks (paragraph + continuation)
  const looseList = lists.find(
    (l) =>
      l.items.length === 2 &&
      JSON.stringify(l.items[0]).includes("Primer elemento con varios párrafos") &&
      JSON.stringify(l.items[0]).includes("Este segundo párrafo")
  );
  assert.ok(looseList, "section 4.6's loose list not found");
  assert.strictEqual(looseList.items.length, 2, "loose list should have 2 items, not be split into separate list nodes");
});

run("synthetic 3-item loose bullet list stays one list node", () => {
  const doc2 = MarkdownParser.parse("- one\n\n- two\n\n- three\n");
  assert.strictEqual(doc2.blocks.length, 1, "expected exactly one list block, got " + doc2.blocks.length);
  assert.strictEqual(doc2.blocks[0].type, "list");
  assert.strictEqual(doc2.blocks[0].items.length, 3);
});

// --- Added by the final-review fix wave (finding I5) ----------------------
// stripComments() and extractLinkReferences() run before block-level fence
// parsing, so they used to mangle content that merely LOOKS like syntax but
// is really a code sample inside a fence.

run("HTML comment inside a fenced code block is not stripped", () => {
  const parsed = MarkdownParser.parse("```html\n<!-- comentario -->\n```\n");
  const codeBlock = parsed.blocks.find((b) => b.type === "code");
  assert.ok(codeBlock, "expected a fenced code block");
  assert.ok(
    codeBlock.content.includes("<!-- comentario -->"),
    "comment was stripped from inside the fence: " + JSON.stringify(codeBlock.content)
  );
});

run("link reference definition inside a fenced code block is not extracted", () => {
  const parsed = MarkdownParser.parse("```markdown\n[ref]: https://x.com\n```\n");
  const codeBlock = parsed.blocks.find((b) => b.type === "code");
  assert.ok(codeBlock, "expected a fenced code block");
  assert.ok(
    codeBlock.content.includes("[ref]: https://x.com"),
    "reference definition was consumed from inside the fence: " + JSON.stringify(codeBlock.content)
  );
});
