  function readabilityContent() {
    if (typeof Readability !== "function") return null;

    try {
      var clone = safeReadableDocumentClone();
      cleanupCookieChrome(clone);
      var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output, .mw-parser-output");
      if (!mediaWikiLike) cleanupAgentRoot(clone);
      cleanupGenericArticleRoot(clone);
      var article = new Readability(clone).parse();
      if (!article || !article.content) return null;

      return {
        title: article.title || document.title,
        byline: article.byline || null,
        excerpt: article.excerpt || null,
        siteName: article.siteName || location.hostname,
        publishedTime: article.publishedTime || null,
        html: article.content,
        textContent: article.textContent || "",
        readerMode: true,
        contentType: "article"
      };
    } catch (_error) {
      // Fall through to the shared article/list heuristics instead of aborting.
      return null;
    }
  }
