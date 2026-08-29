function materializedMarkdown(markdown) {
  var input = String(markdown || "").replace(/\r\n?/g, "\n");
  var output = "";
  var position = 0;
  var paragraphOpen = false;
  var paragraphContainer = null;

  while (position < input.length) {
    if (markdownLineStart(input, position)) {
      var line = input.slice(position, markdownLineEnd(input, position));
      if (paragraphOpen && !markdownParagraphContinues(line, paragraphContainer)) {
        paragraphOpen = false;
        paragraphContainer = null;
      }

      var rawHtmlBlock = markdownRawHtmlBlockAt(input, position, !paragraphOpen);
      if (rawHtmlBlock) {
        output += rawHtmlBlock.value;
        position = rawHtmlBlock.end;
        paragraphOpen = false;
        continue;
      }

      var fence = markdownFencedCodeAt(input, position);
      if (fence) {
        output += input.slice(position, fence.end);
        position = fence.end;
        paragraphOpen = false;
        continue;
      }

      var indentedCode = markdownIndentedCodeAt(input, position, output);
      if (indentedCode) {
        output += input.slice(position, indentedCode.end);
        position = indentedCode.end;
        paragraphOpen = false;
        continue;
      }

      var definition = paragraphOpen ? null : markdownReferenceDefinitionAt(input, position);
      if (definition) {
        output += definition.value;
        position = definition.end;
        paragraphOpen = false;
        continue;
      }

      var opensParagraph = markdownLineOpensParagraph(line);
      if (opensParagraph && !paragraphOpen) paragraphContainer = markdownContainerState(line);
      paragraphOpen = opensParagraph;
    }

    var codeSpan = markdownCodeSpanAt(input, position);
    if (codeSpan) {
      output += input.slice(position, codeSpan.end);
      position = codeSpan.end;
      continue;
    }

    var htmlTag = markdownHtmlTagAt(input, position);
    if (htmlTag) {
      output += htmlTag.value;
      position = htmlTag.end;
      continue;
    }

    var autolink = markdownAutolinkAt(input, position);
    if (autolink) {
      output += autolink.value;
      position = autolink.end;
      continue;
    }

    var link = inlineMarkdownLinkAt(input, position);
    if (link) {
      var label = materializedMarkdown(link.label);
      var url = materializedHttpUrl(link.url);
      output += url ? (link.image ? "!" : "") + "[" + label + "](" + url + link.suffix + ")" : label;
      position = link.end;
      continue;
    }

    output += input[position];
    position += 1;
  }
  return output;
}

