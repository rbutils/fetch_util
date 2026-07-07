  function milliyetLiveArticleContent(metadata) {
    if (!milliyetLiveArticlePage()) return null;

    var body = milliyetLiveArticleBody();
    if (!body) return null;
    milliyetLiveNormalizeStructuredData();

    return profileArticleContent(metadata, body, {
      title: firstText([".news-detail-title", "section.news-detail-content.live-content h1", "h1"]) || metadata.title,
      byline: firstText([".news-detail-author", ".news-author", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      cloneRoot: false,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".news-detail-sticky", ".breadcrumb", ".breadcrumbs",
          "[class*='share' i]", "[class*='social' i]",
          "[class*='advert' i]", "[class*='reklam' i]", "[id*='ad-' i]",
          "[class*='related' i]", "[class*='recommend' i]",
          ".newsletter", "[class*='newsletter' i]"
        ].join(", "));

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
    return !!milliyetLiveArticleBody();
  }

  function milliyetLiveArticleBody() {
    var frame = document.querySelector("section.news-detail-content.live-content") || document;
    var root = document.createElement("article");
    var title = frame.querySelector(".news-detail-title") || document.querySelector(".news-detail-title, h1");
    var lead = frame.querySelector(".news-content.readingTime, .news-content");
    var timeline = frame.querySelector(".timeline-news-box, .insert.insert-controls");

    if (title) root.appendChild(safeDeepClone(title, document));
    if (lead) root.appendChild(safeDeepClone(lead, document));
    if (timeline) root.appendChild(safeDeepClone(timeline, document));

    return normalizeText(root.textContent || "").length >= 250 ? root : null;
  }

  function milliyetLiveNormalizeStructuredData() {
    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      if (/"@type"\s*:\s*"LiveBlogPosting"/i.test(script.textContent || "")) script.remove();
    });
  }

  var milliyetLiveBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return milliyetLiveArticleContent(metadata) || milliyetLiveBaseHostAwareContent(metadata, pageText);
  };
