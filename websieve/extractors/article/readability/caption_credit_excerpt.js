function readabilityCaptionCreditCandidate(value) {
  var text = normalizeText(value || "");
  var length = readabilityExcerptLength(text);
  if (length < 60 || length > 180) return false;
  var existingYearCaption = /\b(?:19|20)\d{2}\b/.test(text) &&
    /(?:\b(?:photo|foto|image|credit|courtesy|reuters|afp)\s*[:/]|©|(?:^|[\s.])[A-Z][a-z]{2,}\/[A-Z][A-Za-z]*)/i.test(text);
  if (existingYearCaption) return true;

  var namedPhotoCredit = text.match(
    /^([\p{Lu}][\p{L}.'’\-]+(?:\s+[\p{Lu}][\p{L}.'’\-]+){1,3}),\s+([^()]+?)\s+\((?:photo|foto)\s*:\s*([^)]+)\)$/iu
  );
  if (!namedPhotoCredit || /\p{Sentence_Terminal}/u.test(namedPhotoCredit[2])) return false;
  return /[\p{Ll}]/u.test(namedPhotoCredit[2]) &&
    /^[\p{Lu}][\p{L}.'’ -]*(?:\/\s*[\p{Lu}][\p{L}.'’ -]*)+$/u.test(namedPhotoCredit[3]);
}

function readabilityCaptionCreditHeaderEvidence(first, excerpt, readerBodyEvidence) {
  if (!readerBodyEvidence || !Array.isArray(readerBodyEvidence.unmappedHeaderParagraphs) ||
      !Array.isArray(readerBodyEvidence.sourceParagraphs)) return false;
  var headers = readerBodyEvidence.unmappedHeaderParagraphs.filter(function(header) {
    return header.text === excerpt && header.source && header.source.localName === "p" &&
      !elementVisuallyHidden(header.source);
  });
  var mappedSources = readerBodyEvidence.sourceParagraphs.filter(function(source) {
    return source && source.localName === "p" && normalizeText(source.textContent || "") === excerpt;
  });
  if (headers.length + mappedSources.length !== 1) return false;
  var headerSource = headers.length ? headers[0].source : mappedSources[0];
  var sourceArticle = headerSource.closest("article");
  if (!sourceArticle || !first.closest("article")) return false;
  var sources = readerBodyEvidence.sourceParagraphs.filter(function(source) {
    return source && source.localName === "p" && source.closest("article") === sourceArticle;
  });
  if (sources.length < 3 || !sources.every(function(source) { return !elementVisuallyHidden(source); })) return false;
  if (mappedSources.length) {
    if (sources[0] !== headerSource) return false;
  } else if (!(headerSource.compareDocumentPosition(sources[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) {
    return false;
  }
  return { sourceArticle: sourceArticle, sourceParagraphs: sources };
}

function readabilityCaptionCreditBodySourceEvidence(paragraphs, sourceParagraphs) {
  var sourceByText = new Map();
  sourceParagraphs.forEach(function(source, index) {
    if (!source || source.localName !== "p") return;
    var text = normalizeText(source.textContent || "");
    var entry = sourceByText.get(text);
    if (entry) {
      entry.count += 1;
    } else {
      sourceByText.set(text, { count: 1, index: index });
    }
  });
  var previousIndex = -1;
  return paragraphs.every(function(node) {
    var entry = sourceByText.get(normalizeText(node.textContent || ""));
    if (!entry || entry.count !== 1 || entry.index <= previousIndex) return false;
    previousIndex = entry.index;
    return true;
  });
}

function readabilityCaptionCreditExcerpt(template, marker, excerpt, readerBodyEvidence) {
  var first = Array.from(template.content.querySelectorAll("p")).find(function(node) {
    return node.getAttribute("data-fetchutil-excerpt-body") === marker;
  });
  if (!first || first.getAttribute("data-fetchutil-excerpt-body") !== marker ||
      normalizeText(first.textContent || "") !== excerpt) return null;
  var owner = first.closest("article");
  if (!owner) return null;
  var paragraphs = Array.from(owner.querySelectorAll("p[data-fetchutil-excerpt-body]")).filter(function(node) {
    return node.getAttribute("data-fetchutil-excerpt-body") === marker && node.closest("article") === owner;
  });
  if (paragraphs[0] !== first) return null;
  var yearlessEvidence = null;
  if (!/\b(?:19|20)\d{2}\b/.test(excerpt)) {
    yearlessEvidence = readabilityCaptionCreditHeaderEvidence(first, excerpt, readerBodyEvidence);
    if (!yearlessEvidence) return null;
  }
  var body = paragraphs.slice(1).filter(function(node) {
    return readabilityExcerptNode(node) && normalizeText(node.textContent || "");
  });
  if (body.length < 3) return null;
  if (yearlessEvidence && !readabilityCaptionCreditBodySourceEvidence(body, yearlessEvidence.sourceParagraphs)) return null;
  return normalizeText(body[0].textContent || "");
}
