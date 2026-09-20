  function tropeWikiContent(metadata) {
    var node = document.querySelector("#main-article .article-content, #main-content .article-content, .article-content.retro-folders");
    if (!node) return null;

    var links = Array.prototype.filter.call(node.querySelectorAll("a[href]"), function(link) {
      return /\/pmwiki\/pmwiki\.php\/Main\//i.test(link.getAttribute("href") || "");
    }).length;
    var listItems = node.querySelectorAll("li").length;
    if (listItems < 20 || links < 10) return null;

    var title = firstText(["#main-article h1", "#main-content h1", "h1"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*-\s*TV Tropes\s*$/i, ""));
    return profileArticleContent(metadata, node, {
      title: title,
      byline: null,
      publishedTime: null,
      minTextLength: 1200,
      rewriteRoot: function(root) {
        ["#modal_overlay", ".modal_overlay", "script", "style", "iframe", ".ad-unit", "[id*='ad-']", "[class*='ad-']", "[class*='advert']", "[class*='watch']"].forEach(function(selector) {
          root.querySelectorAll(selector).forEach(function(el) { el.remove(); });
        });
      }
    });
  }

  function registerTvTropesProfiles() {
    registerHostAwareProfile(true, tropeWikiContent);
  }
