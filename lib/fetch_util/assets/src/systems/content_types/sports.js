  function sportsStructuredDataNodes() {
    return structuredDataNodes().filter(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)(SportsEvent|VideoGame)$/i.test(type);
      });
    });
  }

  function sportsEntityName(value) {
    return entityName(value) || entityText(value) || "";
  }

  function sportsScoreValue(value) {
    if (value === null || value === undefined) return "";
    if (typeof value === "number") return String(value);
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) return sportsScoreValue(value[0]);
    return normalizeText(value.score || value.result || value.value || value.points || "");
  }

  function sportsStructuredEvent() {
    var event = sportsStructuredDataNodes()[0];
    if (!event) return null;

    var home = event.homeTeam || event.competitor || event.team;
    var away = event.awayTeam || (Array.isArray(event.competitor) ? event.competitor[1] : null);
    if (Array.isArray(home)) home = home[0];

    var homeName = sportsEntityName(home);
    var awayName = sportsEntityName(away);
    var homeScore = sportsScoreValue(home && (home.score || home.result || home.points));
    var awayScore = sportsScoreValue(away && (away.score || away.result || away.points));
    var name = sportsEntityName(event);

    return {
      title: name,
      homeName: homeName,
      awayName: awayName,
      homeScore: homeScore,
      awayScore: awayScore,
      startDate: entityText(event.startDate),
      status: humanizeValue(entityText(event.eventStatus) || entityText(event.status) || "")
    };
  }

  function sportsScorePattern(text) {
    text = normalizeText(text);
    if (!text || text.length > 180) return false;
    if (/\b(?:menu|navigation|subscribe|sign in|login|tickets|shop|fantasy|standings|schedule)\b/i.test(text)) return false;

    var compactScore = text.match(/\b[A-Z][A-Za-z.'& -]{1,28}\s+(\d{1,3})\s*,?\s+[A-Z][A-Za-z.'& -]{1,28}\s+(\d{1,3})\b/);
    var dashScore = text.match(/\b[A-Z][A-Za-z.'& -]{1,28}\s+(\d{1,3})\s*[-–]\s*(\d{1,3})\s+[A-Z][A-Za-z.'& -]{1,28}\b/);
    var score = compactScore || dashScore;
    if (!score) return false;

    var first = Number(score[1]);
    var second = Number(score[2]);
    if (!Number.isFinite(first) || !Number.isFinite(second)) return false;
    return first <= 250 && second <= 250;
  }

  function sportsContextText(metadata) {
    return normalizeText([
      location.hostname,
      location.pathname,
      document.title,
      metadata && metadata.title,
      metadata && metadata.siteName,
      metadata && metadata.excerpt,
      metadataValue("article:section", "property"),
      metadataValue("og:type", "property")
    ].join(" ")).toLowerCase();
  }

  function sportsContext(metadata) {
    var context = sportsContextText(metadata);
    if (/\b(sport|sports|football|soccer|nba|nfl|mlb|nhl|cricket|rugby|tennis|golf|boxing|formula 1|f1|basketball|baseball|hockey|game recap|box score|fixtures?)\b/.test(context)) return true;
    return !!document.querySelector("[itemtype*='schema.org/SportsEvent' i], [typeof*='SportsEvent' i]") || sportsStructuredDataNodes().length > 0;
  }

  function sportsRelevantRoot() {
    return document.querySelector("main article, article, main, [role='main']") || document.body;
  }

  function sportsVisibleScoreLines(root) {
    var lines = [];
    var seen = {};
    var selector = "h1, h2, h3, [class*='score' i], [class*='score' i] p, [class*='scoreboard' i], [class*='result' i], [class*='result' i] p, [data-testid*='score' i], [data-testid*='game' i]";

    Array.prototype.forEach.call((root || document).querySelectorAll(selector), function(node) {
      if (node.closest && node.closest("nav, header, footer, aside, form, [aria-hidden='true'], [hidden]")) return;
      var text = normalizeText(node.textContent || "");
      if (!sportsScorePattern(text) || seen[text]) return;
      seen[text] = true;
      lines.push(text);
    });

    return lines.slice(0, 4);
  }

  function sportsTableLooksRelevant(table) {
    if (!table || (table.closest && table.closest("nav, header, footer, aside, form, [aria-hidden='true'], [hidden]"))) return false;
    var text = normalizeText(table.textContent || "");
    if (!text || text.length > 10000) return false;
    var headers = normalizeText(Array.prototype.map.call(table.querySelectorAll("th, thead td"), function(cell) {
      return cell.textContent || "";
    }).join(" ")).toLowerCase();
    var rowCount = table.querySelectorAll("tr").length;
    if (rowCount < 2 || rowCount > 80) return false;
    if (/\b(player|team|pts|reb|ast|min|fg|3pt|ft|plus\/minus|\+\/-|goals?|assists?|shots?|possession|fouls?|score)\b/i.test(headers)) return true;
    return sportsScorePattern(text) && /\b(final|box score|score|result|pts|goals?)\b/i.test(text);
  }

  function sportsTableMarkdown(root) {
    var tables = [];
    Array.prototype.forEach.call((root || document).querySelectorAll("table"), function(table) {
      if (tables.length >= 3) return;
      if (!sportsTableLooksRelevant(table)) return;
      var markdown = cleanupMarkdownNoise(markdownFor(table.outerHTML)).trim();
      if (normalizeText(markdown) && tables.indexOf(markdown) === -1) tables.push(markdown);
    });
    return tables;
  }

  function sportsContentEvidence(metadata) {
    var structured = sportsStructuredEvent();
    var root = sportsRelevantRoot();
    var scoreLines = sportsVisibleScoreLines(root);
    [document.title, metadata && metadata.title].forEach(function(text) {
      text = normalizeText(text);
      if (sportsScorePattern(text) && scoreLines.indexOf(text) === -1) scoreLines.push(text);
    });
    var tables = sportsTableMarkdown(root);
    var structuredScore = structured && (structured.homeScore || structured.awayScore);
    var typedSports = !!(sportsStructuredDataNodes().length || scoreLines.length > 0 || structuredScore);
    var strongScore = typedSports || tables.length > 0;
    var isSports = sportsContext(metadata);

    if (!isSports && !sportsStructuredDataNodes().length) return null;
    if (!strongScore && !/\b(sport|sports|football|soccer|nba|game recap|box score)\b/.test(sportsContextText(metadata))) return null;

    return {
      structured: structured,
      scoreLines: scoreLines,
      tables: tables,
      typed: typedSports,
      event: typedSports
    };
  }

  function sportsDetails(evidence) {
    var details = [];
    var event = evidence && evidence.structured;
    if (event) {
      if (event.awayName && event.homeName && (event.awayScore || event.homeScore)) {
        details.push("Score: " + event.awayName + " " + event.awayScore + ", " + event.homeName + " " + event.homeScore);
      } else if (event.title) {
        details.push("Event: " + event.title);
      }
      if (event.status) details.push("Status: " + event.status);
      if (event.startDate) details.push("Start: " + event.startDate);
    }
    (evidence.scoreLines || []).forEach(function(line) {
      var detail = /^score:/i.test(line) ? line : "Score: " + line;
      if (details.indexOf(detail) === -1) details.push(detail);
    });
    return details.slice(0, 8);
  }

  function sportsContentType(content, evidence) {
    if (evidence && evidence.event) return "sports_event";
    if (evidence && evidence.typed) return "sports";
    return (content && content.contentType) || "article";
  }

  function sportsMetadataContent(metadata) {
    var evidence = sportsContentEvidence(metadata);
    if (!evidence || !evidence.event) return null;

    var title = (evidence.structured && evidence.structured.title) || metadata.title || document.title;
    var details = sportsDetails(evidence);
    var sections = ["# " + title];
    if (details.length) sections.push(details.map(function(detail) { return "- " + detail; }).join("\n"));
    sections = sections.concat(evidence.tables || []);

    var markdown = cleanupMarkdownNoise(sections.filter(Boolean).join("\n\n"));
    if (normalizeText(markdown).length < 80) return null;

    return {
      title: title,
      byline: null,
      excerpt: details[0] || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "sports_event"
    };
  }

  function applySportsContent(content, metadata) {
    if (!content || content.contentType === "search" || content.contentType === "interstitial" || content.docsLike || content.legalProvision) return content;

    var evidence = sportsContentEvidence(metadata);
    if (!evidence) return content;

    var details = sportsDetails(evidence);
    var original = cleanupMarkdownNoise(content.markdown || content.textContent || "").trim();
    var normalizedOriginal = normalizeText(original);
    var sections = [];
    var title = content.title || metadata.title || document.title;

    if (title && !markdownStartsWithTitle(original, title)) sections.push("# " + title);
    if (details.length && details.some(function(detail) { return normalizedOriginal.indexOf(normalizeText(detail)) === -1; })) {
      sections.push(details.map(function(detail) { return "- " + detail; }).join("\n"));
    }
    sections.push(original);
    (evidence.tables || []).forEach(function(tableMarkdown) {
      if (normalizeText(sections.join("\n\n")).indexOf(normalizeText(tableMarkdown)) === -1) sections.push(tableMarkdown);
    });

    content.contentType = sportsContentType(content, evidence);
    content.markdown = cleanupMarkdownNoise(sections.filter(Boolean).join("\n\n"));
    content.textContent = normalizeText(content.markdown);
    if (details[0] && !content.excerpt) content.excerpt = details[0];
    return content;
  }

  function sportsTypedContent(content) {
    return content && (content.contentType === "sports" || content.contentType === "sports_event");
  }
