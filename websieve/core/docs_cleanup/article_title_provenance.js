function sourceArticleForSelectedParagraphs(selectedArticle) {
  if (!selectedArticle) return null;
  var selectedParagraphs = Array.prototype.map.call(selectedArticle.querySelectorAll("p"), function(paragraph) {
    return normalizeText(paragraph.textContent || "");
  }).filter(Boolean);
  if (selectedParagraphs.length < 2) return null;

  var sourceArticles = Array.prototype.filter.call(document.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && !sourceOwnershipInChrome(article) && !article.parentElement.closest("article");
  });
  var owners = sourceArticles.filter(function(owner) {
    var sourceParagraphs = Array.prototype.filter.call(owner.querySelectorAll("p"), function(paragraph) {
      return !elementSubtreeHidden(paragraph) && paragraph.closest("article") === owner;
    }).map(function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    });
    var sourcePositions = new Map();
    sourceParagraphs.forEach(function(text, index) {
      sourcePositions.set(text, sourcePositions.has(text) ? null : index);
    });
    var lastIndex = -1;
    return selectedParagraphs.every(function(text) {
      var index = sourcePositions.get(text);
      if (index === undefined || index === null || index <= lastIndex) return false;
      lastIndex = index;
      return true;
    });
  });
  return owners.length === 1 ? owners[0] : null;
}

function sourceOwnedSelfLinkedArticle(selectedArticle, title) {
  if (!selectedArticle || !title) return null;
  var selectedH1 = selectedArticle.querySelector("h1");
  if (selectedH1 && normalizeText(selectedH1.textContent || "") !== normalizeText(title)) return null;
  var owner = sourceArticleForSelectedParagraphs(selectedArticle) || sourceOwnedSelfLinkedArticleOwner(selectedArticle, title);
  if (!owner) return null;
  var sourceHeadings = Array.prototype.filter.call(owner.querySelectorAll("h1"), function(heading) {
    return heading.closest("article") === owner && !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading);
  });
  if (sourceHeadings.length !== 1 ||
      normalizeText(sourceHeadings[0].textContent || "") !== normalizeText(title)) return null;
  var pageUrl = sourceOwnershipPageUrl(materializedCanonicalUrl() || location.href);
  if (sourceOwnedSelfLinkedArticleHasConflictingRecord(sourceHeadings[0], title, pageUrl)) return null;

  var selectedHeading = selectedH1 || Array.prototype.find.call(selectedArticle.querySelectorAll("h2"), function(heading) {
    return normalizeText(heading.textContent || "") === normalizeText(title);
  }) || null;
  var selectedLinks = selectedHeading ? selectedHeading.querySelectorAll("a[href]") : [];
  var sourceLinks = sourceHeadings[0].querySelectorAll("a[href]");
  if (selectedLinks.length !== 1 || sourceLinks.length !== 1 || elementSubtreeHidden(sourceLinks[0]) ||
      normalizeText(sourceLinks[0].textContent || "") !== normalizeText(title)) return null;
  var sourceUrl = materializedHttpUrl(sourceLinks[0].getAttribute("href"));
  var selectedUrl = materializedHttpUrl(selectedLinks[0].getAttribute("href"));
  if (!sourceUrl || !selectedUrl || selectedUrl !== sourceUrl) return null;
  var destination = new URL(sourceUrl);
  if (destination.origin !== location.origin || destination.pathname !== location.pathname ||
      destination.search !== location.search) return null;
  return { owner: owner, selectedHeading: selectedHeading, sourceHeading: sourceHeadings[0], url: sourceUrl };
}

function sourceOwnedSelfLinkedArticleOwner(selectedArticle, title) {
  if (!selectedArticle) return null;
  var pageUrl = sourceOwnershipPageUrl(materializedCanonicalUrl() || location.href);
  if (!pageUrl) return null;
  var selectedParagraphs = Array.prototype.map.call(selectedArticle.querySelectorAll("p"), function(paragraph) {
    return normalizeText(paragraph.textContent || "");
  }).filter(Boolean);
  if (selectedParagraphs.length < 2) return null;
  var candidates = Array.prototype.filter.call(document.querySelectorAll("article"), function(article) {
    if (elementSubtreeHidden(article) || sourceOwnershipInChrome(article)) return false;
    var headings = Array.prototype.filter.call(article.querySelectorAll("h1"), function(heading) {
      return heading.closest("article") === article && !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading);
    });
    if (headings.length !== 1 || normalizeText(headings[0].textContent || "") !== normalizeText(title)) return false;
    var links = headings[0].querySelectorAll("a[href]");
    if (links.length !== 1 || normalizeText(links[0].textContent || "") !== normalizeText(title) ||
        sourceOwnershipPageUrl(links[0].getAttribute("href")) !== pageUrl) return false;
    return sourceOwnedSelfLinkedArticleBodyMatches(article, selectedArticle, headings[0], selectedParagraphs);
  });
  return candidates.length === 1 ? candidates[0] : null;
}

function sourceOwnedSelfLinkedArticleBodyMatches(sourceArticle, selectedArticle, heading, selectedParagraphs) {
  var sourceNodes = Array.prototype.filter.call(sourceArticle.querySelectorAll("p"), function(paragraph) {
    return paragraph.closest("article") === sourceArticle && !elementSubtreeHidden(paragraph) &&
      !sourceOwnershipArticleChrome(paragraph, sourceArticle);
  });
  var lastNode = null;
  if (!selectedParagraphs.every(function(text) {
    var matches = sourceNodes.filter(function(node) { return normalizeText(node.textContent || "") === text; });
    if (!matches.length) {
      matches = Array.prototype.filter.call(sourceArticle.querySelectorAll("div, section, span"), function(node) {
        return node.closest("article") === sourceArticle && !node.closest("p") && !node.querySelector("p") &&
          !elementSubtreeHidden(node) && !sourceOwnershipArticleChrome(node, sourceArticle) &&
          normalizeText(node.textContent || "") === text;
      });
    }
    if (matches.length !== 1 || (lastNode &&
        !(lastNode.compareDocumentPosition(matches[0]) & Node.DOCUMENT_POSITION_FOLLOWING))) return false;
    lastNode = matches[0];
    return true;
  })) return false;
  return !!heading && sourceArticle.contains(heading);
}

function sourceOwnedSelfLinkedArticleHasConflictingRecord(heading, headline, pageUrl) {
  if (!heading || !headline || !pageUrl || typeof sourceOwnedParsedPublicationRecords !== "function") return false;
  var links = heading.querySelectorAll("a[href]");
  if (links.length !== 1 || normalizeText(links[0].textContent || "") !== normalizeText(headline) ||
      sourceOwnershipPageUrl(links[0].getAttribute("href")) !== pageUrl) return false;
  var records = sourceOwnedParsedPublicationRecords(headline).records || [];
  return records.some(function(record) {
    if (!sourceOwnedArticlePublicationRecord(record) || normalizeText(entityText(record.headline) || "") === normalizeText(headline)) return false;
    var urls = sourceOwnedPublicationRecordUrls(record);
    return urls.values.indexOf(pageUrl) !== -1;
  });
}
