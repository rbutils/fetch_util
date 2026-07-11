  function sportsTableStatLabels(tableText) {
    var labels = normalizeText(tableText).toLowerCase().match(/\b(?:pts?|points?|reb(?:ounds?)?|ast(?:s|sists?)?|min(?:utes?)?|fg|3pt|ft|yds?|goals?|assists?|shots?|fouls?|saves?|possession|rank|record)\b/g) || [];
    return labels.filter(function(label, index) { return labels.indexOf(label) === index; });
  }

  function sportsTableEvidence(root) {
    var tables = [];
    Array.prototype.forEach.call((root || document).querySelectorAll("table"), function(table) {
      if (!sportsTableLooksRelevant(table)) return;
      var text = normalizeText(table.textContent || "");
      var headers = normalizeText(Array.prototype.map.call(table.querySelectorAll("th, thead td"), function(cell) {
        return cell.textContent || "";
      }).join(" ")).toLowerCase();
      if (/\b(?:odds?|handicap|standings?|schedule|search|navigation|results?)\b/i.test(headers)) return;
      var markdown = cleanupMarkdownNoise(markdownFor(table.outerHTML)).trim();
      if (normalizeText(markdown) && !tables.some(function(item) { return item.markdown === markdown; })) {
        tables.push({ markdown: markdown, text: text, rawText: table.textContent || "", labels: sportsTableStatLabels(headers + " " + text), element: table });
      }
    });
    return tables;
  }

  function sportsTableContainsTeam(text, team) {
    var raw = text || "";
    var normalized = normalizeText(raw).toLowerCase();
    var words = normalizeText(team).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
    var initials = words.map(function(word) { return word.charAt(0); }).join("");
    var abbreviations = [initials];
    if (words.length > 1) {
      abbreviations.push(words[0].slice(0, 3), words[0].slice(0, 2) + words[words.length - 1].charAt(0));
    }
    return normalized.indexOf(normalizeText(team).toLowerCase()) !== -1 ||
      normalized.indexOf(words.join(" ")) !== -1 ||
      abbreviations.some(function(abbreviation) {
        return normalized.indexOf(abbreviation) !== -1 || new RegExp("\\b" + abbreviation + "\\b", "i").test(raw);
      }) ||
      (words.length > 1 && new RegExp("\\b" + words[words.length - 1] + "\\b", "i").test(normalized));
  }

  function sportsTableOwnsScore(table, identity) {
    if (!identity) return false;
    var text = table.rawText || table.text || table.markdown || "";
    return identity.teams.every(function(team) { return sportsTableContainsTeam(text, team); }) &&
      identity.scores.every(function(score) { return normalizeText(text).indexOf(String(score)) !== -1; });
  }

  function sportsCredibleGameContainer(node) {
    var current = node;
    while (current && current !== document.body) {
      var identity = normalizeText([
        current.id || "",
        current.className || "",
        current.getAttribute && current.getAttribute("data-testid") || ""
      ].join(" "));
      if (/\b(?:game|match|event|fixture|scoreboard|box[ -]?score)\b/i.test(identity)) return current;
      current = current.parentElement;
    }
    return null;
  }

  function sportsMatchDetailEvidence(scoreLines, tables, scoreNodes) {
    for (var index = 0; index < (scoreLines || []).length; index += 1) {
      var line = scoreLines[index];
      var identity = sportsScoreIdentity(line);
      if (!identity) continue;
      var scoreNode = (scoreNodes || []).filter(function(entry) { return entry.text === line; })[0];
      var owned = (tables || []).some(function(table) {
        if (table.labels.length < 2) return false;
        if (sportsTableOwnsScore(table, identity)) return true;
        var scoreContainer = scoreNode && sportsCredibleGameContainer(scoreNode.node);
        return !!scoreContainer && scoreContainer === sportsCredibleGameContainer(table.element);
      });
      if (owned) return { line: line, identity: identity };
    }
    return null;
  }
