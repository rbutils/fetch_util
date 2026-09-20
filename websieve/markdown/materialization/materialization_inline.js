function inlineMarkdownLinkAt(markdown, position) {
  var image = markdown[position] === "!";
  var bracket = image ? position + 1 : position;
  if (markdown[bracket] !== "[" || markdownEscaped(markdown, position)) return null;

  var labelEnd = markdownLabelEnd(markdown, bracket);
  if (labelEnd < 0 || markdown[labelEnd + 1] !== "(") return null;
  var destination = inlineMarkdownDestinationAt(markdown, labelEnd + 1);
  if (!destination) return null;

  return {
    image: image,
    label: markdown.slice(bracket + 1, labelEnd),
    url: destination.url.replace(/\\([\\()])/g, "$1"),
    suffix: destination.suffix,
    end: destination.end
  };
}

function inlineMarkdownDestinationAt(value, opening) {
  var position = opening + 1;
  var whitespaceStart = position;
  while (position < value.length && /\s/.test(value[position])) position += 1;
  if (/\n[ \t]*\n/.test(value.slice(whitespaceStart, position))) return null;

  var destinationStart = position;
  var url = "";
  if (value[position] === "<") {
    var angleEnd = markdownAngleDestinationEnd(value, position);
    if (angleEnd < 0) return null;
    url = value.slice(position + 1, angleEnd);
    position = angleEnd + 1;
  } else {
    var depth = 0;
    while (position < value.length) {
      var character = value[position];
      if (character === "\\") {
        position += 2;
        continue;
      }
      if (character === "<" || character === ">" || /[\u0000-\u001f\u007f]/.test(character) && !/\s/.test(character)) return null;
      if (character === "(" ) depth += 1;
      else if (character === ")") {
        if (!depth) break;
        depth -= 1;
      } else if (/\s/.test(character)) {
        if (depth) return null;
        break;
      }
      position += 1;
    }
    if (depth) return null;
    url = value.slice(destinationStart, position);
  }

  var destinationEnd = position;
  var suffixStart = position;
  while (position < value.length && /\s/.test(value[position])) position += 1;
  if (/\n[ \t]*\n/.test(value.slice(suffixStart, position))) return null;
  if (value[position] === ")") {
    return { url: url, suffix: value.slice(destinationEnd, position), end: position + 1 };
  }

  var titleEnd = markdownTitleEnd(value, position);
  if (titleEnd < 0) return null;
  position = titleEnd;
  while (position < value.length && /\s/.test(value[position])) position += 1;
  if (value[position] !== ")" || /\n[ \t]*\n/.test(value.slice(titleEnd, position))) return null;
  return { url: url, suffix: value.slice(destinationEnd, position), end: position + 1 };
}

function markdownDestinationAt(value, start) {
  var position = start || 0;
  while (position < value.length && /[ \t]/.test(value[position])) position += 1;
  if (position >= value.length) return null;

  if (value[position] === "<") {
    var angleEnd = markdownAngleDestinationEnd(value, position);
    if (angleEnd < 0) return null;
    return { url: value.slice(position + 1, angleEnd), start: position, end: angleEnd + 1, angle: true };
  }

  var token = markdownDestinationToken(value.slice(position));
  if (!token) return null;
  return { url: token, start: position, end: position + token.length, angle: false };
}

function markdownAngleDestinationEnd(value, position) {
  for (var index = position + 1; index < value.length; index += 1) {
    if (value[index] === "\\") index += 1;
    else if (value[index] === "\n" || value[index] === "<") return -1;
    else if (value[index] === ">") return index;
  }
  return -1;
}

function markdownTitleEnd(value, position) {
  var opening = value[position];
  var closing = opening === "(" ? ")" : opening;
  if (opening !== '"' && opening !== "'" && opening !== "(") return -1;
  for (var index = position + 1; index < value.length; index += 1) {
    if (value[index] === "\\") index += 1;
    else if (value[index] === closing) return index + 1;
    else if (value[index] === "\n" && value[index + 1] === "\n") return -1;
  }
  return -1;
}

function markdownHtmlTagAt(markdown, position) {
  if (markdown[position] !== "<" || markdownEscaped(markdown, position)) return null;
  var remainder = markdown.slice(position);
  var opening = remainder.match(/^<([A-Za-z][A-Za-z0-9-]*)(?:\s|\/?>)/);
  if (!opening) return null;

  var tagEnd = markdownHtmlTagEnd(markdown, position);
  if (tagEnd < 0) return null;
  var tag = opening[1].toLowerCase();
  if (tag === "script" || tag === "style") {
    var closing = new RegExp("<\\/" + tag + "\\s*>", "ig");
    closing.lastIndex = tagEnd + 1;
    var match = closing.exec(markdown);
    return { value: "", end: match ? match.index + match[0].length : markdown.length };
  }
  var template = document.createElement("template");
  template.innerHTML = markdown.slice(position, tagEnd + 1);
  var element = template.content.firstElementChild;
  if (!element) return null;

  materializeHttpAttributes(template.content);
  element = template.content.firstElementChild;
  if (!element) return { value: "", end: tagEnd + 1 };
  var serialized = element.outerHTML;
  var serializedEnd = markdownHtmlTagEnd(serialized, 0);
  if (serializedEnd < 0) return null;
  return { value: serialized.slice(0, serializedEnd + 1), end: tagEnd + 1 };
}

