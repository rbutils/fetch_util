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

  function normalizePublicArticleAccessSignals(root, metadata, options) {
    options = options || {};
    var target = root || document.body;
    if (!target) return root;

    var probe = target.cloneNode(true);
    profileAccessSignalsRemoveNodes(probe, options.removalSelectors);
    profileAccessSignalsRemoveText(probe, options.textRemovalPattern, options.textRemovalMaxLength);

    var text = normalizeText(probe.textContent || "");
    if (options.bodyRejectPattern && options.bodyRejectPattern.test(text)) return root;
    if (options.hardPaywallPattern && options.hardPaywallPattern.test(text)) return root;
    if (options.pageHardPaywallPattern) {
      var pageText = normalizeText(document.body ? (document.body.innerText || document.body.textContent || "") : "");
      if (options.pageHardPaywallPattern.test(pageText)) return root;
    }

    var paragraphSelectors = options.paragraphSelectors || "p";
    var paragraphMinLength = options.paragraphMinLength || 70;
    var paragraphCount = Array.prototype.filter.call(probe.querySelectorAll(paragraphSelectors), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= paragraphMinLength;
    }).length;

    if (text.length < (options.minBodyTextLength || 1200)) return root;
    if (paragraphCount < (options.minParagraphCount === undefined ? 3 : options.minParagraphCount)) return root;

    profileAccessSignalsRemoveNodes(target, options.removalSelectors);
    profileAccessSignalsRemoveText(target, options.textRemovalPattern, options.textRemovalMaxLength);
    profileAccessSignalsRemoveNodes(document, options.signalRemovalSelectors || options.removalSelectors);
    profileAccessSignalsRemoveText(document, options.textRemovalPattern, options.textRemovalMaxLength);
    profileAccessSignalsStripAttributes(options);
    profileAccessSignalsNormalizeMetadata(metadata, options);
    return root;
  }

  function profileAccessSignalsRemoveNodes(root, selectors) {
    if (!root || !selectors) return;
    removeAll(root, Array.isArray(selectors) ? selectors.join(", ") : selectors);
  }

  function profileAccessSignalsRemoveText(root, pattern, maxLength) {
    if (!root || !pattern) return;
    maxLength = maxLength || 280;
    root.querySelectorAll("p, div, span, section, aside, figcaption").forEach(function(el) {
      var text = normalizeText(el.textContent || "");
      if (!text || text.length > maxLength) return;
      if (pattern.test(text)) el.remove();
    });
  }

  function profileAccessSignalsStripAttributes(options) {
    var selector = options.stripAttributeSelectors;
    if (!selector) return;

    document.querySelectorAll(selector).forEach(function(el) {
      if (options.stripIdPattern && options.stripIdPattern.test(el.getAttribute("id") || "")) el.removeAttribute("id");
      if (options.stripClassPattern) {
        var classes = (el.getAttribute("class") || "").split(/\s+/).filter(function(name) {
          return name && !options.stripClassPattern.test(name);
        });
        if (classes.length) {
          el.setAttribute("class", classes.join(" "));
        } else {
          el.removeAttribute("class");
        }
      }
    });
  }

  function profileAccessSignalsNormalizeMetadata(metadata, options) {
    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      var text = script.textContent || "";
      if (options.structuredDataMode === "remove") {
        var removePattern = options.structuredDataRemovalPattern || /isAccessibleForFree/i;
        if (removePattern.test(text)) script.remove();
        return;
      }
      if (/isAccessibleForFree/i.test(text)) {
        script.textContent = text.replace(/("isAccessibleForFree"\s*:\s*)"?(?:false|False)"?/g, "$1true");
      }
    });

    document.querySelectorAll("meta[property='article:content_tier'], meta[name='article:content_tier']").forEach(function(meta) {
      if (/^(locked|metered|premium)$/i.test(meta.getAttribute("content") || "")) meta.remove();
    });

    if (metadata) {
      metadata.isAccessibleForFree = true;
      if (metadata.contentTier) metadata.contentTier = null;
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
