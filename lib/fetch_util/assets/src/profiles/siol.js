var siolArticleContent = simpleArticleProfile({
  hostPattern: /(^|\.)siol\.net$/,
  bodySelectors: [".article_content"],
  titleSelectors: [".article__wrap h1", "h1"],
  bylineSelectors: [".article__wrap [rel='author']", ".article__wrap [class*='author' i]"],
  removalSelectors: [
    ".article_advertorial_widget",
    ".article_content__gallery",
    ".article_content__gallery_wrapper",
    ".article_left_sidebar",
    ".article_right_sidebar",
    ".fold_hotness_and_latest__widget_group",
    ".related_articles_widget",
    ".lightbluebox",
    "aside",
    "nav"
  ],
  minBodyTextLength: 500
});
