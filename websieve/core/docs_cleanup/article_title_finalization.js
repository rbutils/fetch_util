function sourceOwnedArticleTitleResolution(content, metadata, cleanedHtml, markdown, originalPrimaryTitle, siteTitle) {
  if (content.sourceOwnedUnattributedManual === true && content.sourceOwnedManualTitle === originalPrimaryTitle &&
      content.sourceOwnedCleanedManualHtml === content.html) {
    return { title: originalPrimaryTitle, markdown: markdown, identityResolved: true };
  }
  var primaryTitle = originalPrimaryTitle;
  var identityResolved = false;
  var completePageTitle = articleTitleFromCompletePageHeading(content, cleanedHtml, primaryTitle);
  if (completePageTitle !== primaryTitle) {
    primaryTitle = completePageTitle;
    identityResolved = true;
  }
  if ((content.contentType === "article" || content.contentType === "medical") && content.sourceOwnedLiveblog !== true) {
    var declaredDescriptionTitle = articleTitleFromDeclaredDescription(cleanedHtml, primaryTitle, siteTitle, metadata.excerpt);
    if (declaredDescriptionTitle !== primaryTitle) {
      primaryTitle = declaredDescriptionTitle;
      identityResolved = true;
    }
  }
  var externalBodyTitle = articleTitleFromSelectedExternalBodyHeading(content, metadata, primaryTitle);
  if (externalBodyTitle !== primaryTitle) {
    primaryTitle = externalBodyTitle;
    identityResolved = true;
  }
  if ((content.contentType === "article" || content.contentType === "medical") &&
      content.sourceOwnedTitleIdentityUnproven === true && content.sourceOwnedFocalArticle === true && content.sourceOwnedLiveblog !== true) {
    var selectedHeadingTitle = articleTitleFromVisibleArticleHeading(cleanedHtml, primaryTitle, siteTitle);
    if (selectedHeadingTitle === normalizeText(content.sourceOwnedHeadingTitle || "") && selectedHeadingTitle !== primaryTitle) {
      primaryTitle = selectedHeadingTitle;
      identityResolved = true;
    }
  }
  if ((content.contentType === "article" || content.contentType === "medical") &&
      (content.sourceOwnedTitleIdentityUnproven !== true || identityResolved) && content.sourceOwnedLiveblog !== true) {
    primaryTitle = articleTitleFromOwnedHeading(cleanedHtml, primaryTitle, siteTitle);
    primaryTitle = articleTitleFromVisibleArticleHeading(cleanedHtml, primaryTitle, siteTitle);
    primaryTitle = articleTitleFromAdjacentHeading(cleanedHtml, primaryTitle);
    primaryTitle = articleTitleFromOwnedExternalHeading(cleanedHtml, primaryTitle, siteTitle);
    primaryTitle = articleTitleFromSelfLinkedHeading(cleanedHtml, primaryTitle);
    if (!content.docsLike && !content.legalProvision) {
      markdown = articleSelfLinkedHeadlineMarkdown(markdown, content.html || cleanedHtml, primaryTitle);
    }
    if (primaryTitle !== originalPrimaryTitle) {
      var removedBrandedHeading = false;
      markdown = markdown.replace(/^#{1,6}[ \t]+([^\n]+)\n?/gm, function(line, heading) {
        if (removedBrandedHeading || normalizeText(heading) !== originalPrimaryTitle) return line;
        removedBrandedHeading = true;
        return "";
      });
    }
  }
  return { title: primaryTitle, markdown: markdown, identityResolved: identityResolved };
}

