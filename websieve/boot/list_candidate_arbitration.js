  function genericListMayReplace(candidate, focalArticleRoute) {
    var cachedFocal = candidate && (candidate.focalPermalinkContent || focalArticleRoute) &&
      (candidate.contentType === "article" || candidate.contentType === "medical");
    return candidate && !candidate.hostAware && !candidate.docsLike &&
      !cachedFocal && !articleRouteFocalContent(candidate);
  }

  function emptyListCandidateLosesContent(current, candidate) {
    if (!candidate || candidate.contentType !== "list") return false;
    var candidateText = normalizeText(candidate.markdown || candidate.textContent || "");
    var currentText = normalizeText(current && (current.markdown || current.textContent) || "");
    var itemCount = candidate.itemCount || 0;
    if (candidate.listExtraction && Array.isArray(candidate.listExtraction.items)) {
      itemCount = Math.max(itemCount, candidate.listExtraction.items.length);
    }
    if (Array.isArray(candidate.listSourceItems)) {
      itemCount = Math.max(itemCount, candidate.listSourceItems.length);
    }
    if (!itemCount && candidate.html) {
      var candidateRoot = document.createElement("div");
      candidateRoot.innerHTML = candidate.html;
      itemCount = Array.prototype.filter.call(candidateRoot.querySelectorAll("table a[href], .itemlist a[href]"), function(link) {
        return !!materializedHttpUrl(link.getAttribute("href"));
      }).length;
    }
    return !candidateText && itemCount === 0 && !!currentText && !!(current && current.readerMode);
  }
