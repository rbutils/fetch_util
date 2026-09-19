  function semanticMarkdownRecordLine(line) {
    return /^\s*(?:(?:[-+*]|\d{1,9}[.)])\s+\S|\|.*\|\s*$)/.test(line);
  }

  function collapseMarkdownDuplicateLines(markdown) {
    var lines = markdown.split("\n");
    var deduped = [];
    var previous = null;

    lines.forEach(function(line) {
      var trimmed = line.trim();
      var structuredCardField = trimmed.indexOf(STRUCTURED_CARD_FIELD_MARKER) === 0;
      if (trimmed !== previous || !trimmed || structuredCardField) {
        previous = trimmed;
        deduped.push(line);
      } else if (semanticMarkdownRecordLine(line)) {
        deduped.push(line);
      }
    });

    lines = deduped;
    var counts = {};
    lines.forEach(function(line) {
      var key = line.trim();
      if (key && key.indexOf(STRUCTURED_CARD_FIELD_MARKER) !== 0 && !/^#{1,6}\s/.test(key) && !semanticMarkdownRecordLine(line)) {
        counts[key] = (counts[key] || 0) + 1;
      }
    });

    var seen = {};
    return lines.filter(function(line) {
      var key = line.trim();
      if (key.indexOf(STRUCTURED_CARD_FIELD_MARKER) === 0) return true;
      if (!key || /^#{1,6}\s/.test(key) || semanticMarkdownRecordLine(line) || (counts[key] || 0) < 4) return true;
      if (seen[key]) return false;
      seen[key] = true;
      return true;
    }).join("\n");
  }
