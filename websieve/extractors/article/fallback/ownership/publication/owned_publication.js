function readabilityOwnedSelectedPublication(article, metadata, bodyEvidence) {
  if (!article || !metadata || !bodyEvidence || !Array.isArray(bodyEvidence.sourceParagraphs)) return null;
  var pageUrl = sourceOwnershipPageUrl(metadata.canonicalUrl);
  if (!pageUrl || pageUrl !== sourceOwnershipPageUrl(materializedCanonicalUrl())) return null;

  var paragraphs = bodyEvidence.sourceParagraphs;
  var answerDate = sourceOwnedReaderAnswerPublicationTime(paragraphs, pageUrl, article.title || metadata.title);
  if (answerDate) return { publishedTime: answerDate };
  var owner = sourceOwnedMappedPublicationBodyOwner(paragraphs, metadata);
  if (!owner) return null;

  var headerContext = sourceOwnedArticleHeaderContext({
    heading: owner.heading, ownerRoot: owner.ownerRoot, body: { sourceNode: owner.root }
  });
  var visibleDates = headerContext && headerContext !== false ? sourceOwnedPublicationDateNodes(headerContext) : [];
  visibleDates = visibleDates.filter(function(node) {
    return !!(node.compareDocumentPosition(owner.firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING);
  });
  visibleDates = visibleDates.concat(sourceOwnedArticleBodyPublicationDates(
    owner.root, owner.ownerRoot, owner.heading, owner.firstParagraph
  ));
  var readerHeaderDate = sourceOwnedReaderHeaderPublicationTime(paragraphs, owner);
  if (readerHeaderDate) visibleDates.push(readerHeaderDate);
  var contributorDate = sourceOwnedReaderContributorPublicationTime(paragraphs, owner);
  if (contributorDate) visibleDates.push(contributorDate);
  return sourceOwnedSelectedPublicationTime(owner.headline, pageUrl, visibleDates) || { publishedTime: null };
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
  var answerDate = sourceOwnedReaderAnswerPublicationTime(paragraphs, pageUrl, headline);
  if (answerDate) return { publishedTime: answerDate };
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
  visibleDates = visibleDates.concat(sourceOwnedArticleBodyPublicationDates(
    bodyOwner, articleOwnerRoot, headings[0], firstParagraph
  ));
  var readerHeaderDate = sourceOwnedReaderHeaderPublicationTime(paragraphs, {
    heading: headings[0], ownerRoot: articleOwnerRoot
  });
  if (readerHeaderDate) visibleDates.push(readerHeaderDate);
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
  var records = scanned.records.filter(function(record) { return entityText(record.headline) === headline; });
  if (records.length > 1) return { records: null };
  if (!records.length) {
    return scanned.ambiguous ? { records: null, optionalDataInvalid: true } : { records: [] };
  }

  var urls = sourceOwnedPublicationRecordUrls(records[0]);
  if (urls.present && !urls.values.includes(pageUrl)) return { records: null };
  return { records: records };
}

function sourceOwnedArticlePublicationRecord(record) {
  var types = nodeTypes(record);
  return types.some(function(type) {
    return /^(?:Article|NewsArticle|BlogPosting|ReportageNewsArticle|AnalysisNewsArticle|OpinionNewsArticle)$/i.test(type);
  });
}

function sourceOwnedPublicationRecordUrls(record) {
  var directUrl = normalizeText(record && record.url);
  if (directUrl) {
    var normalizedDirectUrl = sourceOwnershipPageUrl(directUrl);
    return { values: normalizedDirectUrl ? [normalizedDirectUrl] : [], present: true };
  }

  var mainEntity = record && record.mainEntityOfPage;
  var mainEntityUrl = mainEntity && typeof mainEntity === "object" ? mainEntity.url || mainEntity["@id"] : mainEntity;
  var normalizedMainEntityUrl = sourceOwnershipPageUrl(mainEntityUrl);
  return { values: normalizedMainEntityUrl ? [normalizedMainEntityUrl] : [], present: !!normalizeText(mainEntityUrl) };
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
  var publicationRecords = sourceOwnedPublicationRecords(headline, pageUrl);
  var records = publicationRecords.records;
  var paired = sourceOwnedPairedPublicationTime(visibleDateNodes, records);
  if (paired) return paired;
  var visibleValues = visibleDateNodes.map(function(node) {
    return typeof node === "string" ? normalizeText(node) : sourceOwnedPublicationNodeDate(node);
  }).filter(Boolean);
  var visible = sourceOwnedUniquePublicationValue(visibleValues);
  var head = sourceOwnedHeadPublicationTime();
  if (visible.ambiguous) return null;
  if (visible.value) {
    // A publisher's concatenated display label is not a timestamp. A precise,
    // unambiguous publication meta value still belongs to this proven owner.
    if ((!Number.isFinite(Date.parse(visible.value)) ||
        /^(?:published|posted)\s+on(?=[A-Z])/i.test(visible.value)) && head.value && !head.ambiguous &&
        sourceOwnedDisplayAgreesWithPreciseDate(visible.value, head.value)) {
      if (records && records.length && records[0].datePublished &&
          !sourceOwnedPublicationDatesEquivalent(head.value, entityText(records[0].datePublished))) {
        return { publishedTime: null };
      }
      return { publishedTime: head.value };
    }
    return { publishedTime: visible.value };
  }
  if (publicationRecords.optionalDataInvalid) {
    return { publishedTime: head.value || null };
  }
  if (!records) return { publishedTime: head.value || null };

  var recordDate = records.length ? entityText(records[0].datePublished) : "";
  if (head.ambiguous) return null;
  if (head.value && recordDate && !sourceOwnedPublicationDatesEquivalent(head.value, recordDate)) {
    return { publishedTime: head.value };
  }

  return { publishedTime: head.value || recordDate || null };
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
  if (leftZoned !== rightZoned) {
    var leftWallClock = sourceOwnedPublicationWallClock(left);
    var rightWallClock = sourceOwnedPublicationWallClock(right);
    return !!leftWallClock && !!rightWallClock && leftWallClock === rightWallClock;
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(left) || /^\d{4}-\d{2}-\d{2}$/.test(right)) {
    return new Date(leftDate).toISOString().slice(0, 10) === new Date(rightDate).toISOString().slice(0, 10);
  }
  return leftDate === rightDate;
}

function sourceOwnedPublicationWallClock(value) {
  var match = normalizeText(value).match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?)/);
  return match ? match[1] + "T" + match[2] : "";
}

function sourceOwnedComparableHeadline(value) {
  return normalizeText(value).replace(/["“”„‟'‘’‚‛]/g, "");
}

function sourceOwnedFallbackProseParagraph(paragraph) {
  return !elementVisuallyHidden(paragraph) && !paragraph.closest("header, [itemprop~='author' i], [itemprop~='creator' i], [class*='byline' i], [class*='author' i], [class*='credit' i]") &&
    !paragraph.closest("nav, aside, footer, form, menu, [role~='navigation' i], [role~='menu' i], [role~='complementary' i]");
}
