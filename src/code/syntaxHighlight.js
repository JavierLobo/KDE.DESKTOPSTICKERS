.pragma library

// Each language rule set is applied via one combined alternation regex built
// from `buildTokenizer`. Rules are tried in array order at every position;
// the first one that matches at the current scan point wins, exactly like a
// classic hand-rolled tokenizer (same approach used by highlight.js).

// Counts a regex source's own top-level capturing groups (a bare "(" not
// followed by "?", i.e. not "(?:", "(?=", "(?!"). None of the rule patterns
// below match a literal "(" character, so this simple scan is safe for them;
// a rule that ever needs to match a literal paren would need to escape it as
// "\(", which this scan also correctly ignores (it only counts unescaped ones
// -- see the check for a preceding backslash).
function countOwnCapturingGroups(source) {
  var count = 0;
  for (var i = 0; i < source.length; i++) {
    if (source[i] === "\\") {
      i++;
      continue;
    }
    if (source[i] === "(" && source[i + 1] !== "?") count++;
  }
  return count;
}

function buildTokenizer(rules, extraFlags) {
  // Each rule gets wrapped in one extra capturing group by this function
  // (below); rules that carry their own internal capturing groups (e.g. a
  // lookahead rule written as `(\s*)(word)(?=:)`) shift every subsequent
  // rule's group index in the combined match array. `groupOffsets[i]` is
  // rule i's OWN wrapping group position, computed up front, so dispatch
  // below checks exactly that slot instead of guessing from array position.
  var groupOffsets = [];
  var runningOffset = 0;
  rules.forEach(function (r) {
    groupOffsets.push(runningOffset);
    runningOffset += 1 + countOwnCapturingGroups(r.re.source);
  });

  // "m" is always on: several rules anchor with ^ meaning "start of line"
  // (diff +/-/@@, YAML/HCL keys). Regex flags don't survive `.source`
  // extraction, so any flag a rule needs (SQL's case-insensitive keywords)
  // is passed once here via `extraFlags` instead of set per-rule.
  var combined = new RegExp(
    rules.map(function (r) {
      return "(" + r.re.source + ")";
    }).join("|"),
    "gm" + (extraFlags || "")
  );
  return function (code) {
    var tokens = [];
    var lastIndex = 0;
    var m;
    combined.lastIndex = 0;
    while ((m = combined.exec(code)) !== null) {
      if (m.index > lastIndex) {
        tokens.push({ text: code.slice(lastIndex, m.index), cls: "plain" });
      }
      var ruleIdx = 0;
      for (var k = 0; k < groupOffsets.length; k++) {
        if (m[1 + groupOffsets[k]] !== undefined) {
          ruleIdx = k;
          break;
        }
      }
      tokens.push({ text: m[0], cls: rules[ruleIdx].cls });
      lastIndex = m.index + m[0].length;
      if (m[0].length === 0) combined.lastIndex++;
    }
    if (lastIndex < code.length) {
      tokens.push({ text: code.slice(lastIndex), cls: "plain" });
    }
    return tokens;
  };
}

function kw(words) {
  return "\\b(?:" + words.join("|") + ")\\b";
}

var COMMON_STRING = '"(?:[^"\\\\]|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\'';
var COMMON_NUMBER = "\\b\\d+(?:\\.\\d+)?\\b";

