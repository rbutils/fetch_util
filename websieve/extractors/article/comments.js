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
    if (!focalOwnership || !focalOwnership.node) return false;
    var semanticArticle = focalOwnership.proof === "unique-semantic-article-source-identity" &&
      focalOwnership.node.matches("article") && focalOwnership.heading &&
      focalOwnership.node.contains(focalOwnership.heading);
    if (!semanticArticle &&
        !/^(?:same-owner-source-headline|same-owner-repeated-headline|canonical-article-metadata|source-record-container|liveblog-parent|unique-canonical-headed-body-branch)$/.test(focalOwnership.proof || "")) return false;
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
    if (sourceOwnedCommentInterfaceOnlyThread(thread)) return false;
    if (thread.matches("div.comments, section.comments")) {
      var promptProbe = thread.cloneNode(true);
      if (stripEmptyCommentUi(promptProbe)) return false;
    }
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
    var sourceClones = new WeakMap();
    var clone = visibilityPrunedClone(source, document, sourceClones);
    if (!clone) return "";
    stripSourceOwnedCommentInterfaceNotices(source, clone, sourceClones);
    if (clone.matches("form, nav, aside, footer, dialog, [class*='promo' i], [class*='sponsor' i], [class*='advert' i]")) return "";
    clone.querySelectorAll("form, div, section").forEach(function(node) {
      if (!node.querySelector("input, textarea, select, button")) return;
      var headings = Array.from(node.querySelectorAll("h1, h2, h3, h4, h5, h6"));
      if (!headings.some(emptyCommentFormHeading)) return;
      var probe = node.cloneNode(true);
      stripCommentFormControls(probe);
      probe.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(heading) {
        if (emptyCommentFormHeading(heading)) heading.remove();
      });
      if (!hasMaterialCommentContent(probe)) node.remove();
    });
    clone.setAttribute("data-fetchutil-social-comment", "true");
    clone.querySelectorAll("form, nav, aside, dialog, [role~='navigation' i], [role~='complementary' i], [role='toolbar' i], [class*='promo' i], [class*='sponsor' i], [class*='advert' i], [class*='newsletter' i], [class*='subscribe' i], button, input, textarea, select").forEach(function(node) {
      node.remove();
    });
    return clone.outerHTML;
  }

  function legacyVisibleCommentEntries(root) {
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
      return { source: entry.source, html: entry.clone.outerHTML };
    });
  }

  function visibleCommentEntries(root, focalOwnership) {
    if (!root || !root.querySelectorAll) return [];
    if (!focalOwnership) return legacyVisibleCommentEntries(root);

    var threads = visibleCommentThreadRoots(root).filter(function(thread) {
      return focalCommentThreadBelongsToArticle(thread, focalOwnership) && commentThreadHasMaterial(thread);
    });
    return threads.map(function(thread) {
      return { source: thread, html: cleanFocalCommentClone(thread) };
    }).filter(function(entry) { return !!entry.html; });
  }

  function visibleCommentMarkup(root, focalOwnership) {
    return visibleCommentEntries(root, focalOwnership).map(function(entry) { return entry.html; }).join("");
  }

  function fallbackCommentCopies(sourceClones) {
    var copies = new WeakMap();
    var restored = new WeakMap();

    function clone(node) {
      var copied = safeDeepClone(node, document);
      mapDomCloneElements(node, copied, copies);
      return copied;
    }

    function clean(node) {
      if (cookieChromeNode(node)) return cleanClone(node);
      var copied = clone(node);
      return copied ? cleanClonedContent(node, copied) : document.createElement("div");
    }

    function rendered(source, root) {
      var node = restored.get(source) || sourceClones.get(source);
      while (node && copies.has(node)) node = copies.get(node);
      return node && (node === root || root.contains(node)) ? node : null;
    }

    function insertAtSourcePosition(root, source, replacement) {
      var branch = source;
      for (var parent = composedDomParent(branch); parent; parent = composedDomParent(branch)) {
        var target = rendered(parent, root);
        if (target && target.nodeType === 1) {
          var siblings = composedDomChildren(parent);
          var position = siblings.indexOf(branch);
          if (position >= 0) {
            var next = null;
            for (var index = position + 1; index < siblings.length; index += 1) {
              var candidate = rendered(siblings[index], root);
              if (candidate && candidate.parentNode === target) {
                next = candidate;
                break;
              }
            }
            target.insertBefore(replacement, next);
            return;
          }
        }
        branch = parent;
      }
      root.appendChild(replacement);
    }

    return {
      clone: clone,
      clean: clean,
      restore: function(root, entries) {
        entries.forEach(function(entry) {
          var container = document.createElement("div");
          container.innerHTML = entry.html;
          var replacement = container.firstElementChild;
          if (!replacement) return;
          var existing = rendered(entry.source, root);
          if (existing === root) {
            while (root.firstChild) root.removeChild(root.firstChild);
            while (replacement.firstChild) root.appendChild(replacement.firstChild);
            restored.set(entry.source, root);
            return;
          }
          if (existing) existing.replaceWith(replacement);
          else insertAtSourcePosition(root, entry.source, replacement);
          restored.set(entry.source, replacement);
        });
      }
    };
  }
