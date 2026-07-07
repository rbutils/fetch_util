  function kompasArticleContent(metadata) {
    if (!kompasArticlePage()) return null;

    var body = kompasArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".read__title", ".article__title", "article h1", "h1"]) || metadata.title,
      byline: firstText([".read__author", ".read__credit__item", ".article__author"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[data-modal-target]",
          "[data-modal]",
          "[class*='apresiasi' i]",
          "[class*='appreciation' i]",
          "[class*='share' i]",
          "[class*='comment' i]",
          "[class*='komentar' i]",
          "[class*='read__aside' i]",
          "[class*='read__right' i]",
          ".social",
          ".social-share",
          ".floating-share",
          ".photo__icon",
          "#div-gpt-for-outstream",
          "[id*='div-gpt' i]",
          "[id*='google_ads' i]",
          "[class*='ads' i]"
        ].join(", "));

        root.querySelectorAll("p, div, section, aside, span, li, button").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(bagikan artikel ini melalui|kirimkan apresiasi|syarat dan ketentuan|gagal mengirimkan apresiasi|kamu telah berhasil mengirimkan apresiasi|pesan apresiasi berhasil|komentar:?\s*\d*|bagikan|salin link)$/i.test(text)) el.remove();
          if (/^terima kasih telah menjadi bagian dari jurnalisme jernih kompas\.com$/i.test(text)) el.remove();
          if (/^googletag\.cmd\.push\(/i.test(text)) el.remove();
        });
      }
    });
  }

  function kompasArticlePage() {
    if (!hostMatches(/(^|\.)kompas\.com$/)) return false;
    if (!/(?:\/read\/|\/artikel\/|\.html(?:$|[?#]))/i.test(location.pathname || "")) return false;
    return !!kompasArticleBody();
  }

  function kompasArticleBody() {
    return document.querySelector(".read__content") ||
      document.querySelector(".artikel-body") ||
      document.querySelector("#articleBody") ||
      document.querySelector(".read-content") ||
      document.querySelector("[itemprop='articleBody']");
  }

  registerHostAwareProfile(true, kompasArticleContent);