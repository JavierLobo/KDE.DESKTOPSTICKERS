// test/markdownParser.inline.test.js
const assert = require("assert");
const path = require("path");
const { loadPragmaLibrary } = require("./loadPragmaLibrary.js");

const MarkdownParser = loadPragmaLibrary(path.join(__dirname, "..", "src", "code", "markdownParser.js"));
const ctx = () => ({ refs: {} });

function run(name, fn) {
  try {
    fn();
    console.log("PASS", name);
  } catch (e) {
    console.error("FAIL", name, "-", e.message);
    process.exitCode = 1;
  }
}

run("plain text", () => {
  const runs = MarkdownParser.parseInline("hola mundo", ctx());
  assert.deepStrictEqual(runs, [{ type: "text", text: "hola mundo" }]);
});

run("bold with inline code inside", () => {
  const html = MarkdownParser.renderInline(MarkdownParser.parseInline("**negrita con `código`**", ctx()));
  assert.strictEqual(
    html,
    '<b>negrita con <span style="font-family:monospace; background-color:#33000000; border-radius:3px; padding:1px 4px">código</span></b>'
  );
});

run("italic with link inside", () => {
  const html = MarkdownParser.renderInline(
    MarkdownParser.parseInline("*cursiva con [enlace](https://example.com) dentro*", ctx())
  );
  assert.strictEqual(html, '<i>cursiva con <a href="https://example.com">enlace</a> dentro</i>');
});

run("bold + italic + strikethrough combo", () => {
  const html = MarkdownParser.renderInline(MarkdownParser.parseInline("***~~texto~~***", ctx()));
  assert.strictEqual(html, '<b><i><span style="text-decoration:line-through">texto</span></i></b>');
});

run("double-backtick escapes a literal backtick", () => {
  const runs = MarkdownParser.parseInline("``código con ` dentro``", ctx());
  assert.deepStrictEqual(runs, [{ type: "code", text: "código con ` dentro" }]);
});

run("shortcut reference with no definition stays literal text", () => {
  // This is exactly the shape of a "> [!NOTE]" callout marker: matchLinkLike
  // must NOT treat it as a link since no [!NOTE]: url definition exists.
  const runs = MarkdownParser.parseInline("[!NOTE]", ctx());
  assert.deepStrictEqual(runs, [{ type: "text", text: "[!NOTE]" }]);
});

run("reference-style link resolves via ctx.refs", () => {
  const c = { refs: { ref1: { href: "https://example.com/pagina", title: "Título opcional" } } };
  const runs = MarkdownParser.parseInline("[enlace de referencia][ref1]", c);
  assert.strictEqual(runs[0].type, "link");
  assert.strictEqual(runs[0].href, "https://example.com/pagina");
});

run("raw <img> tag with width becomes an image run", () => {
  const runs = MarkdownParser.parseInline('<img src="https://via.placeholder.com/300.png" alt="Ejemplo" width="150" />', ctx());
  assert.deepStrictEqual(runs, [
    { type: "image", href: "https://via.placeholder.com/300.png", alt: "Ejemplo", title: null, width: 150 },
  ]);
});

run("kbd and mark render as styled spans", () => {
  const html = MarkdownParser.renderInline(MarkdownParser.parseInline("<kbd>Ctrl</kbd> y <mark>resaltado</mark>", ctx()));
  assert.strictEqual(
    html,
    '<span style="font-family:monospace; background-color:#33000000; border-radius:3px; padding:0px 5px">Ctrl</span> y <span style="background-color:#fff2a8">resaltado</span>'
  );
});

run("HTML entities and emoji shortcodes decode", () => {
  const runs = MarkdownParser.parseInline("&copy; 2026 :rocket:", ctx());
  assert.deepStrictEqual(runs, [{ type: "text", text: "© 2026 🚀" }]);
});

run("footnote reference produces a footnote_ref run", () => {
  const runs = MarkdownParser.parseInline("nota[^1]", ctx());
  assert.deepStrictEqual(runs, [{ type: "text", text: "nota" }, { type: "footnote_ref", id: "1" }]);
});

run("slugify matches GitHub's algorithm", () => {
  const used = {};
  assert.strictEqual(MarkdownParser.slugify("7. Tablas", used), "7-tablas");
  assert.strictEqual(MarkdownParser.slugify("6.3 Bloques delimitados con resaltado de sintaxis", used), "63-bloques-delimitados-con-resaltado-de-sintaxis");
});
