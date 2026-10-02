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
  if (bodyCandidates.length && innermost.length !== 1) return null;

  var root = bodyCandidates.length ? innermost[0] : sourceOwnedReaderMappedParagraphRoot(paragraphs);
  if (!root || Array.from(root.querySelectorAll("h1")).some(function(heading) {
    return !elementVisuallyHidden(heading) &&
      sourceOwnedComparableHeadline(heading.textContent || "") !== comparableHeadline;
  })) return null;
  var ownerRoot = sourceOwnershipCommonAncestor(headings[0], root);
  if (!ownerRoot || ownerRoot === document.body || ownerRoot === document.documentElement) return null;
  if (!bodyCandidates.length && sourceArticleBodyHasForeignLinkedArticle(ownerRoot, root, headings[0], pageUrl)) return null;
  return { root: root, ownerRoot: ownerRoot, heading: headings[0], body: root, firstParagraph: paragraphs[0], headline: headline };
}

function sourceOwnedArticleBodyPublicationDates(body, ownerRoot, heading, firstParagraph) {
  if (!body || !ownerRoot || !heading || !firstParagraph || !body.contains(firstParagraph) ||
      !ownerRoot.contains(heading) || !document.body.contains(body)) return [];
  var selector = "time, [itemprop~='datePublished' i], [class*='date' i], [class*='published' i]";
  return Array.from(body.querySelectorAll(selector)).filter(function(node) {
    if (elementVisuallyHidden(node) || !visiblePublishedTimeField(node) || visiblePublicationSchedule(node) ||
        sourceOwnershipArticleChrome(node, ownerRoot) || node.closest("blockquote, form, [role='note']") ||
        (node.closest("article") && node.closest("article") !== ownerRoot)) return false;
    if (!(heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !(node.compareDocumentPosition(firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    return visiblePublicationDateLike(sourceOwnedPublicationNodeDate(node));
  });
}

function sourceOwnedReaderMappedParagraphRoot(paragraphs) {
  var root = paragraphs[0];
  for (var index = 1; index < paragraphs.length; index += 1) {
    root = sourceOwnershipCommonAncestor(root, paragraphs[index]);
    if (!root) return null;
  }
  if (root === document.body || root === document.documentElement || !document.body.contains(root) ||
      elementSubtreeHidden(root) || sourceOwnershipArticleChrome(root, root)) return null;
  return root;
}

function sourceOwnedReaderAnswerPublicationTime(paragraphs, pageUrl, headline) {
  if (!Array.isArray(paragraphs) || paragraphs.length < 2 || paragraphs.some(function(paragraph, index) {
    return !sourceOwnedQuestionAnswerParagraph(paragraph) ||
      (index > 0 && !(paragraphs[index - 1].compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING));
  })) return "";
  var question = sourceOwnedQuestionAnswerRegion(headline, pageUrl, false);
  if (!question) return "";
  var values = question.records.map(function(record) {
    var owner = sourceOwnedQuestionAnswerOwner(record.link, paragraphs, false);
    return owner ? sourceOwnedQuestionAnswerDate(record.link) : "";
  }).filter(Boolean);
  return sourceOwnedUniquePublicationValue(values).value;
}

function sourceOwnedLeadingQuestionAnswerPublicationTime(headline, pageUrl) {
  var question = sourceOwnedQuestionAnswerRegion(headline, pageUrl, true);
  return question ? sourceOwnedQuestionAnswerDate(question.records[0].link) : "";
}

function sourceOwnedQuestionAnswerRegion(headline, pageUrl, requireMultipleAnswers) {
  var page = sourceOwnedQuestionAnswerPage(pageUrl);
  if (!page) return null;
  var title = sourceOwnedComparableHeadline(headline || "");
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return !elementVisuallyHidden(node) && sourceOwnedComparableHeadline(node.textContent || "");
  });
  if (!title && headings.length === 1) title = sourceOwnedComparableHeadline(headings[0].textContent || "");
  headings = headings.filter(function(node) {
    return sourceOwnedComparableHeadline(node.textContent || "") === title;
  });
  if (!title || headings.length !== 1) return null;
  var links = sourceOwnedQuestionAnswerLinks(page);
  var records = links.map(function(link) {
    return { link: link, owner: sourceOwnedQuestionAnswerOwner(link, null, true) };
  }).filter(function(record) { return !!record.owner; });
  var owners = Array.from(new Set(records.map(function(record) { return record.owner; })));
  if (owners.length < (requireMultipleAnswers ? 2 : 1) ||
      (requireMultipleAnswers &&
        Array.from(records[0].owner.querySelectorAll("p")).filter(sourceOwnedQuestionAnswerParagraph).length < 2)) return null;

  var region = owners.reduce(function(root, owner) {
    return root ? sourceOwnershipCommonAncestor(root, owner) : owner;
  }, headings[0]);
  if (!region || region === document.body || region === document.documentElement ||
      region.matches("article, form, aside, blockquote, [role='article'], [role='complementary']") ||
      sourceOwnershipInChrome(region)) return null;
  var regionHeadings = Array.from(region.querySelectorAll("h1")).filter(function(node) {
    return !elementVisuallyHidden(node);
  });
  if (regionHeadings.length !== 1 || regionHeadings[0] !== headings[0] ||
      owners.some(function(owner) { return !region.contains(owner); })) return null;
  return { page: page, heading: headings[0], region: region, records: records };
}

function sourceOwnedQuestionAnswerPage(pageUrl) {
  var page = sourceOwnershipPageUrl(pageUrl);
  if (!page || page !== sourceOwnershipPageUrl(materializedCanonicalUrl())) return null;
  try {
    return new URL(page);
  } catch (_error) {
    return null;
  }
}

function sourceOwnedQuestionAnswerLinks(page) {
  var answerPrefix = page.pathname.replace(/\/$/, "") + "/answer/";
  return Array.from(document.querySelectorAll("a.answer_timestamp[href]")).filter(function(link) {
    if (!sourceOwnedQuestionAnswerDate(link) || elementVisuallyHidden(link) ||
        link.closest("aside, form, blockquote, pre, code, nav, footer, [role='note'], [role='complementary']") ||
        visiblePublicationSchedule(link)) return false;
    try {
      var target = new URL(link.getAttribute("href"), page.href);
      return target.origin === page.origin && target.pathname.indexOf(answerPrefix) === 0 &&
        target.pathname.length > answerPrefix.length;
    } catch (_error) {
      return false;
    }
  });
}

function sourceOwnedQuestionAnswerDate(link) {
  var date = sourceOwnedPublicationNodeDate(link);
  return visiblePublicationDateLike(date) ||
    /^\d+\s*(?:y|yr|yrs|year|years|mo|mos|month|months|w|wk|wks|week|weeks|d|day|days|h|hr|hrs|hour|hours|min|mins|m)$/i.test(date) ? date : "";
}

function sourceOwnedQuestionAnswerParagraph(paragraph) {
  return !!paragraph && paragraph.localName === "p" && !elementVisuallyHidden(paragraph) &&
    !paragraph.closest("aside, form, blockquote, pre, code, [role='note'], [role='complementary']");
}

function sourceOwnedQuestionAnswerOwner(link, selectedParagraphs, questionRegion) {
  for (var ancestor = link.parentElement; ancestor && ancestor !== document.body; ancestor = ancestor.parentElement) {
    if (ancestor.matches("aside, form, blockquote, pre, code, [role='note'], [role='complementary']") ||
        elementSubtreeHidden(ancestor) || sourceOwnershipInChrome(ancestor)) break;
    if (ancestor.closest("article")) return null;
    var timestamps = ancestor.querySelectorAll("a.answer_timestamp[href]");
    if (timestamps.length !== 1 || timestamps[0] !== link) continue;
    if (selectedParagraphs) {
      if (selectedParagraphs.every(function(paragraph) { return ancestor.contains(paragraph); })) return ancestor;
      continue;
    }
    if (Array.from(ancestor.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(heading) {
      return !elementVisuallyHidden(heading);
    })) return null;
    var prose = Array.from(ancestor.querySelectorAll("p")).filter(sourceOwnedQuestionAnswerParagraph);
    if (prose.length >= (questionRegion ? 1 : 2)) return ancestor;
  }
  return null;
}

function sourceOwnedReaderHeaderPublicationTime(paragraphs, owner) {
  if (!Array.isArray(paragraphs) || !owner || !owner.heading || !owner.ownerRoot) return "";
  var candidates = Array.from(owner.ownerRoot.querySelectorAll(
    "time, [itemprop~='datePublished' i], [class*='date' i], [class*='published' i]"
  )).filter(function(node) {
    if (!node.matches("time, [itemprop~='datePublished' i], [class*='date' i], [class*='published' i]")) return false;
    var value = sourceOwnedPublicationNodeDate(node);
    return !!value && visiblePublicationDateLike(value) && visiblePublishedTimeField(node);
  });
  var values = [];
  candidates.forEach(function(node) {
    var header = node.closest("header, [class*='article-header' i], [class*='entry-header' i]");
    if (!header || !owner.ownerRoot.contains(header) || elementSubtreeHidden(header) || sourceOwnershipInChrome(header) ||
        sourceOwnedHeaderContainsChrome(header) || sourceOwnedHeaderContainsForeignArticle(header)) return;
    var headerHeadings = Array.from(header.querySelectorAll("h1")).filter(function(heading) {
      return !elementVisuallyHidden(heading);
    });
    if (headerHeadings.length !== 1 || headerHeadings[0] !== owner.heading) return;
    var followingBody = paragraphs.find(function(paragraph) {
      return !header.contains(paragraph) && normalizeText(paragraph.textContent || "").length > 80 &&
        (node.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    if (!followingBody || !sourceOwnedHeaderPrecedesBody(header, followingBody)) return;
    values.push(sourceOwnedPublicationNodeDate(node));
  });
  return sourceOwnedUniquePublicationValue(values).value;
}
