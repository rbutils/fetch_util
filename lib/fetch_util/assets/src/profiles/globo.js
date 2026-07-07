  var globoArticleContent = simpleArticleProfile({
    hostPattern: /(?:^|\.)globo\.(?:com|es)$/,
    pathPattern: /(?:\/noticia\/|\.ghtml(?:$|[?#])|\/jogo\/)/i,
    bodySelectors: [
      ".mc-article-body",
      ".content-article__content",
      ".article__content",
      ".glb-conteudo",
      "article[itemprop='articleBody']",
      "[itemprop='articleBody']"
    ],
    titleSelectors: [
      ".content-head__title",
      ".content-article__title",
      ".article__title",
      "h1"
    ],
    bylineSelectors: [
      ".content-publication-data__from",
      ".content-publication-data__updated",
      ".content-article__author",
      ".article__author"
    ],
    removalSelectors: [
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
    ],
    removalTextPatterns: [/^(assista também|minimizar vídeo|vídeo player|00:00\s*\/)/i],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, globoArticleContent);
