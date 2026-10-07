  function readabilityCompactBodyOwner(owner) {
    var signal = owner && ((owner.id || "") + " " + (owner.className || ""))
      .replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ").toLowerCase();
    return !!signal && /\b(?:article|entry|post|story) body\b/.test(signal);
  }

  function readabilityCompactBodyExcerpt(template, marker, excerpt, bodyEvidence) {
    var paragraphs = Array.prototype.filter.call(template.content.querySelectorAll("p[data-fetchutil-excerpt-body]"), function(node) {
      return node.getAttribute("data-fetchutil-excerpt-body") === marker;
    });
    var sourceOwnedBody = false;
    if (paragraphs.length < 2 || !readabilityCompactBodyOwner(paragraphs[0].parentElement)) {
      var sources = bodyEvidence && bodyEvidence.sourceParagraphs;
      var selected = Array.from(template.content.querySelectorAll("p"));
      if (!Array.isArray(sources) || sources.length < 2 || sources.length !== selected.length ||
          (bodyEvidence.unmappedHeaderParagraphs || []).length ||
          (bodyEvidence.unmappedTrailingParagraphs || []).length) return null;
      var sourceOwner = sources[0] && sources[0].parentElement;
      if (!readabilityCompactBodyOwner(sourceOwner) || sourceOwner.ownerDocument !== document ||
          !sourceOwner.isConnected || elementVisuallyHidden(sourceOwner)) return null;
      if (!sources.every(function(source, index) {
        return source && source.parentElement === sourceOwner && !elementVisuallyHidden(source) &&
          normalizeText(source.textContent || "") === normalizeText(selected[index].textContent || "");
      })) return null;
      paragraphs = selected;
      sourceOwnedBody = true;
    }
    var first = paragraphs[0];
    var owner = first.parentElement;
    if (!owner || paragraphs.some(function(node) { return !owner.contains(node); })) return null;

    var firstText = normalizeText(first.textContent || "");
    if (normalizeText(excerpt || "") !== firstText &&
        !/^(?:テーマ|(?:theme|category|topic)\s*)[:：]/i.test(normalizeText(excerpt || ""))) return null;
    if ((readabilityExcerptLength(firstText) < 25 && !sourceOwnedBody) ||
        !/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(firstText)) return null;
    var lead = "";
    for (var index = 0; index < paragraphs.length; index += 1) {
      var part = normalizeText(paragraphs[index].textContent || "");
      if (!part) continue;
      var expanded = lead ? lead + " " + part : part;
      // Bound only the excerpt field; the article body retains every paragraph.
      if (readabilityExcerptLength(expanded) > 280) break;
      lead = expanded;
    }
    return readabilityExcerptLength(lead) >= 80 ? lead : null;
  }
