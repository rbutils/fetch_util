function readerSourceOwnedRestoreConflictingCredits(article, metadata, sourceClones, sourceIdentities, marker, readerBodyEvidence, sourceBylines) {
  var paragraphs = readerBodyEvidence && readerBodyEvidence.sourceParagraphs;
  if (!article || !Array.isArray(paragraphs) || paragraphs.length < 2 ||
      !Array.isArray(readerBodyEvidence.unmappedHeaderParagraphs) || !Array.isArray(readerBodyEvidence.unmappedTrailingParagraphs) ||
      readerBodyEvidence.unmappedHeaderParagraphs.length || readerBodyEvidence.unmappedTrailingParagraphs.length ||
      !(sourceBylines instanceof Set) || !sourceBylines.size) return article && article.content;

  var headlines = [];
  sourceClones.forEach(function(clone, source) {
    if (source.localName === "h1" && clone.getAttribute("data-fetchutil-reader-source-headline") === marker) headlines.push(source);
  });
  if (headlines.length !== 1) return article.content;
  var headline = headlines[0];
  var visibleHeadlines = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return !elementVisuallyHidden(node) && !node.closest("nav, footer, aside, form, [role='navigation'], [role='complementary']");
  });
  if (visibleHeadlines.length !== 1 || visibleHeadlines[0] !== headline ||
      !sourceOwnedReaderHeadlineTitleMatches(headline.textContent, article, metadata)) return article.content;

  var paragraphSet = new Set();
  for (var index = 0; index < paragraphs.length; index += 1) {
    var paragraph = paragraphs[index];
    if (!paragraph || paragraph.localName !== "p" || elementSubtreeHidden(paragraph) || paragraphSet.has(paragraph)) return article.content;
    paragraphSet.add(paragraph);
  }
  var owner = sourceOwnedReaderHeadlineBodyOwner(headline, paragraphs);
  if (!owner || !owner.contains(headline) || paragraphs.some(function(paragraph) { return !owner.contains(paragraph); })) return article.content;

  var orderedBylines = [];
  var bylineSet = new Set();
  var sourceBylineCandidates = Array.from(sourceBylines).filter(function(node) {
    return !node.closest("figure, figcaption, caption, blockquote, q, li, td, th, pre, code");
  });
  var articleRecord = paragraphs[0].closest("article");
  var retainedHeaderBylines = new Set();
  sourceBylineCandidates.forEach(function(sourceByline) {
    var readableClone = sourceClones.get(sourceByline);
    var markerText = normalizeText(sourceByline && sourceByline.textContent || "");
    if (paragraphSet.has(sourceByline) && sourceByline.localName === "p" && readableClone &&
        readableClone.getAttribute("data-fetchutil-reader-source-paragraph") && !elementSubtreeHidden(sourceByline) &&
        owner.contains(sourceByline) && !sourceOwnershipInChrome(sourceByline) &&
        !sourceByline.querySelector("p, article, main, section, figure, table, blockquote, pre, form") &&
        markerText && markerText === normalizeText(readableClone.textContent || "") &&
        (headline.compareDocumentPosition(sourceByline) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        sourceByline.closest("article") === articleRecord) retainedHeaderBylines.add(sourceByline);
  });
  var firstBodyParagraph = paragraphs.find(function(paragraph) { return !retainedHeaderBylines.has(paragraph); });
  if (!firstBodyParagraph) return article.content;
  for (var bylineIndex = 0; bylineIndex < sourceBylineCandidates.length; bylineIndex += 1) {
    var sourceByline = sourceBylineCandidates[bylineIndex];
    var readableClone = sourceClones.get(sourceByline);
    var markerText = normalizeText(sourceByline && sourceByline.textContent || "");
    if (retainedHeaderBylines.has(sourceByline)) {
      if (sourceByline.compareDocumentPosition(firstBodyParagraph) & Node.DOCUMENT_POSITION_FOLLOWING) {
        bylineSet.add(sourceByline);
        orderedBylines.push(sourceByline);
      }
      continue;
    }
    if (paragraphSet.has(sourceByline)) continue;
    if (!sourceByline || sourceByline.localName !== "p" || !readableClone ||
        !readableClone.getAttribute("data-fetchutil-reader-source-paragraph") || elementSubtreeHidden(sourceByline) ||
        !owner.contains(sourceByline) || sourceOwnershipInChrome(sourceByline) || sourceByline.querySelector("p, article, main, section, figure, table, blockquote, pre, form") ||
        !markerText || markerText !== normalizeText(readableClone.textContent || "") ||
        !(headline.compareDocumentPosition(sourceByline) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !(sourceByline.compareDocumentPosition(firstBodyParagraph) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        sourceByline.closest("article") !== articleRecord ||
        bylineSet.has(sourceByline)) continue;
    bylineSet.add(sourceByline);
    orderedBylines.push(sourceByline);
  }
  if (!orderedBylines.length) return article.content;
  orderedBylines.sort(function(left, right) {
    return left === right ? 0 : (left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1);
  });
  var missingBylines = orderedBylines.filter(function(sourceByline) {
    return !retainedHeaderBylines.has(sourceByline);
  });
  if (!missingBylines.length) return article.content;

  var template = document.createElement("template");
  template.innerHTML = article.content || "";
  var matchingHeadings = Array.from(template.content.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(node) {
    return normalizeText(node.textContent || "") === normalizeText(headline.textContent || "");
  });
  if (matchingHeadings.length > 1) return article.content;
  var outputHeading = matchingHeadings[0] || null;
  if (!outputHeading) {
    var headlineClone = sourceClones.get(headline);
    if (!headlineClone) return article.content;
    outputHeading = headlineClone.cloneNode(true);
    template.content.insertBefore(outputHeading, template.content.firstChild);
  } else if (outputHeading.localName !== "h1") {
    var promoted = document.createElement("h1");
    Array.from(outputHeading.attributes).forEach(function(attribute) { promoted.setAttribute(attribute.name, attribute.value); });
    while (outputHeading.firstChild) promoted.appendChild(outputHeading.firstChild);
    outputHeading.replaceWith(promoted);
    outputHeading = promoted;
  }

  var sourceByToken = new Map();
  var sourceById = new Map();
  var ambiguousSourceMapping = false;
  sourceClones.forEach(function(clone, source) {
    if (source.localName !== "p" || clone.nodeType !== Node.ELEMENT_NODE) return;
    var identity = sourceIdentities && sourceIdentities.get(source);
    if (!identity) return;
    var token = clone.getAttribute("data-fetchutil-reader-source-paragraph");
    if (token && token.indexOf(marker + ":") === 0) {
      if (sourceByToken.has(token) && sourceByToken.get(token) !== source) ambiguousSourceMapping = true;
      sourceByToken.set(token, source);
    }
    if (identity.unique) {
      if (sourceById.has(identity.id) && sourceById.get(identity.id) !== source) ambiguousSourceMapping = true;
      sourceById.set(identity.id, source);
    }
  });
  if (ambiguousSourceMapping) return article.content;

  var outputParagraphs = Array.from(template.content.querySelectorAll("p")).filter(function(node) {
    return !!normalizeText(node.textContent || "");
  });
  var outputParagraphIndexes = new Map();
  outputParagraphs.forEach(function(node, index) { outputParagraphIndexes.set(node, index); });
  var outputGroupsBySource = new Map();
  var firstBodyOutputParagraph = null;
  outputParagraphs.forEach(function(node) {
    var source = sourceReaderParagraphOrigin(node, template.content, sourceByToken, sourceById, marker);
    if (source === firstBodyParagraph && !firstBodyOutputParagraph) firstBodyOutputParagraph = node;
    if (!retainedHeaderBylines.has(source)) return;
    if (!outputGroupsBySource.has(source)) outputGroupsBySource.set(source, []);
    outputGroupsBySource.get(source).push(node);
  });
  if (!firstBodyOutputParagraph) return article.content;

  var retainedOutputGroups = new Map();
  var previousRetainedOutput = null;
  var firstSectionHeading = Array.from(template.content.querySelectorAll("h2, h3, h4, h5, h6")).find(function(node) {
    return node !== outputHeading && (outputHeading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) &&
      (node.compareDocumentPosition(firstBodyOutputParagraph) & Node.DOCUMENT_POSITION_FOLLOWING);
  });
  var headerBoundary = firstSectionHeading || firstBodyOutputParagraph;
  for (var orderedIndex = 0; orderedIndex < orderedBylines.length; orderedIndex += 1) {
    var orderedSource = orderedBylines[orderedIndex];
    if (!retainedHeaderBylines.has(orderedSource)) continue;
    var outputGroup = outputGroupsBySource.get(orderedSource);
    var identity = sourceIdentities && sourceIdentities.get(orderedSource);
    var readableByline = sourceClones.get(orderedSource);
    var expectedSegments = identity && identity.breakSegments;
    var expectedTexts = expectedSegments || [normalizeText(readableByline && readableByline.textContent || "")];
    if (!outputGroup || !outputGroup.length || !identity || !readableByline ||
        outputGroup.length !== expectedTexts.length ||
        !(outputHeading.compareDocumentPosition(outputGroup[0]) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !(outputGroup[outputGroup.length - 1].compareDocumentPosition(headerBoundary) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        (previousRetainedOutput && !(previousRetainedOutput.compareDocumentPosition(outputGroup[0]) & Node.DOCUMENT_POSITION_FOLLOWING))) {
      return article.content;
    }
    for (var groupIndex = 0; groupIndex < outputGroup.length; groupIndex += 1) {
      if (normalizeText(outputGroup[groupIndex].textContent || "") !== expectedTexts[groupIndex] ||
          (groupIndex > 0 && outputParagraphIndexes.get(outputGroup[groupIndex]) !== outputParagraphIndexes.get(outputGroup[groupIndex - 1]) + 1)) {
        return article.content;
      }
    }
    retainedOutputGroups.set(orderedSource, outputGroup);
    previousRetainedOutput = outputGroup[outputGroup.length - 1];
  }

  var insertionPoint = outputHeading;
  for (var insertionIndex = 0; insertionIndex < orderedBylines.length; insertionIndex += 1) {
    var sourceByline = orderedBylines[insertionIndex];
    if (retainedHeaderBylines.has(sourceByline)) {
      var retainedGroup = retainedOutputGroups.get(sourceByline);
      if (!retainedGroup || !(insertionPoint.compareDocumentPosition(retainedGroup[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) {
        return article.content;
      }
      insertionPoint = retainedGroup[retainedGroup.length - 1];
      continue;
    }
    if (!insertionPoint || !(insertionPoint.compareDocumentPosition(headerBoundary) & Node.DOCUMENT_POSITION_FOLLOWING)) {
      return article.content;
    }
    var bylineClone = sourceClones.get(sourceByline).cloneNode(true);
    insertionPoint.insertAdjacentElement("afterend", bylineClone);
    insertionPoint = bylineClone;
  }
  return template.innerHTML;
}
