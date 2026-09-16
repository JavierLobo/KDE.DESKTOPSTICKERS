// test/loadPragmaLibrary.js
//
// Loads a QML ".pragma library" JS file under plain Node for testing. QML's
// JS engine treats the literal first line ".pragma library" as a directive;
// Node's parser rejects it as a syntax error, so this strips that one line
// and evaluates the rest in a fresh sandbox. Top-level `function`/`var`
// bindings become properties of the returned object automatically (that's
// how a `vm` context's global object works), the same way they become
// callable as `Alias.fnName()` after `.import "file.js" as Alias` in QML.
const fs = require("fs");
const vm = require("vm");

function loadPragmaLibrary(filePath) {
  const source = fs.readFileSync(filePath, "utf8");
  const stripped = source.replace(/^\s*\.pragma library\s*\n/, "");
  const sandbox = {};
  vm.createContext(sandbox);
  vm.runInContext(stripped, sandbox, { filename: filePath });
  return sandbox;
}

module.exports = { loadPragmaLibrary };
