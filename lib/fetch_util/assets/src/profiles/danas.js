  var danasArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)danas\.rs$/,
    bodySelectors: [".post-content.content", ".post-content"],
    titleSelectors: [".post-title", "article h1", "h1"],
    bylineSelectors: [".post-author .author-name a", ".post-author .author-name", "[rel='author']"],
    removalSelectors: [
      ".social-share-top",
      ".social-share-sticky",
      ".social-share-bottom",
      ".post-disclaimer",
      ".tags",
      ".comment-form",
      "#comment-form-div",
      ".more-comments-button",
      ".code-block",
      ".danas-dfp",
      ".embed-container",
      "iframe"
    ],
    minBodyTextLength: 500
  });

  registerHostAwareProfile(true, danasArticleContent);
  hostAwareProfiles.unshift(hostAwareProfiles.pop());