var LANGS = {
  java: buildTokenizer([
    { re: /\/\/[^\n]*/, cls: "comment" },
    { re: /\/\*[\s\S]*?\*\//, cls: "comment" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    { re: /@[A-Za-z_][A-Za-z0-9_]*/, cls: "keyword" },
    {
      re: new RegExp(
        kw([
          "public", "private", "protected", "class", "interface", "extends", "implements",
          "static", "final", "void", "new", "return", "import", "package", "if", "else",
          "for", "while", "try", "catch", "throw", "throws", "int", "String", "boolean",
          "long", "double", "float", "this", "super",
        ])
      ),
      cls: "keyword",
    },
    { re: new RegExp(kw(["true", "false", "null"])), cls: "literal" },
    { re: new RegExp(COMMON_NUMBER), cls: "number" },
  ]),

  python: buildTokenizer([
    { re: /#[^\n]*/, cls: "comment" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    {
      re: new RegExp(
        kw([
          "def", "return", "if", "elif", "else", "while", "for", "in", "import", "from",
          "class", "try", "except", "finally", "with", "as", "lambda", "pass", "yield",
          "raise", "not", "and", "or", "is",
        ])
      ),
      cls: "keyword",
    },
    { re: new RegExp(kw(["True", "False", "None"])), cls: "literal" },
    { re: /\b(?:int|str|float|bool|list|dict)\b(?=\s*[\[\(])/, cls: "type" },
    { re: new RegExp(COMMON_NUMBER), cls: "number" },
  ]),

  javascript: buildTokenizer([
    { re: /\/\/[^\n]*/, cls: "comment" },
    { re: /\/\*[\s\S]*?\*\//, cls: "comment" },
    { re: new RegExp(COMMON_STRING + "|`(?:[^`\\\\]|\\\\.)*`"), cls: "string" },
    {
      re: new RegExp(
        kw([
          "const", "let", "var", "function", "return", "if", "else", "for", "while",
          "class", "extends", "new", "this", "import", "export", "from", "async", "await",
          "try", "catch", "throw", "typeof", "instanceof",
        ])
      ),
      cls: "keyword",
    },
    { re: new RegExp(kw(["true", "false", "null", "undefined"])), cls: "literal" },
    { re: new RegExp(COMMON_NUMBER), cls: "number" },
  ]),

  sql: buildTokenizer([
    { re: /--[^\n]*/, cls: "comment" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    {
      re: new RegExp(
        kw([
          "SELECT", "FROM", "WHERE", "GROUP", "BY", "ORDER", "AS", "COUNT", "SUM", "AVG",
          "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "JOIN", "LEFT", "RIGHT",
          "INNER", "ON", "AND", "OR", "NOT", "NULL", "DESC", "ASC", "LIMIT", "CREATE",
          "TABLE", "PRIMARY", "KEY",
        ])
      ),
      cls: "keyword",
    },
    { re: new RegExp(COMMON_NUMBER), cls: "number" },
  ], "i"),

  bash: buildTokenizer([
    { re: /#[^\n]*/, cls: "comment" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    { re: /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/, cls: "variable" },
    {
      re: new RegExp(
        kw(["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac", "function", "set", "export", "echo", "local"])
      ),
      cls: "keyword",
    },
    { re: /^#!.*/, cls: "comment" },
  ]),

  yaml: buildTokenizer([
    { re: /#[^\n]*/, cls: "comment" },
    { re: /^(\s*)([A-Za-z0-9_-]+)(?=:)/m, cls: "attr" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    { re: new RegExp(kw(["true", "false", "null"])), cls: "literal" },
    { re: new RegExp(COMMON_NUMBER), cls: "number" },
  ]),

  json: buildTokenizer([
    { re: /"(?:[^"\\]|\\.)*"(?=\s*:)/, cls: "attr" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    { re: new RegExp(kw(["true", "false", "null"])), cls: "literal" },
    { re: new RegExp(COMMON_NUMBER), cls: "number" },
  ]),

  hcl: buildTokenizer([
    { re: /#[^\n]*|\/\/[^\n]*/, cls: "comment" },
    { re: new RegExp(COMMON_STRING), cls: "string" },
    { re: /\$\{[^}]*\}/, cls: "variable" },
    { re: new RegExp(kw(["resource", "data", "variable", "output", "module", "provider", "locals", "terraform"])), cls: "keyword" },
    { re: new RegExp(kw(["true", "false", "null"])), cls: "literal" },
    { re: /^\s*[a-zA-Z_][a-zA-Z0-9_-]*(?=\s+(?:"[^"]*"\s*)*\{)/m, cls: "type" },
  ]),

  diff: buildTokenizer([
    { re: /^\+[^\n]*/m, cls: "diff-add" },
    { re: /^-[^\n]*/m, cls: "diff-remove" },
    { re: /^@@[^\n]*/m, cls: "diff-hunk" },
  ]),

  markdown: buildTokenizer([
    { re: /^#{1,6}\s+[^\n]*/m, cls: "keyword" },
    { re: /\*\*[^*\n]+\*\*/, cls: "attr" },
    { re: /`[^`\n]+`/, cls: "string" },
    { re: /^```[^\n]*/m, cls: "comment" },
  ]),
};

function highlight(code, lang) {
  var tokenizer = LANGS[(lang || "").toLowerCase()];
  if (!tokenizer) {
    return [{ text: code, cls: "plain" }];
  }
  return tokenizer(code);
}
