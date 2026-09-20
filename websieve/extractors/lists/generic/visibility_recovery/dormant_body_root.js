  function dormantBodyRootText(node) {
    var clone = safeDeepClone(node, document);
    if (!clone) return "";
    Array.prototype.forEach.call(clone.querySelectorAll("script, style, noscript, template, svg"), function(child) {
      child.remove();
    });
    return normalizeText(clone.textContent || "");
  }

  function dormantBodyIgnoredChild(node) {
    return /^(?:script|style|link|meta|noscript|template|svg|iframe)$/i.test(node && node.tagName || "");
  }

  function dormantBodyChromeRoot(node) {
    if (!node) return true;
    if ((node.localName || "").indexOf("-") >= 0) return true;
    if (node.matches("header, footer, nav, aside, [role='dialog'], [role='navigation']")) return true;
    if (/^(?:root|app|__next|___gatsby)$/i.test(node.id || "")) return true;
    var identity = [node.id, node.className, node.getAttribute("role")].join(" ").replace(/[_-]+/g, " ");
    return /\b(?:cookie|consent|privacy|cmp|onetrust|modal|dialog|drawer|menu|navigation|navbar|header|footer|auth|login|signin|signup|overlay)\b/i.test(identity) ||
      /\b(?:app|application|react|vue|svelte|angular|next|nuxt)\s+(?:root|shell)\b/i.test(identity);
  }

  function dormantBodyMaterialLinkCount(node) {
    return Array.prototype.filter.call(node.querySelectorAll("a[href]"), function(link) {
      return !!materializedHttpUrl(link.href);
    }).length;
  }

  function dormantBodyElementIndependentlyHidden(node) {
    if (node.hidden || node.getAttribute("aria-hidden") === "true" || node.hasAttribute("inert")) return true;
    if (!global.getComputedStyle) return false;

    var style = global.getComputedStyle(node);
    if (!style) return false;
    if (style.display === "none" || parseFloat(style.opacity) === 0) return true;
    if (style.visibility !== "hidden" && style.visibility !== "collapse") return false;

    var parentStyle = node.parentElement ? global.getComputedStyle(node.parentElement) : null;
    return !parentStyle || parentStyle.visibility !== style.visibility;
  }

  function dormantBodyOwnHiddenRatioIsLow(node) {
    var descendants = Array.prototype.slice.call(node.querySelectorAll("*"));
    if (!descendants.length) return false;
    var hiddenCount = descendants.filter(function(descendant) {
      return dormantBodyElementIndependentlyHidden(descendant);
    }).length;
    return hiddenCount * 10 <= descendants.length;
  }

  function dormantBodyHasHiddenOwnedContent(node) {
    return Array.prototype.some.call(node.querySelectorAll("[aria-hidden='true'], [inert]"), function(hidden) {
      if (hidden.matches("a[href]") && materializedHttpUrl(hidden.href)) return true;
      if (dormantBodyMaterialLinkCount(hidden)) return true;
      var prose = hidden.matches("h1, h2, h3, h4, h5, h6, p") ? hidden :
        hidden.querySelector("h1, h2, h3, h4, h5, h6, p");
      return !!(prose && normalizeText(prose.textContent || ""));
    });
  }

  function dormantBodyHasVisibleFocalContent() {
    return Array.prototype.some.call(document.querySelectorAll("main, article, [role='main'], [itemprop='articleBody']"), function(node) {
      if (elementVisuallyHidden(node)) return false;
      var clone = visibilityPrunedClone(node, document);
      return normalizeText(clone.textContent || "").length > 0 || dormantBodyMaterialLinkCount(clone) > 0 ||
        !!clone.querySelector("img[alt]:not([alt='']), video, audio, table, pre, blockquote");
    });
  }

  function dormantDominantBodyRoot() {
    if (!document.body || normalizeText(document.body.innerText || "").length > 120 || dormantBodyHasVisibleFocalContent()) return null;
    var bodyTextLength = dormantBodyRootText(document.body).length;
    if (bodyTextLength < 1200) return null;

    var candidates = Array.prototype.filter.call(document.body.children, function(node) {
      if (dormantBodyIgnoredChild(node) || dormantBodyChromeRoot(node) || !elementVisuallyHidden(node)) return false;
      var textLength = dormantBodyRootText(node).length;
      if (textLength < 1200 || textLength * 100 < bodyTextLength * 85) return false;
      var headings = Array.prototype.filter.call(node.querySelectorAll("h1, h2, h3, h4, h5, h6"), function(heading) {
        return !!normalizeText(heading.textContent || "");
      }).length;
      var paragraphs = Array.prototype.filter.call(node.querySelectorAll("p"), function(paragraph) {
        return !!normalizeText(paragraph.textContent || "");
      }).length;
      return headings >= 3 && paragraphs >= 3 && dormantBodyMaterialLinkCount(node) >= 8 &&
        dormantBodyOwnHiddenRatioIsLow(node) && !dormantBodyHasHiddenOwnedContent(node);
    });

    return candidates.length === 1 ? candidates[0] : null;
  }

  function dormantBodyRootListContent(content, metadata) {
    if (!content || content.contentType !== "list" || content.hostAware || content.docsLike || !content.listExtraction) return null;
    if (normalizeText(content.markdown || content.textContent || "").length > 120) return null;
    if (materializedListItemCount(content.listExtraction.items)) return null;

    var root = dormantDominantBodyRoot();
    if (!root) return null;
    var recovered = listContent(metadata, { preservedRoots: [root] });
    if (!recovered || !recovered.listExtraction) return null;
    if (normalizeText(recovered.markdown || "").length < 1200) return null;
    if (materializedListItemCount(recovered.listExtraction.items) < 8) return null;
    return recovered;
  }
