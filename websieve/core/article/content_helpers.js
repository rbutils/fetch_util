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
    "article .post-description",
    ".post-description",
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

    var body = wordpressArticleBody(options) || wordpressRestArticleBody(options, metadata);
    if (!body) return null;
    var pageRoot = wordpressBlockPageRoot(body);
    if (pageRoot) body = pageRoot;
    var comments = options.includeHeaderContext ? wordpressArticleCommentThreads(body) : [];
    if (options.includeHeaderContext) body = wordpressArticleHeaderContext(body);
    var excerpt = options.excerpt;
    if (excerpt === undefined && options.includeHeaderContext) excerpt = wordpressArticleExcerpt;

    var content = profileArticleContent(metadata, body, {
      title: wordpressArticleTitle(metadata, options),
      byline: wordpressArticleByline(metadata, options),
      publishedTime: options.publishedTime,
      excerpt: excerpt,
      minTextLength: options.minBodyTextLength || options.minTextLength || 0,
      contentType: options.contentType || "article",
      extra: options.extra,
      rewriteRoot: function(root, node) {
        removeAll(root, wordpressArticleRemovalSelectors(options).join(", "));
        simpleArticleRemoveText(root, options.removalTextPatterns);
        if (!pageRoot && typeof options.rewriteRoot === "function") options.rewriteRoot(root, node);
      }
    });
    if (content && pageRoot) content.wordpressBlockPage = true;
    return wordpressArticleAppendComments(content, comments);
  }

  function wordpressArticleBody(options) {
    if (typeof options.body === "function") return options.body();

    var ownedBody = options.includeHeaderContext && wordpressFocalPostBody();
    if (ownedBody) return ownedBody;

    var minTextLength = options.minVisibleBodyTextLength || 0;
    var selectors = options.bodySelectors || WORDPRESS_ARTICLE_BODY_SELECTORS;
    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = document.querySelectorAll(selectors[i]);
      for (var j = 0; j < nodes.length; j += 1) {
        var node = nodes[j];
        if (!elementSubtreeHidden(node) && normalizeText(node.innerText || "").length >= minTextLength) return node;
      }
    }
    return null;
  }

  function wordpressFocalPostBody() {
    var headings = Array.from(document.querySelectorAll("article h1")).filter(function(heading) {
      var owner = heading.closest("article");
      return !elementSubtreeHidden(heading) && !owner.parentElement.closest("article") &&
        !owner.closest("aside, nav, footer, [role='navigation'], [role='complementary']");
    });
    if (headings.length !== 1) return null;
    var owner = headings[0].closest("article");
    var bodies = Array.from(owner.querySelectorAll(".post-body")).filter(function(body) {
      return body.closest("article") === owner && !elementSubtreeHidden(body) &&
        !body.closest("aside, nav, footer, [role='navigation'], [role='complementary']") &&
        !!(headings[0].compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        Array.from(body.querySelectorAll("p")).some(function(paragraph) {
          return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "");
        });
    });
    return bodies.length === 1 ? bodies[0] : null;
  }

  function wordpressArticleTitle(metadata, options) {
    if (typeof options.title === "function") return options.title(metadata);
    if (options.title !== undefined) return options.title;
    var heading = firstText(options.titleSelectors || WORDPRESS_ARTICLE_TITLE_SELECTORS);
    if (heading) return heading;

    var title = normalizeText(metadata && metadata.title);
    var publisher = document.querySelector("meta[property='og:site_name' i]");
    var siteName = normalizeText(publisher && publisher.getAttribute("content"));
    if (!options.includeHeaderContext || !siteName || !metadata ||
        siteName.toLowerCase() !== normalizeText(metadata.siteName).toLowerCase()) return title;
    var parts = title.match(/^(.*\S)\s+[|\u2013\u2014-]\s+(.+)$/);
    return parts && normalizeText(parts[2]).toLowerCase() === siteName.toLowerCase() ? parts[1] : title;
  }

  function wordpressArticleByline(metadata, options) {
    if (typeof options.byline === "function") return options.byline(metadata);
    if (options.byline !== undefined) return options.byline;
    return (metadata && metadata.byline) || firstText(options.bylineSelectors || WORDPRESS_ARTICLE_BYLINE_SELECTORS);
  }

  function wordpressArticleRemovalSelectors(options) {
    return WORDPRESS_ARTICLE_REMOVAL_SELECTORS.concat(options.removalSelectors || []);
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