function markdownFencedCodeAt(value, position) {
  var lineEnd = markdownLineEnd(value, position);
  var line = value.slice(position, lineEnd);
  var container = markdownContainerState(line);
  var opening = line.slice(container.offset).match(/^(`{3,}|~{3,})(.*)$/);
  if (!opening || (opening[1][0] === "`" && opening[2].indexOf("`") >= 0)) return null;

  var character = opening[1][0];
  var length = opening[1].length;
  var closingPattern = new RegExp("^" + character + "{" + length + ",}[ \\t]*$");
  var cursor = lineEnd < value.length ? lineEnd + 1 : value.length;
  while (cursor < value.length) {
    var closingEnd = markdownLineEnd(value, cursor);
    var closingLine = value.slice(cursor, closingEnd);
    var closingOffset = container.steps.length ? markdownMatchingContainerOffset(closingLine, container) : markdownContainerOffset(closingLine);
    if (closingOffset !== null) closingOffset = markdownUpToThreeSpaces(closingLine, closingOffset);
    if (closingOffset === null) return { end: cursor };
    if (closingPattern.test(closingLine.slice(closingOffset))) return { end: closingEnd };
    cursor = closingEnd < value.length ? closingEnd + 1 : value.length;
  }
  return { end: value.length };
}

function markdownIndentedCodeAt(value, position, output) {
  var firstEnd = markdownLineEnd(value, position);
  var firstLine = value.slice(position, firstEnd);
  var contentStart = markdownContainerOffset(firstLine);
  if (!/^(?: {1}|\t)/.test(firstLine.slice(contentStart)) || !markdownPreviousContainerLineBlank(value, position, firstLine, output)) return null;

  var cursor = position;
  while (cursor < value.length) {
    var lineEnd = markdownLineEnd(value, cursor);
    var line = value.slice(cursor, lineEnd);
    var offset = markdownContainerOffset(line);
    if (line.trim() && !/^(?: {1}|\t)/.test(line.slice(offset))) break;
    cursor = lineEnd < value.length ? lineEnd + 1 : value.length;
  }
  return { end: cursor };
}

function markdownReferenceDefinitionAt(value, position) {
  var lineEnd = markdownLineEnd(value, position);
  var line = value.slice(position, lineEnd);
  var container = markdownContainerState(line);
  var contentOffset = container.offset;
  if (line[contentOffset] !== "[") return null;

  var labelEnd = markdownLabelEnd(line, contentOffset);
  if (labelEnd <= contentOffset + 1 || line[labelEnd + 1] !== ":") return null;
  if (line.slice(contentOffset + 1, labelEnd).length > 999) return null;
  var destinationLineStart = position;
  var destinationLine = line;
  var destinationOffset = labelEnd + 2;
  while (/[ \t]/.test(destinationLine[destinationOffset] || "")) destinationOffset += 1;

  if (destinationOffset >= destinationLine.length) {
    destinationLineStart = lineEnd < value.length ? lineEnd + 1 : value.length;
    if (destinationLineStart >= value.length) return null;
    var continuationEnd = markdownLineEnd(value, destinationLineStart);
    destinationLine = value.slice(destinationLineStart, continuationEnd);
    destinationOffset = markdownReferenceContinuationOffset(destinationLine, container);
    if (destinationOffset === null || destinationOffset >= destinationLine.length) return null;
  }

  var destinationText = destinationLine.slice(destinationOffset);
  var destination = markdownDestinationAt(destinationText);
  if (!destination) return null;
  var suffix = destinationText.slice(destination.end);
  if (suffix.trim() && !markdownCompleteTitle(suffix)) return null;

  var blockEnd = destinationLineStart + destinationLine.length;
  if (!suffix.trim() && blockEnd < value.length) {
    var titleStart = blockEnd + 1;
    var titleEnd = markdownLineEnd(value, titleStart);
    var titleLine = value.slice(titleStart, titleEnd);
    var titleOffset = markdownReferenceContinuationOffset(titleLine, container);
    if (titleOffset !== null && markdownCompleteTitle(titleLine.slice(titleOffset))) blockEnd = titleEnd;
  }

  var absoluteStart = destinationLineStart + destinationOffset + destination.start;
  var absoluteEnd = destinationLineStart + destinationOffset + destination.end;
  var safeUrl = materializedHttpUrl(destination.url.replace(/\\([\\()])/g, "$1"));
  if (!safeUrl) {
    return { value: value.slice(position, blockEnd).replace(/[^\n]/g, ""), end: blockEnd };
  }

  var serialized = destination.angle ? "<" + safeUrl + ">" : safeUrl;
  return {
    value: value.slice(position, absoluteStart) + serialized + value.slice(absoluteEnd, blockEnd),
    end: blockEnd
  };
}

function markdownReferenceContinuationOffset(line, container) {
  if (!container.steps.length) return markdownContainerOffset(line);
  var offset = markdownMatchingContainerOffset(line, container);
  return offset === null ? null : markdownUpToThreeSpaces(line, offset);
}

function markdownCompleteTitle(value) {
  var start = 0;
  while (/[ \t]/.test(value[start] || "")) start += 1;
  var end = markdownTitleEnd(value, start);
  if (end < 0) return false;
  while (/[ \t]/.test(value[end] || "")) end += 1;
  return end === value.length;
}
