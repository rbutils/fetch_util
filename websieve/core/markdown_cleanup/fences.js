  function protectMarkdownFences(markdown) {
    var input = String(markdown || "");
    var fencedBlocks = [];
    var protectedMarkdown = "";
    var position = 0;
    while (position < input.length) {
      var fence = markdownFencedCodeAt(input, position) || markdownIndentedFenceAt(input, position);
      if (fence && fence.end > position) {
        protectedMarkdown += "@@FETCH_UTIL_FENCE_" + fencedBlocks.length + "@@";
        fencedBlocks.push(input.slice(position, fence.end));
        position = fence.end;
      } else {
        var lineEnd = markdownLineEnd(input, position);
        var next = lineEnd < input.length ? lineEnd + 1 : lineEnd;
        protectedMarkdown += input.slice(position, next);
        position = next;
      }
    }

    return { markdown: protectedMarkdown, blocks: fencedBlocks };
  }

  function markdownIndentedFenceAt(value, position) {
    var lineEnd = markdownLineEnd(value, position);
    var opening = value.slice(position, lineEnd).match(/^([ \t]+)(`{3,}|~{3,})(.*)$/);
    if (!opening || (opening[2][0] === "`" && opening[3].indexOf("`") >= 0)) return null;

    // List continuations can indent fences beyond the ordinary three-space prefix.
    var indentation = opening[1];
    var closing = new RegExp("^" + opening[2][0] + "{" + opening[2].length + ",}[ \\t]*$");
    var cursor = lineEnd < value.length ? lineEnd + 1 : lineEnd;
    while (cursor < value.length) {
      var end = markdownLineEnd(value, cursor);
      var line = value.slice(cursor, end);
      if (line.trim() && line.indexOf(indentation) !== 0) return { end: cursor };
      if (closing.test(line.slice(indentation.length).replace(/^ {0,3}/, ""))) return { end: end };
      cursor = end < value.length ? end + 1 : end;
    }
    return { end: value.length };
  }

  function restoreMarkdownFences(markdown, fencedBlocks) {
    return markdown.replace(/@@FETCH_UTIL_FENCE_(\d+)@@/g, function(match, index) {
      return fencedBlocks[Number(index)] || "";
    });
  }

  function compactMarkdownSpacing(markdown) {
    var protectedMarkdown = protectMarkdownFences(markdown);
    var compacted = protectedMarkdown.markdown.replace(/\n{3,}/g, "\n\n").trim();
    return restoreMarkdownFences(compacted, protectedMarkdown.blocks);
  }