function articleTitleFromCompletePageHeading(content, html, title) {
  if (!document.body || !content || !html || !title || content.sourceOwnedLiveblog === true ||
      content.sourceOwnedUnattributedManual === true ||
      (content.contentType !== "article" && content.contentType !== "medical")) return title;

  var declaredTitle = normalizeText(document.title || "");
  if (!declaredTitle || declaredTitle === normalizeText(title)) return title;
  var articles = Array.prototype.filter.call(document.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && !sourceOwnershipInChrome(article);
  });
  if (articles.length !== 1 || articles[0].querySelector("article")) return title;
  var owner = articles[0];
  var headers = Array.prototype.filter.call(owner.children, function(node) {
    return node.tagName === "HEADER" && !elementSubtreeHidden(node);
  });
  if (headers.length !== 1) return title;
  var headings = Array.prototype.filter.call(headers[0].querySelectorAll("h1, h2, h3, h4, h5, h6"), function(heading) {
    return !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading);
  });
  if (headings.length !== 1 || normalizeText(headings[0].textContent || "") !== declaredTitle) return title;

  var exteriorHeadings = Array.prototype.filter.call(document.querySelectorAll("h1"), function(heading) {
    return !owner.contains(heading) && !elementSubtreeHidden(heading) &&
      normalizeText(heading.textContent || "") === normalizeText(title);
  });
  if (exteriorHeadings.length !== 1 ||
      !(exteriorHeadings[0].compareDocumentPosition(owner) & Node.DOCUMENT_POSITION_FOLLOWING)) return title;
  var conflictingTitle = Array.prototype.some.call(document.querySelectorAll(
    "meta[property='og:title' i], meta[name='twitter:title' i]"
  ), function(node) {
    var value = normalizeText(node.getAttribute("content") || "");
    return value && value !== declaredTitle;
  });
  var pageUrl = sourceOwnershipPageUrl(materializedCanonicalUrl() || location.href);
  if (conflictingTitle || sourceOwnedTitleMetadataConflictsWithHeading(declaredTitle, pageUrl)) return title;

  var selected = document.createElement("div");
  selected.innerHTML = html;
  var selectedHeadings = Array.prototype.filter.call(selected.querySelectorAll("h1, h2, h3, h4, h5, h6"), function(heading) {
    return normalizeText(heading.textContent || "") === declaredTitle;
  });
  if (selectedHeadings.length !== 1 ||
      normalizeText(selected.textContent || "") !== normalizeText(owner.textContent || "")) return title;
  return declaredTitle;
}

