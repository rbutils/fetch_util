function sourceOwnedContentClone(source, preservedFooterNodes) {
  var sourceClones = new WeakMap();
  var clone = visibilityPrunedClone(source, document, sourceClones);
  if (!clone) return document.createElement("div");
  var editorialHeadings = [];
  if (typeof genericArticleEditorialHeading === "function") {
    Array.from(source.querySelectorAll("h2[id], h3[id], h4[id], h5[id], h6[id]")).forEach(function(node) {
      var widget = node.parentElement && node.parentElement.closest("form, [class*='newsletter' i], [id*='newsletter' i], [class*='subscribe' i], [id*='subscribe' i]");
      if (!widget && genericArticleEditorialHeading(node)) {
        editorialHeadings.push({ id: node.id, tag: node.tagName, text: normalizeText(node.textContent || "") });
      }
    });
  }
  materializeEditorialFrameLinks(source, clone);
  normalizeCodeSurfaces(clone);
  cleanupCookieChrome(clone);
  clone.querySelectorAll("script, style, noscript, template, nav, aside, form, dialog, [role~='navigation' i], [role~='complementary' i], [role='toolbar' i]").forEach(function(node) {
    node.remove();
  });
  clone.querySelectorAll("footer").forEach(function(footer) {
    var preserved = (preservedFooterNodes || []).some(function(sourceFooter) {
      return sourceClones.get(sourceFooter) === footer;
    });
    if (!preserved) footer.remove();
  });
  clone.querySelectorAll("[class*='sidebar' i], [id*='sidebar' i], [class*='newsletter' i], [id*='newsletter' i], [class*='subscribe' i], [id*='subscribe' i], [data-ad], [data-ads]").forEach(function(node) {
    var retainedHeading = editorialHeadings.some(function(heading) {
      return node.id === heading.id && node.tagName === heading.tag && normalizeText(node.textContent || "") === heading.text;
    });
    if (retainedHeading) return;
    node.remove();
  });
  clone.querySelectorAll("input, textarea, select, button").forEach(function(node) { node.remove(); });
  return clone;
}

function sourceOwnedHeaderShareControl(anchor) {
  var author = "[rel~='author' i], [itemprop~='author' i], [class*='byline' i], [class*='author' i]";
  if (anchor.closest(author) || anchor.closest("h1, h2, h3, h4, h5, h6, p, blockquote, figure, [itemprop~='articleBody' i]")) return false;
  var identity = [anchor.getAttribute("rel"), anchor.className, anchor.id, anchor.getAttribute("data-event_label")].join(" ");
  if (/(?:permalink|canonical|bookmark)/i.test(identity)) return false;
  var label = normalizeText([anchor.getAttribute("aria-label"), anchor.getAttribute("title"), anchor.textContent].filter(Boolean).join(" "));
  var explicitShareAction = /^(?:share(?:\s+(?:on|to|this)\s+\S+)?|copy(?:\s+this)?\s+link)$/i.test(label);
  var explicitShareControl = /(?:share[-_ ]?(?:button|control|link|icon)|social[-_ ]share|full_social|social_mobile)/i.test(identity);
  return explicitShareAction || (explicitShareControl && /^(?:email|print)$/i.test(label));
}

