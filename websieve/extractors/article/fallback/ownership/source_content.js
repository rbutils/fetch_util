function sourceOwnedContentClone(source, preservedFooterNodes, ownership, sourceClones) {
  sourceClones = sourceClones || new WeakMap();
  var clone = visibilityPrunedClone(source, document, sourceClones);
  if (!clone) return document.createElement("div");
  sourceOwnedCleanCommentFormRoots(source, clone, sourceClones, ownership);
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
  var mixedSidebarWrappers = new WeakSet();
  var sidebarSelector = sourceOwnedMixedSidebarSelector();
  if (clone.matches(sidebarSelector) && sourceOwnedMixedSidebarLayoutWrapper(clone)) mixedSidebarWrappers.add(clone);
  Array.from(clone.querySelectorAll(sidebarSelector)).forEach(function(node) {
    if (sourceOwnedMixedSidebarLayoutWrapper(node)) mixedSidebarWrappers.add(node);
  });
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
    if (retainedHeading || mixedSidebarWrappers.has(node)) return;
    node.remove();
  });
  clone.querySelectorAll("input, textarea, select, button").forEach(function(node) { node.remove(); });
  return clone;
}

function sourceOwnedCleanCommentFormRoots(source, clone, sourceClones, ownership) {
  if (!ownership || !ownership.ownerRoot || !ownership.ownerRoot.contains(source) ||
      sourceClones.get(source) !== clone) return;
  var body = ownership.body.sourceNode === source;
  var selectedHeader = sourceOwnedArticleHeaderNodes(ownership.headerContext).indexOf(source) !== -1;
  if ((!body && !selectedHeader) || !sourceOwnedCommentFormParagraphsMapExactly(source, clone, sourceClones)) return;
  if (body && !sourceOwnedCommentFormNoUnprovenParagraphsOutsideBody(source, ownership)) return;

  sourceOwnedCommentFormRoots(source).forEach(function(wrapper) {
    var wrapperClone = sourceClones.get(wrapper);
    if (!wrapperClone || !clone.contains(wrapperClone) || !sourceOwnedCommentFormRootHasInterface(wrapper, wrapperClone, sourceClones, ownership)) return;
    var rootRemoved = stripEmptyCommentUi(wrapperClone);
    if (wrapperClone.matches("form") && hasMaterialCommentContent(wrapperClone)) {
      preserveMaterialCommentForm(clone, wrapperClone);
    }
    if (rootRemoved && wrapperClone.parentNode && !wrapperClone.children.length &&
        !normalizeText(wrapperClone.textContent || "")) wrapperClone.remove();
  });
}

