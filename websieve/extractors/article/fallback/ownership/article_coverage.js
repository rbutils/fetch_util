function sourceOwnedArticleMarkup(ownership) {
  var article = document.createElement("article");
  var source = ownership.body.sourceNode;
  var headers = sourceOwnedArticleHeaderNodes(ownership.headerContext);
  var threads = sourceOwnedArticleMaterialCommentThreads(ownership);
  var bodyFooters = sourceOwnedArticleCommentFooters(threads.filter(function(thread) {
    return source.contains(thread);
  }));

  if (headers.length) {
    headers.forEach(function(header) {
      var headerThreads = threads.filter(function(thread) { return header.contains(thread); });
      article.appendChild(sourceOwnedArticleHeaderClone(header, sourceOwnedArticleCommentFooters(headerThreads), ownership));
    });
  } else if (ownership.heading && !source.contains(ownership.heading)) {
    article.appendChild(sourceOwnedContentClone(ownership.heading));
  }
  var bodySourceClones = new WeakMap();
  article.appendChild(sourceOwnedContentClone(source, bodyFooters, ownership, bodySourceClones));
  threads.filter(function(thread) { return source.contains(thread); }).forEach(function(thread) {
    var clone = bodySourceClones.get(thread);
    if (clone && article.contains(clone)) clone.setAttribute("data-fetchutil-social-comment", "true");
  });
  stripSourceOwnedTerminalArticleFurniture(article, bodySourceClones);

  threads.filter(function(thread) {
    return !source.contains(thread) && !headers.some(function(header) { return header.contains(thread); });
  }).forEach(function(thread) {
    var markup = cleanFocalCommentClone(thread);
    if (markup) article.insertAdjacentHTML("beforeend", markup);
  });
  stripArticleAdWidgets(article);
  return article;
}

function sourceOwnedArticleHeaderClone(header, preservedFooters, ownership) {
  var clone = sourceOwnedContentClone(header, preservedFooters, ownership);
  Array.from(clone.querySelectorAll("a[href]")).forEach(function(anchor) {
    if (!sourceOwnedHeaderShareControl(anchor)) return;
    var item = anchor.closest("li");
    if (item && item.querySelectorAll("a[href]").length === 1 && !normalizeText(item.textContent || "")) item.remove();
    else anchor.remove();
  });
  clone.querySelectorAll("[class*='share' i], [class*='social' i]").forEach(function(node) {
    if (!normalizeText(node.textContent || "") && !node.querySelector("a[href], img, svg, video, figure")) node.remove();
  });
  return clone;
}

function sourceOwnedArticleCommentFooters(threads) {
  var footers = [];
  threads.forEach(function(thread) {
    Array.from(thread.querySelectorAll("footer")).forEach(function(footer) {
      if (footers.indexOf(footer) === -1) footers.push(footer);
    });
  });
  return footers;
}

function sourceOwnedArticleMaterialCommentThreads(ownership) {
  return visibleCommentThreadRoots(document).filter(function(thread) {
    return commentThreadHasMaterial(thread) && focalCommentThreadBelongsToArticle(thread, ownership);
  });
}

function sourceOwnedArticleHasUncoveredMaterial(ownership) {
  var root = ownership.ownerRoot;
  var threadRoots = visibleCommentThreadRoots(root);
  var ownedThreads = sourceOwnedArticleMaterialCommentThreads(ownership);
  if (sourceOwnedArticleHasUncoveredText(ownership, threadRoots, ownedThreads)) return true;

  var selector = "p, h2, h3, h4, h5, h6, ul, ol, li, blockquote, table, pre, code, figure, img, picture, video, audio, iframe, object, embed, a[href], [itemprop~='articleBody' i], [data-article-body]";
  return Array.from(root.querySelectorAll(selector)).some(function(node) {
    return !sourceOwnedArticleMaterialNodeCovered(node, ownership, threadRoots, ownedThreads);
  });
}

function sourceOwnedArticleHasUncoveredText(ownership, threadRoots, ownedThreads) {
  var walker = document.createTreeWalker(ownership.ownerRoot, NodeFilter.SHOW_TEXT);
  var text;
  while ((text = walker.nextNode())) {
    if (!normalizeText(text.nodeValue || "")) continue;
    var element = text.parentElement;
    if (!element || element.closest("script, style, noscript, template") || elementVisuallyHidden(element)) continue;
    if (!sourceOwnedArticleMaterialNodeCovered(element, ownership, threadRoots, ownedThreads)) return true;
  }
  return false;
}

