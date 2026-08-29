  function financialTimesContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!/(^|\b)ft\.com\b|financial times/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    return newsHomepageListContent(metadata, {
      linkSelector: "main a[href*='/content/'], main a[href*='/stream/']",
      cardSelector: "article, section, .story-group__article, .story-group-slice, .o-teaser",
      minItems: 4,
      minTitleLength: 18,
      maxTitleLength: 180,
      titleBuilder: function(link) {
        return normalizeText(link.textContent);
      },
      transformTitle: function(title) {
        return title.replace(/^opinion content\.?\s*/i, "");
      },
      rejectTitle: /^(top stories|news|opinion|companies|markets news|video|life & arts|spotlight|most read|must-reads you missed|more opinion|more companies|more europe news|more markets news|more technology)$/i,
      siteName: location.hostname,
      defaultTitle: ""
    });
  }

  function economistContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)economist\.com$/) && !/economist/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    return newsHomepageListContent(metadata, {
      linkSelector: "main a[href]",
      cardSelector: "article, section, li, div",
      minItems: 4,
      minTitleLength: 18,
      maxTitleLength: 180,
      acceptLink: function(href) {
        return /(\/\d{4}\/\d{2}\/\d{2}\/|\/interactive\/)/.test(href);
      },
      rejectTitle: /^(subscribe|log in|the economist pro|weekly edition|current topics|world|business & economics|opinion|in depth|culture, history & society|our a-to-zs|featured story)$/i,
      siteName: "The Economist",
      defaultTitle: ""
    });
  }

  function bloombergContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)bloomberg\.com$/) && !/bloomberg/i.test(signature)) return null;
    if (/(\/news\/|\/opinion\/|\/features\/|\/graphics\/)/.test(location.pathname)) return null;

    return newsHomepageListContent(metadata, {
      linkSelector: "a[href*='/news/articles/'], a[href*='/news/features/'], a[href*='/opinion/articles/'], a[href*='/features/'], a[href*='/graphics/'], a[href*='/news/newsletters/']",
      cardSelector: "article, section, div",
      minItems: 4,
      minTitleLength: 18,
      maxTitleLength: 220,
      transformTitle: function(title) {
        return title.replace(/^AP Photo\s*/i, "").replace(/^Opinion\s*/i, "");
      },
      rejectTitle: /^(bloomberg opinion|bloomberg businessweek|newsletter:|watch)$/i,
      siteName: "Bloomberg",
      defaultTitle: ""
    });
  }

  function registerGenericPortalHomepageProfiles() {
    registerHostAwareProfile(true, genericPortalHomepageContent);
  }

  function registerNewsHomepageProfiles() {
    registerHostAwareProfile(true, bloombergContent);
    registerHostAwareProfile(true, economistContent);
    registerHostAwareProfile(true, financialTimesContent);
    registerGenericPortalHomepageProfiles();
  }
