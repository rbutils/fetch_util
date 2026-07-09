  function chosunArticleContent(metadata) {
    if (!hostMatches(/(^|\.)chosun\.com$/)) return null;

    var body = chosunArticleBody();
    if (!body || !body.querySelector("p, figure, blockquote")) return null;

    normalizePublicArticleAccessSignals(body, metadata, {
      minBodyTextLength: 300,
      minParagraphCount: 3,
      paragraphMinLength: 40,
      removalSelectors: [
        ".article-related-content",
        ".story-card",
        "[class*='related' i]",
        "[class*='story-card' i]",
        "[class*='recommend' i]"
      ].join(", ")
    });

    return profileArticleContent(metadata, body, {
      title: firstText(["article h1", "main h1", "h1"]) || metadata.title,
      byline: firstText([".byline", "[rel='author']"]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".article-related-content",
          ".story-card",
          "[class*='related' i]",
          "[class*='story-card' i]",
          "[class*='recommend' i]"
        ].join(", "));

        root.querySelectorAll("p, div, span, section, aside").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (text.length > 220) return;
          if (/^(관련기사|추천기사|많이 본 뉴스|많이 본 기사|구독|프리미엄)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function chosunArticleBody() {
    return document.querySelector("main") ||
      document.querySelector("article") ||
      document.querySelector("main article");
  }

  registerHostAwareProfile(true, chosunArticleContent);
