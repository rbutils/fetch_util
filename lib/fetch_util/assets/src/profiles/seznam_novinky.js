  function seznamNovinkyArticleContent(metadata) {
    if (!seznamNovinkyArticlePage(metadata)) return null;

    var body = seznamNovinkyArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText(["[data-dot='ogm-article-header'] h1", ".article-header h1", "h1"]) || metadata.title,
      byline: firstText(["[data-dot='ogm-article-author-header']", ".article-author", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[data-dot*='advert' i]",
          "[class*='advert' i]",
          "[data-dot='mol-social-share-buttons']",
          "[data-dot='mol-social-share-popover']",
          "[data-dot='ogm-related-tags']",
          "[data-dot='ogm-timeline']",
          "[data-dot='ogm-seznam-recommends']",
          ".share-bar",
          ".social-share-buttons",
          ".related-tags",
          "[class*='discussion' i]",
          "[class*='recommend' i]",
          "[class*='timeline' i]"
        ].join(", "));

        root.querySelectorAll("h1, h2, h3, h4, h5, h6, p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(hlavní obsah|článek|chcete-li článek poslouchat|přehrát článek|sdílet|diskuze|související|nejnovější články|výběr článků)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function seznamNovinkyArticlePage(metadata) {
    if (!seznamNovinkyHost(metadata)) return false;
    if (homepageRootPath()) return false;
    return !!seznamNovinkyArticleBody();
  }

  function seznamNovinkyHost(metadata) {
    if (hostMatches(/(^|\.)novinky\.cz$/)) return true;
    var canonical = (metadata && metadata.canonicalUrl) || firstText(["link[rel='canonical']"], "href");
    try {
      return new URL(canonical, location.href).hostname.replace(/^www\./i, "") === "novinky.cz";
    } catch (e) {
      return false;
    }
  }

  function seznamNovinkyArticleBody() {
    var article = document.querySelector("article[data-dot='ogm-content']") ||
      document.querySelector("article[data-e2e='ogm-content']") ||
      document.querySelector("article[aria-labelledby='accessibility-article']") ||
      document.querySelector(".article-body") ||
      document.querySelector("[data-article]") ||
      document.querySelector(".m-article-text") ||
      document.querySelector("article article");
    if (!article) return null;

    var wrapper = document.createElement("div");
    var perex = document.querySelector("[data-dot='ogm-article-perex'], .article-perex");
    if (perex) wrapper.appendChild(safeDeepClone(perex, document));
    wrapper.appendChild(safeDeepClone(article, document));
    return wrapper;
  }

  registerHostAwareProfile(true, seznamNovinkyArticleContent);