function readerSourceOwnedBylineForContent(content, metadata, contentByline, metadataByline) {
  if (content && content.readerMode) {
    return readerSourceOwnedReaderBylineExtension(content, metadata, contentByline, metadataByline);
  }
  return readerSourceOwnedBylineExtension(content, metadata, contentByline, metadataByline);
}

function readerSourceOwnedReaderBylineExtension(content, metadata, contentByline, metadataByline) {
  if (!content || content.contentType !== "article" || !content.readerMode || content.sourceOwnedLiveblog === true ||
      content.isolatedLiveblogEntry || !content.html) return null;
  metadata = metadata || {};
  var candidate = readerSourceOwnedSelectedHeaderByline(content, metadata, contentByline, metadataByline);
  var decision = candidate ? readerSourceOwnedBylineDecision(candidate, content, metadata, contentByline, metadataByline) : null;
  return decision;
}

function readerSourceOwnedSelectedHeaderByline(content, metadata, contentByline, metadataByline) {
  var hasBodySources = Array.isArray(content.sourceOwnedReaderBodyParagraphSources);
  var hasHeaderEdges = Array.isArray(content.sourceOwnedReaderUnmappedHeaderParagraphs);
  var hasTrailingEdges = Array.isArray(content.sourceOwnedReaderUnmappedTrailingParagraphs);
  if (!hasBodySources || !hasHeaderEdges || !hasTrailingEdges) return null;
  var paragraphs = content.sourceOwnedReaderBodyParagraphSources;
  if (paragraphs.length < 2) return null;
  var paragraphSet = new Set();
  for (var paragraphIndex = 0; paragraphIndex < paragraphs.length; paragraphIndex += 1) {
    var paragraph = paragraphs[paragraphIndex];
    if (!paragraph || paragraph.localName !== "p" || elementSubtreeHidden(paragraph) || paragraphSet.has(paragraph)) return null;
    paragraphSet.add(paragraph);
  }

  var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementSubtreeHidden(heading) && !heading.closest("nav, footer, aside, form, [role='navigation'], [role='complementary']");
  });
  if (headings.length !== 1 || !sourceOwnedReaderHeadlineTitleMatches(headings[0].textContent, content, metadata)) return null;

  var heading = headings[0];
  var owner = sourceOwnedReaderHeadlineBodyOwner(heading, paragraphs);
  if (!owner || !owner.contains(heading) || paragraphs.some(function(paragraph) { return !owner.contains(paragraph); })) return null;
  if (!readerSourceOwnedTrailingParagraphsInOwner(
    content.sourceOwnedReaderUnmappedTrailingParagraphs, owner, paragraphs
  )) return null;
  var headingBranch = sourceOwnedDirectChild(owner, heading);
  var bodyBranch = sourceOwnedDirectChild(owner, paragraphs[0]);
  var children = Array.from(owner.children);
  var headingIndex = children.indexOf(headingBranch);
  var bodyIndex = children.indexOf(bodyBranch);
  if (headingIndex < 0 || bodyIndex <= headingIndex) return null;
  var ownedHeaderBranches = children.slice(headingIndex + 1, bodyIndex).filter(function(branch) {
    return !elementSubtreeHidden(branch) && !sourceOwnershipInChrome(branch) &&
      !branch.matches("article, main, [role='main']");
  });
  var headerBranchesBySource = new Map();
  var claimedHeaderSources = new Set();
  for (var edgeIndex = 0; edgeIndex < content.sourceOwnedReaderUnmappedHeaderParagraphs.length; edgeIndex += 1) {
    var edge = content.sourceOwnedReaderUnmappedHeaderParagraphs[edgeIndex];
    var source = edge && edge.source;
    if (!source || source.localName === "p" || elementSubtreeHidden(source) ||
        normalizeText(source.textContent || "") !== edge.text || !owner.contains(source) || claimedHeaderSources.has(source)) return null;
    var branch = sourceOwnedDirectChild(owner, source);
    if (!branch || ownedHeaderBranches.indexOf(branch) === -1) return null;
    claimedHeaderSources.add(source);
    headerBranchesBySource.set(source, branch);
  }

  var selected = document.createElement("div");
  selected.innerHTML = content.html;
  var sourceByline = [];
  var candidateBranches = new Set();
  children.slice(headingIndex + 1, bodyIndex).forEach(function(branch) {
    if (elementSubtreeHidden(branch) || sourceOwnershipInChrome(branch) || branch.matches("article, main, [role='main']")) return;
    var datedByline = readerSourceOwnedSemanticHeaderByline({ headerContext: branch }) ||
      readerSourceOwnedDatedSourceAttribution(branch);
    if (datedByline) {
      sourceByline.push(datedByline);
      candidateBranches.add(branch);
    }
    var markedByline = readerSourceOwnedMarkedHeaderByline(branch);
    if (markedByline) {
      sourceByline.push(markedByline);
      candidateBranches.add(branch);
    }
    var extendedByline = readerSourceOwnedPublisherPrefixByline(
      branch, selected, content, metadata, contentByline, metadataByline
    );
    if (extendedByline) {
      sourceByline.push(extendedByline);
      candidateBranches.add(branch);
    }
  });
  for (var headerSource of claimedHeaderSources) {
    var ownedBranch = headerBranchesBySource.get(headerSource);
    if (!candidateBranches.has(ownedBranch) && !readerSourceOwnedHeaderCaptionBranch(ownedBranch)) return null;
  }
  return sourceByline.length === 1 ? sourceByline[0] : null;
}

