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
    registerGenericPortalHomepageProfiles();
  }
