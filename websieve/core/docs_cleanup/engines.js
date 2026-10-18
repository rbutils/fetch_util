function docsContentBySelectors(metadata, selectors, options) {
  var node = firstMatchingNode(selectors);
  return docsContentForNode(metadata, node, options);
}

function docsEngineContent(metadata, info, descriptor) {
  info = info || docsSystemInfo(metadata);
  if (!info || info.system !== descriptor.system) return null;

  var headingFormatter = descriptor.headingFormatter || function(text) { return cleanDocsHeadingText(text); };
  var titleFormatter = descriptor.titleFormatter || descriptor.headingFormatter;
  var options = {
    preserveSelector: descriptor.preserveSelector,
    pruneSourceVisibility: descriptor.pruneSourceVisibility === true,
    rewriteRoot: function(root) {
      if (descriptor.removeSelectors) {
        root.querySelectorAll(descriptor.removeSelectors).forEach(function(el) {
          el.remove();
        });
      }
      if (descriptor.removeTextPattern) {
        removeNodesByText(root, descriptor.removeTextSelector || "a, button, div, p, span, li", descriptor.removeTextPattern);
      }
      if (typeof descriptor.rewriteRoot === "function") descriptor.rewriteRoot(root, titleText);
      if (descriptor.headingFormatter !== false) cleanDocsHeadings(root, descriptor.headingSelector, headingFormatter);
    }
  };
  var titleText = null;

  if (descriptor.preferFragmentTitle === false) {
    titleText = docsTitleText(metadata, descriptor.titleSelectors, descriptor.fallbackTitle, titleFormatter);
    options.title = titleText;
  } else {
    options.titleSelectors = descriptor.titleSelectors;
    options.fallbackTitle = descriptor.fallbackTitle;
    options.titleFormatter = titleFormatter;
  }

  var node = firstMatchingNode(descriptor.rootSelectors);
  if (typeof descriptor.contentType === "function") options.contentType = descriptor.contentType(node, info);
  else if (descriptor.contentType) options.contentType = descriptor.contentType;
  return docsContentForNode(metadata, node, options);
}

function docsContentForNode(metadata, node, options) {
  options = options || {};
  if (!node) return null;

  var articleOptions = {};
  Object.keys(options).forEach(function(key) {
    if (key === "titleSelectors" || key === "fallbackTitle" || key === "preferFragmentTitle" || key === "titleFormatter") return;
    articleOptions[key] = options[key];
  });

  if (!articleOptions.title && (options.titleSelectors || options.fallbackTitle)) {
    var title = options.preferFragmentTitle === false ? null : docsFragmentTitle(node);
    title = formatDocsTitle(title, options.titleFormatter, metadata) ||
      docsTitleText(metadata, options.titleSelectors, options.fallbackTitle, options.titleFormatter);
    articleOptions.title = title;
  }

  return docsArticleContent(metadata, node, articleOptions);
}

function docsArticleContent(metadata, node, options) {
  if (!node) return null;

  options = options || {};
  var sourceNode = options.focusFragment === false ? node : focusedDocsNode(node);
  var pruneSourceVisibility = options.pruneSourceVisibility === true ||
    (options.pruneSourceVisibility !== false && sourceNode.isConnected &&
      sourceNode.ownerDocument === document && sourceNode.getRootNode() === document);
  var materialRoot = options.preserveSourceMaterialRoot;
  var referenceRoots = (options.preserveSourceReferenceRoots || []).filter(function(reference) { return sourceNode.contains(reference); });
  var preserveCodeTargets = pruneSourceVisibility && sourceNode.querySelector("pre a[id], pre a[name]");
  var authoredReferences = docsAuthoredSourceReferences(sourceNode);
  var needsSourceClones = (materialRoot && sourceNode.contains(materialRoot)) || referenceRoots.length || preserveCodeTargets ||
    (pruneSourceVisibility && authoredReferences.length);
  var sourceClones = needsSourceClones ? new Map() : null;
  var readableSource = pruneSourceVisibility ?
    visibilityPrunedClone(sourceNode, document, sourceClones, options.preserveMaterializedCollection === true) : sourceNode;
  if (preserveCodeTargets) restorePrunedNamedCodeTargets(sourceNode, sourceClones);
  if (sourceClones && materialRoot) {
    for (var ancestor = materialRoot; ancestor && sourceNode.contains(ancestor); ancestor = ancestor.parentElement) {
      var clone = sourceClones.get(ancestor);
      if (clone) Array.from(clone.classList).forEach(function(token) {
        if (/(?:sidebar|side-nav|sidenav|left-rail|right-rail|article-drawer|toc-drawer|table-of-contents|mobile-menu|mobile-nav|hamburger-menu|toc)/i.test(token)) {
          clone.classList.remove(token);
        }
      });
      if (ancestor === sourceNode) break;
    }
  }
  referenceRoots.forEach(function(reference) {
    var clone = sourceClones.get(reference);
    if (clone) clone.setAttribute("data-fetchutil-source-owned-primary", "true");
  });
  if (readableSource !== sourceNode && typeof options.prepareRoot === "function") options.prepareRoot(readableSource);
  var cleanedElements = authoredReferences.length ? new WeakMap() : null;
  var root = cleanClone(readableSource, options.preserveSelector, cleanedElements);
  rememberDocsAuthoredReferences(root, sourceNode, readableSource, authoredReferences, sourceClones, cleanedElements);

  if (options.preserveAuthoredSections && root.querySelector(VISIBLE_COMMENT_THREAD_SELECTOR + ", " + VISIBLE_COMMENT_RECORD_SELECTOR)) {
    visibleCommentThreadRoots(root).forEach(function(thread) {
      var records = [thread].concat(Array.from(thread.querySelectorAll(VISIBLE_COMMENT_RECORD_SELECTOR)));
      if (records.some(function(record) { return commentRecordMarker(record) && commentThreadHasMaterial(record); })) {
        thread.setAttribute("data-fetchutil-social-comment", "true");
      }
    });
  }
  cleanupAgentRoot(root);

  if (!options.preserveAuthoredSections) cleanupDocsRoot(root, options);

  if (typeof options.rewriteRoot === "function") {
    try {
      options.rewriteRoot(root);
    } catch(e) {
    }
  }

  var markdown;
  try {
    markdown = docsMarkdownForRoot(root, options.preserveCleanedRoot === true).trim();
  } catch(e) {
    markdown = "";
  }
  if (typeof options.postProcessMarkdown === "function") markdown = options.postProcessMarkdown(markdown, root);
  var title = cleanDocsHeadingText(options.title || docsFragmentTitle(node) || firstRootText(root, ["h1", "header h1", "h2"]) || "") || null;
  var description = options.description || firstRootText(root, ["p"]);

  if (!markdown) {
    if (!title && !description) return null;

    return articleContentFromParts({
      title: title || metadata.title,
      description: description || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      docsLike: true,
      hostAware: options.hostAware !== false
    });
  }

  if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

  return {
    title: title || metadata.title,
    byline: metadata.byline,
    excerpt: description || metadata.excerpt,
    siteName: metadata.siteName || location.hostname,
    publishedTime: metadata.publishedTime,
    html: root.innerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    docsLike: true,
    hostAware: options.hostAware !== false,
    readerMode: false,
    contentType: options.contentType || "article"
  };
}
