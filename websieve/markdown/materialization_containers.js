function markdownContainerOffset(line) {
  return markdownContainerState(line).offset;
}

function markdownContainerState(line) {
  var position = 0;
  var steps = [];
  while (position < line.length) {
    var spaced = markdownUpToThreeSpaces(line, position);
    if (line[spaced] === ">" && (!line[spaced + 1] || /[ \t]/.test(line[spaced + 1]))) {
      steps.push({ type: "quote" });
      position = spaced + 1;
      if (/[ \t]/.test(line[position] || "")) position += 1;
      continue;
    }

    var marker = line.slice(spaced).match(/^(?:[-+*]|\d{1,9}[.)])/);
    if (marker) {
      var markerEnd = spaced + marker[0].length;
      var spacing = (line.slice(markerEnd).match(/^[ \t]+/) || [""])[0];
      if (!spacing) {
        position = spaced;
        break;
      }
      var spacingLength = spacing.length > 4 ? 1 : spacing.length;
      steps.push({ type: "list", width: markerEnd + spacingLength - position });
      if (spacing.length > 4) {
        position = markerEnd + 1;
        break;
      }
      position = markerEnd + spacing.length;
      continue;
    }

    position = spaced;
    break;
  }
  return { offset: position, steps: steps };
}

function markdownMatchingContainerOffset(line, container) {
  if (!line.trim() && container.steps.length && container.steps.every(function(step) { return step.type === "list"; })) return 0;
  var position = 0;
  for (var index = 0; index < container.steps.length; index += 1) {
    var step = container.steps[index];
    if (step.type === "quote") {
      var spaced = markdownUpToThreeSpaces(line, position);
      if (line[spaced] !== ">" || (line[spaced + 1] && !/[ \t]/.test(line[spaced + 1]))) return null;
      position = spaced + 1;
      if (/[ \t]/.test(line[position] || "")) position += 1;
      continue;
    }

    var indentation = (line.slice(position).match(/^[ \t]+/) || [""])[0];
    if (indentation.length < step.width) return null;
    position += step.width;
  }
  return position;
}

function markdownContainerEnd(value, position, container) {
  if (!container.steps.length) return value.length;

  var cursor = markdownLineEnd(value, position);
  cursor = cursor < value.length ? cursor + 1 : value.length;
  while (cursor < value.length) {
    var lineEnd = markdownLineEnd(value, cursor);
    if (markdownMatchingContainerOffset(value.slice(cursor, lineEnd), container) === null) return cursor;
    cursor = lineEnd < value.length ? lineEnd + 1 : value.length;
  }
  return value.length;
}

function markdownParagraphContinues(line, container) {
  if (!container || !container.steps.length) return !markdownContainerState(line).steps.length;
  return markdownMatchingContainerOffset(line, container) !== null;
}

function markdownUpToThreeSpaces(value, position) {
  var end = position;
  while (end < position + 3 && value[end] === " ") end += 1;
  return end;
}

function markdownLineStart(value, position) {
  return position === 0 || value[position - 1] === "\n";
}

function markdownLineEnd(value, position) {
  var lineEnd = value.indexOf("\n", position);
  return lineEnd < 0 ? value.length : lineEnd;
}

function markdownPreviousLineBlank(value, position) {
  if (!position) return true;
  var previousEnd = position - 1;
  var previousStart = value.lastIndexOf("\n", previousEnd - 1) + 1;
  return !value.slice(previousStart, previousEnd).trim();
}

function markdownPreviousContainerLineBlank(value, position, line, output) {
  if (!position) return true;

  var currentOffset = markdownContainerOffset(line);
  if (currentOffset > markdownUpToThreeSpaces(line, 0) && /\n[ \t]*$/.test(output)) return true;

  var previousEnd = position - 1;
  var previousStart = value.lastIndexOf("\n", previousEnd - 1) + 1;
  var previousLine = value.slice(previousStart, previousEnd);
  var previousOffset = markdownContainerOffset(previousLine);
  return !previousLine.slice(previousOffset).trim();
}
