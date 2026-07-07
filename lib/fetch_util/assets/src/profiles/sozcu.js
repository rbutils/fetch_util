  function sozcuContent(metadata) {
    if (!hostMatches(/(^|\.)sozcu\.com\.tr$/)) return null;

    return sozcuHomepageContent(metadata);
  }

  function sozcuHomepageContent(metadata) {
    return newsHomepageListContent(metadata, sozcuHomepageListConfig());
  }

  function sozcuHomepageListConfig() {
    return {
      pathAllowed: homepageRootPath,
      linkSelector: ".breaking-news a[href], .news-card a[href]",
      excludeClosest: ".bik-ilan, .currency, .authorSwiper, header, nav, footer, aside, form",
      cardSelector: ".news-card, .breaking-news, article, section, li",
      acceptLink: function(_href, url) { return /^https?:\/\/(?:www\.)?sozcu\.com\.tr\//i.test(url) && /-p\d+(?:$|[?#])/i.test(url); },
      rejectTitle: /^(son dakika|tümünü gör|sözcü tv|canlı izle)$/i,
      defaultTitle: "Sözcü",
      siteName: "Sözcü",
      hostAware: true,
      statusPage: true
    };
  }

  registerNewsHomepageListProfile(/(^|\.)sozcu\.com\.tr$/, sozcuHomepageListConfig);
  registerHostAwareProfile(true, sozcuContent);
