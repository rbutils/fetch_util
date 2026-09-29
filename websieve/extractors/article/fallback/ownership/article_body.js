function sourceOwnershipPageUrl(value) {
  if (!value) return "";
  try {
    var parsed = new URL(value, location.href);
    if (!/^https?:$/.test(parsed.protocol) || parsed.username || parsed.password) return "";
    parsed.hash = "";
    return parsed.origin + parsed.pathname.replace(/\/$/, "") + parsed.search;
  } catch (_error) {
    return "";
  }
}

function sourceOwnershipCommonAncestor(left, right) {
  for (var node = left; node; node = node.parentElement) {
    if (node.contains(right)) return node;
  }
  return null;
}

function sourceOwnershipInChrome(node) {
  return !node || node.closest("nav, aside, footer, form, menu, [role~='navigation' i], [role~='menu' i], [role~='complementary' i], [class*='sidebar' i], [id*='sidebar' i], [class*='sidemenu' i], [id*='sidemenu' i], [class*='side-menu' i], [id*='side-menu' i], [class*='recommend' i], [id*='recommend' i], [class*='related-posts' i], [id*='related-posts' i]");
}

function sourceArticleBodyCandidates() {
  return Array.from(document.querySelectorAll([
    "article", "[itemprop~='articleBody' i]", "[data-article-body]",
    "[class*='article-body' i]", "[class*='article-content' i]", "[class*='story-content' i]",
    "[class*='post-content' i]", "[class*='entry-content' i]", "[class*='detail' i][class*='content' i]",
    "[class*='description-area' i]"
  ].join(", ")));
}

function sourceArticleBodyHasForeignLinkedArticle(ownerRoot, bodyNode, heading, currentUrl) {
  if (!ownerRoot || !bodyNode || !heading) return false;
  var articles = Array.from(ownerRoot.querySelectorAll("article"));
  if (ownerRoot.matches("article")) articles.unshift(ownerRoot);
  return articles.some(function(candidate) {
    if (candidate.contains(heading) && candidate.contains(bodyNode)) return false;
    if (commentRecordMarker(candidate) || candidate.closest(VISIBLE_COMMENT_THREAD_SELECTOR)) return false;
    if (sourceOwnershipInChrome(candidate) || candidate.closest("figure, [class*='read-more' i], [class*='readmore' i], [class*='embedRelatedStory' i]")) return false;
    return Array.from(candidate.querySelectorAll("h2 a[href], h3 a[href], h4 a[href]")).some(function(link) {
      if (link.closest("article") !== candidate) return false;
      if (elementVisuallyHidden(link) || sourceOwnershipInChrome(link) || normalizeText(link.textContent || "").length < 8) return false;
      var linkedPage = sourceOwnershipPageUrl(link.getAttribute("href"));
      return !!linkedPage && linkedPage !== currentUrl;
    });
  });
}

function sourceOwnershipHasLiveblogEvidence() {
  var current = sourceOwnershipPageUrl(location.href);
  if (typeof structuredDataNodes === "function" && typeof nodeTypes === "function") {
    var parent = structuredDataNodes().some(function(entity) {
      if (!nodeTypes(entity).some(function(type) { return /LiveBlogPosting/i.test(type); })) return false;
      var page = entity.mainEntityOfPage;
      if (page && typeof page === "object") page = page.url || page["@id"];
      return [entity.url, page, entity["@id"]].some(function(value) {
        return sourceOwnershipPageUrl(value) === current;
      });
    });
    if (parent) return true;
  }

  return Array.from(document.querySelectorAll("[data-liveblog], [id*='liveblog' i], [class*='liveblog' i], [class*='live-updates' i]"))
    .some(function(marker) {
      if (elementSubtreeHidden(marker) || sourceOwnershipInChrome(marker)) return false;
      var records = Array.from(marker.querySelectorAll("li, article, [data-liveblog-update], [itemprop~='liveBlogUpdate' i]")).filter(function(record) {
        if (elementSubtreeHidden(record) || sourceOwnershipInChrome(record)) return false;
        var heading = record.querySelector("h2, h3, h4, [itemprop~='headline' i]");
        var date = record.querySelector("time, [itemprop~='datePublished' i], [class*='update-time' i], [class*='timestamp' i], [class*='date' i]");
        var prose = normalizeText(Array.from(record.querySelectorAll("p, blockquote")).map(function(node) {
          return elementVisuallyHidden(node) ? "" : node.textContent || "";
        }).join(" "));
        return !!(heading && date && prose.length >= 40);
      });
      return records.length >= 2;
    });
}