function sourceOwnedArticleHeaderContext(ownership) {
  if (!ownership.heading || !ownership.ownerRoot || !ownership.body || !ownership.body.sourceNode ||
      !ownership.ownerRoot.contains(ownership.heading)) return false;

  var body = ownership.body.sourceNode;
  if (body.contains(ownership.heading)) return null;
  var candidates = Array.from(ownership.ownerRoot.querySelectorAll("header, [class*='article-header' i], [class*='entry-header' i]"));
  if (ownership.ownerRoot.matches("header, [class*='article-header' i], [class*='entry-header' i]")) candidates.unshift(ownership.ownerRoot);
  for (var ancestor = ownership.heading.parentElement; ancestor && ancestor !== ownership.ownerRoot; ancestor = ancestor.parentElement) {
    if (/^(?:DIV|SECTION|HEADER|HGROUP|ARTICLE)$/.test(ancestor.tagName)) candidates.push(ancestor);
  }
  candidates = candidates.filter(function(node, index) { return candidates.indexOf(node) === index; });
  candidates = candidates.filter(function(header) {
    return header.contains(ownership.heading) && !elementSubtreeHidden(header) && !sourceOwnershipInChrome(header);
  });
  if (!candidates.length) {
    var prefix = sourceOwnedArticleHeaderPrefix(ownership);
    return prefix || (sourceOwnedHeaderContributions(ownership).length ? false : null);
  }

  var safe = candidates.filter(function(header) {
    if (!ownership.ownerRoot.contains(header) || header === ownership.ownerRoot || header.contains(body) ||
        !sourceOwnedHeaderPrecedesBody(header, body) || sourceOwnedHeaderContainsChrome(header) ||
        sourceOwnedHeaderContainsForeignArticle(header)) return false;

    var headings = Array.from(header.querySelectorAll("h1")).filter(function(node) {
      return !elementVisuallyHidden(node) && !node.closest("nav, aside, footer, form, [role~='navigation' i], [role~='complementary' i]");
    });
    return headings.length === 1 && headings[0] === ownership.heading;
  });
  if (safe.length !== candidates.length) return false;

  var outermost = safe.filter(function(header) {
    return !safe.some(function(other) { return header !== other && other.contains(header); });
  });
  if (outermost.length !== 1) return false;

  var header = outermost[0];
  var uncovered = sourceOwnedHeaderContributions(ownership).some(function(node) { return !header.contains(node); });
  if (!uncovered) return header;
  return sourceOwnedArticleHeaderPrefix(ownership) || false;
}


function sourceOwnedArticleHeaderNodes(context) {
  if (!context) return [];
  return Array.isArray(context) ? context : [context];
}

function sourceOwnedArticleAuthorsShareGroup(authors, authorSelector) {
  if (!Array.isArray(authors) || authors.length < 2) return false;
  var selector = authorSelector || "[rel~='author' i], [itemprop~='author' i], [class*='author-name' i], " +
    "[class*='byline' i], [class*='writer' i], [class*='reporter' i]";
  var leaves = authors.filter(function(author, index) {
    return authors.indexOf(author) === index && !elementSubtreeHidden(author) &&
      normalizeText(author.textContent || "") && !author.querySelector(selector);
  });
  if (leaves.length !== authors.length) return false;
  var group = leaves[0].parentElement;
  if (!group || !group.matches("[class*='author' i], [class*='writer' i], [class*='byline' i]")) return false;
  if (!leaves.every(function(author) { return author.parentElement === group; })) return false;
  return Array.from(group.childNodes).every(function(node) {
    if (node.nodeType === 3) return !normalizeText(node.nodeValue || "").replace(/\band\b|[&|·•,;:/+–—-]/gi, "");
    return node.nodeType === 1 && leaves.indexOf(node) !== -1;
  });
}

function sourceOwnedArticleHeaderPrefix(ownership) {
  var root = ownership.ownerRoot;
  var body = ownership.body.sourceNode;
  var headingBranch = sourceOwnedDirectChild(root, ownership.heading);
  var bodyBranch = sourceOwnedDirectChild(root, body);
  if (!headingBranch || !bodyBranch || headingBranch === bodyBranch) return null;

  var children = Array.from(root.children);
  var headingIndex = children.indexOf(headingBranch);
  var bodyIndex = children.indexOf(bodyBranch);
  if (headingIndex < 0 || bodyIndex <= headingIndex) return null;

  var startIndex = headingIndex;
  var precedingAttributions = children.slice(0, headingIndex).filter(function(node) {
    return sourceOwnedArticleHeaderHasAttribution([node]);
  });
  if (precedingAttributions.length === 1) {
    startIndex = children.indexOf(precedingAttributions[0]);
  }
  var prefix = children.slice(startIndex, bodyIndex);
  if (!prefix.length || prefix.some(function(node) {
    return elementSubtreeHidden(node) || sourceOwnershipInChrome(node) ||
      sourceOwnedHeaderContainsChrome(node) || sourceOwnedHeaderContainsForeignArticle(node);
  })) return null;

  var contributions = sourceOwnedHeaderContributions(ownership);
  if (contributions.some(function(node) {
    return !prefix.some(function(candidate) { return candidate === node || candidate.contains(node); });
  })) return null;
  return prefix;
}

