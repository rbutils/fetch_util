  function blicContent(metadata) {
    if (!hostMatches(/(^|\.)blic\.rs$/)) return null;
    if (metadata) metadata.language = "";

    return blicHomepageContent(metadata) || blicArticleContent(metadata);
  }

  function blicHomepageContent(metadata) {
    if (!homepageRootPath()) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("main a[href], .section a[href], body a[href]").forEach(function(link) {
      if (items.length >= 18) return;
      if (link.closest("header, nav, footer, aside, form, [role='navigation'], [role='banner'], [role='contentinfo']")) return;

      var href = link.getAttribute("href") || "";
      var url = absoluteUrl(href);
      if (!url || !/^https?:\/\/(?:www\.)?blic\.rs\//i.test(url) || seen[url]) return;
      if (!/\/[^/]+\/[^/]+\/[a-z0-9]{6,}(?:$|[?#])/i.test(url)) return;

      var title = normalizeText(((link.querySelector("h1, h2, h3, h4") || {}).textContent) || link.textContent || link.getAttribute("aria-label") || "");
      title = title.replace(/^\s*(foto|video|uživo)\s*/i, "");
      if (!title || title.length < 18 || title.length > 240) return;
      if (/^(najnovije|vesti|sport|showbiz|zabava|biznis|slobodno vreme|login|prijavi se|komentari|saznaj više|pročitajte još)$/i.test(title)) return;

      var container = link.closest("article, section, li, .news, .news-box__item, [class*='card'], [class*='story']") || link.parentElement;
      var detail = searchItemDetail(container, title);
      if (detail.length > 220) detail = "";

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 4) return null;

    return listContentResult({
      title: metadata.title || document.title || "Blic",
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "Blic",
      items: items
    });
  }

  function blicArticleContent(metadata) {
    if (!blicArticlePath()) return null;

    var body = blicArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".article-title", ".article__title", "article h1", "h1"]) || metadata.title,
      byline: firstText([".article__author-name", ".article-author", ".author", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".banner",
          ".wrapperAd",
          ".audio-player",
          ".article__share",
          ".share",
          ".comments",
          ".comments-header",
          ".news-box",
          ".news-aside",
          ".story-sp2026",
          ".tabs",
          ".related",
          ".newsletter",
          ".carousel-button",
          ".jwplayer",
          "[id^='InText_']",
          "[data-placeholder-caption]"
        ].join(", "));

        root.querySelectorAll("p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(slušaj vest|oglas|galerija|pročitajte još|budi prvi koji će komentarisati)$/i.test(text) && text.length < 120) el.remove();
        });
      }
    });
  }

  function blicArticlePath() {
    return /\/(?:vesti|sport|zabava|showbiz|biznis|slobodno-vreme|kultura|zdravlje)\//i.test(location.pathname || "");
  }

  function blicArticleBody() {
    return document.querySelector(".article-body") ||
      document.querySelector("div.article-text") ||
      document.querySelector(".single-article-body") ||
      document.querySelector(".article__body") ||
      document.querySelector(".article__text") ||
      document.querySelector(".article__content");
  }

  var blicBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return blicContent(metadata) || blicBaseHostAwareContent(metadata, pageText);
  };
