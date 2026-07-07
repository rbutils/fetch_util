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

  function composeProfileArticleRoot(config) {
    config = config || {};

    var scope = profileArticleRootScope(config);
    if (!scope) return null;

    var root = document.createElement("article");
    var seenText = [];
    var hasBody = false;

    profileArticleAppendPart(root, scope, config.titleSelectors, seenText, false);
    profileArticleAppendPart(root, scope, config.leadSelectors, seenText, false);
    profileArticleAppendPart(root, scope, config.summarySelectors, seenText, false);
    profileArticleAppendPart(root, scope, config.captionSelectors || config.mediaCaptionSelectors, seenText, false);
    hasBody = profileArticleAppendPart(root, scope, config.bodySelectors, seenText, true);

    if (config.requireBody !== false && !hasBody) return null;
    return normalizeText(root.textContent || "").length >= (config.minTextLength || 0) ? root : null;
  }

  function profileArticleRootScope(config) {
    if (typeof config.scope === "function") return config.scope();
    if (config.scope) return config.scope;

    var selectors = config.scopeSelectors || [];
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node) return node;
    }

    return document;
  }

  function profileArticleAppendPart(root, scope, selectors, seenText, appendAll) {
    if (!selectors) return false;

    var selectorList = Array.isArray(selectors) ? selectors : [selectors];
    var appended = false;
    for (var i = 0; i < selectorList.length; i += 1) {
      var node = profileArticlePartNode(scope, selectorList[i]);
      if (!node) continue;

      if (profileArticleAppendNode(root, node, seenText)) appended = true;
      if (appended && !appendAll) return true;
    }
    return appended;
  }

  function profileArticlePartNode(scope, selector) {
    if (typeof selector === "function") return selector(scope, document);
    if (selector && selector.nodeType === 1) return selector;
    if (!selector) return null;
    return (scope.querySelector && scope.querySelector(selector)) || document.querySelector(selector);
  }

  function profileArticleAppendNode(root, node, seenText) {
    var text = normalizeText(node.textContent || "");
    if (!text || seenText.indexOf(text) >= 0) return false;

    seenText.push(text);
    root.appendChild(safeDeepClone(node, document));
    return true;
  }

  function liveblogSingleEntryContent(metadata, options) {
    options = options || {};

    var entry = liveblogSelectedEntry(options);
    if (!entry) return null;

    if (typeof options.beforeBuild === "function") options.beforeBuild(metadata, entry);

    var root = liveblogArticleRoot(entry, options);
    if (!root) return null;

    var articleOptions = {};
    Object.keys(options).forEach(function(key) { articleOptions[key] = options[key]; });
    articleOptions.cloneRoot = false;
    articleOptions.title = options.title !== undefined ? liveblogEntryValue(options.title, metadata, root, entry) : liveblogEntryText(entry, options.titleSelector);
    articleOptions.byline = options.byline !== undefined ? liveblogEntryValue(options.byline, metadata, root, entry) : liveblogEntryText(entry, options.bylineSelector);
    articleOptions.publishedTime = options.publishedTime !== undefined ? liveblogEntryValue(options.publishedTime, metadata, root, entry) : liveblogEntryTime(entry, options.timeSelector);
    articleOptions.rewriteRoot = function(cleanRoot, originalNode) {
      if (options.cleanupSelectors) removeAll(cleanRoot, Array.isArray(options.cleanupSelectors) ? options.cleanupSelectors.join(", ") : options.cleanupSelectors);
      if (typeof options.rewriteRoot === "function") options.rewriteRoot(cleanRoot, originalNode);
    };
    articleOptions.extra = function(md, cleanRoot, originalNode, markdown, text) {
      var extra = profileArticleValue(options.extra, md, cleanRoot, originalNode, markdown, text) || {};
      extra.isolatedLiveblogEntry = true;
      return extra;
    };

    return profileArticleContent(metadata, root, articleOptions);
  }

  function liveblogSelectedEntry(options) {
    if (typeof options.selectedEntry === "function") return options.selectedEntry(options);
    if (options.selectedEntry) return options.selectedEntry;

    var id = typeof options.entryIdFromUrl === "function" ? options.entryIdFromUrl(location) : options.entryIdFromUrl;
    if (id) {
      var byId = document.getElementById(String(id));
      if (!byId && options.entryIdPrefix) byId = document.getElementById(options.entryIdPrefix + id);
      if (!byId && typeof options.entryForId === "function") byId = options.entryForId(id);
      if (byId) return byId;
    }

    if (!options.entrySelector) return null;

    var entries = Array.prototype.slice.call(document.querySelectorAll(options.entrySelector));
    if (!entries.length) return null;
    if (typeof options.entryMatcher === "function") {
      var matched = entries.find(function(entry) { return options.entryMatcher(entry, options); });
      if (matched) return matched;
    }
    return entries[0];
  }

  function liveblogArticleRoot(entry, options) {
    if (typeof options.rootBuilder === "function") return options.rootBuilder(entry, options);
    if (!options.bodySelector) return entry;

    var root = document.createElement("article");
    liveblogAppendMatches(root, entry, options.bodySelector);
    return normalizeText(root.textContent || "") ? root : null;
  }

  function liveblogEntryValue(value, metadata, root, entry) {
    if (typeof value === "function") return value(metadata, root, entry);
    return value;
  }

  function liveblogAppendMatches(root, entry, selectors) {
    (Array.isArray(selectors) ? selectors : [selectors]).forEach(function(selector) {
      if (!selector) return;
      var node = entry.matches && entry.matches(selector) ? entry : entry.querySelector(selector);
      if (node) root.appendChild(safeDeepClone(node, document));
    });
  }

  function liveblogEntryText(entry, selectors) {
    if (!selectors) return undefined;
    var selectorList = Array.isArray(selectors) ? selectors : [selectors];
    for (var i = 0; i < selectorList.length; i += 1) {
      var selector = selectorList[i];
      var node = entry.querySelector(selector.selector || selector);
      var value = selector.attr ? node && node.getAttribute(selector.attr) : node && node.textContent;
      value = normalizeText(value);
      if (value) return value;
    }
    return undefined;
  }

  function liveblogEntryTime(entry, selector) {
    if (!selector) return undefined;
    var node = entry.querySelector(selector);
    return node ? (node.getAttribute("datetime") || normalizeText(node.textContent || "")) : undefined;
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