function sourceOwnedDirectChild(root, node) {
  if (!root || !node || !root.contains(node)) return null;
  var child = node;
  while (child.parentElement && child.parentElement !== root) child = child.parentElement;
  return child.parentElement === root ? child : null;
}

function sourceOwnedHeaderPrecedesBody(header, body) {
  return !!(header.compareDocumentPosition(body) & 4);
}

function sourceOwnedHeaderContainsChrome(header) {
  return !!header.querySelector("nav, aside, footer, form, [role~='navigation' i], [role~='complementary' i], [class*='sidebar' i], [id*='sidebar' i], [class*='recommend' i], [id*='recommend' i], [class*='related' i], [id*='related' i]");
}

function sourceOwnedHeaderContainsForeignArticle(header) {
  return Array.from(header.querySelectorAll("article")).some(function(article) {
    return !commentRecordMarker(article) && !article.closest(VISIBLE_COMMENT_THREAD_SELECTOR);
  });
}

function sourceOwnedHeaderContributions(ownership) {
  var body = ownership.body.sourceNode;
  return Array.from(ownership.ownerRoot.querySelectorAll("p, h2, h3, h4, h5, h6, blockquote, ul, ol, li, table, pre, code, figure, img, picture, video, audio, iframe, object, embed, a[href]")).filter(function(node) {
    if (elementVisuallyHidden(node) || sourceOwnershipInChrome(node) || body.contains(node) || node.contains(ownership.heading)) return false;
    if (!sourceOwnedHeaderPrecedesBody(node, body)) return false;
    var article = node.closest("article");
    return !article || article === ownership.ownerRoot ||
      (!commentRecordMarker(article) && !article.closest(VISIBLE_COMMENT_THREAD_SELECTOR));
  });
}

function genericSourceOwnedPageContent(metadata) {
  var ownership = resolveCanonicalArticleBodyOwnership();
  if (ownership) return canonicalArticleBodyContent(metadata, ownership);
  var semantic = sourceOwnedSemanticArticleOwnership(metadata);
  return semantic.ownership ? canonicalArticleBodyContent(metadata, semantic.ownership) : null;
}

function canonicalArticleBodyContent(metadata, ownership) {
  var article = sourceOwnedArticleMarkup(ownership);
  var text = normalizeText(article.textContent || "");
  var headerMetadata = sourceOwnedFallbackHeaderMetadata(ownership.body.sourceNode, ownership.title, metadata || {});
  var attribution = headerMetadata || metadata || {};
  var titleIdentityUnproven = ownership.titleIdentityProven === false;
  return {
    title: titleIdentityUnproven ? (metadata && metadata.title) || ownership.title : ownership.title,
    byline: attribution.byline || null,
    excerpt: fallbackArticleExcerpt(ownership.body.sourceNode, text, metadata, true),
    siteName: (metadata && metadata.siteName) || location.hostname,
    publishedTime: attribution.publishedTime || null,
    html: article.innerHTML,
    textContent: text,
    readerMode: false,
    contentType: "article",
    sourceOwnedFocalArticle: true,
    sourceOwnedTitleIdentityUnproven: titleIdentityUnproven,
    sourceOwnedHeadingTitle: ownership.title,
    focalPermalinkContent: true
  };
}
