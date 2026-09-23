  function readabilityCompactBodyExcerpt(template, marker, excerpt) {
    var paragraphs = Array.prototype.filter.call(template.content.querySelectorAll("p[data-fetchutil-excerpt-body]"), function(node) {
      return node.getAttribute("data-fetchutil-excerpt-body") === marker;
    });
    if (paragraphs.length < 2) return null;

    var first = paragraphs[0];
    var owner = first.parentElement;
    if (!owner || paragraphs.some(function(node) { return !owner.contains(node); })) return null;
    var signal = ((owner.id || "") + " " + (owner.className || ""))
      .replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ").toLowerCase();
    if (!/\b(?:article|entry|post|story) body\b/.test(signal)) return null;

    var firstText = normalizeText(first.textContent || "");
    if (normalizeText(excerpt || "") !== firstText &&
        !/^(?:テーマ|(?:theme|category|topic)\s*)[:：]/i.test(normalizeText(excerpt || ""))) return null;
    if (readabilityExcerptLength(firstText) < 25 ||
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