function markdownHtmlTagEnd(value, position) {
  var quote = null;
  for (var index = position + 1; index < value.length; index += 1) {
    if (quote) {
      if (value[index] === quote) quote = null;
    } else if (value[index] === '"' || value[index] === "'") {
      quote = value[index];
    } else if (value[index] === ">") {
      return index;
    }
  }
  return -1;
}

function markdownAutolinkAt(markdown, position) {
  if (markdown[position] !== "<" || markdownEscaped(markdown, position)) return null;
  var end = markdown.indexOf(">", position + 1);
  if (end < 0) return null;
  var value = markdown.slice(position + 1, end);
  if (/\s/.test(value)) return null;

  var uri = /^[A-Za-z][A-Za-z0-9+.-]{1,31}:/.test(value);
  var email = /^[^<>\s@]+@[^<>\s@]+\.[^<>\s@]+$/.test(value);
  if (!uri && !email) return null;
  var url = uri ? materializedHttpUrl(value) : null;
  var visibleValue = value;
  if (uri && !url) {
    try {
      var parsed = new URL(value);
      if ((parsed.protocol === "http:" || parsed.protocol === "https:") && (parsed.username || parsed.password)) {
        parsed.username = "";
        parsed.password = "";
        visibleValue = parsed.href;
      }
    } catch (_error) {
      // Preserve malformed literal text.
    }
  }
  var visible = visibleValue.replace(/:/g, "&#58;").replace(/@/g, "&#64;");
  return { value: url ? "<" + url + ">" : visible, end: end + 1 };
}

function markdownCredentialUrlAt(markdown, position) {
  if (markdownEscaped(markdown, position)) return null;
  var candidate = markdown.slice(position).match(/^https?:\/\/[^\s<>]+/i);
  if (!candidate) return null;

  var visible = credentialFreeHttpText(candidate[0]);
  if (visible === candidate[0]) return null;
  return { value: visible, end: position + candidate[0].length };
}

function markdownDelimiterEnd(value, start, opening, closing) {
  var depth = 0;
  for (var index = start; index < value.length; index += 1) {
    if (value[index] === "\\") {
      index += 1;
    } else if (value[index] === opening) {
      depth += 1;
    } else if (value[index] === closing) {
      depth -= 1;
      if (!depth) return index;
    }
  }
  return -1;
}

function markdownLabelEnd(value, start) {
  var depth = 0;
  for (var index = start; index < value.length; index += 1) {
    if (value[index] === "\\") {
      index += 1;
    } else if (value[index] === "`") {
      var code = markdownCodeSpanAt(value, index);
      if (code) index = code.end - 1;
    } else if (value[index] === "[") {
      depth += 1;
    } else if (value[index] === "]") {
      depth -= 1;
      if (!depth) return index;
    }
  }
  return -1;
}

function markdownDestinationToken(value) {
  var depth = 0;
  for (var index = 0; index < value.length; index += 1) {
    if (value[index] === "\\") {
      index += 1;
    } else if (value[index] === "<" || value[index] === ">" || /[\u0000-\u001f\u007f]/.test(value[index]) && !/[ \t]/.test(value[index])) {
      return null;
    } else if (value[index] === "(") {
      depth += 1;
    } else if (value[index] === ")" && depth) {
      depth -= 1;
    } else if (value[index] === ")") {
      return null;
    } else if (/[ \t]/.test(value[index])) {
      return depth ? null : value.slice(0, index);
    }
  }
  return depth ? null : value;
}

function markdownRunLength(value, position, character) {
  var end = position;
  while (value[end] === character) end += 1;
  return end - position;
}

function markdownCodeSpanAt(value, position) {
  if (value[position] !== "`" || markdownEscaped(value, position)) return null;
  var ticks = markdownRunLength(value, position, "`");
  for (var index = position + ticks; index < value.length;) {
    if (value[index] !== "`") {
      index += 1;
      continue;
    }
    var length = markdownRunLength(value, index, "`");
    if (length === ticks) return { end: index + ticks };
    index += length;
  }
  return null;
}

function markdownEscaped(value, position) {
  var slashes = 0;
  for (var index = position - 1; index >= 0 && value[index] === "\\"; index -= 1) slashes += 1;
  return slashes % 2 === 1;
}