function sourceOwnedArticleMaterialNodeCovered(node, ownership, threadRoots, ownedThreads) {
  var commentThread = threadRoots.find(function(thread) { return thread === node || thread.contains(node); });
  if (commentThread && commentThreadHasMaterial(commentThread)) {
    return ownedThreads.indexOf(commentThread) !== -1;
  }

  if (elementVisuallyHidden(node) || sourceOwnershipInChrome(node)) return true;
  if (ownership.heading && (node === ownership.heading || ownership.heading.contains(node))) return true;
  var body = ownership.body.sourceNode;
  if (body === node || body.contains(node)) return true;
  if (sourceOwnedArticleHeaderNodes(ownership.headerContext).some(function(header) {
    return header === node || header.contains(node);
  })) return true;
  return sourceOwnedArticleIndependentLinkedCollection(node, ownership.ownerRoot, ownership);
}

function sourceOwnedArticleIndependentLinkedCollection(node, root, ownership) {
  if (!node || !root || typeof genericListStructuredCardLink !== "function") return false;
  var list = node.closest("ul, ol");
  if (!list) {
    var collectionHeading = node.closest("h1, h2, h3, h4, h5, h6, [class*='title' i], [class*='heading' i]");
    if (!collectionHeading || collectionHeading === (ownership && ownership.heading) || !root.contains(collectionHeading) ||
        elementSubtreeHidden(collectionHeading) || sourceOwnershipInChrome(collectionHeading) ||
        collectionHeading.querySelector("a[href], img, picture, video, audio, iframe, object, embed, figure, canvas, svg")) {
      return sourceOwnedArticleIndependentLinkedHeadingCollection(node, root, ownership);
    }
    list = collectionHeading.nextElementSibling;
  }
  if (!list || !list.matches("ul, ol") || !root.contains(list) || elementSubtreeHidden(list) || sourceOwnershipInChrome(list)) {
    return sourceOwnedArticleIndependentLinkedHeadingCollection(node, root, ownership);
  }
  var items = Array.from(list.children);
  if (!items.every(function(item) {
    return item.matches("li") && !elementSubtreeHidden(item) || sourceOwnedNonrenderedCollectionPlaceholder(item);
  })) return false;
  items = items.filter(function(item) { return !sourceOwnedNonrenderedCollectionPlaceholder(item); });
  if (items.length < 2) return false;

  var current = sourceOwnershipPageUrl(location.href);
  var destinations = [];
  var independentlyLinked = items.every(function(item) {
    var link = genericListStructuredCardLink(item, false);
    if (!link || link.closest("li") !== item || elementVisuallyHidden(link)) return false;
    var destination = sourceOwnershipPageUrl(link.getAttribute("href"));
    if (!destination || destination === current || destinations.indexOf(destination) !== -1) return false;
    if (sourceOwnedLinkedCardHasUnownedMaterial(item, destination)) return false;
    destinations.push(destination);
    return true;
  });
  return independentlyLinked && destinations.length === items.length;
}

function sourceOwnedArticleIndependentLinkedHeadingCollection(node, root, ownership) {
  var body = ownership && ownership.body && ownership.body.sourceNode;
  var headers = sourceOwnedArticleHeaderNodes(ownership && ownership.headerContext);
  for (var container = node && node.parentElement; container && container !== root; container = container.parentElement) {
    if (!root.contains(container) || elementSubtreeHidden(container) || sourceOwnershipInChrome(container) ||
        container === body || (body && body.contains(container)) || headers.some(function(header) {
          return header === container || header.contains(container);
        })) return false;
    if (relatedHeadingLinkedRecordGroup(container) || relatedHeadingLinkedCardGroup(container)) return true;
  }
  return false;
}

function sourceOwnedLinkedCardHasUnownedMaterial(item, destination) {
  var clone = visibilityPrunedClone(item, document);
  var cardLinks = Array.from(clone.querySelectorAll("a[href]")).filter(function(anchor) {
    return sourceOwnershipPageUrl(anchor.getAttribute("href")) === destination;
  });
  if (!cardLinks.length) return true;
  cardLinks.forEach(function(anchor) { anchor.remove(); });
  if (normalizeText(clone.textContent || "")) return true;
  return !!clone.querySelector("a[href], img, picture, video, audio, iframe, object, embed, figure, table, pre, code, blockquote");
}

function sourceOwnedNonrenderedCollectionPlaceholder(item) {
  if (!item || !item.matches("li")) return false;
  var visibleContent = visibilityPrunedClone(item, document);
  visibleContent.querySelectorAll("script, style, template").forEach(function(node) { node.remove(); });
  return !normalizeText(visibleContent.textContent || "") &&
    !visibleContent.querySelector("a[href], img, picture, video, audio, iframe, object, embed, figure, table, pre, code, blockquote, form, input, textarea, select, button, [role='img']");
}
