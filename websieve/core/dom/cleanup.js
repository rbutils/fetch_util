  function removeAll(root, selectors) {
    if (!root || !selectors) return root;
    root.querySelectorAll(selectors).forEach(function(el) {
      el.remove();
    });
    return root;
  }

  function cleanupAgentRoot(root) {
    cleanupCookieChrome(root);
    stripInlineConsentPrompts(root);

    // Strip comment sections (WordPress, Disqus, generic)
    root.querySelectorAll("#comments, #respond, .comments-area, .comment-list, .comments-section, #disqus_thread, .disqus-comment-count, [class*='comment-respond'], .wp-block-comments, .post-comments").forEach(function(el) {
      el.remove();
    });

    // Strip related-article containers by class/id patterns
    root.querySelectorAll(RELATED_CONTAINER_SELECTOR).forEach(function(el) {
      el.remove();
    });

    // Strip sections introduced by headings that indicate related/non-article content.
    // Detects h2/h3/h4 whose text matches "Related", "More from this category", etc.
    // and removes the heading plus all following siblings within the same parent.
    stripRelatedSectionsByHeading(root);

    root.querySelectorAll("section, div, aside, form, table, ul").forEach(function(el) {
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
      if (looksLikeInlineJS(el.textContent) && !el.querySelector("p, h1, h2, h3, h4, h5, h6, ul, ol, table, blockquote, pre, article")) el.remove();
    });

    root.querySelectorAll("p, div, span, li, td").forEach(function(el) {
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
