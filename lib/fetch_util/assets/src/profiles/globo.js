  function globoArticleContent(metadata) {
    if (!globoArticlePage()) return null;

    var body = globoArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([
        ".content-head__title",
        ".content-article__title",
        ".article__title",
        "h1"
      ]) || metadata.title,
      byline: firstText([
        ".content-publication-data__from",
        ".content-publication-data__updated",
        ".content-article__author",
        ".article__author"
      ]) || metadata.byline,
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".content-media__video",
          ".content-media__embed",
          ".cxm-block-video__player-wrapper",
          ".mc-video",
          ".mc-intertitle",
          ".mc-advertising",
          ".content-ads",
          ".content-share-bar",
          ".share-bar",
          ".bstn-related",
          ".bstn-fd-relatedtext",
          ".feed-post",
          "[data-type='advertising']",
          "[data-testid*='share']"
        ].join(", "));

        root.querySelectorAll("p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(assista também|minimizar vídeo|vídeo player|00:00\s*\/)/i.test(text) && text.length < 120) el.remove();
        });
      }
    });
  }

  function globoArticlePage() {
    if (!hostMatches(/(^|\.)globo\.com$/) && !hostMatches(/(^|\.)globo\.es$/)) return false;
    if (!/(?:\/noticia\/|\.ghtml(?:$|[?#])|\/jogo\/)/i.test(location.pathname || "")) return false;
    return !!globoArticleBody();
  }

  function globoArticleBody() {
    return document.querySelector(".mc-article-body") ||
      document.querySelector(".content-article__content") ||
      document.querySelector(".article__content") ||
      document.querySelector(".glb-conteudo") ||
      document.querySelector("article[itemprop='articleBody']") ||
      document.querySelector("[itemprop='articleBody']");
  }

  var globoBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return globoArticleContent(metadata) || globoBaseHostAwareContent(metadata, pageText);
  };
