  function simpleArticlePatternMatches(pattern, value) {
    if (!pattern) return true;
    value = value || "";
    if (pattern instanceof RegExp) return pattern.test(value);
    if (typeof pattern === "string") return value === pattern || value.slice(-(pattern.length + 1)) === "." + pattern;
    return false;
  }

  function simpleArticleBody(config) {
    if (typeof config.body === "function") return config.body();

    var selectors = config.bodySelectors || [];
    for (var i = 0; i < selectors.length; i += 1) {
      var body = document.querySelector(selectors[i]);
      if (body) return body;
    }

    return null;
  }

  function simpleArticleTitle(config, metadata) {
    if (typeof config.title === "function") return config.title(metadata);
    if (config.title !== undefined) return config.title;
    if (config.titleSelectors) return firstText(config.titleSelectors) || normalizeText(metadata && metadata.title);
    return undefined;
  }

  function simpleArticleByline(config, metadata) {
    if (typeof config.byline === "function") return config.byline(metadata);
    if (config.byline !== undefined) return config.byline;
    if (config.bylineSelectors) return firstText(config.bylineSelectors) || (metadata && metadata.byline);
    return undefined;
  }

  function simpleArticleRemoveText(root, patterns) {
    (patterns || []).forEach(function(pattern) {
      root.querySelectorAll("p, div, span, section, a, button, h2, h3, h4, li").forEach(function(el) {
        var text = normalizeText(el.textContent || "");
        if (!text) return;
        if (pattern instanceof RegExp && pattern.test(text)) el.remove();
        if (typeof pattern === "string" && text === pattern) el.remove();
      });
    });
  }

  function simpleArticleProfile(config) {
    config = config || {};
    return function(metadata) {
      if (!simpleArticlePatternMatches(config.hostPattern, location.hostname)) return null;
      if (config.pathPattern && !simpleArticlePatternMatches(config.pathPattern, location.pathname || "")) return null;
      if (config.homepagePath && simpleArticlePatternMatches(config.homepagePath, location.pathname || "")) return null;
      if (typeof config.beforeExtract === "function") config.beforeExtract(metadata);

      var body = simpleArticleBody(config);
      if (!body) return null;

      return profileArticleContent(metadata, body, {
        title: simpleArticleTitle(config, metadata),
        titleSelectors: config.titleSelectors,
        byline: simpleArticleByline(config, metadata),
        publishedTime: config.publishedTime,
        minTextLength: config.minBodyTextLength || 0,
        contentType: config.contentType || "article",
        extra: config.extra,
        rewriteRoot: function(root, node) {
          removeAll(root, (config.removalSelectors || []).join(", "));
          simpleArticleRemoveText(root, config.removalTextPatterns);
          if (typeof config.rewriteRoot === "function") config.rewriteRoot(root, node);
        }
      });
    };
  }

  function simpleArticleProfileRegistration(config) {
    config = config || {};
    registerHostAwareProfile(config.condition === undefined ? true : config.condition, simpleArticleProfile(config));
  }
