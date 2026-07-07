  var kompasArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)kompas\.com$/,
    pathPattern: /(?:\/read\/|\/artikel\/|\.html(?:$|[?#]))/i,
    bodySelectors: [
      ".read__content",
      ".artikel-body",
      "#articleBody",
      ".read-content",
      "[itemprop='articleBody']"
    ],
    titleSelectors: [".read__title", ".article__title", "article h1", "h1"],
    bylineSelectors: [".read__author", ".read__credit__item", ".article__author"],
    removalSelectors: [
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
    ],
    removalTextPatterns: [
      /^(bagikan artikel ini melalui|kirimkan apresiasi|syarat dan ketentuan|gagal mengirimkan apresiasi|kamu telah berhasil mengirimkan apresiasi|pesan apresiasi berhasil|komentar:?\s*\d*|bagikan|salin link)$/i,
      /^terima kasih telah menjadi bagian dari jurnalisme jernih kompas\.com$/i,
      /^googletag\.cmd\.push\(/i
    ],
    minBodyTextLength: 250
  });

  registerHostAwareProfile(true, kompasArticleContent);
