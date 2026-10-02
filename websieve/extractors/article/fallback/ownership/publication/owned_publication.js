function readabilityOwnedSelectedPublication(article, metadata, bodyEvidence) {
  if (!article || !metadata || !bodyEvidence || !Array.isArray(bodyEvidence.sourceParagraphs)) return null;
  var pageUrl = sourceOwnershipPageUrl(metadata.canonicalUrl);
  if (!pageUrl || pageUrl !== sourceOwnershipPageUrl(materializedCanonicalUrl())) return null;

  var paragraphs = bodyEvidence.sourceParagraphs;
  var owner = sourceOwnedMappedPublicationBodyOwner(paragraphs, metadata);
  if (!owner) return null;

  var headerContext = sourceOwnedArticleHeaderContext({
    heading: owner.heading, ownerRoot: owner.ownerRoot, body: { sourceNode: owner.root }
  });
  var visibleDates = headerContext && headerContext !== false ? sourceOwnedPublicationDateNodes(headerContext) : [];
  visibleDates = visibleDates.filter(function(node) {
    return !!(node.compareDocumentPosition(owner.firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING);
  });
  return sourceOwnedSelectedPublicationTime(owner.headline, pageUrl, visibleDates) || { publishedTime: null };
}

function sourceOwnedMappedPublicationBodyOwner(paragraphs, metadata) {
  if (!Array.isArray(paragraphs) || paragraphs.length < 2 || !metadata) return null;
  if (paragraphs.some(function(paragraph, index) {
    return !paragraph || paragraph.localName !== "p" || elementVisuallyHidden(paragraph) ||
      (index > 0 && !(paragraphs[index - 1].compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING));
  })) return null;

  var pageUrl = sourceOwnershipPageUrl(metadata.canonicalUrl);
  var pageTitle = sourceOwnedComparableHeadline(metadata.title || "");
  if (!pageUrl || pageUrl !== sourceOwnershipPageUrl(materializedCanonicalUrl()) || !pageTitle) return null;
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    if (elementVisuallyHidden(heading)) return false;
    var title = sourceOwnedComparableHeadline(heading.textContent || "");
    return title === pageTitle || (pageTitle.indexOf(title) === 0 &&
      /^\s*(?:-|–|—|:|：|\/|\|)\s*\S/.test(pageTitle.slice(title.length)));
  });
  if (headings.length !== 1) return null;

  var headline = normalizeText(headings[0].textContent || "");
  var comparableHeadline = sourceOwnedComparableHeadline(headline);
  var bodyCandidates = sourceArticleBodyCandidates().filter(function(candidate) {
    return paragraphs.every(function(paragraph) { return candidate.contains(paragraph); }) &&
      !elementSubtreeHidden(candidate) && !sourceOwnershipArticleChrome(candidate, candidate);
  });
  var innermost = bodyCandidates.filter(function(candidate) {
    return !bodyCandidates.some(function(other) { return other !== candidate && candidate.contains(other); });
  });
  if (innermost.length !== 1) return null;

  var root = innermost[0];
  if (Array.from(root.querySelectorAll("h1")).some(function(heading) {
    return !elementVisuallyHidden(heading) &&
      sourceOwnedComparableHeadline(heading.textContent || "") !== comparableHeadline;
  })) return null;
  var ownerRoot = sourceOwnershipCommonAncestor(headings[0], root);
  if (!ownerRoot || ownerRoot === document.body || ownerRoot === document.documentElement) return null;
  return { root: root, ownerRoot: ownerRoot, heading: headings[0], body: root, firstParagraph: paragraphs[0], headline: headline };
}

