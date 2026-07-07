  function interiaArticleContent(metadata) {
    if (!interiaArticlePage()) return null;

    var body = interiaArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText(["article h1", "h1"]) || metadata.title,
      minTextLength: 250,
      cloneRoot: false,
      rewriteRoot: function(root) {
        removeAll(root, [
          "[data-component-0='wrapper-group']",
          "[data-component-0='article-list']",
          "[data-component-0='ad-rectangle']",
          "[data-component-0='ads']",
          "[data-component-0='share']",
          "[data-icon]",
          ".audio-news-player",
          ".ids-audio-news-player",
          ".emotion-bar",
          ".like-button",
          ".reaction",
          ".share-bar",
          ".social-share",
          "[class*='emotion' i]",
          "[class*='share' i]",
          "[class*='social' i]",
          "[class*='related' i]",
          "[class*='article-list' i]",
          "[class*='ads' i]",
          "[id*='ad-' i]",
          "[id*='google_ads' i]",
          "script",
          "style"
        ].join(", "));

        root.querySelectorAll("p, div, section, span, li, button, h2").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text) return;
          if (/^(odsłuchaj artykuł|audio generowane przez ai|lubię to|zły|super|hahaha|szok|smutny|udostępnij|zobacz również:?|reklama)$/i.test(text)) el.remove();
          if (/^\d{1,2}:\d{2}\s*min$/i.test(text)) el.remove();
        });
      }
    });
  }

  function interiaArticlePage() {
    if (!hostMatches(/(^|\.)interia\.pl$/)) return false;
    return !!interiaArticleBody();
  }

  function interiaArticleBody() {
    var article = document.querySelector("[data-component-0='article-content']") ||
      document.querySelector(".article-body") ||
      document.querySelector("#article-content") ||
      document.querySelector(".content-article") ||
      document.querySelector("[itemprop='articleBody']");
    if (!article) return null;

    var lead = document.querySelector("[data-component-1='body'].ids-paragraph--lead") ||
      document.querySelector(".lead-text") ||
      document.querySelector("article header [data-component-1='body']");
    var root = leadBodyArticleRoot(lead, article);
    return root;
  }

  registerHostAwareProfile(true, interiaArticleContent);
