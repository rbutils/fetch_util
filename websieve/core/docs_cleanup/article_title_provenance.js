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
  if (selectedLinks.length > 1 || sourceLinks.length !== 1 || elementSubtreeHidden(sourceLinks[0]) ||
      normalizeText(sourceLinks[0].textContent || "") !== normalizeText(title)) return null;
  var sourceUrl = materializedHttpUrl(sourceLinks[0].getAttribute("href"));
  if (!sourceUrl) return null;
  if (selectedLinks.length === 1 && materializedHttpUrl(selectedLinks[0].getAttribute("href")) !== sourceUrl) return null;
  var destination = new URL(sourceUrl);
  if (destination.origin !== location.origin || destination.pathname !== location.pathname ||
      destination.search !== location.search) return null;
  var completeBody = sourceOwnedSelfLinkedArticleCompleteBodyMatches(owner, selectedArticle, title);
  return { owner: owner, selectedHeading: selectedHeading, sourceHeading: sourceHeadings[0], url: sourceUrl, completeBody: completeBody };
}

function sourceOwnedSelfLinkedArticleCompleteBodyMatches(sourceArticle, selectedArticle, title) {
  function visibleBodyText(article) {
    var clone = article.cloneNode(true);
    var sourceNodes = [article].concat(Array.prototype.slice.call(article.querySelectorAll("*")));
    var clonedNodes = [clone].concat(Array.prototype.slice.call(clone.querySelectorAll("*")));
    sourceNodes.forEach(function(node, index) {
      if (!index) return;
      if (elementSubtreeHidden(node) || sourceOwnershipArticleChrome(node, article) ||
          /^(?:ARTICLE|HEADER|FOOTER|SCRIPT|STYLE|NOSCRIPT|TEMPLATE)$/.test(node.tagName) ||
          node.matches("[data-toc]") ||
          (/^(?:H1|H2)$/.test(node.tagName) && normalizeText(node.textContent || "") === normalizeText(title))) {
        clonedNodes[index].remove();
      }
    });
    return normalizeText(clone.textContent || "");
  }

  var sourceText = visibleBodyText(sourceArticle);
  return !!sourceText && sourceText === visibleBodyText(selectedArticle);
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

function sourceOwnedTitleSuffixMatchesPublisher(suffix, siteName, source, headline) {
  if (!suffix) return false;
  var match = normalizeText(suffix).match(/^(?:-|\||\u2013|\u2014)\s+(.+)$/);
  if (!match) return false;
  var firstComponent = normalizeText(match[1].split(/\s*[|·•]\s*/)[0]).replace(/^www\./i, "").toLowerCase();
  var publisher = normalizeText(siteName || "").split(/\s*[|·•]\s*/)[0].replace(/^www\./i, "").toLowerCase();
  var hostParts = (location.hostname || "").replace(/^www\./i, "").toLowerCase().split(".").filter(function(part) {
    return part.length >= 3 && !/^(?:com|net|org|gov|edu|co)$/.test(part);
  });
  if (firstComponent && (firstComponent === publisher || hostParts.indexOf(firstComponent) !== -1)) return true;
  if (!source || !source.matches("article") || !headline ||
      !sourceOwnedGeneratorBrandMatches(firstComponent, source)) return false;
  var pageUrl = sourceOwnershipPageUrl(materializedCanonicalUrl() || location.href);
  return !!pageUrl && !sourceOwnedTitleMetadataConflictsWithHeading(headline, pageUrl);
}

function sourceOwnedGeneratorBrandMatches(publisher, source) {
  if (!publisher || !source) return false;
  var generators = document.querySelectorAll('meta[name="generator" i]');
  if (generators.length !== 1) return false;
  var generator = normalizeText(generators[0].getAttribute("content") || "").split(/\s+/)[0];
  return normalizeText(generator).replace(/^www\./i, "").toLowerCase() === publisher;
}

function sourceOwnedTitleMetadataConflictsWithHeading(headline, pageUrl) {
  if (typeof sourceOwnedParsedPublicationRecords !== "function" ||
      typeof sourceOwnedArticlePublicationRecord !== "function" ||
      typeof sourceOwnedPublicationRecordUrls !== "function") return false;
  var records = sourceOwnedParsedPublicationRecords(headline).records || [];
  return records.some(function(record) {
    if (!sourceOwnedArticlePublicationRecord(record)) return false;
    var recordHeadline = normalizeText(entityText(record.headline) || "");
    if (!recordHeadline) return false;
    var urls = sourceOwnedPublicationRecordUrls(record);
    if (!urls.present) return false;
    return urls.values.indexOf(pageUrl) === -1 ? recordHeadline === normalizeText(headline) :
      recordHeadline !== normalizeText(headline);
  });
}

function preserveUnprovenSourceTitleExtension(markdown, sourceTitle, documentTitle) {
  var heading = normalizeText(sourceTitle || "");
  var title = normalizeText(documentTitle || "");
  if (!heading || !title || title.indexOf(heading) !== 0) return markdown;
  var suffix = normalizeText(title.slice(heading.length));
  if (!/^(?:-|\||:|\u2013|\u2014)\s+\S/.test(suffix)) return markdown;
  var lines = (markdown || "").split("\n");
  var headingIndex = lines.findIndex(function(line) {
    var match = normalizeText(line).match(/^(#{1,6})\s+(.*)/);
    return normalizeText(match && match[2]) === heading;
  });
  if (headingIndex < 0) return markdown;
  var marker = lines[headingIndex].match(/^(#{1,6}\s+)/);
  lines[headingIndex] = marker[1] + title;
  return lines.join("\n");
}
