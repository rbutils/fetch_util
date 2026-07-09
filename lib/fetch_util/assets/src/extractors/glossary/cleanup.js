  function cleanGlossaryExcerpt(text) {
    return normalizeText(text || "")
      .replace(/\s*see (?:the )?full definition\b.*$/i, "")
      .replace(/\s*opens in new tab\.?$/i, "")
      .replace(/\s*[|:-]\s*(?:merriam-webster|definitions?\.net|dictionary(?:\.com)?|diki)\b.*$/i, "")
      .trim();
  }

  function glossaryDefinitionKey(text) {
    return normalizeText(text || "")
      .toLowerCase()
      .replace(/^[\s#>*-]*(?:\d+[.)]|[a-z][.)]|[ivx]+[.)])\s*/i, "")
      .replace(/^definition\s*[:.-]\s*/i, "")
      .replace(/^[^:]{1,40}:\s+/, "")
      .replace(/\b(?:source|references?|citation|cite this entry)\b.*$/i, "")
      .replace(/[^a-z0-9]+/g, " ")
      .trim()
      .slice(0, 240);
  }

  function glossaryNeedsMetadataFallback(text, metadata) {
    var excerpt = cleanGlossaryExcerpt((metadata && metadata.excerpt) || "").toLowerCase();
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return true;
    if (glossaryUtilityHeavy(normalized)) return true;
    if (!excerpt || excerpt.length < 18) return false;

    return normalized.indexOf(excerpt) === -1 && normalized.length < Math.max(260, excerpt.length * 3);
  }

  function glossaryNoiseNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var heading = normalizeText((node.querySelector("h2, h3, h4, strong") || {}).textContent || "");
    var text = normalizeText(node.textContent || "");
    var attrs = normalizeText([(node.id || ""), (node.className || "")].join(" ")).toLowerCase();

    if (audioFallbackText(text)) return true;
    if (utilityHeadingText(heading)) return true;
    if (/^(love words\? need even more definitions|top lookups|add to chrome|add to firefox)$/i.test(text)) return true;
    if (/^discuss these .+ definitions with the community/i.test(text)) return true;
    if (/subscribe for ad-free|word of the day|browse definitions\.net|popular in grammar|popular in wordplay/i.test(text)) return true;
    if (/(cookie|privacy|consent)/.test(attrs) && text.length < 2400) return true;

    return false;
  }

  function pruneDuplicateGlossaryDefinitions(root) {
    var seen = {};

    root.querySelectorAll("p.desc, dd, .dtText, .sense, .def, .definition, [class*='definition'], [class*='meaning'], [itemprop='description']").forEach(function(node) {
      var text = normalizeText(node.textContent || "");
      var key = glossaryDefinitionKey(text);
      if (!key || key.length < 16) return;
      if (seen[key]) {
        node.remove();
        return;
      }
      seen[key] = true;
    });
  }
