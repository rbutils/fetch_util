function readabilityCaptionCreditCandidate(value) {
  var text = normalizeText(value || "");
  return readabilityExcerptLength(text) >= 60 && readabilityExcerptLength(text) <= 180 &&
    /\b(?:19|20)\d{2}\b/.test(text) &&
    /(?:\b(?:photo|foto|image|credit|courtesy|reuters|afp)\s*[:/]|©|(?:^|[\s.])[A-Z][a-z]{2,}\/[A-Z][A-Za-z]*)/i.test(text);
}

function readabilityCaptionCreditExcerpt(template, marker, excerpt) {
  var first = template.content.querySelector("p");
  if (!first || first.getAttribute("data-fetchutil-excerpt-body") !== marker ||
      normalizeText(first.textContent || "") !== excerpt) return null;
  var owner = first.closest("article");
  if (!owner) return null;
  var paragraphs = Array.from(owner.querySelectorAll("p[data-fetchutil-excerpt-body]")).filter(function(node) {
    return node.getAttribute("data-fetchutil-excerpt-body") === marker;
  });
  if (paragraphs[0] !== first) return null;
  var body = paragraphs.slice(1).filter(function(node) {
    return readabilityExcerptLength(node.textContent || "") >= 100;
  });
  return body.length >= 3 ? readabilityExcerptPrefix(body[0].textContent || "") : null;
}
