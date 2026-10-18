  function markdownLiteralPreAt(value, position) {
    var lineEnd = markdownLineEnd(value, position);
    var opening = value.slice(position, lineEnd).match(/^[ \t]*(?:(?:>[ \t]*)|(?:[-+*]|\d+[.)])[ \t]+)*<pre(?=[\s>])/i);
    if (!opening) return null;
    var cursor = position + opening[0].length - 4;
    var depth = 0;
    while (cursor < value.length) {
      var start = value.indexOf("<", cursor);
      if (start < 0) break;
      if (!/[a-z/]/i.test(value[start + 1] || "")) { cursor = start + 1; continue; }
      var name = value.slice(start, start + 6).match(/^<\/?pre(?=[\s>])/i);
      // Every tag owns its quoted attributes, including a literal closing-PRE
      // string in a reference title. Only actual PRE tags change block depth.
      var quote = "", end = start + 1;
      for (; end < value.length; end++) {
        var character = value[end];
        if (quote) {
          if (character === quote) quote = "";
        } else if (character === "\"" || character === "'") {
          quote = character;
        } else if (character === ">") {
          break;
        }
      }
      if (end === value.length) return { end: value.length };
      if (name && name[0][1] === "/") {
        depth--;
        if (!depth) return { end: end + 1 };
      } else if (name) {
        depth++;
      }
      cursor = end + 1;
    }
    // CommonMark's literal PRE block also owns an unclosed remainder. Keeping
    // it in one protected span avoids rescanning every later line as an opener.
    return { end: value.length };
  }
