function newsletterVisibleMarkdownLength(line) {
  return normalizeText(String(line || "")
    .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
    .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")).length;
}

function newsletterCommerceCardCount(root) {
  if (!root) return 0;
  var cards = root.querySelectorAll(
    "[itemtype*='Product' i], [itemtype*='Offer' i], [itemprop='offers'], [data-product-id], [data-item-id][data-detail-setting]"
  );
  var destinationsSeen = [];
  for (var i = 0; i < cards.length; i++) {
    var card = cards[i];
    var links = [];
    if (card.matches("a[href]")) links.push(card);
    Array.prototype.forEach.call(card.querySelectorAll("a[href]"), function(link) { links.push(link); });
    var destinations = [];
    var linkedImage = false;
    for (var j = 0; j < links.length; j++) {
      var destination = links[j].href || links[j].getAttribute("href");
      if (destination && destinations.indexOf(destination) === -1) destinations.push(destination);
      if (links[j].querySelector("img")) linkedImage = true;
    }
    if (destinations.length === 1 && linkedImage && destinationsSeen.indexOf(destinations[0]) === -1) {
      destinationsSeen.push(destinations[0]);
    }
  }
  return destinationsSeen.length;
}

function newsletterTitleMatches(candidate, title, exact) {
  var candidateTitle = normalizeText(candidate || "");
  var pageTitle = normalizeText(title || "");
  if (!candidateTitle || !pageTitle) return false;
  if (candidateTitle === pageTitle) return true;
  return !exact && candidateTitle.length >= 6 && pageTitle.indexOf(candidateTitle) === 0 &&
    /^[\s|:–—-]/.test(pageTitle.slice(candidateTitle.length));
}

function newsletterPageTitleHeading(heading) {
  if (heading.tagName.toLowerCase() !== "h2") return true;
  return !heading.closest("a[href]") && !heading.querySelector("a[href]");
}

function newsletterParagraphMaterial(paragraph) {
  var clone = paragraph.cloneNode(true);
  Array.prototype.forEach.call(clone.querySelectorAll("a, button, img, time, [datetime]"), function(node) {
    node.parentNode.removeChild(node);
  });
  return normalizeText(clone.textContent || "");
}

function newsletterSourceTextOverlap(selectedText, sourceText) {
  var selected = normalizeText(selectedText || "");
  var source = normalizeText(sourceText || "");
  if (selected.length < 20 || source.length < 20) return false;
  if (source.indexOf(selected) !== -1) return true;

  var selectedWords = selected.toLowerCase().match(/[\p{L}\p{N}]{4,}/gu) || [];
  var sourceWords = new Set(source.toLowerCase().match(/[\p{L}\p{N}]{4,}/gu) || []);
  var sharedWords = selectedWords.filter(function(word) { return sourceWords.has(word); });
  return selectedWords.length >= 4 && sharedWords.length >= Math.ceil(selectedWords.length * 0.8);
}

function newsletterOwnerHasLocalSourceMaterial(selectedOwner, sourceOwner, ignored) {
  var ownerSelector = "article, [itemprop='articleBody'], main, [role='main']";
  var sourceClone = visibilityPrunedClone(sourceOwner, document);
  Array.from(sourceClone.querySelectorAll(ownerSelector)).forEach(function(nestedOwner) {
    nestedOwner.parentNode.removeChild(nestedOwner);
  });
  var sourceText = normalizeText(sourceClone.textContent || "");
  var hasLocalMaterial = Array.from(selectedOwner.querySelectorAll("p")).some(function(paragraph) {
    if (paragraph.closest(ignored) || paragraph.closest(ownerSelector) !== selectedOwner) return false;
    return newsletterSourceTextOverlap(newsletterParagraphMaterial(paragraph), sourceText);
  });
  if (hasLocalMaterial) return true;

  var selectedDestinations = newsletterIndependentLinkedSectionDestinations(selectedOwner, false);
  var sourceDestinations = newsletterIndependentLinkedSectionDestinations(sourceClone, false);
  return Array.from(selectedDestinations).filter(function(destination) {
    return sourceDestinations.has(destination);
  }).length >= 4;
}

function newsletterSelectedSourceTitleOwner(root, title, exact) {
  if (!root || !root.querySelectorAll || !title) return null;
  var headingSelector = "h1, [itemprop='headline'], h2";
  var ignored = multiTopicIgnoredContainerSelector();
  var selectedHeadings = Array.from(root.querySelectorAll(headingSelector)).filter(function(heading) {
    return newsletterPageTitleHeading(heading) && !heading.closest(ignored) &&
      newsletterTitleMatches(heading.textContent, title, exact);
  });
  if (selectedHeadings.length > 1) return null;

  var sourceHeadings = Array.from(document.querySelectorAll(headingSelector)).filter(function(heading) {
    return newsletterPageTitleHeading(heading) && !elementVisuallyHidden(heading) && !heading.closest(ignored) &&
      newsletterTitleMatches(heading.textContent, title, exact);
  });
  if (sourceHeadings.length !== 1) return null;

  var selectedHeading = selectedHeadings[0] || null;
  var sourceHeading = sourceHeadings[0];
  var ownerSelector = "article, [itemprop='articleBody'], main, [role='main']";
  var sourceOwner = sourceHeading.closest(ownerSelector);
  var selectedOwner = selectedHeading && selectedHeading.closest(ownerSelector);
  if (!sourceOwner || sourceOwner.closest("aside, nav, footer")) return null;
  if (selectedHeading && !selectedOwner) return null;

  if (!selectedOwner) {
    var candidates = Array.from(root.querySelectorAll(ownerSelector)).filter(function(owner) {
      return !owner.closest(ignored) && !owner.closest("aside, nav, footer") &&
        newsletterOwnerHasLocalSourceMaterial(owner, sourceOwner, ignored);
    });
    var deepestCandidates = candidates.filter(function(owner) {
      return !candidates.some(function(other) { return other !== owner && owner.contains(other); });
    });
    if (deepestCandidates.length !== 1) return null;
    selectedOwner = deepestCandidates[0];
  } else if (selectedOwner.closest(ignored) || selectedOwner.closest("aside, nav, footer") ||
      !newsletterOwnerHasLocalSourceMaterial(selectedOwner, sourceOwner, ignored)) {
    return null;
  }

  return { heading: selectedHeading, selectedOwner: selectedOwner, sourceHeading: sourceHeading, sourceOwner: sourceOwner };
}

function newsletterOwnedEditorialIntro(root, metadata, content) {
  if (!root || !root.querySelectorAll) return false;
  var pageTitle = (content && content.title) || (metadata && metadata.title) || "";
  var titleOwner = newsletterSelectedSourceTitleOwner(root, pageTitle, false);
  var mainRoots = Array.from(root.querySelectorAll("main, [role='main']"));
  var owner = titleOwner ? titleOwner.selectedOwner :
    (root.matches && root.matches("main, [role='main']") ? root : (mainRoots.length === 1 ? mainRoots[0] : root));
  var headings = Array.from(owner.querySelectorAll("h2, h3, h4, h5, h6"));
  var firstRecordHeading = headings.find(function(heading) {
    if (heading.closest(multiTopicIgnoredContainerSelector())) return false;
    return Array.from(heading.querySelectorAll("a[href]")).some(function(link) {
      return !!newsletterRecordDestination(link);
    });
  });
  if (!firstRecordHeading || newsletterIndependentLinkedSectionCount(owner, true) < 4) return false;

  return Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
    if (paragraph.closest(multiTopicIgnoredContainerSelector())) return false;
    if (!(paragraph.compareDocumentPosition(firstRecordHeading) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    var nestedRecord = paragraph.closest("article, li");
    if (nestedRecord && nestedRecord !== owner) return false;
    var text = newsletterParagraphMaterial(paragraph);
    return text.length >= 40 && /\b(?:editor(?:s|['’]s)?|curated|curation|selected|selection|handpicked|chosen|gathered)\b/i.test(text);
  });
}

function newsletterEditionContext(metadata, content, root) {
  var context = (content && content.title) || (metadata && metadata.title) || "";
  return /\b(?:newsletter|digest|briefing|bulletin|round[- ]?up|report collection|selected reports|curated reports)\b/i.test(normalizeText(context)) ||
    newsletterOwnedEditorialIntro(root, metadata, content);
}

function newsletterSingleArticleIdentity(root) {
  var type = document.querySelector("meta[property='og:type' i]");
  var title = document.querySelector("meta[property='og:title' i]");
  if (!type || !/\barticle\b/i.test(type.getAttribute("content") || "") || !title) return false;
  var sourceTitle = normalizeText(title.getAttribute("content") || "");
  return !!newsletterSelectedSourceTitleOwner(root, sourceTitle, true);
}

function newsletterNonEditorialList(root) {
  var type = document.querySelector("meta[property='og:type' i]");
  if (type && /\b(?:profile|product)\b/i.test(type.getAttribute("content") || "")) return true;
  return newsletterCommerceCardCount(root) > 0;
}

function newsletterRecordDestination(link) {
  if (link.matches("[download], [rel~='tag' i], [rel~='cite' i], [rel~='author' i]")) return null;
  if (link.closest(
    "aside, nav, footer, cite, sup, [role~='complementary' i], [role~='navigation' i], " +
    "[class*='taxonomy' i], [class~='tag' i], [class~='tags' i], [class*='tag-list' i], " +
    "[class*='citation' i], [id*='citation' i], [class*='footnote' i], [id*='footnote' i]"
  )) return null;

  var destination = materializedHttpUrl(link.getAttribute("href") || "");
  if (!destination) return null;
  try {
    var parsed = new URL(destination);
    var current = new URL(location.href);
    parsed.hash = "";
    current.hash = "";
    Array.from(parsed.searchParams.keys()).forEach(function(name) {
      if (/^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name)) parsed.searchParams.delete(name);
    });
    Array.from(current.searchParams.keys()).forEach(function(name) {
      if (/^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name)) current.searchParams.delete(name);
    });
    var key = parsed.origin + parsed.pathname.replace(/\/+$/, "") + parsed.search;
    var currentKey = current.origin + current.pathname.replace(/\/+$/, "") + current.search;
    return key === currentKey ? null : key;
  } catch (_error) {
    return null;
  }
}

function newsletterIndependentLinkedSectionDestinations(root, requireAuthoredSummary, requireLinkedHeading) {
  var destinations = new Set();
  if (!root || !root.querySelectorAll) return destinations;
  var headings = Array.from(root.querySelectorAll("h2, h3, h4, h5, h6"));

  headings.forEach(function(heading, index) {
    if (heading.closest(
      "aside, nav, footer, [role~='complementary' i], [role~='navigation' i], " +
      "[class*='taxonomy' i], [class~='tag' i], [class~='tags' i], [class*='tag-list' i]"
    )) return;

    var level = Number(heading.tagName.slice(1));
    var boundary = null;
    var hasNestedHeading = false;
    for (var nextIndex = index + 1; nextIndex < headings.length; nextIndex++) {
      var nextLevel = Number(headings[nextIndex].tagName.slice(1));
      if (nextLevel <= level) {
        boundary = headings[nextIndex];
        break;
      }
      hasNestedHeading = true;
    }
    if (hasNestedHeading) return;

    var range = document.createRange();
    range.setStartAfter(heading);
    if (boundary) range.setEndBefore(boundary);
    else range.setEnd(root, root.childNodes.length);
    var section = range.cloneContents();
    if (section.querySelector("table, dl")) return;
    var textLength = normalizeText([heading.textContent || "", section.textContent || ""].join(" ")).length;
    if (!textLength || textLength >= 200) return;

    var headingLinks = Array.from(heading.querySelectorAll("a[href]"));
    if (requireLinkedHeading && !headingLinks.some(function(link) { return !!newsletterRecordDestination(link); })) return;
    var links = Array.from(section.querySelectorAll("a[href]"));
    links = headingLinks.concat(links);
    var sectionDestinations = Array.from(new Set(links.map(newsletterRecordDestination).filter(Boolean)));
    if (!sectionDestinations.length) return;
    if (requireAuthoredSummary) {
      if (sectionDestinations.length !== 1) return;
      var summaryText = Array.from(section.querySelectorAll("p")).map(function(paragraph) {
        var summary = paragraph.cloneNode(true);
        Array.prototype.forEach.call(summary.querySelectorAll("a, button, img, time, [datetime]"), function(node) {
          node.parentNode.removeChild(node);
        });
        return normalizeText(summary.textContent || "");
      }).join(" ");
      if (summaryText.length < 20) return;
    }

    destinations.add(sectionDestinations[0]);
  });

  return destinations;
}

function newsletterIndependentLinkedSectionCount(root, requireAuthoredSummary, requireLinkedHeading) {
  return newsletterIndependentLinkedSectionDestinations(root, requireAuthoredSummary, requireLinkedHeading).size;
}
