function sourceOwnedSemanticArticleOwnership(metadata) {
  return withSourceVisibilityRead(function() {
    return computeSourceOwnedSemanticArticleOwnership(metadata);
  });
}

function computeSourceOwnedSemanticArticleOwnership(metadata) {
  if (!metadata) return { considered: false, ownership: null };
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && !sourceOwnershipInChrome(heading);
  });
  if (headings.length !== 1) return { considered: false, ownership: null };
  var heading = headings[0];
  var headline = normalizeText(heading.textContent || "");
  var sourceMetadata = focalSourceArticleMetadata();
  var titleMatches = articleTitleFromOwnedHeading(heading.outerHTML, metadata.title, metadata.siteName) === headline;
  var declaredHeadlineMatches = !!(sourceMetadata && sourceMetadata.headlines.indexOf(headline) !== -1);
  var titleIdentityProven = titleMatches || declaredHeadlineMatches;
  var pageTitleRemainder = normalizeText(metadata.title || "").slice(headline.length);
  var brandedPageTitleMatches = normalizeText(metadata.title || "").indexOf(headline) === 0 &&
    /^\s*(?:-|–|—|:|：|\|)\s*\S/.test(pageTitleRemainder);
  if (!titleMatches && !declaredHeadlineMatches && !heading.closest("article") && !brandedPageTitleMatches) {
    return { considered: false, ownership: null };
  }

  var articles = Array.from(document.querySelectorAll("article")).filter(function(article) {
    return !article.parentElement.closest("article") && !elementSubtreeHidden(article) &&
      !sourceOwnershipInChrome(article) && !commentRecordMarker(article) && !article.closest(VISIBLE_COMMENT_THREAD_SELECTOR);
  });
  var articleBodies = articles.map(function(article) {
    var body = focalOwnershipVisibleBody(article);
    return body && body.text.length >= 120 ? { article: article, body: body } : null;
  }).filter(Boolean);
  if (!articleBodies.length) return { considered: false, ownership: null };
  var focalArticle = heading.closest("article");
  var candidates = articleBodies.filter(function(record) {
    return focalArticle ? record.article === focalArticle : sourceOwnedArticleDescriptionMatchesBody(metadata, record.article);
  });
  if (candidates.length !== 1) {
    return { considered: true, ownership: null };
  }

  var article = candidates[0].article;
  var body = candidates[0].body;
  // Keep the established extraction path when serializing this root would make
  // the shared related-container cleaner discard the selected article itself.
  if (article.matches(RELATED_CONTAINER_SELECTOR)) return { considered: true, ownership: null };
  var ownerRoot = sourceOwnedArticleBoundaryRoot(heading, article);
  if (!ownerRoot || ownerRoot === document.body || ownerRoot === document.documentElement || sourceOwnershipInChrome(ownerRoot)) {
    return { considered: true, ownership: null };
  }
  body.sourceNode = article;
  var ownership = {
    node: article,
    ownerRoot: ownerRoot,
    heading: heading,
    title: headline,
    body: body,
    proof: "unique-semantic-article-source-identity"
  };
  ownership.titleIdentityProven = titleIdentityProven;
  var headerContext = sourceOwnedArticleHeaderContext(ownership);
  if (headerContext === false) return { considered: true, ownership: null };
  ownership.headerContext = headerContext;
  if (!article.contains(heading)) {
    var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(main) {
      return !elementVisuallyHidden(main) && main.contains(heading) && main.contains(article);
    });
    var headerNodes = sourceOwnedArticleHeaderNodes(headerContext);
    if (mains.length > 1 || !sourceOwnedArticleDescriptionMatchesBody(metadata, article) ||
        !headerNodes.length || !sourceOwnedArticleHeaderHasAttribution(headerNodes)) {
      return { considered: true, ownership: null };
    }
    ownership.titleIdentityProven = true;
  }
  if (sourceOwnedArticleHasUncoveredMaterial(ownership)) {
    return { considered: true, ownership: null };
  }
  return { considered: true, ownership: ownership };
}
