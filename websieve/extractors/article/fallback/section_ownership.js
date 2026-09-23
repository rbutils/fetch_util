  function sourceOwnedFallbackSections(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText) {
    if (!document.body || primary.contentType !== "article" || fallback.contentType !== "article" ||
        articleRouteFocalContent(primary) || fallbackText.length < Math.max(400, primaryText.length * 2)) return false;

    var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(node) {
      return !elementSubtreeHidden(node);
    });
    if (mains.length !== 1) return false;

    var owner = visibilityPrunedClone(mains[0], document);
    if (normalizeText(owner.textContent || "").length < fallbackText.length * 0.85) return false;

    var readerParagraphs = Array.prototype.map.call(primaryRoot.querySelectorAll("p"), function(node) {
      return normalizeText(node.textContent || "");
    }).filter(function(text) { return text.length >= 45; });
    if (readerParagraphs.length < 2 || !readerParagraphs.every(function(text) {
      return fallbackText.indexOf(text) !== -1;
    })) return false;

    var readerHeadings = Array.prototype.map.call(primaryRoot.querySelectorAll("h1, h2, h3"), function(node) {
      return normalizeText(node.textContent || "");
    });
    var ownerHeadings = new Set(Array.prototype.map.call(owner.querySelectorAll("h1, h2, h3"), function(node) {
      return normalizeText(node.textContent || "");
    }).filter(Boolean));
    var newHeadings = Array.prototype.filter.call(fallbackRoot.querySelectorAll("h1, h2, h3"), function(node) {
      var text = normalizeText(node.textContent || "");
      return text && ownerHeadings.has(text) && readerHeadings.indexOf(text) === -1;
    });
    if (newHeadings.length < 3) return false;

    var newParagraphs = Array.prototype.filter.call(fallbackRoot.querySelectorAll("p"), function(node) {
      var text = normalizeText(node.textContent || "");
      return text.length >= 45 && primaryText.indexOf(text) === -1;
    });
    if (newParagraphs.length >= 2) return true;

    var readerUrls = new Set(Array.prototype.map.call(primaryRoot.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean));
    var ownerUrls = new Set(Array.prototype.map.call(owner.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean));
    var newUrls = new Set(Array.prototype.map.call(fallbackRoot.querySelectorAll("a[href]"), function(link) {
      if (!normalizeText(link.textContent || link.getAttribute("aria-label") || "")) return null;
      var url = materializedHttpUrl(link.getAttribute("href"));
      return url && ownerUrls.has(url) && !readerUrls.has(url) ? url : null;
    }).filter(Boolean));
    return newHeadings.length >= 4 && newUrls.size >= 4;
  }

  function sourceOwnedFallbackContent(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText) {
    if (!sourceOwnedFallbackSections(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText)) return null;
    fallback.sourceOwnedSections = true;
    return fallback;
  }

  function sourceOwnedFallbackListLoss(content, candidate) {
    if (!content || !content.sourceOwnedSections || !candidate || candidate.contentType !== "list") return false;
    var root = document.createElement("div");
    root.innerHTML = sanitizedHtml(content.html || "");
    var rendered = normalizeText(candidate.markdown || candidate.textContent || "");
    return Array.prototype.some.call(root.querySelectorAll("h2, h3"), function(heading) {
      var text = normalizeText(heading.textContent || "");
      return text && rendered.indexOf(text) === -1;
    });
  }
