.pragma library

var HEADING_RE = /^ {0,3}(#{1,6})(?:\s+(.*?))?\s*$/;
var ATX_CLOSE_RE = /\s+#+\s*$/;
var SETEXT_RE = /^ {0,3}(=+|-+)\s*$/;
var HR_RE = /^ {0,3}(-{3,}|\*{3,}|_{3,})\s*$/;
var FENCE_RE = /^( {0,3})(`{3,}|~{3,})\s*(.*)$/;
var MATH_BLOCK_RE = /^ {0,3}\$\$\s*$/;
var BQ_RE = /^ {0,3}>( ?)(.*)$/;
var BULLET_RE = /^( {0,3})([-*+])(?:( +)(.*)|())$/;
var ORDERED_RE = /^( {0,3})(\d{1,9})([.)])(?:( +)(.*)|())$/;
var DEFLIST_RE = /^: ?(.*)$/;
var FOOTNOTE_DEF_RE = /^\[\^([^\]]+)\]:\s?(.*)$/;
var TABLE_DELIM_RE = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;

function isBlank(line) {
  return /^\s*$/.test(line);
}

function stripComments(src) {
  return src.replace(/<!--[\s\S]*?-->/g, "");
}

// Recognized inline HTML tags -- passed through verbatim into the compiled
// rich-text string (Qt's Text.RichText already understands all of these).
// Anything not in this set falls through to literal escaped text.
var INLINE_HTML_TAGS = { kbd: true, mark: true, sub: true, sup: true, u: true, strong: true, em: true, b: true, i: true };

var ENTITIES = {
  copy: "©",
  amp: "&",
  lt: "<",
  gt: ">",
  nbsp: " ",
  mdash: "—",
  hellip: "…",
  rarr: "→",
  euro: "€",
  quot: '"',
  apos: "'",
};

var EMOJI_MAP = {
  rocket: "🚀",
  white_check_mark: "✅",
  warning: "⚠️",
  bug: "🐛",
  tada: "🎉",
};

function slugify(text, used) {
  var slug = text
    .toLowerCase()
    .trim()
    .replace(/[^\p{L}\p{N}\p{M}\- ]+/gu, "")
    .replace(/\s+/g, "-");
  if (used[slug] === undefined) {
    used[slug] = 0;
  } else {
    used[slug] += 1;
    slug = slug + "-" + used[slug];
  }
  return slug;
}

function parseInline(text, ctx) {
  var runs = [];
  var i = 0;
  var n = text.length;
  var buf = "";

  function flush() {
    if (buf !== "") {
      runs.push({ type: "text", text: decodeEntitiesAndEmoji(buf) });
      buf = "";
    }
  }

  while (i < n) {
    var c = text[i];

    // Hard line break: an explicit <br> (two-trailing-spaces soft breaks are
    // already collapsed to a plain newline by the block parser upstream, and
    // a bare "\n" here is treated the same way as <br>).
    if (c === "\n") {
      flush();
      runs.push({ type: "linebreak" });
      i++;
      continue;
    }
    if (text.slice(i, i + 4) === "<br>" || text.slice(i, i + 6) === "<br />" || text.slice(i, i + 5) === "<br/>") {
      flush();
      runs.push({ type: "linebreak" });
      i += text[i + 3] === "/" ? 5 : text.slice(i, i + 6) === "<br />" ? 6 : 4;
      continue;
    }

    // Escaped character.
    if (c === "\\" && i + 1 < n && /[!"#$%&'()*+,\-./:;<=>?@[\]^_`{|}~\\]/.test(text[i + 1])) {
      buf += text[i + 1];
      i += 2;
      continue;
    }

    // Code span: run of backticks, closes at a run of the same length.
    if (c === "`") {
      var tickRun = /^`+/.exec(text.slice(i))[0];
      var closeIdx = text.indexOf(tickRun, i + tickRun.length);
      while (closeIdx !== -1) {
        var afterLen = /^`+/.exec(text.slice(closeIdx))[0].length;
        if (afterLen === tickRun.length) break;
        closeIdx = text.indexOf(tickRun, closeIdx + afterLen);
      }
      if (closeIdx !== -1) {
        flush();
        var codeContent = text.slice(i + tickRun.length, closeIdx).trim();
        runs.push({ type: "code", text: codeContent });
        i = closeIdx + tickRun.length;
        continue;
      }
    }

    // Inline math: $...$ (not $$, no newline inside, skip escaped \$).
    if (c === "$" && text[i - 1] !== "\\" && text[i + 1] !== "$") {
      var mEnd = -1;
      for (var k = i + 1; k < n; k++) {
        if (text[k] === "\n") break;
        if (text[k] === "$" && text[k - 1] !== "\\") {
          mEnd = k;
          break;
        }
      }
      if (mEnd !== -1 && mEnd > i + 1) {
        flush();
        runs.push({ type: "math_inline", content: text.slice(i + 1, mEnd) });
        i = mEnd + 1;
        continue;
      }
    }

    // Autolink <http://...> / <email>, raw <img>, or a recognized inline tag.
    if (c === "<") {
      var autoMatch = /^<((?:https?|ftp):[^\s<>]+|[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+)>/.exec(text.slice(i));
      if (autoMatch) {
        flush();
        var href = autoMatch[1];
        var isEmail = href.indexOf("@") !== -1 && !/^[a-z]+:/i.test(href);
        runs.push({ type: "autolink", href: isEmail ? "mailto:" + href : href, text: href });
        i += autoMatch[0].length;
        continue;
      }
      var imgTagMatch = /^<img\b([^>]*)\/?>/.exec(text.slice(i));
      if (imgTagMatch) {
        flush();
        var attrsStr = imgTagMatch[1];
        var srcM = /\bsrc="([^"]*)"/.exec(attrsStr);
        var altM = /\balt="([^"]*)"/.exec(attrsStr);
        var widthM = /\bwidth="([^"]*)"/.exec(attrsStr);
        runs.push({
          type: "image",
          href: srcM ? srcM[1] : "",
          alt: altM ? altM[1] : "",
          title: null,
          width: widthM ? parseInt(widthM[1], 10) : null,
        });
        i += imgTagMatch[0].length;
        continue;
      }
      var tagMatch = /^<\/?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>/.exec(text.slice(i));
      if (tagMatch && INLINE_HTML_TAGS[tagMatch[1].toLowerCase()]) {
        flush();
        runs.push({ type: "html", raw: tagMatch[0] });
        i += tagMatch[0].length;
        continue;
      }
    }

    // Image: ![alt](url "title") or ![alt][ref]
    if (c === "!" && text[i + 1] === "[") {
      var img = matchLinkLike(text, i + 1, ctx);
      if (img) {
        flush();
        runs.push({ type: "image", alt: img.label, href: img.href, title: img.title });
        i = img.next;
        continue;
      }
    }

    // Footnote reference, or link: [text](url "title") / [text][ref] / [text][] / [text]
    if (c === "[") {
      if (/^\[\^/.test(text.slice(i))) {
        var fnRefMatch = /^\[\^([^\]]+)\]/.exec(text.slice(i));
        if (fnRefMatch) {
          flush();
          runs.push({ type: "footnote_ref", id: fnRefMatch[1] });
          i += fnRefMatch[0].length;
          continue;
        }
      }
      var link = matchLinkLike(text, i, ctx);
      if (link) {
        flush();
        runs.push({ type: "link", href: link.href, title: link.title, children: parseInline(link.label, ctx) });
        i = link.next;
        continue;
      }
    }

    // Emphasis-family delimiters: ***x***, **x**, *x*, ~~x~~
    var emph = matchEmphasis(text, i, ctx);
    if (emph) {
      flush();
      runs.push(emph.run);
      i = emph.next;
      continue;
    }

    buf += c;
    i++;
  }
  flush();
  return runs;
}

