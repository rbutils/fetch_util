  function readabilityContent(metadata) {
    if (typeof Readability !== "function") return null;

    try {
      var comments = visibleCommentMarkup(document);
      var clone = safeReadableDocumentClone();
      var sourceClones = new Map();
      pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, sourceClones);
      stripPublisherCtaNotes(clone);
      var excerptMarker = markReadabilityExcerptSources(clone);
      var sourceIdentities = markReadabilitySourceNodeProvenance(clone, sourceClones, excerptMarker);
      normalizeCodeSurfaces(clone);
      if (commentOnlyRoot(clone)) return null;
      prepareInlineArticleProse(clone);
      cleanupCookieChrome(clone);
      markTerminalArticleLinkCollections(clone);
      var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output, .mw-parser-output");
      if (!mediaWikiLike) cleanupAgentRoot(clone);
      cleanupGenericArticleRoot(clone);
      var reader = new Readability(clone);
      var checkByline = reader._checkByline;
      // Readability removes accepted bylines; linked records own their own attribution.
      reader._checkByline = function(node, matchString) {
        return articleBylineNode(node) && checkByline.call(this, node, matchString);
      };
      var article = reader.parse();
      if (!article || !article.content) return null;
      if (normalizeText(article.textContent || "").length < 40) return null;
      article = sourceOwnedReaderRetainedHeadline(article, metadata, sourceClones, sourceIdentities, excerptMarker) || article;
      var sourceParagraphTemplate = document.createElement("template");
      sourceParagraphTemplate.innerHTML = article.content;
      var selectedSourceParagraphs = sourceOwnedReaderParagraphIdentitySources(
        sourceParagraphTemplate.content, sourceClones, sourceIdentities, excerptMarker
      );
      var excerpt = readabilityArticleExcerpt(article, metadata, excerptMarker);
      if (!excerpt) excerpt = sourceOwnedReaderMissingExcerpt(article, metadata);
      article.content = stripReadabilityExcerptMarkers(article.content, excerptMarker);
      article.content = stripReadabilitySourceNodeMarkers(article.content, excerptMarker, sourceIdentities);
      article.content += comments;

      var content = {
        title: article.title || null,
        byline: article.byline || null,
        excerpt: excerpt,
        siteName: article.siteName || null,
        publishedTime: article.publishedTime || null,
        html: article.content,
        textContent: article.textContent || "",
        readerMode: true,
        sourceOwnedArticleBoundary: article.sourceOwnedArticleBoundary === true,
        contentType: "article"
      };
      Object.defineProperty(content, "sourceOwnedReaderParagraphSources", { value: selectedSourceParagraphs });
      return content;
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