function resolveCanonicalArticleBodyOwnership() {
  var metadata = focalSourceArticleMetadata();
  var currentUrl = sourceOwnershipPageUrl(location.href);
  var canonical = document.querySelector("link[rel~='canonical' i]");
  if (!metadata || !currentUrl || sourceOwnershipPageUrl(canonical && canonical.getAttribute("href")) !== currentUrl || sourceOwnershipHasLiveblogEvidence()) return null;

  var headings = Array.from(document.querySelectorAll("h1, [itemprop~='headline' i]")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && metadata.headlines.indexOf(normalizeText(heading.textContent || "")) !== -1;
  });
  if (headings.length !== 1) return null;
  var heading = headings[0];
  var candidates = sourceArticleBodyCandidates().filter(function(node) {
    if (sourceOwnershipInChrome(node) || elementSubtreeHidden(node)) return false;
    var shell = sourceOwnershipCommonAncestor(heading, node);
    if (!shell || shell === document.body || shell === document.documentElement || sourceOwnershipInChrome(shell)) return false;
    var shellHint = String(shell.className || "") + " " + String(shell.id || "");
    if (!shell.matches("article, main, [role~='main' i]") && !/(?:article|story|post|entry|detail|content|main)/i.test(shellHint)) return false;
    if (sourceArticleBodyHasForeignLinkedArticle(shell, node, heading, currentUrl)) return false;
    var body = focalOwnershipVisibleBody(node);
    if (!body || body.text.length < 120) return false;
    body.sourceNode = node;
    return true;
  });
  var innermost = candidates.filter(function(node) {
    return !candidates.some(function(other) { return node !== other && node.contains(other); });
  });
  if (innermost.length !== 1) return null;

  var node = innermost[0];
  var body = focalOwnershipVisibleBody(node);
  var ownerRoot = sourceOwnershipCommonAncestor(heading, node);
  if (!body || !ownerRoot) return null;
  body.sourceNode = node;
  var ownership = {
    node: node,
    ownerRoot: ownerRoot,
    heading: heading,
    title: normalizeText(heading.textContent || ""),
    body: body,
    proof: "canonical-article-metadata"
  };
  var headerContext = sourceOwnedArticleHeaderContext(ownership);
  if (headerContext === false) return null;
  ownership.headerContext = headerContext;
  if (sourceOwnedArticleHasUncoveredMaterial(ownership)) return null;
  return ownership;
}

function sourceOwnedArticleDescriptionMatchesBody(metadata, article) {
  var description = normalizeText(metadata && metadata.excerpt || "");
  if (!description || !article) return false;
  return Array.from(article.querySelectorAll("p")).some(function(paragraph) {
    return !elementVisuallyHidden(paragraph) && normalizeText(paragraph.textContent || "") === description;
  });
}

function sourceOwnedArticleHeaderDateNodes(headerNodes) {
  var selector = "time[datetime], time, [itemprop~='datePublished' i], [itemprop~='dateModified' i], " +
    "[class*='date' i], [class*='time' i], [data-testid*='date' i]";
  var nodes = [];
  sourceOwnedArticleHeaderNodes(headerNodes).forEach(function(header) {
    if (header.matches(selector)) nodes.push(header);
    nodes = nodes.concat(Array.from(header.querySelectorAll(selector)));
  });
  nodes = nodes.filter(function(node, index) {
    if (nodes.indexOf(node) !== index || elementVisuallyHidden(node) || !visiblePublishedTimeField(node)) return false;
    if (node.querySelector("a[href], p, h1, h2, h3, h4, article, main, figure, blockquote, pre, table")) return false;
    var value = node.getAttribute("datetime") || node.getAttribute("content") || node.textContent || "";
    return visiblePublicationDateLike(value);
  });
  return nodes.filter(function(node) {
    return !nodes.some(function(other) { return other !== node && other.contains(node); });
  });
}

function sourceOwnedArticleHeaderHasAttribution(headerNodes) {
  var roots = sourceOwnedArticleHeaderNodes(headerNodes);
  if (sourceOwnedArticleHeaderDateNodes(roots).length !== 1) return false;
  var authorSelector = "[rel~='author' i], [itemprop~='author' i], [class*='author-name' i], " +
    "[class*='byline' i], [class*='writer' i], [class*='reporter' i]";
  var authors = [];
  var authorLinks = [];
  var paragraphs = [];
  roots.forEach(function(root) {
    if (root.matches(authorSelector)) authors.push(root);
    authors = authors.concat(Array.from(root.querySelectorAll(authorSelector)));
    if (root.matches("a[href]")) authorLinks.push(root);
    authorLinks = authorLinks.concat(Array.from(root.querySelectorAll("a[href]")));
    if (root.matches("p")) paragraphs.push(root);
    paragraphs = paragraphs.concat(Array.from(root.querySelectorAll("p")));
  });
  var hasText = function(node) {
    return !elementVisuallyHidden(node) && !!normalizeText(node.textContent || "");
  };
  authors = authors.filter(function(node, index) {
    return authors.indexOf(node) === index && hasText(node) && !node.querySelector(authorSelector);
  });
  if (authors.length === 1) return true;
  if (authors.length > 1) return sourceOwnedArticleAuthorsShareGroup(authors, authorSelector);
  var current = sourceOwnershipPageUrl(location.href);
  var currentOrigin = current ? new URL(current).origin : "";
  authorLinks = authorLinks.filter(function(link, index) {
    if (authorLinks.indexOf(link) !== index || !hasText(link) || link.closest("h1, h2, h3, h4")) return false;
    var destination = sourceOwnershipPageUrl(link.getAttribute("href"));
    return !!(destination && destination !== current && currentOrigin && new URL(destination).origin === currentOrigin);
  });
  if (authorLinks.length === 1) return true;
  if (authorLinks.length > 1) return false;
  paragraphs = paragraphs.filter(function(paragraph, index) {
    return paragraphs.indexOf(paragraph) === index && hasText(paragraph) &&
      !paragraph.querySelector("time, [itemprop~='datePublished' i], [itemprop~='dateModified' i]");
  });
  return paragraphs.length === 1;
}

function sourceOwnedSemanticArticleOwnership(metadata) {
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

function sourceOwnedArticleBoundaryRoot(heading, article) {
  var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(main) {
    return !elementVisuallyHidden(main) && main.contains(heading) && main.contains(article);
  });
  if (mains.length === 1) return mains[0];
  if (mains.length > 1) return null;
  var outermostArticle = article;
  var parentArticle = outermostArticle.parentElement && outermostArticle.parentElement.closest("article");
  while (parentArticle) {
    outermostArticle = parentArticle;
    parentArticle = outermostArticle.parentElement && outermostArticle.parentElement.closest("article");
  }
  return outermostArticle === article ? sourceOwnershipCommonAncestor(heading, article) : outermostArticle;
}