function sourceOwnedCommentFormParagraphsMapExactly(source, clone, sourceClones) {
  var paragraphs = Array.from(source.querySelectorAll("p")).filter(function(node) {
    return !elementVisuallyHidden(node);
  });
  if (source.matches("p") && !elementVisuallyHidden(source)) paragraphs.unshift(source);
  if (!paragraphs.length) return false;
  var previousClone = null;
  return paragraphs.every(function(paragraph) {
    var paragraphClone = sourceClones.get(paragraph);
    if (!paragraphClone || paragraphClone.localName !== "p" || !clone.contains(paragraphClone)) return false;
    if (previousClone && !(previousClone.compareDocumentPosition(paragraphClone) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    previousClone = paragraphClone;
    return true;
  });
}

function sourceOwnedCommentFormNoUnprovenParagraphsOutsideBody(source, ownership) {
  var headers = sourceOwnedArticleHeaderNodes(ownership.headerContext);
  return !Array.from(ownership.ownerRoot.querySelectorAll("p, blockquote")).some(function(node) {
    if (elementVisuallyHidden(node) || source.contains(node)) return false;
    if (headers.some(function(header) { return header === node || header.contains(node); })) return false;
    return !sourceOwnershipInChrome(node);
  });
}

function sourceOwnedCommentFormRoots(source) {
  var selector = "[class~='comment-form' i], [id='comment-form-div' i]";
  var roots = Array.from(source.querySelectorAll(selector));
  if (source.matches(selector)) roots.unshift(source);
  return roots;
}

function sourceOwnedCommentFormRootHasInterface(sourceRoot, cloneRoot, sourceClones, ownership) {
  var sourceForms = sourceRoot.matches("form") ? [sourceRoot] : Array.from(sourceRoot.querySelectorAll("form"));
  var cloneForms = sourceForms.filter(function(form) {
    var controls = Array.from(form.querySelectorAll("input, textarea, select")).filter(function(control) {
      return !elementVisuallyHidden(control);
    });
    var formClone = sourceClones.get(form);
    return controls.length > 0 && formClone && cloneRoot.contains(formClone);
  });
  if (!cloneForms.length) return false;

  var headings = Array.from(sourceRoot.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && sourceOwnedCommentFormHeadingMatches(heading, ownership) &&
      sourceClones.get(heading) && cloneRoot.contains(sourceClones.get(heading));
  });
  return headings.length === 1 || hasMarkedCommentContent(sourceRoot) || cloneForms.some(hasMaterialCommentContent);
}

function sourceOwnedCommentFormHeadingMatches(heading, ownership) {
  if (heading.closest("blockquote, [itemprop~='comment' i], [data-fetchutil-social-comment], [class~='comment' i], [class~='comments' i], [class~='reply' i], [class~='comment-body' i], [class~='comment-content' i], [class~='reply-body' i], [class~='reply-content' i]")) return false;
  var article = heading.closest("article");
  if (article && article !== ownership.ownerRoot && article !== ownership.body.sourceNode) return false;
  var text = normalizeText(heading.textContent || "");
  if (text.normalize) text = text.normalize("NFC");
  return EMPTY_COMMENT_FORM_HEADING_PATTERN.test(text);
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

    var headingSelector = ownership.proof === "declared-complete-physical-article-body" ? "h1, h2, [itemprop~='headline' i]" : "h1";
    var headings = Array.from(header.querySelectorAll(headingSelector)).filter(function(node) {
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
    if (sourceOwnedPlainArticleInterfaceNode(node, ownership)) return false;
    if (elementVisuallyHidden(node) || sourceOwnershipInChrome(node) || body.contains(node) || node.contains(ownership.heading)) return false;
    if (!sourceOwnedHeaderPrecedesBody(node, body)) return false;
    var article = node.closest("article");
    return !article || article === ownership.ownerRoot ||
      (!commentRecordMarker(article) && !article.closest(VISIBLE_COMMENT_THREAD_SELECTOR));
  });
}

function genericSourceOwnedPageContent(metadata) {
  var ownership = resolveCanonicalArticleBodyOwnership();
  if (ownership) {
    var preview = fallbackFocalHeadlineOwnership();
    var article = sourceOwnedArticleMarkup(ownership);
    var previewRoot = ownership.body.sourceNode === ownership.ownerRoot ? article.firstElementChild : article;
    var publicPreview = preview && preview.node === ownership.ownerRoot && preview.body.publicPreview &&
      previewRoot && focalOwnershipRetainPublicPreview(previewRoot) ? preview.body : null;
    return canonicalArticleBodyContent(metadata, ownership, article, publicPreview);
  }
  var semantic = sourceOwnedSemanticArticleOwnership(metadata);
  if (semantic.ownership) return canonicalArticleBodyContent(metadata, semantic.ownership);
  if (semantic.considered) return null;
  var headed = sourceOwnedHeadedBranchOwnership(metadata);
  if (headed) return canonicalArticleBodyContent(metadata, headed);
  var plain = sourceOwnedPlainArticleBodyOwnership(metadata);
  return plain ? canonicalArticleBodyContent(metadata, plain) : null;
}
