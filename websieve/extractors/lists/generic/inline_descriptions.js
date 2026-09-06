  function listInlineDescriptionNode(node) {
    if (!paragraphLikeDiv(node) || node.closest("a, button, label, summary, p, table, ul, ol, pre, code, blockquote") ||
        node.querySelector("button, input, select, textarea, label, video, audio, canvas, object, iframe")) return false;

    var hiddenSelector = "[aria-hidden='true' i], [inert]";
    if (node.closest(hiddenSelector) || Array.prototype.some.call(node.querySelectorAll(hiddenSelector), function(hidden) {
      return !!normalizeText(hidden.textContent);
    })) return false;
    if (node.closest(COMMON_CHROME_SELECTOR + ", header, dialog, [role='dialog'], [aria-modal='true'], [role='navigation'], [role='menu'], [role='toolbar']")) return false;
    if (AD_LABEL_TEXT_PATTERN.test(normalizeText(node.textContent))) return false;

    var withoutMetadata = node.cloneNode(true);
    var metadata = withoutMetadata.querySelectorAll("time, [datetime], [rel='author'], [itemprop='author'], [class*='author' i], [class*='score' i], [class*='reply' i], [class*='replies' i], [class*='community' i]");
    if (metadata.length) {
      metadata.forEach(function(field) { field.remove(); });
      if (!/\p{L}/u.test(normalizeText(withoutMetadata.textContent))) return false;
    }

    for (var owner = node; owner; owner = owner.parentElement) {
      var identity = [owner.id, owner.getAttribute("class")].join(" ").replace(/([a-z])([A-Z])/g, "$1-$2");
      if (/(cookie|consent|privacy)[-_\s]*(modal|dialog|banner|notice|popup|container)/i.test(identity)) return false;
    }

    // Inline link collections are records, not a paragraph describing those records.
    if (node.querySelector("a[href]")) {
      var prose = node.cloneNode(true);
      prose.querySelectorAll("a").forEach(function(link) { link.remove(); });
      prose.querySelectorAll("time, [datetime]").forEach(function(time) { time.remove(); });
      var remainder = normalizeText(prose.textContent)
        .replace(/\b\d+(?:\.\d+)?\s*(?:seconds?|minutes?|hours?|days?|weeks?|months?|years?)\s+ago\b/gi, "")
        .replace(/\b\d+(?:\.\d+)?[kmb](?=\s|$)/gi, "");
      if (!/\p{L}/u.test(remainder)) return false;
    }
    return true;
  }

  function listMarkdownWithInlineDescriptions(extraction) {
    var descriptions = listDescriptionParts(extraction.root, extraction.items, { includeInlineProse: true });
    if (!descriptions.some(function(part) { return part.node.tagName === "DIV"; })) return "";

    var links = Array.prototype.slice.call(extraction.root.querySelectorAll("a[href]"));
    var cards = extraction.items.map(function(item) {
      if (item.sourceNode) return item;
      var key = item.url && listCanonicalKey(item.url);
      var link = key && links.find(function(candidate) {
        if (item.card && !item.card.contains(candidate)) return false;
        var url = materializedHttpUrl(candidate.getAttribute("href"));
        return url && listCanonicalKey(url) === key;
      });
      return Object.assign({}, item, { sourceNode: link || item.card || extraction.root });
    });
    return sectionedListMarkdownWithDescriptions({ regions: [{ node: extraction.root, cards: cards }] }, descriptions);
  }
