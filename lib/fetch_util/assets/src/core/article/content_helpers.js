  function profileArticleTitle(metadata, root, node, options) {
    if (typeof options.title === "function") return normalizeText(options.title(metadata, root, node));
    if (options.title) return normalizeText(options.title);

    if (options.titleSelectors) {
      var title = firstText(options.titleSelectors);
      if (title) return title;
    }

    return normalizeText(metadata && metadata.title);
  }

  function profileArticleValue(value, metadata, root, node, markdown, text) {
    if (typeof value === "function") return value(metadata, root, node, markdown, text);
    return value;
  }

  var PUBLIC_ARTICLE_PAYWALL_SELECTORS = [
    "[data-paywall]",
    "[class*='paywall' i]",
    "[id*='paywall' i]",
    "[class*='subscribe-wall' i]",
    "[class*='premium-wall' i]",
    "[class*='piano-offer' i]"
  ];

  function profileArticleContent(metadata, node, options) {
    return profileHtmlContent(metadata, node, options);
  }

  var WORDPRESS_ARTICLE_BODY_SELECTORS = [
    "article[id^='post-'] .entry-content",
    "article[id^='post-'] .post-content",
    "article[id^='post-'] [itemprop='articleBody']",
    ".entry-content",
    ".post-content",
    "[itemprop='articleBody']"
  ];

  var WORDPRESS_ARTICLE_TITLE_SELECTORS = ["h1.entry-title", ".entry-title", "article h1", "main h1", "h1"];
  var WORDPRESS_ARTICLE_BYLINE_SELECTORS = ["[rel='author']", ".author", ".byline", ".post-author", "[class*='author' i]"];
  var WORDPRESS_ARTICLE_REMOVAL_SELECTORS = [
    ".sharedaddy",
    ".share",
    ".share-links",
    ".share-buttons",
    ".social-sharing",
    ".social-buttons",
    ".related-posts",
    ".yarpp-related",
    ".jp-relatedposts",
    ".adsbygoogle",
    "[class*='related' i]",
    "[class*='recommend' i]",
    "[class*='share' i]",
    "[class*='advert' i]",
    "[class*='sponsor' i]",
    "[id*='ad-' i]",
    "iframe",
    "script",
    "style"
  ];

  function wordpressArticleContent(metadata, options) {
    options = options || {};
    if (options.hostPattern && !simpleArticlePatternMatches(options.hostPattern, location.hostname)) return null;
    if (options.pathPattern && !simpleArticlePatternMatches(options.pathPattern, location.pathname || "")) return null;
    if (options.homepagePath && simpleArticlePatternMatches(options.homepagePath, location.pathname || "")) return null;
    if (typeof options.beforeExtract === "function") options.beforeExtract(metadata);

    var body = wordpressArticleBody(options) || wordpressRestArticleBody(options);
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: wordpressArticleTitle(metadata, options),
      byline: wordpressArticleByline(metadata, options),
      publishedTime: options.publishedTime,
      minTextLength: options.minBodyTextLength || options.minTextLength || 0,
      contentType: options.contentType || "article",
      extra: options.extra,
      rewriteRoot: function(root, node) {
        removeAll(root, wordpressArticleRemovalSelectors(options).join(", "));
        simpleArticleRemoveText(root, options.removalTextPatterns);
        if (typeof options.rewriteRoot === "function") options.rewriteRoot(root, node);
      }
    });
  }

  function wordpressArticleBody(options) {
    if (typeof options.body === "function") return options.body();

    var minTextLength = options.minVisibleBodyTextLength || 0;
    if (!minTextLength) return simpleArticleBody({ bodySelectors: options.bodySelectors || WORDPRESS_ARTICLE_BODY_SELECTORS });

    var selectors = options.bodySelectors || WORDPRESS_ARTICLE_BODY_SELECTORS;
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node && normalizeText(node.textContent || "").length >= minTextLength) return node;
    }
    return null;
  }

  function wordpressArticleTitle(metadata, options) {
    if (typeof options.title === "function") return options.title(metadata);
    if (options.title !== undefined) return options.title;
    return firstText(options.titleSelectors || WORDPRESS_ARTICLE_TITLE_SELECTORS) || normalizeText(metadata && metadata.title);
  }

  function wordpressArticleByline(metadata, options) {
    if (typeof options.byline === "function") return options.byline(metadata);
    if (options.byline !== undefined) return options.byline;
    return (metadata && metadata.byline) || firstText(options.bylineSelectors || WORDPRESS_ARTICLE_BYLINE_SELECTORS);
  }

  function wordpressArticleRemovalSelectors(options) {
    return WORDPRESS_ARTICLE_REMOVAL_SELECTORS.concat(options.removalSelectors || []);
  }

  function wordpressRestArticleBody(options) {
    var rest = options.restFallback;
    if (!rest) return null;

    var postId = wordpressRestPostId(rest);
    if (!postId) return null;

    var payload = wordpressRestFetch(rest, postId);
    var html = payload && payload.content && payload.content.rendered;
    if (!html) return null;

    var root = document.createElement("div");
    root.innerHTML = html;
    if (normalizeText(root.textContent || "").length < (rest.minTextLength || options.minBodyTextLength || 0)) return null;
    return root;
  }

  function wordpressRestPostId(rest) {
    if (typeof rest.postId === "function") return rest.postId(location);
    if (rest.postId) return rest.postId;

    var pattern = rest.postIdPattern || /(?:^|\/)news_(\d+)\/?$/i;
    var match = (location.pathname || "").match(pattern);
    return match && match[1];
  }

  function wordpressRestFetch(rest, postId) {
    var path = typeof rest.path === "function" ? rest.path(postId) : (rest.path || "/wp-json/wp/v2/posts/" + postId);
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("GET", path, false);
      xhr.send(null);
      if (xhr.status < 200 || xhr.status >= 300 || !xhr.responseText) return null;
      return JSON.parse(xhr.responseText);
    } catch (e) {
      return null;
    }
  }

  function profileHtmlContent(metadata, node, options) {
    if (!node) return null;

    options = options || {};
    var root = options.cloneRoot === false ? node : cleanClone(node);
    if (!root) return null;

    if (typeof options.rewriteRoot === "function") options.rewriteRoot(root, node);
    if (options.cleanupRoot !== false) cleanupAgentRoot(root);

    var markdown = markdownFor(root.innerHTML);
    if (options.cleanupMarkdown !== false) markdown = cleanupMarkdownNoise(markdown);
    if (typeof options.postProcessMarkdown === "function") markdown = options.postProcessMarkdown(markdown, root, node);

    var text = normalizeText(markdown);
    if (!text || text.length < (options.minTextLength || 0)) return null;
    if (typeof options.validateMarkdown === "function" && !options.validateMarkdown(markdown, text, root, node)) return null;

    var title = profileArticleTitle(metadata, root, node, options);
    if (title && options.prependTitle !== false && !markdownStartsWithTitle(markdown, title)) {
      markdown = "# " + title + "\n\n" + markdown;
    }

    var finalText = normalizeText(markdown);
    var excerpt = profileArticleValue(options.excerpt, metadata, root, node, markdown, text);
    if (excerpt === undefined && options.defaultExcerpt !== false) excerpt = text.slice(0, 280) || (metadata && metadata.excerpt);
    var byline = profileArticleValue(options.byline, metadata, root, node, markdown, text);
    if (byline === undefined) byline = metadata && metadata.byline;

    var result = {
      title: title || (metadata && metadata.title),
      byline: byline,
      excerpt: excerpt,
      siteName: profileArticleValue(options.siteName, metadata, root, node, markdown, text) || (metadata && metadata.siteName) || location.hostname,
      publishedTime: options.publishedTime === null ? null : (profileArticleValue(options.publishedTime, metadata, root, node, markdown, text) || (metadata && metadata.publishedTime)),
      html: root.innerHTML,
      markdown: markdown,
      textContent: finalText,
      readerMode: false,
      contentType: options.contentType || "article",
      hostAware: options.hostAware !== false
    };

    if (options.extra) {
      var extra = profileArticleValue(options.extra, metadata, root, node, markdown, text) || {};
      Object.keys(extra).forEach(function(key) { result[key] = extra[key]; });
    }

    return result;
  }