function decodeEntitiesAndEmoji(s) {
  s = s.replace(/&([a-zA-Z]+);/g, function (m, name) {
    return ENTITIES.hasOwnProperty(name) ? ENTITIES[name] : m;
  });
  s = s.replace(/:([a-z0-9_+-]+):/g, function (m, name) {
    return EMOJI_MAP.hasOwnProperty(name) ? EMOJI_MAP[name] : m;
  });
  return s;
}

// Shared matcher for [label](href "title") / [label][ref] / [label][] / [label]
// starting at `pos`, which must point at '['. `ctx.refs` (populated up front
// by extractLinkReferences in Task 2, before any inline parsing happens) is
// consulted immediately: a `[label]`/`[label][]`/`[label][ref]` with no
// matching definition is NOT a link -- returns null so the caller falls
// through to plain literal text, matching CommonMark (this is what keeps a
// bare `[!NOTE]` callout marker, which defines no reference, as plain text).
function matchLinkLike(text, pos, ctx) {
  var depth = 0;
  var j = pos + 1;
  var labelStart = j;
  while (j < text.length) {
    if (text[j] === "\\") {
      j += 2;
      continue;
    }
    if (text[j] === "[") depth++;
    if (text[j] === "]") {
      if (depth === 0) break;
      depth--;
    }
    j++;
  }
  if (j >= text.length) return null;
  var label = text.slice(labelStart, j);
  var after = j + 1;

  if (text[after] === "(") {
    var close = text.indexOf(")", after);
    if (close === -1) return null;
    var inner = text.slice(after + 1, close);
    var titleMatch = /^(\S+)(?:\s+"([^"]*)")?$/.exec(inner.trim());
    return {
      label: label,
      href: titleMatch ? titleMatch[1] : inner.trim(),
      title: titleMatch ? titleMatch[2] || null : null,
      next: close + 1,
    };
  }
  var refs = (ctx && ctx.refs) || {};
  if (text[after] === "[") {
    var refClose = text.indexOf("]", after);
    if (refClose === -1) return null;
    var explicitRefId = text.slice(after + 1, refClose) || label;
    var explicitRef = refs[explicitRefId.toLowerCase()];
    if (!explicitRef) return null;
    return { label: label, href: explicitRef.href, title: explicitRef.title, next: refClose + 1 };
  }
  // Shortcut reference: [label] with no following () or [] -- only a link
  // if `label` itself is a known reference id.
  var shortcutRef = refs[label.toLowerCase()];
  if (!shortcutRef) return null;
  return { label: label, href: shortcutRef.href, title: shortcutRef.title, next: after };
}