function readerSourceOwnedDatedSourceAttribution(root) {
  if (!root.matches("div, span, p, address") || root.children.length || elementSubtreeHidden(root) || sourceOwnershipInChrome(root)) return null;
  var text = normalizeText(root.textContent || "");
  var match = text.match(/^(\d{4}[-/]\d{1,2}[-/]\d{1,2}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)\s+(?:来源|source|quelle|fonte|fuente)\s*[:：]\s*\S.+$/i);
  return match && visiblePublicationDateLike(match[1]) ? text : null;
}

function readerSourceOwnedHeaderCaptionBranch(branch) {
  return branch.matches("figure, figcaption, [class*='caption' i], [class*='credit' i]") ||
    (branch.matches("[class*='image' i]") && branch.matches("[class*='heading' i]"));
}

function readerSourceOwnedTrailingParagraphsInOwner(edges, owner, paragraphs) {
  var previous = paragraphs[paragraphs.length - 1];
  var article = paragraphs[0].closest("article");
  var section = paragraphs[paragraphs.length - 1].closest("section");
  var trailingOwner = article || section;
  var claimed = new Set();
  for (var index = 0; index < edges.length; index += 1) {
    var edge = edges[index];
    var source = edge && edge.source;
    if (!source || !trailingOwner || !owner.contains(source) || !trailingOwner.contains(source) || claimed.has(source) ||
        source.localName === "p" || elementSubtreeHidden(source) || source.querySelector("p") ||
        normalizeText(source.textContent || "") !== edge.text || sourceOwnershipInChrome(source) ||
        (article && source.closest("article") !== article) ||
        !(previous.compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    claimed.add(source);
    previous = source;
  }
  return true;
}

function readerSourceOwnedMarkedHeaderByline(root) {
  var selector = "[rel~='author' i], [itemprop~='author' i], [class*='author-name' i], " +
    "[class*='byline' i], [class*='writer' i], [class*='reporter' i]";
  var nodes = [];
  if (root.matches(selector)) nodes.push(root);
  nodes = nodes.concat(Array.from(root.querySelectorAll(selector))).filter(function(node, index, all) {
    return all.indexOf(node) === index && !elementSubtreeHidden(node) && !node.querySelector(selector) &&
      !node.closest("nav, aside, footer, form, [role~='navigation' i], [role~='complementary' i]") &&
      normalizeText(node.textContent || "") && !visiblePublicationDateLike(node.textContent || "");
  });
  return nodes.length === 1 ? normalizeText(nodes[0].textContent || "") : null;
}

function readerSourceOwnedPublisherPrefixByline(root, selected, content, metadata, contentByline, metadataByline) {
  if (root.matches("h1, h2, h3, h4, h5, h6") ||
      !root.matches("[class*='sub-heading' i], [class*='subtitle' i]")) return null;
  if (root.querySelector("a[href], img, picture, svg, video, audio, iframe, figure, table, time, h1, h2, h3, h4")) return null;
  var candidate = normalizeText(root.textContent || "");
  if (!candidate || /[.!?؟؛。．…]\s*$/u.test(candidate)) return null;
  var selectedNodes = Array.from(selected.querySelectorAll("p, div, span, address")).filter(function(node) {
    if (normalizeText(node.textContent || "") !== candidate) return false;
    return !Array.from(node.querySelectorAll("p, div, span, address")).some(function(child) {
      return normalizeText(child.textContent || "") === candidate;
    });
  });
  if (selectedNodes.length !== 1) return null;

  var names = [contentByline, metadataByline, metadata.declaredByline, content.siteName, metadata.siteName]
    .map(function(value) { return normalizeText(readerTextBylineName(value) || value || ""); })
    .filter(function(value, index, all) { return value && all.indexOf(value) === index; });
  var extensions = names.filter(function(name) {
    if (!readerSourceOwnedBylineExtendsExisting(candidate, name)) return false;
    var normalizedName = normalizeText(readerTextBylineName(name) || name || "");
    return /^\s*[:·•|,–—-]\s*\S/u.test(candidate.slice(normalizedName.length));
  });
  return extensions.length === 1 ? candidate : null;
}
