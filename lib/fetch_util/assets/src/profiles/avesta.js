  var avestaArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)avesta\.tj$/,
    pathPattern: /\/\d{4}\/\d{2}\/\d{2}\/[^/?#]+\/?$/i,
    bodySelectors: [
      ".entry-content.with-share .content-inner",
      ".entry-content .content-inner",
      ".single-post .content-inner"
    ],
    titleSelectors: [
      ".jeg_post_title",
      ".entry-header h1",
      "h1"
    ],
    minBodyTextLength: 200,
    removalSelectors: [
      ".jeg_share_button",
      ".jeg_share_top_container",
      ".jeg_ad",
      ".jeg_breadcrumbs",
      ".jeg_post_meta",
      ".jeg_post_tags",
      ".post-navigation",
      "script",
      "style"
    ]
  });

  registerHostAwareProfile(/(^|\.)avesta\.tj$/, avestaArticleContent);
