  function sourceMaterialBlocksListCandidate(content, candidate, metadata) {
    return sourceOwnedArticleProseListLoss(content, candidate) ||
      sourceOwnedTypedRuntimeDetailListLoss(content, candidate) ||
      listCandidateLosesArticleMaterial(content, candidate) ||
      listCandidateLosesArticleTableMaterial(content, candidate, metadata);
  }

  function productListLosesArticleMaterial(content, candidate, strongArticle, commerceLikePage, metadata) {
    return sourceOwnedArticleProseListLoss(content, candidate) ||
      listCandidateLosesArticleTableMaterial(content, candidate, metadata) ||
      (strongArticle && (!commerceLikePage || listCandidateLosesArticleMaterial(content, candidate)));
  }

  function sourceOwnedArticleProseListLoss(content, candidate) {
    if (!content || !candidate || content.contentType !== "article" || candidate.contentType !== "list" ||
        content.sourceOwnedFocalArticle !== true) return false;
    var source = content.sourceOwnedArticleBody;
    if (!source || source.ownerDocument !== document || !document.documentElement.contains(source) ||
        elementSubtreeHidden(source)) return false;

    var sourceParagraphs = new Set(Array.from(source.querySelectorAll("p")).filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph);
    }).map(function(paragraph) { return normalizeText(paragraph.textContent || ""); }));
    var selected = document.createElement("div");
    selected.innerHTML = content.html || "";
    var paragraphs = Array.from(selected.querySelectorAll("p")).map(function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text && sourceParagraphs.has(text); });
    var markdown = candidate.listArbitrationMarkdown == null ?
      candidate.markdown || candidate.textContent || "" : candidate.listArbitrationMarkdown;
    var text = normalizeText(markdown
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/[`*_~#>|]/g, " "));
    var cursor = 0;
    return paragraphs.some(function(paragraph) {
      var index = text.indexOf(paragraph, cursor);
      if (index === -1) return true;
      cursor = index + paragraph.length;
      return false;
    });
  }