function sourceOwnedFallbackPublication(metadata, sourceRoot, selected) {
  if (!metadata || !sourceRoot || !selected || selected.node !== sourceRoot || !selected.visibleNode) return null;
  var pageUrl = sourceOwnershipPageUrl(metadata.canonicalUrl);
  if (!pageUrl || pageUrl !== sourceOwnershipPageUrl(materializedCanonicalUrl()) ||
      sourceRoot === document.body || sourceRoot === document.documentElement || !document.body.contains(sourceRoot)) return null;

  var headings = Array.from(sourceRoot.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (!headings.length) return null;
  var headline = normalizeText(headings[0].textContent || "");
  if (!headline || headings.some(function(heading) { return normalizeText(heading.textContent || "") !== headline; })) return null;
  var pageTitle = sourceOwnedComparableHeadline(metadata.title || "");
  var comparableHeadline = sourceOwnedComparableHeadline(headline);
  if (pageTitle.indexOf(comparableHeadline) !== 0 || (pageTitle.length > comparableHeadline.length &&
      !/^\s*(?:-|–|—|:|：|\/|\|)\s*\S/.test(pageTitle.slice(comparableHeadline.length)))) return null;

  var paragraphs = Array.from(sourceRoot.querySelectorAll("p")).filter(function(paragraph) {
    return sourceOwnedFallbackProseParagraph(paragraph) &&
      (!paragraph.closest("article") || paragraph.closest("article") === sourceRoot);
  });
  if (paragraphs.length < 2 || paragraphs.some(function(paragraph, index) {
    return index > 0 && !(paragraphs[index - 1].compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
  })) return null;
  var body = paragraphs.reduce(function(root, paragraph) {
    return root ? sourceOwnershipCommonAncestor(root, paragraph) : paragraph;
  }, null);
  if (!body || body === sourceRoot && sourceRoot.matches("main")) return null;

  var bodyCandidates = sourceArticleBodyCandidates().filter(function(candidate) {
    return sourceRoot.contains(candidate) && candidate !== sourceRoot && candidate.contains(body) &&
      paragraphs.every(function(paragraph) { return candidate.contains(paragraph); }) &&
      !elementSubtreeHidden(candidate) && !sourceOwnershipArticleChrome(candidate, candidate);
  });
  var innermostBodies = bodyCandidates.filter(function(candidate) {
    return !bodyCandidates.some(function(other) { return candidate !== other && candidate.contains(other); });
  });
  var bodyOwner = innermostBodies.length === 1 ? innermostBodies[0] : body;
  if (!sourceRoot.contains(bodyOwner) || bodyOwner === document.body || bodyOwner === document.documentElement) return null;
  if (sourceArticleBodyHasForeignLinkedArticle(sourceRoot, bodyOwner, headings[0], pageUrl)) return null;

  var articleOwnerRoot = bodyOwner.contains(headings[0]) ? bodyOwner : sourceRoot;
  var headerContext = sourceOwnedArticleHeaderContext({
    heading: headings[0], ownerRoot: articleOwnerRoot, body: { sourceNode: bodyOwner }
  });
  var firstParagraph = paragraphs[0];
  var visibleDates = headerContext && headerContext !== false ? sourceOwnedPublicationDateNodes(headerContext) : [];
  var publication = sourceOwnedSelectedPublicationTime(headline, pageUrl, visibleDates);
  return publication || { publishedTime: null };
}

function sourceOwnedPublicationDateNodes(headerNodes) {
  return sourceOwnedArticleHeaderDateNodes(headerNodes).filter(function(node) {
    return !node.closest(
      "[class*='schedule' i], [id*='schedule' i], [class*='calendar' i], [id*='calendar' i], " +
      "[class*='event' i], [id*='event' i], [itemprop~='event' i], [itemtype$='Event' i], [data-type='event' i]"
    );
  });
}

function sourceOwnedPublicationRecords(headline, pageUrl) {
  var scanned = sourceOwnedParsedPublicationRecords(headline);
  if (scanned.ambiguous) return null;
  var records = scanned.records;
  if (records.length > 1) return null;
  if (!records.length || entityText(records[0].headline) !== headline) return [];

  var urls = sourceOwnedPublicationRecordUrls(records[0]);
  if (urls.invalid || urls.values.some(function(url) { return url !== pageUrl; })) return null;
  return records;
}

function sourceOwnedArticlePublicationRecord(record) {
  var types = nodeTypes(record);
  return types.some(function(type) {
    return /^(?:Article|NewsArticle|BlogPosting|ReportageNewsArticle|AnalysisNewsArticle|OpinionNewsArticle)$/i.test(type);
  });
}

function sourceOwnedPublicationRecordUrls(record) {
  var mainEntity = record && record.mainEntityOfPage;
  var values = [record && record.url];
  if (mainEntity && typeof mainEntity === "object") {
    values.push(mainEntity.url, mainEntity["@id"]);
  } else {
    values.push(mainEntity);
  }
  values = values.filter(function(value) { return !!normalizeText(value); });
  var urls = values.map(sourceOwnershipPageUrl);
  return { values: urls.filter(Boolean), invalid: urls.some(function(url) { return !url; }) };
}

function sourceOwnedParsedPublicationRecords(headline) {
  var scripts = Array.from(document.querySelectorAll('script[type="application/ld+json"]'));
  var records = [];
  var ambiguous = false;
  scripts.forEach(function(script) {
    var source = script.textContent || script.innerText || "";
    var parsed;
    try {
      parsed = JSON.parse(source);
    } catch (_error) {
      var repaired = sourceOwnedRepairHeadlineJson(source, headline);
      if (!repaired.matched) {
        if (normalizeText(source)) ambiguous = true;
        return;
      }
      if (!repaired.parsed) {
        ambiguous = true;
        return;
      }
      parsed = repaired.value;
    }
    sourceOwnedCollectArticlePublicationRecords(parsed, records);
  });
  return { records: records, ambiguous: ambiguous };
}

function sourceOwnedCollectArticlePublicationRecords(value, records) {
  if (!value || typeof value !== "object") return;
  if (Array.isArray(value)) {
    value.forEach(function(item) { sourceOwnedCollectArticlePublicationRecords(item, records); });
    return;
  }
  if (sourceOwnedArticlePublicationRecord(value)) records.push(value);
  Object.keys(value).forEach(function(key) {
    sourceOwnedCollectArticlePublicationRecords(value[key], records);
  });
}

function sourceOwnedRepairHeadlineJson(source, headline) {
  var key = '"headline"';
  var keyIndex = source.indexOf(key);
  if (keyIndex < 0 || source.indexOf(key, keyIndex + key.length) >= 0) return { matched: false };

  var cursor = keyIndex + key.length;
  while (/\s/.test(source.charAt(cursor))) cursor += 1;
  if (source.charAt(cursor) !== ":") return { matched: false };
  cursor += 1;
  while (/\s/.test(source.charAt(cursor))) cursor += 1;
  if (source.charAt(cursor) !== '"') return { matched: false };

  var valueStart = cursor + 1;
  var valueEnd = valueStart + headline.length;
  if (source.slice(valueStart, valueEnd) !== headline || source.charAt(valueEnd) !== '"' ||
      !/^\s*[,}]/.test(source.slice(valueEnd + 1))) return { matched: false };

  var corrected = source.slice(0, cursor) + JSON.stringify(headline) + source.slice(valueEnd + 1);
  var parsed;
  try {
    parsed = JSON.parse(corrected);
  } catch (_error) {
    return { matched: true, parsed: false, records: [] };
  }

  var records = [];
  sourceOwnedCollectArticlePublicationRecords(parsed, records);
  if (records.length !== 1 || entityText(records[0].headline) !== headline) {
    return { matched: true, parsed: false, records: [] };
  }
  return { matched: true, parsed: true, records: records, value: parsed };
}

function sourceOwnedSelectedPublicationTime(headline, pageUrl, visibleDateNodes) {
  var records = sourceOwnedPublicationRecords(headline, pageUrl);
  if (!records) return null;
  var visibleValues = visibleDateNodes.map(sourceOwnedPublicationNodeDate).filter(Boolean);
  var visible = sourceOwnedUniquePublicationValue(visibleValues);
  var head = sourceOwnedHeadPublicationTime();
  if (visible.ambiguous || head.ambiguous) return null;

  var recordDate = records.length ? entityText(records[0].datePublished) : "";
  var values = [visible.value, recordDate, head.value].filter(Boolean);
  if (values.some(function(value, index) {
    return values.slice(index + 1).some(function(other) {
      return !sourceOwnedPublicationDatesEquivalent(value, other);
    });
  })) return null;

  return { publishedTime: visible.value || recordDate || head.value || null };
}

function sourceOwnedPublicationNodeDate(node) {
  return normalizeText(node.getAttribute("datetime") || node.getAttribute("content") || node.textContent || "");
}

function sourceOwnedHeadPublicationTime() {
  if (!document.head) return { value: "", ambiguous: false };
  var nodes = Array.from(document.head.querySelectorAll(
    'meta[property="article:published_time" i], meta[property="og:article:published_time" i], ' +
    'meta[name="datePublished" i], meta[itemprop~="datePublished" i]'
  ));
  var result = sourceOwnedUniquePublicationValue(nodes.map(sourceOwnedPublicationNodeDate).filter(Boolean));
  return { value: result.value, ambiguous: result.ambiguous };
}

function sourceOwnedUniquePublicationValue(values) {
  if (!values.length) return { value: "", ambiguous: false };
  return values.every(function(value) {
    return sourceOwnedPublicationDatesEquivalent(values[0], value);
  }) ? { value: values[0], ambiguous: false } : { value: "", ambiguous: true };
}

function sourceOwnedPublicationDatesEquivalent(left, right) {
  left = normalizeText(left);
  right = normalizeText(right);
  if (left === right) return true;

  var leftZoned = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(left);
  var rightZoned = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(right);
  if (leftZoned && rightZoned) return Date.parse(left) === Date.parse(right);

  var leftDate = Date.parse(left);
  var rightDate = Date.parse(right);
  if (!Number.isFinite(leftDate) || !Number.isFinite(rightDate)) return false;
  if (/^\d{4}-\d{2}-\d{2}$/.test(left) || /^\d{4}-\d{2}-\d{2}$/.test(right)) {
    return new Date(leftDate).toISOString().slice(0, 10) === new Date(rightDate).toISOString().slice(0, 10);
  }
  if (leftZoned !== rightZoned) return false;
  return leftDate === rightDate;
}

function sourceOwnedComparableHeadline(value) {
  return normalizeText(value).replace(/["“”„‟'‘’‚‛]/g, "");
}

function sourceOwnedFallbackProseParagraph(paragraph) {
  return !elementVisuallyHidden(paragraph) && !paragraph.closest("header, [itemprop~='author' i], [itemprop~='creator' i], [class*='byline' i], [class*='author' i], [class*='credit' i]") &&
    !paragraph.closest("nav, aside, footer, form, menu, [role~='navigation' i], [role~='menu' i], [role~='complementary' i]");
}
