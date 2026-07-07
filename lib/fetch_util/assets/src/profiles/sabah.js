  function sabahArticleContent(metadata) {
    if (!sabahArticlePage()) return null;

    var body = sabahArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".contentFrame .pageTitle", ".contentFrame h1", "h1"]) || metadata.title,
      byline: metadata.byline,
      minTextLength: 250,
      cloneRoot: false,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[class*='advert' i]",
          "[class*='reklam' i]",
          "[class*='ad-' i]",
          "[id*='ad-' i]",
          "[class*='share' i]",
          "[class*='social' i]",
          "[class*='related' i]",
          "[class*='gallery' i]",
          "[class*='video' i]",
          "a[href*='trkvz.im']",
          "img[src*='googlenews' i]"
        ].join(", "));

        root.querySelectorAll("p, div, section, span, h2, h3, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          var tag = (el.tagName || "").toLowerCase();
          if (!text) return;
          if (/^(son dakika|günün en çok okunanları|sıradaki haber|ilgili haberler|galeri|video|reklam|haber girişi|uygulamalara özel ayrıcalıkları keşfedin)$/i.test(text)) el.remove();
          if (text.indexOf("Sabah.com.tr Uygulam") === 0) el.remove();
          if (tag !== "div" && tag !== "section" && /google haberler'de tüm gelişmeleri tek kaynakta görmek için sabah'ı takip edin/i.test(text)) el.remove();
        });
      }
    });
  }

  function sabahArticlePage() {
    if (!hostMatches(/(^|\.)sabah\.com\.tr$/)) return false;
    return !!sabahArticleBody();
  }

  function sabahArticleBody() {
    var frame = document.querySelector(".contentFrame") || document.querySelector("main") || document;
    var bodySelector = ".newsDetailText, section[data-url] .page[data-page], [itemprop='articleBody']";
    var bodyNodes = Array.prototype.slice.call(frame.querySelectorAll(bodySelector));
    if (bodyNodes.length === 0 && frame !== document) bodyNodes = Array.prototype.slice.call(document.querySelectorAll(bodySelector));
    if (bodyNodes.length === 0) return null;

    var root = document.createElement("article");
    [".pageTitle", "h1.pageTitle", "h1", ".spot", "h2.spot"].forEach(function(selector) {
      var node = frame.querySelector(selector) || document.querySelector(selector);
      if (node && !root.querySelector(selector)) root.appendChild(safeDeepClone(node, document));
    });

    bodyNodes.forEach(function(node) {
      var text = normalizeText(node.textContent || "");
      if (text.length >= 60) root.appendChild(safeDeepClone(node, document));
    });

    return normalizeText(root.textContent || "").length >= 250 ? root : null;
  }

  var sabahBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return sabahArticleContent(metadata) || sabahBaseHostAwareContent(metadata, pageText);
  };