function matchEmphasis(text, pos, ctx) {
  var rest = text.slice(pos);
  var combos = [
    { marker: "***", type: "strong-em" },
    { marker: "___", type: "strong-em" },
    { marker: "~~", type: "strike" },
    { marker: "**", type: "strong" },
    { marker: "__", type: "strong" },
    { marker: "*", type: "em" },
    { marker: "_", type: "em" },
  ];
  for (var c = 0; c < combos.length; c++) {
    var marker = combos[c].marker;
    if (rest.slice(0, marker.length) !== marker) continue;
    if (/\s/.test(rest[marker.length] || "")) continue; // no space right after opening
    var searchFrom = marker.length;
    var closeIdx = -1;
    while (true) {
      var found = rest.indexOf(marker, searchFrom);
      if (found === -1) break;
      if (!/\s/.test(rest[found - 1])) {
        closeIdx = found;
        break;
      }
      searchFrom = found + marker.length;
    }
    if (closeIdx === -1) continue;
    var inner = rest.slice(marker.length, closeIdx);
    if (inner === "") continue;
    var type = combos[c].type;
    var run;
    if (type === "strong-em") {
      run = { type: "strong", children: [{ type: "em", children: parseInline(inner, ctx) }] };
    } else if (type === "strike") {
      run = { type: "strike", children: parseInline(inner, ctx) };
    } else {
      run = { type: type, children: parseInline(inner, ctx) };
    }
    return { run: run, next: pos + closeIdx + marker.length };
  }
  return null;
}

// ---------------------------------------------------------------------------
// renderInline: compiles an array of inline runs (as produced by parseInline)
// into a Qt Text.RichText-compatible HTML-subset string. Every tag used here
// is one Qt's rich text engine renders natively: <b>, <i>, <a href>, <sub>,
// <sup>, <u>, <span style="...">, <br>, <img src width>.
// ---------------------------------------------------------------------------

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function renderInline(runs) {
  return runs.map(renderRun).join("");
}

