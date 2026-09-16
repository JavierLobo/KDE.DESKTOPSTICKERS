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

function fixObjectPrototypes(obj) {
  if (obj === null || typeof obj !== "object") {
    return obj;
  }
  if (Array.isArray(obj)) {
    const arr = [];
    for (let i = 0; i < obj.length; i++) {
      arr[i] = fixObjectPrototypes(obj[i]);
    }
    return arr;
  }
  if (obj instanceof Date || obj instanceof RegExp || obj instanceof Error) {
    return obj;
  }
  // For plain objects, recreate with the main context's Object.prototype
  const fixed = Object.create(Object.prototype);
  for (const key of Object.keys(obj)) {
    fixed[key] = fixObjectPrototypes(obj[key]);
  }
  return fixed;
}

function loadPragmaLibrary(filePath) {
  const source = fs.readFileSync(filePath, "utf8");
  const stripped = source.replace(/^\s*\.pragma library\s*\n/, "");
  const sandbox = {};
  vm.createContext(sandbox);
  vm.runInContext(stripped, sandbox, { filename: filePath });

  // Wrap functions to fix prototype mismatches in their return values
  const result = {};
  for (const key of Object.keys(sandbox)) {
    const value = sandbox[key];
    if (typeof value === "function") {
      // Wrap the function to fix prototypes of returned objects
      result[key] = function(...args) {
        const retVal = value.apply(this, args);
        return fixObjectPrototypes(retVal);
      };
    } else {
      // Fix non-function values
      result[key] = fixObjectPrototypes(value);
    }
  }
  return result;
}

module.exports = { loadPragmaLibrary };