function articleTitleFromSelectedExternalBodyHeading(content, metadata, title) {
  if (!document.body || !content || content.sourceOwnedLiveblog === true || !content.html || !title ||
      (content.contentType !== "article" && content.contentType !== "medical")) return title;

  var ownershipMetadata = Object.assign({}, metadata || {});
  ownershipMetadata.title = ownershipMetadata.title || content.title || title || document.title;
  ownershipMetadata.siteName = ownershipMetadata.siteName || content.siteName || location.hostname;
  if (!ownershipMetadata.excerpt) {
    var descriptions = Array.prototype.map.call(document.querySelectorAll(
      "meta[name='description' i], meta[property='og:description' i]"
    ), function(node) {
      return normalizeText(node.getAttribute("content") || "");
    }).filter(Boolean);
    if (descriptions.length === 1) ownershipMetadata.excerpt = descriptions[0];
  }
  var semantic = sourceOwnedSemanticArticleOwnership(ownershipMetadata);
  var ownership = semantic && semantic.ownership;
  if (!ownership || ownership.titleIdentityProven !== true || !ownership.heading || !ownership.body ||
      !ownership.body.sourceNode || ownership.body.sourceNode.tagName !== "ARTICLE" ||
      ownership.heading.closest("article") || ownership.body.sourceNode.querySelector("article")) return title;

  var headline = normalizeText(ownership.heading.textContent || "");
  var declaredTitle = normalizeText(title);
  var titleRemainder = declaredTitle.slice(headline.length);
  if (!headline || !declaredTitle.startsWith(headline) ||
      (declaredTitle !== headline && !/^\s*[|·:–—-]\s*\S/u.test(titleRemainder))) return title;

  var main = ownership.heading.closest("main, [role~='main' i]");
  var headerNodes = sourceOwnedArticleHeaderNodes(ownership.headerContext);
  if (!main || !main.contains(ownership.body.sourceNode) || !headerNodes.length ||
      !headerNodes.some(function(node) { return node.contains(ownership.heading); }) ||
      !sourceOwnedArticleHeaderHasAttribution(headerNodes)) return title;

  var visibleHeadings = Array.prototype.filter.call(main.querySelectorAll("h1"), function(heading) {
    return !elementSubtreeHidden(heading);
  });
  var topLevelArticles = Array.prototype.filter.call(main.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && !article.parentElement.closest("article");
  });
  if (visibleHeadings.length !== 1 || visibleHeadings[0] !== ownership.heading ||
      topLevelArticles.length !== 1 || topLevelArticles[0] !== ownership.body.sourceNode) return title;

  var unrelatedHeaderMaterial = headerNodes.some(function(node) {
    if (!node || sourceOwnershipInChrome(node) || sourceOwnedHeaderContainsChrome(node) ||
        sourceOwnedHeaderContainsForeignArticle(node)) return true;
    var titleBranch = node.contains(ownership.heading);
    var attributionBranch = sourceOwnedArticleHeaderHasAttribution([node]);
    if (!titleBranch && !attributionBranch) return true;
    var blocks = Array.prototype.slice.call(node.querySelectorAll(
      "h2, h3, h4, h5, h6, blockquote, ul, ol, li, table, pre, code, figure, img, picture, video, audio, iframe, object, embed"
    ));
    var remainder = node.cloneNode(true);
    remainder.querySelectorAll(
      "h1, time, [itemprop~='datePublished' i], [itemprop~='dateModified' i], [class*='date' i], [class*='time' i], " +
      "[data-testid*='date' i], [rel~='author' i], [itemprop~='author' i], [class*='author' i], " +
      "[class*='byline' i], [class*='writer' i], [class*='reporter' i], a[href]"
    ).forEach(function(field) { field.remove(); });
    return blocks.length > 0 || !!normalizeText(remainder.textContent || "");
  });
  if (unrelatedHeaderMaterial) return title;

  var sourceArticle = ownership.body.sourceNode;
  var sourceParagraphNodes = Array.prototype.filter.call(sourceArticle.querySelectorAll("p"), function(paragraph) {
    return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "");
  });
  var sourceParagraphs = sourceParagraphNodes.map(function(paragraph) {
    return normalizeText(paragraph.textContent || "");
  });
  if (sourceParagraphs.length < 2) return title;

  var selected = document.createElement("div");
  selected.innerHTML = content.html;
  var selectedArticles = selected.querySelectorAll("article");
  if (selectedArticles.length > 1) return title;
  var selectedBody = selectedArticles.length === 1 ? selectedArticles[0] : selected;
  var selectedParagraphs = Array.prototype.map.call(selectedBody.querySelectorAll("p"), function(paragraph) {
    return normalizeText(paragraph.textContent || "");
  }).filter(Boolean);
  if (!sourceOwnedSelectedArticleTextMatches(sourceArticle, selectedBody, sourceParagraphs, selectedParagraphs)) return title;
  return headline || title;
}

function sourceOwnedSelectedArticleTextMatches(sourceArticle, selectedBody, sourceParagraphs, selectedParagraphs) {
  if (normalizeText(sourceArticle.textContent || "") !== normalizeText(selectedBody.textContent || "")) return false;
  var sourcePositions = new Map();
  sourceParagraphs.forEach(function(paragraph, index) {
    sourcePositions.set(paragraph, sourcePositions.has(paragraph) ? null : index);
  });
  if (Array.from(sourcePositions.values()).some(function(index) { return index === null; })) return false;

  var sourceIndex = 0;
  return selectedParagraphs.every(function(paragraph) {
    if (paragraph === sourceParagraphs[sourceIndex]) {
      sourceIndex += 1;
      return true;
    }
    if (sourcePositions.has(paragraph)) return false;
    var matchingSourceUnits = Array.prototype.filter.call(sourceArticle.querySelectorAll("*"), function(node) {
      return node.tagName !== "P" && !node.closest("p") && node.closest("article") === sourceArticle &&
        !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) &&
        normalizeText(node.textContent || "") === paragraph;
    });
    return matchingSourceUnits.length === 1;
  }) && sourceIndex === sourceParagraphs.length;
}
