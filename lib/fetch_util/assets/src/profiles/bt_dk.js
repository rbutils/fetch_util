  var btDkArticleContent = simpleArticleProfile({
    hostPattern: /(^|\.)bt\.dk$/,
    homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
    bodySelectors: ["article[itemtype='https://schema.org/NewsArticle']:has([itemprop='articleBody'])", "article:has([itemprop='articleBody'])", "article:has(.article-body)"],
    title: function(metadata) { return firstText(["article [itemprop='headline']", "article h1", "h1"]) || normalizeText(metadata && metadata.title).replace(/\s+\|\s+.*$/i, ""); },
    removalSelectors: [".AdBanner_container__o4c56", "ad-banner", ".StandardArticleHead_meta__cZ9Sd", ".NewsArticleContent_actions__nChPf", ".NewsArticleContent_shareButtons__8S3eG", ".NewsArticleContent_rightColumnAds__r0wLC", ".ArticleSoftWall_container__0nfsw", "[class*='SoftWall' i]", "[class*='ShareButtons' i]", "[class*='frontPage' i]", "[class*='FrontPage' i]", "[data-ad-banner]"],
    removalTextPatterns: [/^(navigation|sektioner|del:?|forsiden|mest læste|log ind og læs)$/i],
    minBodyTextLength: 300,
    beforeExtract: function() { removeAll(document, "#article_soft_paywall, .ArticleSoftWall_container__0nfsw"); }
  });

  registerHostAwareProfile(true, btDkArticleContent);
