  function hiddenSubstantiveMainSafeLinks(root, seen) {
    seen = seen || {};

    return Array.prototype.map.call(root.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href") || link.href || "");
    }).filter(function(url) {
      if (!url || seen[url]) return false;
      seen[url] = true;
      return true;
    });
  }

  function hiddenSubstantiveMainAccessibilityHidden(node) {
    return !!(node && (node.hidden || node.hasAttribute("inert") || node.getAttribute("aria-hidden") === "true"));
  }

  function hiddenSubstantiveMainAccessibilityHiddenWithin(node, boundary) {
    var current = node;
    while (current && current !== boundary && current.nodeType === 1) {
      if (hiddenSubstantiveMainAccessibilityHidden(current)) return true;
      current = current.parentElement;
    }
    return false;
  }

  function hiddenSubstantiveMainHiddenState(node) {
    return hiddenSubstantiveMainAccessibilityHidden(node) || elementVisuallyHidden(node);
  }

  function hiddenSubstantiveMainRootHasMaterial(root) {
    if (normalizeText(root.textContent || "") || hiddenSubstantiveMainSafeLinks(root).length) return true;

    return Array.prototype.some.call(root.querySelectorAll("img[alt]"), function(image) {
      return !!normalizeText(image.getAttribute("alt") || "");
    });
  }

  function hiddenSubstantiveMainTopHiddenRoots(main) {
    return Array.prototype.filter.call(main.querySelectorAll("*"), function(node) {
      if (!hiddenSubstantiveMainHiddenState(node)) return false;

      var parent = node.parentElement;
      while (parent && parent !== main) {
        if (hiddenSubstantiveMainHiddenState(parent)) return false;
        parent = parent.parentElement;
      }

      return true;
    });
  }

  function hiddenSubstantiveMainUnsafeIdentity(node, nested) {
    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")
      .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
      .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")).toLowerCase();

    var pattern = nested ?
      /(^|[\s_-])(auth|login|sign[\s_-]?in|sign[\s_-]?up|register|account|paywall|subscribe|subscription|premium|members?[\s_-]?only|cookie|consent|privacy|template|draft)(?:$|[\s_-])/ :
      /(^|[\s_-])(auth|login|sign[\s_-]?in|sign[\s_-]?up|register|account|paywall|subscribe|subscription|premium|members?[\s_-]?only|cookie|consent|privacy|modal|popup|drawer|offcanvas|template|draft|skeleton|placeholder)(?:$|[\s_-])/;
    return pattern.test(attrs);
  }

  function hiddenSubstantiveMainUnsafeNode(node, main, inspectDescendants, nestedIdentity) {
    if (!node || !main.contains(node) || node.hidden || node.hasAttribute("inert") || node.getAttribute("aria-hidden") === "true") return true;
    if (node.matches("script, style, template, noscript") || node.closest("details:not([open])")) return true;

    var semanticChrome = node.closest("header, footer, nav, aside, dialog, menu, [role='dialog'], [role='alertdialog'], [role='navigation'], [role='menu'], [role='menubar']");
    if (semanticChrome && semanticChrome !== main && main.contains(semanticChrome)) return true;

    var current = node;
    while (current && current !== main) {
      if (listChromeNode(current) || cookieChromeNode(current)) return true;
      if (hiddenSubstantiveMainUnsafeIdentity(current, nestedIdentity || current !== node)) return true;
      current = current.parentElement;
    }

    if (inspectDescendants !== false) {
      if (node.querySelector("header, footer, nav, aside, dialog, menu, details:not([open]), [role='dialog'], [role='alertdialog'], [role='navigation'], [role='menu'], [role='menubar'], input[type='password'], form[action*='login' i], [data-paywall], [class*='paywall' i], [id*='paywall' i]")) return true;
      var unsafeDescendant = Array.prototype.some.call(
        node.querySelectorAll("[id], [class], [role], [aria-label], [data-testid], [hidden], [inert], [aria-hidden='true']"),
        function(descendant) {
          if (hiddenSubstantiveMainAccessibilityHidden(descendant) &&
              hiddenSubstantiveMainRootHasMaterial(descendant)) return true;
          return cookieChromeNode(descendant) ||
            hiddenSubstantiveMainUnsafeIdentity(descendant, true);
        }
      );
      if (unsafeDescendant) return true;
    }

    var text = normalizeText(node.textContent || "");
    return consentWallDominates(text) || subscriptionWallDominates(text);
  }

  function hiddenSubstantiveMainVisibleOwner(root, main) {
    if (hiddenSubstantiveMainUnsafeNode(root, main)) return null;

    var owner = root;
    while (owner.parentElement && owner.parentElement !== main) owner = owner.parentElement;
    if (owner.parentElement !== main || elementVisuallyHidden(owner) || hiddenSubstantiveMainUnsafeNode(owner, main, false, true)) return null;

    var visibleOwner = visibilityPrunedClone(owner);
    var visibleText = normalizeText(visibleOwner.textContent || "");
    var visibleLinks = hiddenSubstantiveMainSafeLinks(visibleOwner).length;
    return visibleText.length >= 80 || visibleLinks >= 1 ? owner : null;
  }

  function hiddenSubstantiveMainLine(value) {
    return normalizeText(materializedMarkdown(String(value || ""))
      .replace(/^[\s#>+-]+/, "")
      .replace(/[`*_~]/g, " ")
      .toLowerCase());
  }

  function hiddenSubstantiveMainKeepsCurrent(currentMarkdown, recoveredMarkdown) {
    var currentLines = String(currentMarkdown || "").split(/\n+/)
      .map(hiddenSubstantiveMainLine).filter(Boolean);
    var recoveredLines = String(recoveredMarkdown || "").split(/\n+/)
      .map(hiddenSubstantiveMainLine).filter(Boolean);
    var cursor = 0;

    return currentLines.every(function(line) {
      for (var index = cursor; index < recoveredLines.length; index += 1) {
        if (recoveredLines[index] !== line) continue;
        cursor = index + 1;
        return true;
      }
      return false;
    });
  }

  function hiddenSubstantiveMainPreparedRoot(source) {
    var root = cleanClone(source);
    prepareFallbackInlineProse(root);
    cleanupGenericArticleRoot(root);
    prepareFallbackInlineProse(root);
    cleanupFallbackArticleChrome(root);
    return root;
  }

  function hiddenSubstantiveMainFinalResultSafe(current, recovered) {
    if (!current || !recovered || current.contentType !== "article" || recovered.contentType !== "article") return false;

    var currentWarnings = {};
    (current.warnings || []).forEach(function(reason) { currentWarnings[reason] = true; });
    if ((current.warnings || []).some(function(reason) { return (recovered.warnings || []).indexOf(reason) === -1; })) return false;

    return !(recovered.warnings || []).some(function(reason) {
      return !currentWarnings[reason] && /(interstitial|wall|paywall|bot_or_access|challenge)/.test(reason);
    });
  }

  function hiddenSubstantiveMainContent(content, metadata, pageText) {
    if (!content || content.contentType !== "article" || !content.readerMode ||
        content.hostAware || content.docsLike || content.legalProvision) return null;
    if (paywallSignals() || interstitialPageType(metadata || {}, pageText)) return null;

    var currentMarkdown = materializedMarkdown(cleanupMarkdownNoise(
      content.markdown || markdownFor(content.html || "")
    ));
    var currentLength = normalizeText(currentMarkdown).length;
    var currentRoot = document.createElement("div");
    currentRoot.innerHTML = content.html || "";
    if (currentLength < 40 || currentLength > 2500 || hiddenSubstantiveMainSafeLinks(currentRoot).length) return null;

    var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(node) {
      if (elementVisuallyHidden(node) || hiddenSubstantiveMainAccessibilityHiddenWithin(node, null) ||
          listChromeNode(node)) return false;
      return !node.parentElement || !node.parentElement.closest("main, [role='main']");
    });
    if (mains.length !== 1) return null;

    var main = mains[0];
    if (main.closest("header, nav, aside, dialog, [role='dialog'], [role='navigation']") ||
        cookieChromeNode(main) || hiddenSubstantiveMainUnsafeIdentity(main, false)) return null;

    var rawText = normalizeText(main.textContent || "");
    var renderedText = normalizeText(main.innerText || "");
    if (renderedText.length < 400 || rawText.length < renderedText.length * 2.5) return null;

    var hiddenRoots = hiddenSubstantiveMainTopHiddenRoots(main);
    if (hiddenRoots.some(function(root) {
      return hiddenSubstantiveMainRootHasMaterial(root) && hiddenSubstantiveMainUnsafeNode(root, main);
    })) return null;

    hiddenRoots = hiddenRoots.filter(function(root) {
      return normalizeText(root.textContent || "").length >= 80 || hiddenSubstantiveMainSafeLinks(root).length >= 1;
    });
    var hiddenOwners = [];
    var hiddenTextLength = 0;
    var hiddenLinkSeen = {};
    for (var hiddenIndex = 0; hiddenIndex < hiddenRoots.length; hiddenIndex += 1) {
      var hiddenRoot = hiddenRoots[hiddenIndex];
      var owner = hiddenSubstantiveMainVisibleOwner(hiddenRoot, main);
      if (!owner) return null;
      if (hiddenOwners.indexOf(owner) === -1) hiddenOwners.push(owner);

      var style = window.getComputedStyle ? window.getComputedStyle(hiddenRoot) : null;
      if (!style || (style.display !== "none" && style.visibility !== "hidden" && style.visibility !== "collapse") || Number(style.opacity) === 0) return null;

      hiddenTextLength += normalizeText(hiddenRoot.textContent || "").length;
      hiddenSubstantiveMainSafeLinks(hiddenRoot, hiddenLinkSeen);
    }
    if (hiddenOwners.length < 3 || hiddenTextLength < rawText.length * 0.4 || Object.keys(hiddenLinkSeen).length < 5) return null;

    var visibleRoot = hiddenSubstantiveMainPreparedRoot(visibilityPrunedClone(main));
    var visibleMarkdown = materializedMarkdown(cleanupMarkdownNoise(markdownFor(visibleRoot.innerHTML)));
    if (!hiddenSubstantiveMainKeepsCurrent(currentMarkdown, visibleMarkdown)) return null;

    var clone = hiddenSubstantiveMainPreparedRoot(main);

    var text = normalizeText(clone.textContent || "");
    var markdown = materializedMarkdown(cleanupMarkdownNoise(markdownFor(clone.innerHTML)));
    var links = hiddenSubstantiveMainSafeLinks(clone);
    var blocks = clone.querySelectorAll("h1, h2, h3, h4, p, li, blockquote, table").length;
    var heading = clone.querySelector("h1, [itemprop='headline']");
    var title = normalizeText((heading && heading.textContent) || "");
    if (text.length < 5000 || text.length < currentLength * 2.5 || links.length < 8 || blocks < 8) return null;
    if (title.length < 8 || !hiddenSubstantiveMainKeepsCurrent(currentMarkdown, markdown)) return null;

    return {
      title: title,
      byline: content.byline || null,
      excerpt: content.excerpt || null,
      siteName: content.siteName || location.hostname,
      publishedTime: content.publishedTime || null,
      html: clone.innerHTML,
      textContent: text,
      readerMode: false,
      contentType: "article"
    };
  }
