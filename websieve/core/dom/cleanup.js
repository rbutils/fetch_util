  function removeAll(root, selectors) {
    if (!root || !selectors) return root;
    root.querySelectorAll(selectors).forEach(function(el) {
      el.remove();
    });
    return root;
  }

  function cleanupMatchesIncludingRoot(root, selector) {
    var matches = Array.from(root.querySelectorAll(selector));
    if (root.matches && root.matches(selector)) matches.unshift(root);
    return matches;
  }

  function removeCleanupNode(root, node) {
    if (node === root) {
      Array.from(root.attributes || []).forEach(function(attribute) { root.removeAttribute(attribute.name); });
      while (root.firstChild) root.firstChild.remove();
      return true;
    } else {
      node.remove();
    }
    return false;
  }

  function markedCommentContentSelector() {
    return [
      "[itemprop~='comment' i]", "[data-comment-id]", "[class~='comment' i]", "[class~='reply' i]",
      "[class~='comment-body' i]", "[class~='comment-content' i]", "[class~='reply-body' i]",
      "[class~='reply-content' i]", "[class~='comment-text' i]", "[class~='reply-text' i]", "article", "blockquote"
    ].join(", ");
  }

  function hasMarkedCommentContent(node) {
    var selector = markedCommentContentSelector();
    return node.matches(selector) || !!node.querySelector(selector);
  }

  function hasMaterialCommentContent(node) {
    var probe = node.cloneNode(true);
    probe.querySelectorAll("label, legend, input, textarea, select, option, button").forEach(function(ui) { ui.remove(); });
    if (normalizeText(probe.textContent || "")) return true;
    return !!probe.querySelector("img[src], img[srcset], img[data-src], img[data-original], img[data-original-src], img[data-lazy-src], img[data-srcset], img[data-lazy-srcset], source[src], source[srcset], source[data-src], source[data-original-src], source[data-srcset], source[data-lazy-src], source[data-lazy-srcset], video[src], video[poster], audio[src], object[data], embed[src]");
  }

  function stripCommentFormControls(form) {
    form.querySelectorAll("label, legend, input, textarea, select, option, button").forEach(function(control) { control.remove(); });
  }

  function preserveMaterialCommentForm(root, form) {
    stripCommentFormControls(form);
    if (form === root || !form.parentNode) return;
    while (form.firstChild) form.parentNode.insertBefore(form.firstChild, form);
    form.remove();
  }

  function commentContinuationDestinationSupportsLabel(control, label) {
    if (!control.matches("a[href]")) return false;
    var destination;
    try {
      var rawHref = control.getAttribute("href");
      if (/\\|%(?:2f|5c)/i.test(rawHref)) return false;
      var baseUrl = /^https?:$/.test(window.location.protocol) ? window.location.href : "https://fetchutil.invalid/";
      var parsed = new URL(rawHref, baseUrl);
      if (!/^https?:$/.test(parsed.protocol) || parsed.username || parsed.password) return false;
      if (parsed.origin !== new URL(baseUrl).origin) return false;
      destination = decodeURIComponent(parsed.pathname).toLowerCase();
    } catch (_) {
      return false;
    }
    var routePattern = /^(?:comments?|komentari?|repl(?:y|ies)|discussion|responses?|odgovori?)$/i;
    var labelPattern = /(?:^|\s)(?:comments?|komentari?|repl(?:y|ies)|discussion|responses?|odgovori?)(?=\s|$)/i;
    var routeMatches = destination.split("/").some(function(segment) { return routePattern.test(segment); });
    return routeMatches && labelPattern.test(normalizeText(label));
  }

  function hasCommentContinuationResidual(node, control) {
    if (node === control) return false;
    var probe = node.cloneNode(true);
    var probeControl = probe.querySelector("a, button");
    if (probeControl) probeControl.remove();
    return hasMaterialCommentContent(probe);
  }

  function stripEmptyCommentUi(root) {
    var removedRoot = false;
    cleanupMatchesIncludingRoot(root, "[class~='more-comments-button' i]").forEach(function(node) {
      var controls = Array.from(node.querySelectorAll("a, button"));
      if (node.matches("a, button")) controls.unshift(node);
      if (controls.length !== 1) return;
      if (hasCommentContinuationResidual(node, controls[0])) return;
      if (hasMarkedCommentContent(controls[0])) return;
      var text = normalizeText(node.textContent || "");
      var controlText = normalizeText(controls[0].textContent || "");
      if (!text || text !== controlText || text.length > 120 || !/\(\s*0\s*\)$/.test(text)) return;
      var label = text.replace(/\(\s*0\s*\)$/, "").trim();
      if (label.split(/\s+/).length > 8 || /[.!?](?:\s|$)/.test(label)) return;
      if (!commentContinuationDestinationSupportsLabel(controls[0], label)) return;
      removedRoot = removeCleanupNode(root, node) || removedRoot;
    });

    var formSelector = "[class~='comment-form' i], [id='comment-form-div' i]";
    cleanupMatchesIncludingRoot(root, formSelector).forEach(function(node) {
      if (hasMaterialCommentContent(node)) {
        if (node.matches("form")) {
          preserveMaterialCommentForm(root, node);
        } else {
          node.querySelectorAll("form").forEach(function(form) {
            if (hasMaterialCommentContent(form)) {
              preserveMaterialCommentForm(root, form);
            } else {
              form.remove();
            }
          });
          stripCommentFormControls(node);
        }
        return;
      }
      var formUi = node.matches("form") || node.querySelector("form, label, legend, textarea, input, select, button");
      var emptyWrapper = !normalizeText(node.textContent || "") && !node.querySelector("*");
      if (formUi || emptyWrapper) removedRoot = removeCleanupNode(root, node) || removedRoot;
    });
    return removedRoot;
  }

  function cleanupAgentRoot(root) {
    cleanupCookieChrome(root);
    stripInlineConsentPrompts(root);

    // Strip comment sections (WordPress, Disqus, generic)
    root.querySelectorAll("#comments, #respond, .comments-area, .comment-list, .comments-section, #disqus_thread, .disqus-comment-count, [class*='comment-respond'], .wp-block-comments, .post-comments").forEach(function(el) {
      el.remove();
    });
    stripEmptyCommentUi(root);

    stripShortRecommendationFurniture(root);

    // Strip related-article containers by class/id patterns
    root.querySelectorAll(RELATED_CONTAINER_SELECTOR).forEach(function(el) {
      if (el.closest("[data-fetchutil-page-overview], [data-fetchutil-editorial-aside]")) return;
      el.remove();
    });

    // Strip sections introduced by headings that indicate related/non-article content.
    // Detects h2/h3/h4 whose text matches "Related", "More from this category", etc.
    // and removes the heading plus all following siblings within the same parent.
    stripRelatedSectionsByHeading(root);

    root.querySelectorAll("section, div, aside, form, table, ul").forEach(function(el) {
      if (el.closest("[data-fetchutil-page-overview], [data-fetchutil-editorial-aside]")) return;
      if (utilitySectionNode(el)) el.remove();
    });

    stripPromoAdModules(root);

    root.querySelectorAll('a[href^="#"]').forEach(function(el) {
      var text = normalizeText(el.textContent);
      var className = (el.className || "").toString();
      if (!text || /anchor|heading/i.test(className)) el.remove();
      if (/^skip\s+(to\s+)?(main\s+)?/i.test(text)) el.remove();
      // Strip skip-navigation markers in Arabic/Hebrew/RTL: "تخطى" (skip), "דלג" (skip)
      if (/^(تخطى|تجاوز|דלג)\s/i.test(text)) el.remove();
      // Strip skip-navigation in Greek, Ukrainian, Vietnamese, Thai, Indonesian
      if (/^(μετάβαση στο |παράλειψη |перейти до |пропустити |bỏ qua |ข้ามไปยัง|lewati |langsung ke )/i.test(text)) el.remove();
      // Strip skip-navigation in Dutch, Serbian, Malay, Portuguese
      if (/^(ga naar |doorgaan naar |overslaan|spring naar |прескочи |пређи на |langkau |ir para |pular para |saltar )/i.test(text)) el.remove();
      // Strip skip-navigation in Czech, Swedish, Danish, Filipino, Norwegian, Catalan
      if (/^(přejít na |přeskočit |gå til |spring over |hoppa till |gå vidare |pumunta sa |laktawan |hopp over |gå til innhold|anar a |saltar a )/i.test(text)) el.remove();
      // Strip skip-navigation in Polish
      if (/^(przejdź do |pomiń )/i.test(text)) el.remove();
    });

    root.querySelectorAll("a, button").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (ACCOUNT_ACTION_TEXT_PATTERN.test(text)) el.remove();
    });

    root.querySelectorAll("p, div, span, a, button, li").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (AD_LABEL_TEXT_PATTERN.test(text) && textLength(el) < 80) el.remove();
    });

    root.querySelectorAll("p, div").forEach(function(el) {
      if (isBadgeNode(el)) el.remove();
    });

    root.querySelectorAll("p, div, li, span, strong, button").forEach(function(el) {
      if (audioFallbackText(el.textContent) || videoFallbackText(el.textContent)) el.remove();
    });

    root.querySelectorAll("svg, .octicon").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll(".anchor, .heading-link, .header-anchor").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (el.closest("h1, h2, h3, h4, h5, h6") && text.length >= 8) {
        el.replaceWith(document.createTextNode(text));
      } else {
        el.remove();
      }
    });

    root.querySelectorAll("p, div, span, li, td").forEach(function(el) {
      if (codeContentNode(el)) return;
      if (looksLikeInlineJS(el.textContent) && !el.querySelector("p, h1, h2, h3, h4, h5, h6, ul, ol, table, blockquote, pre, article")) el.remove();
    });

    root.querySelectorAll("p, div, span, li, td").forEach(function(el) {
      if (codeContentNode(el)) return;
      if (looksLikeDebugData(el.textContent) && !el.querySelector("p, h1, h2, h3, h4, h5, h6, ul, ol, table, blockquote, pre, article")) el.remove();
    });

    stripTrackingPixels(root);
    resolveLazyImages(root);
    stripUIWidgets(root);
    stripNavigationLeaks(root);

    return root;
  }

  function stripInlineConsentPrompts(root) {
    if (!root || !root.querySelectorAll) return root;

    root.querySelectorAll("p, div, span, section, aside, figcaption, li, a, button").forEach(function(el) {
      var text = normalizeText(el.textContent || "");
      if (!text || text.length > 250) return;
      if (!INLINE_CONSENT_PROMPT_PATTERN.test(text)) return;
      el.remove();
    });

    return root;
  }

  function sanitizedHtml(html) {
    var root = document.createElement("div");
    root.innerHTML = html;
    cleanupAgentRoot(root);
    return root.innerHTML;
  }
