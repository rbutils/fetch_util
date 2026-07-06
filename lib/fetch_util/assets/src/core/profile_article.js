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

  function profileArticleContent(metadata, node, options) {
    return profileHtmlContent(metadata, node, options);
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
