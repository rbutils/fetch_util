  var hindustanTimesArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)hindustantimes\.com$/i,
    bodySelectors: [".artContent"],
    titleSelectors: ["h1"],
    beforeExtract: function(metadata) {
      if (metadata) metadata.publishedTime = null;
    },
    publishedTime: null,
    removalTextPatterns: [
      /^Get Current Updates on\b/i,
      /^Prefer HT\b/i,
      /^Hindi Language$/i,
      /^SIGN UP TO SUBSCRIBE$/i
    ],
    extra: {
      packagePage: true
    },
    removalSelectors: [
      ".bottomTopics",
      ".topicListContainer",
      ".storyAd",
      ".middleTaboola",
      ".promotedWidget",
      ".adHeight313",
      ".minHeight325",
      ".h325",
      ".footerLogin",
      ".nav-footer",
      "footer",
      "[id^='taboola-']",
      "[id^='ad-']",
      ".fc-footer",
      ".fc-dialog-restricted-content"
    ]
  });

  registerHostAwareProfile(true, hindustanTimesArticleContent);
