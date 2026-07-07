var maroelaMediaArticleContent = simpleArticleProfile({
  hostPattern: /(^|\.)maroelamedia\.co\.(?:za|tz)$/,
  pathPattern: /^\/(?:nuus|debat)\/(?:[^/]+\/)+[^/]+\/?$/i,
  homepagePath: /^(?:\/|\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?|)$/i,
  bodySelectors: [".entry-content", "article .entry-content", ".post-content", ".article-content", "[itemprop='articleBody']"],
  title: function(metadata) { return normalizeText(((metadata && metadata.title) || document.title || "").replace(/\s*-\s*Maroela Media\s*$/i, "")); },
  removalTextPatterns: [/^o wee, die gesang is uit!/i],
  minBodyTextLength: 250
});

registerHostAwareProfile(true, maroelaMediaArticleContent);
