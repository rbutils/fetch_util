  function blicContent(metadata) {
    if (!hostMatches(/(^|\.)blic\.rs$/)) return null;
    if (metadata) metadata.language = "";

    return blicHomepageContent(metadata) || blicArticleContent(metadata);
  }

  function blicHomepageContent(metadata) {
    return newsHomepageListContent(metadata, blicHomepageListConfig());
  }

  function blicHomepageListConfig() {
    return {
      pathAllowed: homepageRootPath,
      prepareMetadata: function(metadata) { if (metadata) metadata.language = ""; },
      linkSelector: "main a[href], .section a[href], body a[href]",
      excludeClosest: "header, nav, footer, aside, form, [role='navigation'], [role='banner'], [role='contentinfo']",
      cardSelector: "article, section, li, .news, .news-box__item, [class*='card'], [class*='story']",
      acceptLink: function(_href, url) {
        return /^https?:\/\/(?:www\.)?blic\.rs\//i.test(url) && /\/[^/]+\/[^/]+\/[a-z0-9]{6,}(?:$|[?#])/i.test(url);
      },
      titleBuilder: function(link) {
        return normalizeText(((link.querySelector("h1, h2, h3, h4") || {}).textContent) || link.textContent || link.getAttribute("aria-label") || "");
      },
      transformTitle: function(title) { return title.replace(/^\s*(foto|video|uživo)\s*/i, ""); },
      maxTitleLength: 240,
      rejectTitle: /^(najnovije|vesti|sport|showbiz|zabava|biznis|slobodno vreme|login|prijavi se|komentari|saznaj više|pročitajte još)$/i,
      defaultTitle: "Blic",
      siteName: "Blic",
      statusPage: true
    };
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

  registerNewsHomepageListProfile(/(^|\.)blic\.rs$/, blicHomepageListConfig);
  registerHostAwareProfile(true, blicContent);
