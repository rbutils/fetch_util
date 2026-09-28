  var PRIMARY_COMMENT_THREAD_SELECTOR = "#comments, #comment-area, .comments, .comments-area, .comment-list, .comments-section, #disqus_thread";
  var VISIBLE_COMMENT_THREAD_SELECTOR = [
    PRIMARY_COMMENT_THREAD_SELECTOR,
    "[class*='comments-list' i], [class*='comment-thread' i], [class*='comment-wrap' i]"
  ].join(", ");
  var VISIBLE_COMMENT_RECORD_SELECTOR = "[role~='comment' i], [itemprop~='comment' i], [class*='comment' i], [id*='comment' i], [class*='reply' i], [id*='reply' i]";
  var COMMENT_ACTION_LABEL_PATTERN = /^(?:comments?|repl(?:y|ies)|like|share|report|sign in|log in|login|register|subscribe|join|more)$/i;

  function commentRecordMarker(node) {
    if (node.matches("[role~='comment' i], [itemprop~='comment' i]")) return true;
    if (/-comment$/i.test(String(node.localName || ""))) return true;
    var identities = Array.from(node.classList || []).concat(node.id || "");
    return identities.some(function(identity) {
      return /^(?:(?:comment|reply|response)(?:[-_]?(?:item|unit|entry|record|row|card|message))?|(?:comments|replies|responses)[-_](?:item|unit|entry|record|row|card|message))$/i.test(identity);
    });
  }

  function visibleCommentThreadRoots(root) {
    var selector = VISIBLE_COMMENT_THREAD_SELECTOR + ", " + VISIBLE_COMMENT_RECORD_SELECTOR;
    var threads = Array.prototype.slice.call(root.querySelectorAll(selector));
    Array.prototype.forEach.call(root.getElementsByTagName("*"), function(node) {
      if (/-comment$/i.test(String(node.localName || "")) && threads.indexOf(node) === -1) threads.push(node);
    });
    threads = threads.filter(function(thread) {
      if (elementVisuallyHidden(thread)) return false;
      var signature = String(thread.className || "") + " " + String(thread.id || "");
      if (/(?:promo|advert|sponsor|subscribe|newsletter|sidebar|related|recommend|widget)/i.test(signature)) return false;
      return !thread.closest("nav, aside, footer, form, dialog, [role~='navigation' i], [role~='complementary' i], [class*='sidebar' i], [class*='promo' i], [class*='sponsor' i], [class*='advert' i]");
    });
    threads.sort(function(left, right) {
      return left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });
    var primaryThreads = threads.filter(function(thread) { return thread.matches(PRIMARY_COMMENT_THREAD_SELECTOR); });
    threads = threads.filter(function(thread) {
      if (thread.matches(PRIMARY_COMMENT_THREAD_SELECTOR) || commentRecordMarker(thread)) return true;
      return !primaryThreads.some(function(primary) { return thread !== primary && thread.contains(primary); });
    });
    return threads.filter(function(thread) {
      return !threads.some(function(parent) { return parent !== thread && parent.contains(thread); });
    });
  }

  function focalCommentThreadBelongsToArticle(thread, focalOwnership) {
    if (!focalOwnership || !focalOwnership.node ||
        !/^(?:same-owner-source-headline|same-owner-repeated-headline|canonical-article-metadata|source-record-container)$/.test(focalOwnership.proof || "")) return false;
    if (focalOwnership.proof === "source-record-container") {
      var record = focalOwnership.sourceRecord;
      return !!(record && record.recordContainer === focalOwnership.node &&
        sourceRecordCommentThreadBelongsToContainer(thread, record));
    }
    var focalNode = focalOwnership.node;
    var article = focalNode.matches("article") ? focalNode : focalNode.closest("article");
    var ownerRoot = article || focalOwnership.ownerRoot;
    if (!ownerRoot || thread.contains(ownerRoot)) return false;
    var threadArticle = thread.closest("article");
    if (threadArticle && threadArticle !== article && !commentRecordMarker(threadArticle)) return false;
    if (ownerRoot.contains(thread)) {
      if (article) return true;
      return !!(focalNode.compareDocumentPosition(thread) & Node.DOCUMENT_POSITION_FOLLOWING);
    }

    var boundary = ownerRoot.parentElement;
    while (boundary && boundary !== document.body && !boundary.contains(thread)) boundary = boundary.parentElement;
    if (!boundary || boundary === document.body || boundary === document.documentElement) return false;
    var records = Array.prototype.filter.call(boundary.querySelectorAll("article"), function(record) {
      return record === ownerRoot || !record.closest(VISIBLE_COMMENT_THREAD_SELECTOR);
    });
    if (records.length !== 1 || records[0] !== ownerRoot) return false;
    return !!(ownerRoot.compareDocumentPosition(thread) & Node.DOCUMENT_POSITION_FOLLOWING);
  }

  function commentThreadHasMaterial(thread) {
    var material = thread.matches("p, li, blockquote, [slot='comment'], [itemprop~='text' i], [class*='body' i], img, picture, video, audio") ?
      [thread] : [];
    material = material.concat(Array.prototype.slice.call(thread.querySelectorAll("p, li, blockquote, [slot='comment'], [itemprop~='text' i], [class*='body' i], img, picture, video, audio")));
    return material.some(function(node) {
      if (elementVisuallyHidden(node) || node.closest("nav, aside, footer, form, dialog, [role~='navigation' i], [role~='complementary' i], [class*='promo' i], [class*='sponsor' i], [class*='advert' i]")) return false;
      var text = normalizeText(node.textContent || "");
      if (text && !COMMENT_ACTION_LABEL_PATTERN.test(text)) return true;
      return node.matches("img, picture, video, audio") && !!(node.getAttribute("src") || node.querySelector("img[src], video[src], audio[src]"));
    });
  }

  function cleanFocalCommentClone(source) {
    var clone = visibilityPrunedClone(source, document);
    if (!clone) return "";
    if (clone.matches("form, nav, aside, footer, dialog, [class*='promo' i], [class*='sponsor' i], [class*='advert' i]")) return "";
    clone.setAttribute("data-fetchutil-social-comment", "true");
    clone.querySelectorAll("form, nav, aside, dialog, [role~='navigation' i], [role~='complementary' i], [role='toolbar' i], [class*='promo' i], [class*='sponsor' i], [class*='advert' i], [class*='newsletter' i], [class*='subscribe' i], button, input, textarea, select").forEach(function(node) {
      node.remove();
    });
    return clone.outerHTML;
  }

  function legacyVisibleCommentMarkup(root) {
    var containers = [];
    visibleCommentCandidates(root).forEach(function(node) {
      if (!node.querySelector("p, li, [class*='body' i], [slot='comment']")) return;
      if (!containers.some(function(parent) { return parent.contains(node); })) containers.push(node);
    });
    return containers.map(function(source) {
      return { source: source, clone: visibilityPrunedClone(source, document) };
    }).filter(function(entry) {
      var minimum = /-comment$/.test(String(entry.source.localName || "")) ? 8 : 40;
      return normalizeText(entry.clone.textContent || "").length >= minimum;
    }).map(function(entry) {
      return entry.clone.outerHTML;
    }).join("");
  }

  function visibleCommentMarkup(root, focalOwnership) {
    if (!root || !root.querySelectorAll) return "";
    if (!focalOwnership) return legacyVisibleCommentMarkup(root);

    var threads = visibleCommentThreadRoots(root).filter(function(thread) {
      return focalCommentThreadBelongsToArticle(thread, focalOwnership) && commentThreadHasMaterial(thread);
    });
    return threads.map(cleanFocalCommentClone).join("");
  }
