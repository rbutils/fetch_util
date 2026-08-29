function markdownRawHtmlBlockAt(value, position, allowTypeSeven) {
  var lineEnd = markdownLineEnd(value, position);
  var firstLine = value.slice(position, lineEnd);
  var offset = markdownContainerOffset(firstLine);
  var content = firstLine.slice(offset);
  var contentStart = position + offset;
  var container = markdownContainerState(firstLine);
  var containerEnd = markdownContainerEnd(value, position, container);
  var delimited = [
    { prefix: "<!--", suffix: "-->" },
    { prefix: "<?", suffix: "?>" },
    { prefix: "<![CDATA[", suffix: "]]>" }
  ];

  for (var index = 0; index < delimited.length; index += 1) {
    var boundary = delimited[index];
    if (content.indexOf(boundary.prefix) !== 0) continue;
    var closing = value.indexOf(boundary.suffix, contentStart + boundary.prefix.length);
    var end = closing < 0 || closing + boundary.suffix.length > containerEnd ? containerEnd : closing + boundary.suffix.length;
    return { value: value.slice(position, end), end: end };
  }

  if (/^<![A-Z]/.test(content)) {
    var declarationEnd = value.indexOf(">", contentStart + 2);
    declarationEnd = declarationEnd < 0 || declarationEnd + 1 > containerEnd ? containerEnd : declarationEnd + 1;
    return { value: value.slice(position, declarationEnd), end: declarationEnd };
  }

  var rawText = content.match(/^<(script|pre|style|textarea)(?:\s|>|$)/i);
  if (rawText) return markdownRawTextBlock(value, position, contentStart, rawText, containerEnd, container);

  var blockTags = "address|article|aside|blockquote|body|caption|center|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frameset|h1|h2|h3|h4|h5|h6|head|header|html|iframe|legend|li|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|ul";
  var knownBlock = new RegExp("^<\\/?(?:" + blockTags + ")(?:\\s|\\/?>|$)", "i").test(content);
  if (!knownBlock && (!allowTypeSeven || !markdownTypeSevenBlockTag(content))) return null;

  var blockEnd = markdownHtmlBlockEnd(value, position, containerEnd, container);
  return { value: materializedMarkdownHtmlBlock(value, position, blockEnd, container), end: blockEnd };
}

function markdownTypeSevenBlockTag(value) {
  if (!/^<\/?[A-Za-z][A-Za-z0-9-]*(?:\s|\/?>)/.test(value)) return false;
  var end = markdownHtmlTagEnd(value, 0);
  return end >= 0 && !value.slice(end + 1).trim();
}

function markdownLineOpensParagraph(line) {
  var content = line.slice(markdownContainerOffset(line));
  if (!content.trim()) return false;
  if (/^#{1,6}(?:[ \t]+|$)/.test(content)) return false;
  if (/^(?:=+|-+)[ \t]*$/.test(content)) return false;
  if (/^(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,}|(?:-[ \t]*){3,})$/.test(content)) return false;
  return true;
}

function markdownRawTextBlock(value, position, contentStart, opening, containerEnd, container) {
  var tag = opening[1].toLowerCase();
  var closing = new RegExp("<\\/" + tag + "\\s*>", "ig");
  closing.lastIndex = contentStart + opening[0].length;
  var match = closing.exec(value);
  if (match && match.index + match[0].length > containerEnd) match = null;

  if (!match) {
    if (tag === "script" || tag === "style") return { value: "", end: containerEnd };
    return { value: materializedMarkdownHtmlBlock(value, position, containerEnd, container), end: containerEnd };
  }

  var end = match.index + match[0].length;
  return {
    value: tag === "script" || tag === "style" ? "" : materializedMarkdownHtmlBlock(value, position, end, container),
    end: end
  };
}

function materializedMarkdownHtmlBlock(value, position, end, container) {
  var lines = value.slice(position, end).split("\n");
  var prefixes = [];
  var html = lines.map(function(line, index) {
    var offset = index ? markdownMatchingContainerOffset(line, container) : container.offset;
    if (offset === null) offset = markdownContainerOffset(line);
    prefixes.push(line.slice(0, offset));
    return line.slice(offset);
  }).join("\n");
  var sanitized = materializedHtml(html);
  if (!sanitized) return "";

  var fallbackPrefix = prefixes[prefixes.length - 1] || prefixes[0] || "";
  return sanitized.split("\n").map(function(line, index) {
    return (prefixes[index] === undefined ? fallbackPrefix : prefixes[index]) + line;
  }).join("\n");
}

function markdownHtmlBlockEnd(value, position, containerEnd, container) {
  var cursor = markdownLineEnd(value, position);
  if (cursor >= value.length) return value.length;
  cursor += 1;

  while (cursor < containerEnd) {
    var lineEnd = markdownLineEnd(value, cursor);
    var line = value.slice(cursor, lineEnd);
    var offset = container.steps.length ? markdownMatchingContainerOffset(line, container) : markdownContainerOffset(line);
    if (/^[ \t]*$/.test(line.slice(offset))) return cursor;
    cursor = lineEnd < value.length ? lineEnd + 1 : value.length;
  }
  return containerEnd;
}
