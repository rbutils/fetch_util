  function headingCardLinkNode(node) {
    if (node.nodeName !== "A" || node.closest("li")) return false;
    return Array.from(node.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(heading) {
      var literal = heading.closest("pre, code, kbd, samp, table");
      return !literal || !node.contains(literal);
    });
  }

  function headingCardLinkMarkdown(content, destination) {
    var position = 0;
    while (position < content.length) {
      var program = markdownFencedCodeAt(content, position) || markdownIndentedFenceAt(content, position) ||
        markdownLiteralPreAt(content, position);
      if (program && program.end > position) {
        position = program.end;
        continue;
      }
      var end = markdownLineEnd(content, position);
      var line = content.slice(position, end);
      var heading = line.match(/^(#{1,6}[ \t]+)([^\r\n]+)/);
      if (heading) {
        return content.slice(0, position) + heading[1] +
          markdownLinkWithFormattedLabel(heading[2], destination) + content.slice(end);
      }
      position = end < content.length ? end + 1 : end;
    }
    return content;
  }
