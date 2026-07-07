  function btDkArticleContent(metadata) {
    if (!btDkArticlePage()) return null;
    removeAll(document, "#article_soft_paywall, .ArticleSoftWall_container__0nfsw");

    var article = document.querySelector("article[itemtype='https://schema.org/NewsArticle']") ||
      document.querySelector("article [itemprop='articleBody']") && document.querySelector("article");
    if (!article) return null;

    return profileArticleContent(metadata, article, {
      title: firstText(["article [itemprop='headline']", "article h1", "h1"]) || btDkCleanTitle(metadata && metadata.title),
      byline: firstText(["article [rel='author']", "article [class*='Byline' i]"]) || (metadata && metadata.byline),
      minTextLength: 300,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".AdBanner_container__o4c56",
          "ad-banner",
          ".StandardArticleHead_meta__cZ9Sd",
          ".NewsArticleContent_actions__nChPf",
          ".NewsArticleContent_shareButtons__8S3eG",
          ".NewsArticleContent_rightColumnAds__r0wLC",
          ".ArticleSoftWall_container__0nfsw",
          "[class*='SoftWall' i]",
          "[class*='ShareButtons' i]",
          "[class*='frontPage' i]",
          "[class*='FrontPage' i]",
          "[data-ad-banner]"
        ].join(", "));

        root.querySelectorAll("a, div, span, p").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(navigation|sektioner|del:?|forsiden|mest læste|log ind og læs)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function btDkArticlePage() {
    if (!hostMatches(/(^|\.)bt\.dk$/)) return false;
    if (homepageRootPath()) return false;
    return !!document.querySelector("article[itemtype='https://schema.org/NewsArticle'] [itemprop='articleBody'], article .article-body");
  }

  function btDkCleanTitle(title) {
    return normalizeText(title || "").replace(/\s+\|\s+.*$/i, "");
  }

  var btDkBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return btDkArticleContent(metadata) || btDkBaseHostAwareContent(metadata, pageText);
  };
