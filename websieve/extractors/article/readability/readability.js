  function readabilityContent(metadata) {
    if (typeof Readability !== "function") return null;

    try {
      var comments = visibleCommentMarkup(document);
      var clone = safeReadableDocumentClone();
      pruneHiddenClone(document.documentElement, clone.documentElement);
      stripPublisherCtaNotes(clone);
      var excerptMarker = markReadabilityExcerptSources(clone);
      normalizeCodeSurfaces(clone);
      if (commentOnlyRoot(clone)) return null;
      prepareInlineArticleProse(clone);
      cleanupCookieChrome(clone);
      markTerminalArticleLinkCollections(clone);
      var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output, .mw-parser-output");
      if (!mediaWikiLike) cleanupAgentRoot(clone);
      cleanupGenericArticleRoot(clone);
      var article = new Readability(clone).parse();
      if (!article || !article.content) return null;
      if (normalizeText(article.textContent || "").length < 40) return null;
      var excerpt = readabilityArticleExcerpt(article, metadata, excerptMarker);
      if (!excerpt) excerpt = sourceOwnedReaderMissingExcerpt(article, metadata);
      article.content = stripReadabilityExcerptMarkers(article.content, excerptMarker);
      article.content += comments;

      return {
        title: article.title || null,
        byline: article.byline || null,
        excerpt: excerpt,
        siteName: article.siteName || null,
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

  function prepareInlineArticleProse(root) {
    root.querySelectorAll("p span, li span, blockquote span, p font, li font, blockquote font").forEach(function(node) {
      if (node.querySelector("p, li, blockquote, div, ul, ol, table, pre")) return;
      node.replaceWith.apply(node, Array.prototype.slice.call(node.childNodes));
    });
  }
