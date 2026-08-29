  function semanticMarkdownRecordLine(line) {
    return /^\s*(?:(?:[-+*]|\d{1,9}[.)])\s+\S|\|.*\|\s*$)/.test(line);
  }

  function collapseMarkdownDuplicateLines(markdown) {
    var lines = markdown.split("\n");
    var deduped = [];
    var previous = null;

    lines.forEach(function(line) {
      var trimmed = line.trim();
      if (trimmed !== previous || !trimmed) {
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
      if (key && !/^#{1,6}\s/.test(key) && !semanticMarkdownRecordLine(line)) {
        counts[key] = (counts[key] || 0) + 1;
      }
    });

    var seen = {};
    return lines.filter(function(line) {
      var key = line.trim();
      if (!key || /^#{1,6}\s/.test(key) || semanticMarkdownRecordLine(line) || (counts[key] || 0) < 4) return true;
      if (seen[key]) return false;
      seen[key] = true;
      return true;
    }).join("\n");
  }
