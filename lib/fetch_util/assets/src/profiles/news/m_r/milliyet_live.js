  function milliyetLiveArticleContent(metadata) {
    if (!milliyetLiveArticlePage()) return null;

    return liveblogSingleEntryContent(metadata, {
      entrySelector: "section.news-detail-content.live-content",
      bodySelector: [
        ".news-detail-title",
        ".news-content.readingTime, .news-content",
        ".timeline-news-box, .insert.insert-controls"
      ],
      title: firstText([".news-detail-title", "section.news-detail-content.live-content h1", "h1"]) || metadata.title,
      byline: firstText([".news-detail-author", ".news-author", "[rel='author']"]) || metadata.byline,
      beforeBuild: milliyetLiveNormalizeStructuredData,
      minTextLength: 250,
      cleanupSelectors: [
        ".news-detail-sticky", ".breadcrumb", ".breadcrumbs",
        "[class*='share' i]", "[class*='social' i]",
        "[class*='advert' i]", "[class*='reklam' i]", "[id*='ad-' i]",
        "[class*='related' i]", "[class*='recommend' i]",
        ".newsletter", "[class*='newsletter' i]"
      ],
      rewriteRoot: function(root) {
        root.querySelectorAll("p, div, section, span, h2, h3, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(son dakika|sıradaki haber|ilgili haberler|en çok okunanlar|günün en çok okunanları|paylaş|reklam)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function milliyetLiveArticlePage() {
    if (!hostMatches(/(^|\.)milliyet\.com\.tr$/)) return false;
    if (!/\/live-/i.test(location.pathname || "") && !document.querySelector("section.news-detail-content.live-content")) return false;
    return !!document.querySelector("section.news-detail-content.live-content");
  }

  function milliyetLiveNormalizeStructuredData() {
    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      if (/"@type"\s*:\s*"LiveBlogPosting"/i.test(script.textContent || "")) script.remove();
    });
  }

  registerHostAwareProfile(true, milliyetLiveArticleContent);