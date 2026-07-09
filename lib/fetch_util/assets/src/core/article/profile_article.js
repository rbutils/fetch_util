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