function renderRun(run) {
  switch (run.type) {
    case "text":
      return escapeHtml(run.text);
    case "linebreak":
      return "<br>";
    case "strong":
      return "<b>" + renderInline(run.children) + "</b>";
    case "em":
      return "<i>" + renderInline(run.children) + "</i>";
    case "strike":
      return '<span style="text-decoration:line-through">' + renderInline(run.children) + "</span>";
    case "code":
      return '<span style="font-family:monospace; background-color:#33000000; border-radius:3px; padding:1px 4px">' + escapeHtml(run.text) + "</span>";
    case "math_inline":
      return '<span style="font-family:monospace; background-color:#22000000">' + escapeHtml(run.content) + "</span>";
    case "link":
      return '<a href="' + escapeHtml(run.href) + '">' + renderInline(run.children) + "</a>";
    case "autolink":
      return '<a href="' + escapeHtml(run.href) + '">' + escapeHtml(run.text) + "</a>";
    case "image":
      return (
        '<img src="' +
        escapeHtml(run.href) +
        '" alt="' +
        escapeHtml(run.alt || "") +
        '"' +
        (run.width ? ' width="' + run.width + '"' : "") +
        ">"
      );
    case "footnote_ref":
      return '<a href="#fnref-' + escapeHtml(run.id) + '" name="fnref-' + escapeHtml(run.id) + '"><sup>[' + escapeHtml(run.id) + "]</sup></a>";
    case "html":
      // Only tags in INLINE_HTML_TAGS reach here (see parseInline above);
      // kbd and mark have no native Qt rich-text meaning, so they're
      // translated to an equivalent styled span, everything else (strong,
      // em, sub, sup, u, b, i) passes through verbatim.
      if (/^<\/?kbd>$/.test(run.raw)) {
        return run.raw[1] === "/"
          ? "</span>"
          : '<span style="font-family:monospace; background-color:#33000000; border-radius:3px; padding:0px 5px">';
      }
      if (/^<\/?mark>$/.test(run.raw)) {
        return run.raw[1] === "/" ? "</span>" : '<span style="background-color:#fff2a8">';
      }
      return run.raw;
    default:
      return "";
  }
}

// ---------------------------------------------------------------------------
// Block parsing
// ---------------------------------------------------------------------------

function extractFrontMatter(lines) {
  if (lines.length === 0 || lines[0].trim() !== "---") {
    return { frontMatter: null, rest: lines };
  }
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "---") {
      return { frontMatter: lines.slice(1, i).join("\n"), rest: lines.slice(i + 1) };
    }
  }
  return { frontMatter: null, rest: lines };
}

// parseBlocks consumes an array of *already dedented* lines representing one
// container's content (top-level document, a list item, or a blockquote) and
// returns an array of block nodes. `ctx` carries cross-cutting state
// (footnote definitions, heading slug registry, link references).
function parseBlocks(lines, ctx) {
  var blocks = [];
  var i = 0;
  var n = lines.length;

  function paragraphLinesAhead(from) {
    var out = [];
    var j = from;
    while (j < n && !isBlank(lines[j]) && !startsSpecialBlock(lines, j)) {
      // A setext underline (=== or ---, not long enough/uniform to already
      // have been claimed by HR_RE inside startsSpecialBlock) ends the
      // paragraph *before* consuming it, so the setext check just below
      // this function's call site sees it at `lines[para.next]`.
      if (out.length > 0 && SETEXT_RE.test(lines[j])) break;
      out.push(lines[j]);
      j++;
    }
    return { text: out, next: j };
  }

  function startsSpecialBlock(ls, idx) {
    var line = ls[idx];
    if (HEADING_RE.test(line) && /^ {0,3}#{1,6}(\s|$)/.test(line)) return true;
    if (HR_RE.test(line)) return true;
    if (FENCE_RE.test(line)) return true;
    if (MATH_BLOCK_RE.test(line)) return true;
    if (BQ_RE.test(line)) return true;
    if (BULLET_RE.test(line)) return true;
    if (ORDERED_RE.test(line)) return true;
    if (FOOTNOTE_DEF_RE.test(line)) return true;
    if (/^ {0,3}<(details|div|table)\b/.test(line)) return true;
    return false;
  }

  while (i < n) {
    var line = lines[i];

    if (isBlank(line)) {
      i++;
      continue;
    }

    // Footnote definition -------------------------------------------------
    var fnMatch = FOOTNOTE_DEF_RE.exec(line);
    if (fnMatch) {
      var fnId = fnMatch[1];
      var fnFirst = fnMatch[2];
      var fnLines = [fnFirst];
      i++;
      while (i < n && (isBlank(lines[i]) ? lines[i + 1] && /^ {4}/.test(lines[i + 1]) : /^ {4}/.test(lines[i]))) {
        if (isBlank(lines[i])) {
          fnLines.push("");
          i++;
        } else {
          fnLines.push(lines[i].replace(/^ {4}/, ""));
          i++;
        }
      }
      while (fnLines.length && fnLines[fnLines.length - 1] === "") fnLines.pop();
      ctx.footnotes[fnId] = parseBlocks(fnLines, ctx);
      continue;
    }

    // ATX heading -----------------------------------------------------------
    var hMatch = /^ {0,3}(#{1,6})(?:\s+(.*))?$/.exec(line);
    if (hMatch) {
      var level = hMatch[1].length;
      var text = (hMatch[2] || "").replace(ATX_CLOSE_RE, "").trim();
      blocks.push({
        type: "heading",
        level: level,
        inline: parseInline(text, ctx),
        slug: slugify(text, ctx.slugsUsed),
      });
      i++;
      continue;
    }

    // Thematic break OR setext continuation is checked after paragraph below.
    if (HR_RE.test(line) && !/^ {0,3}(-{1,2}|\*{1,2}|_{1,2})\s*$/.test(line)) {
      blocks.push({ type: "hr" });
      i++;
      continue;
    }

    // Math block ($$ ... $$) ------------------------------------------
    if (MATH_BLOCK_RE.test(line)) {
      var mathLines = [];
      i++;
      while (i < n && !MATH_BLOCK_RE.test(lines[i])) {
        mathLines.push(lines[i]);
        i++;
      }
      i++; // skip closing $$
      blocks.push({ type: "math_block", content: mathLines.join("\n").trim() });
      continue;
    }

    // Fenced code block -------------------------------------------------
    var fenceMatch = FENCE_RE.exec(line);
    if (fenceMatch) {
      var fenceChar = fenceMatch[2][0];
      var fenceLen = fenceMatch[2].length;
      var info = fenceMatch[3].trim();
      var codeLines = [];
      i++;
      while (i < n) {
        var closeMatch = new RegExp("^ {0,3}(" + fenceChar + "{" + fenceLen + ",})\\s*$").exec(lines[i]);
        if (closeMatch) {
          i++;
          break;
        }
        codeLines.push(lines[i]);
        i++;
      }
      blocks.push({ type: "code", lang: info.split(/\s+/)[0] || "", content: codeLines.join("\n"), fence: true });
      continue;
    }

    // Indented code block ---------------------------------------------
    if (/^ {4}/.test(line)) {
      var indLines = [];
      while (i < n && (/^ {4}/.test(lines[i]) || isBlank(lines[i]))) {
        indLines.push(isBlank(lines[i]) ? "" : lines[i].replace(/^ {4}/, ""));
        i++;
      }
      while (indLines.length && indLines[indLines.length - 1] === "") {
        indLines.pop();
        i--;
      }
      blocks.push({ type: "code", lang: "", content: indLines.join("\n"), fence: false });
      continue;
    }

    // Blockquote (with GitHub callout detection) -----------------------
    if (BQ_RE.test(line)) {
      var qLines = [];
      while (i < n && BQ_RE.test(lines[i])) {
        var qm = BQ_RE.exec(lines[i]);
        qLines.push(qm[2]);
        i++;
      }
      var innerBlocks = parseBlocks(qLines, ctx);
      var calloutType = null;
      if (innerBlocks.length && innerBlocks[0].type === "paragraph") {
        var firstRun = innerBlocks[0].inline[0];
        if (firstRun && firstRun.type === "text") {
          var co = /^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]$/.exec(firstRun.text);
          if (co) {
            calloutType = co[1];
            var inlineRuns = innerBlocks[0].inline;
            inlineRuns.shift(); // the "[!TYPE]" marker text run
            if (inlineRuns[0] && inlineRuns[0].type === "linebreak") {
              inlineRuns.shift(); // the line break separating marker from body
            }
            if (inlineRuns.length === 0) {
              innerBlocks.shift(); // whole first paragraph was just the marker
            }
          }
        }
      }
      blocks.push({ type: "blockquote", blocks: innerBlocks, calloutType: calloutType });
      continue;
    }

    // HTML block (restricted subset: details / div / table) -----------
    var detailsStart = /^ {0,3}<details>\s*$/.exec(line);
    if (detailsStart) {
      i++;
      var summaryText = "";
      if (i < n && /^\s*<summary>/.test(lines[i])) {
        var sm = /^\s*<summary>([\s\S]*?)<\/summary>\s*$/.exec(lines[i]);
        summaryText = sm ? sm[1] : lines[i].replace(/<\/?summary>/g, "");
        i++;
      }
      var detailLines = [];
      while (i < n && lines[i].trim() !== "</details>") {
        detailLines.push(lines[i]);
        i++;
      }
      i++; // skip </details>
      blocks.push({
        type: "html_block",
        tag: "details",
        summaryInline: parseInline(summaryText, ctx),
        children: parseBlocks(detailLines, ctx),
      });
      continue;
    }

    var divStart = /^ {0,3}<div\s+align="([^"]*)">\s*$/.exec(line);
    if (divStart) {
      i++;
      var divLines = [];
      while (i < n && lines[i].trim() !== "</div>") {
        divLines.push(lines[i]);
        i++;
      }
      i++; // skip </div>
      blocks.push({
        type: "html_block",
        tag: "div",
        attrs: { align: divStart[1] },
        inline: parseInline(divLines.join(" "), ctx),
      });
      continue;
    }

    var tableTagStart = /^ {0,3}<table>\s*$/.exec(line);
    if (tableTagStart) {
      i++;
      var htmlTableLines = [];
      while (i < n && lines[i].trim() !== "</table>") {
        htmlTableLines.push(lines[i]);
        i++;
      }
      i++; // skip </table>
      blocks.push(parseHtmlTable(htmlTableLines.join("\n"), ctx));
      continue;
    }

    // Ordered / bullet list ------------------------------------------------
    var bulletMatch = BULLET_RE.exec(line);
    var orderedMatch = ORDERED_RE.exec(line);
    if (bulletMatch || orderedMatch) {
      var listResult = parseList(lines, i, ctx);
      blocks.push(listResult.node);
      i = listResult.next;
      continue;
    }

    // Table -----------------------------------------------------------------
    if (line.indexOf("|") !== -1 && i + 1 < n && TABLE_DELIM_RE.test(lines[i + 1]) && lines[i + 1].indexOf("-") !== -1) {
      var tableResult = parseTable(lines, i, ctx);
      blocks.push(tableResult.node);
      i = tableResult.next;
      continue;
    }

    // Definition list ------------------------------------------------------
    if (i + 1 < n && DEFLIST_RE.test(lines[i + 1]) && !isBlank(line)) {
      var deflistResult = parseDeflist(lines, i, ctx);
      blocks.push(deflistResult.node);
      i = deflistResult.next;
      continue;
    }

    // Paragraph (with setext lookahead) -------------------------------------
    var para = paragraphLinesAhead(i);
    if (para.next < n && SETEXT_RE.test(lines[para.next]) && para.text.length > 0) {
      var setextMarker = lines[para.next].trim()[0];
      var headingText = para.text.join(" ").trim();
      blocks.push({
        type: "heading",
        level: setextMarker === "=" ? 1 : 2,
        inline: parseInline(headingText, ctx),
        slug: slugify(headingText, ctx.slugsUsed),
      });
      i = para.next + 1;
      continue;
    }
    var paraText = para.text.join("\n");
    blocks.push({ type: "paragraph", inline: parseInline(paraText, ctx) });
    i = para.next;
  }

  return blocks;
}

function parseHtmlTable(html, ctx) {
  var rows = [];
  var rowRe = /<tr>([\s\S]*?)<\/tr>/g;
  var rm;
  while ((rm = rowRe.exec(html)) !== null) {
    var cells = [];
    var cellRe = /<(td|th)>([\s\S]*?)<\/\1>/g;
    var cm;
    var isHead = false;
    while ((cm = cellRe.exec(rm[1])) !== null) {
      if (cm[1] === "th") isHead = true;
      cells.push(parseInline(cm[2].trim(), ctx));
    }
    rows.push({ isHead: isHead, cells: cells });
  }
  var head = rows.length && rows[0].isHead ? rows.shift().cells : [];
  return {
    type: "table",
    align: head.map(function () {
      return null;
    }),
    head: head,
    rows: rows.map(function (r) {
      return r.cells;
    }),
  };
}

function parseTable(lines, start, ctx) {
  var headerCells = splitTableRow(lines[start]);
  var delimCells = splitTableRow(lines[start + 1]);
  var align = delimCells.map(function (c) {
    var left = c.trim().charAt(0) === ":";
    var right = c.trim().charAt(c.trim().length - 1) === ":";
    if (left && right) return "center";
    if (right) return "right";
    if (left) return "left";
    return null;
  });
  var i = start + 2;
  var rows = [];
  while (i < lines.length && !isBlank(lines[i]) && lines[i].indexOf("|") !== -1) {
    rows.push(splitTableRow(lines[i]).map(function (c) {
      return parseInline(c, ctx);
    }));
    i++;
  }
  return {
    node: {
      type: "table",
      align: align,
      head: headerCells.map(function (c) {
        return parseInline(c, ctx);
      }),
      rows: rows,
    },
    next: i,
  };
}

function splitTableRow(line) {
  var trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  var cells = [];
  var current = "";
  for (var i = 0; i < trimmed.length; i++) {
    var c = trimmed[i];
    if (c === "\\" && trimmed[i + 1] === "|") {
      current += "|";
      i++;
    } else if (c === "|") {
      cells.push(current);
      current = "";
    } else {
      current += c;
    }
  }
  cells.push(current);
  return cells.map(function (c) {
    return c.trim();
  });
}

function parseDeflist(lines, start, ctx) {
  var items = [];
  var i = start;
  while (i < lines.length && !isBlank(lines[i]) && i + 1 < lines.length && DEFLIST_RE.test(lines[i + 1])) {
    var term = lines[i];
    i++;
    var defs = [];
    while (i < lines.length && DEFLIST_RE.test(lines[i])) {
      defs.push(parseInline(DEFLIST_RE.exec(lines[i])[1], ctx));
      i++;
    }
    items.push({ term: parseInline(term, ctx), defs: defs });
    if (i < lines.length && isBlank(lines[i])) i++;
  }
  return { node: { type: "deflist", items: items }, next: i };
}

function parseList(lines, start, ctx) {
  var n = lines.length;
  var firstBullet = BULLET_RE.exec(lines[start]);
  var firstOrdered = ORDERED_RE.exec(lines[start]);
  var ordered = !!firstOrdered;
  var markerChar = firstBullet ? firstBullet[2] : null;
  var startNum = firstOrdered ? parseInt(firstOrdered[2], 10) : 1;

  var items = [];
  var i = start;

  while (i < n) {
    var peek = i;
    while (peek < n && isBlank(lines[peek])) peek++;
    if (peek >= n) break;
    var m = ordered ? ORDERED_RE.exec(lines[peek]) : BULLET_RE.exec(lines[peek]);
    if (!m) break;
    if (!ordered && m[2] !== markerChar) break;
    i = peek; // consume the blank line(s) that separated this item from the previous one (a "loose list")

    var indent = m[1].length;
    var markerText = ordered ? m[2] + m[3] : m[2];
    var spacer = (ordered ? m[4] : m[3]) || " ";
    var firstContent = (ordered ? m[5] : m[4]) || "";
    var contentCol = indent + markerText.length + Math.max(spacer.length, 1);

    var itemLines = [firstContent];
    i++;
    while (i < n) {
      if (isBlank(lines[i])) {
        // Blank line belongs to the item only if the *next* non-blank line
        // is still indented enough to continue it; otherwise it ends the list.
        var j = i;
        while (j < n && isBlank(lines[j])) j++;
        if (j < n && (lines[j].length - lines[j].replace(/^ */, "").length) >= contentCol) {
          itemLines.push("");
          i++;
          continue;
        }
        break;
      }
      var lineIndent = lines[i].length - lines[i].replace(/^ */, "").length;
      if (lineIndent >= contentCol) {
        itemLines.push(lines[i].slice(contentCol));
        i++;
        continue;
      }
      break;
    }
    while (itemLines.length && itemLines[itemLines.length - 1] === "") itemLines.pop();

    var task = null;
    var taskMatch = /^\[([ xX])\]\s+(.*)$/.exec(itemLines[0] || "");
    if (taskMatch) {
      task = { checked: taskMatch[1].toLowerCase() === "x" };
      itemLines[0] = taskMatch[2];
    }

    items.push({ blocks: parseBlocks(itemLines, ctx), task: task });
  }

  return {
    node: { type: "list", ordered: ordered, start: startNum, items: items },
    next: i,
  };
}

// ---------------------------------------------------------------------------
// Reference-style link definitions ([id]: url "title") are stripped out of
// the raw lines and collected into ctx.refs *before* any block/inline
// parsing runs, so matchLinkLike (Task 1) can resolve (or reject) a
// reference by name immediately instead of needing a placeholder-and-patch
// post-pass.
// ---------------------------------------------------------------------------

function extractLinkReferences(lines) {
  var refs = {};
  var kept = [];
  var refDefRe = /^ {0,3}\[([^\]]+)\]:\s*(\S+)(?:\s+"([^"]*)")?\s*$/;
  for (var i = 0; i < lines.length; i++) {
    var m = refDefRe.exec(lines[i]);
    if (m && !/^\^/.test(m[1])) {
      refs[m[1].toLowerCase()] = { href: m[2], title: m[3] || null };
    } else {
      kept.push(lines[i]);
    }
  }
  return { refs: refs, lines: kept };
}

function parse(source) {
  var cleaned = stripComments(source);
  var rawLines = cleaned.split(/\r\n|\r|\n/);
  var extracted = extractFrontMatter(rawLines);
  var refExtraction = extractLinkReferences(extracted.rest);
  var ctx = { footnotes: {}, slugsUsed: Object.create(null), refs: refExtraction.refs };
  var blocks = parseBlocks(refExtraction.lines, ctx);
  return { frontMatter: extracted.frontMatter, blocks: blocks, footnotes: ctx.footnotes };
}

// Finds which top-level block (by index into `blocks`) contains a
// footnote_ref inline run with the given id, searching recursively through
// nested blocks/inline runs. Used by MarkdownView.qml (Task 6) to scroll a
// footnote's "back to reference" link to roughly the right place -- scoped
// to *top-level* blocks only (not, say, a footnote referenced from inside a
// deeply nested list item), which is what MdBlockList.yForIndex() can
// actually resolve a y-position for.
function findTopLevelBlockIndexForFootnoteRef(blocks, footnoteId) {
  function containsRef(node) {
    if (Array.isArray(node)) return node.some(containsRef);
    if (!node || typeof node !== "object") return false;
    if (node.type === "footnote_ref" && node.id === footnoteId) return true;
    return Object.keys(node).some(function (k) {
      return containsRef(node[k]);
    });
  }
  for (var i = 0; i < blocks.length; i++) {
    if (containsRef(blocks[i])) return i;
  }
  return -1;
}
