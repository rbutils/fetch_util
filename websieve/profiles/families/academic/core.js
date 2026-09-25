  var SCHOLARLY_ARTICLE_NOISE_SELECTOR = "#articleDenialBlock, #denialBlockWrapper, #keywords, section[property='keywords'], [id*='supplementary' i], [class*='supplementary' i], .articleMetrics_count, .articleMetrics, .metrics, .recommended, .recommendations, .citation-tools, .purchase, .access-options, .toolbar-metric__menu-section, .article-tools, .related, .figure-inline-download, .carousel-item, [class*='metric' i], [class*='metrics' i], [class*='recommend' i], [class*='related' i], [class*='collateral' i], [class*='share' i], [class*='purchase' i], [class*='institution' i], aside, nav, form, button, input, footer, script, style, noscript, template, iframe";

  function scholarlyArticleNoiseSelector() {
    return SCHOLARLY_ARTICLE_NOISE_SELECTOR;
  }

  function cleanScholarlyClone(node, extraSelector, cloneOptions) {
    if (!node) return null;
    cloneOptions = cloneOptions || {};
    var sourceClones = cloneOptions.visibilityAware ? new Map() : null;
    var clone = cloneOptions.visibilityAware ? visibilityPrunedClone(node, document, sourceClones) : cleanClone(node);
    (cloneOptions.excludeNodes || []).forEach(function(excluded) {
      var excludedClone = sourceClones && sourceClones.get(excluded);
      if (excludedClone && excluded !== node) excludedClone.remove();
    });
    if (cloneOptions.visibilityAware) clone = cleanClone(clone);
    var selectors = scholarlyArticleNoiseSelector();
    if (extraSelector) selectors += ", " + extraSelector;
    clone.querySelectorAll(selectors).forEach(function(el) {
      el.remove();
    });
    clone.querySelectorAll("a[href*='/action/doSearch']").forEach(function(link) {
      var item = link.closest("li, [role='listitem']") || link;
      item.remove();
    });
    cleanupAgentRoot(clone);
    return clone;
  }

  function scholarlyTitleFromOptions(options, metadata) {
    var title = "";
    if (options.title) title = options.title;
    else if (options.titleNode) title = options.titleNode.getAttribute && options.titleNode.getAttribute("content") || options.titleNode.textContent || "";
    else if (options.titleSelectors) {
      for (var i = 0; i < options.titleSelectors.length; i += 1) {
        var node = document.querySelector(options.titleSelectors[i]);
        if (!node) continue;
        title = node.getAttribute && node.getAttribute("content") || node.textContent || "";
        title = normalizeText(title);
        if (title) break;
      }
    }
    title = normalizeText(title || metadata.title || document.title || "");
    if (options.titleCleanup) title = title.replace(options.titleCleanup, "");
    return normalizeText(title);
  }

  function assembleScholarlyArticle(options) {
    options = options || {};
    var metadata = options.metadata || {};
    var abstractRoot = options.abstractRoot || null;
    var sections = [];
    if (options.orderedRoots) sections = options.orderedRoots.filter(Boolean);
    else {
      if (abstractRoot) sections.push(abstractRoot);
      if (options.bodyRoots) sections = sections.concat(options.bodyRoots.filter(Boolean));
      else if (options.bodyRoot) sections.push(options.bodyRoot);
    }
    if (!sections.length && !options.details) return null;

    var title = scholarlyTitleFromOptions(options, metadata);
    var root = document.createElement("article");
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    sections.forEach(function(section) {
      var clone = cleanScholarlyClone(section, options.extraNoiseSelector, {
        visibilityAware: options.visibilityAware,
        excludeNodes: options.excludeNodes
      });
      if (!clone) return;
      if (section === options.abstractRootToLabel) {
        var abstractSection = document.createElement("section");
        var abstractHeading = document.createElement("h2");
        abstractHeading.textContent = options.abstractLabel || "Abstract";
        abstractSection.appendChild(abstractHeading);
        abstractSection.appendChild(clone);
        root.appendChild(abstractSection);
      } else root.appendChild(clone);
    });

    if (options.details && options.details.length) {
      var list = document.createElement("ul");
      options.details.forEach(function(detail) {
        var item = document.createElement("li");
        item.textContent = detail;
        list.appendChild(item);
      });
      root.appendChild(list);
    }

    cleanupAgentRoot(root);
    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    if (options.markdownFallback && normalizeText(markdown).length < normalizeText(root.textContent || "").length * 0.2) {
      markdown = options.markdownFallback();
    }
    var text = normalizeText(markdown);
    if (text.length < (options.minTextLength || 300)) return null;

    var abstractText = normalizeText(abstractRoot && abstractRoot.textContent || "");
    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: options.preserveFullExcerpt ? (options.excerpt || abstractText) : (options.excerpt || abstractText).slice(0, 280) || metadata.excerpt,
      siteName: options.siteName || metadata.siteName,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }
