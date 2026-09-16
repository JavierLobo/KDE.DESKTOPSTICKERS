.pragma library

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
