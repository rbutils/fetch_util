  var SCHOLARLY_ARTICLE_NOISE_SELECTOR = "#articleDenialBlock, #denialBlockWrapper, #references, #bibliography, #keywords, section[property='keywords'], [id*='supplementary' i], [class*='supplementary' i], .articleMetrics_count, .articleMetrics, .metrics, .references, .recommended, .recommendations, .citation-tools, .purchase, .access-options, .toolbar-metric__menu-section, .article-tools, .related, .figure-inline-download, .carousel-item, [role='doc-bibliography'], [class*='metric' i], [class*='metrics' i], [class*='recommend' i], [class*='related' i], [class*='citation' i], [class*='reference' i], [class*='collateral' i], [class*='share' i], [class*='purchase' i], [class*='institution' i], aside, nav, form, button, input, footer, script, style, noscript, template, iframe";

  function scholarlyArticleNoiseSelector() {
    return SCHOLARLY_ARTICLE_NOISE_SELECTOR;
  }

  function firstScholarlyElement(selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node) return node;
    }
    return null;
  }

  function cleanScholarlyClone(node, extraSelector) {
    if (!node) return null;
    var clone = cleanClone(node);
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
    if (abstractRoot) sections.push(abstractRoot);
    if (options.bodyRoots) sections = sections.concat(options.bodyRoots.filter(Boolean));
    else if (options.bodyRoot) sections.push(options.bodyRoot);
    if (!sections.length && !options.details) return null;

    var title = scholarlyTitleFromOptions(options, metadata);
    var root = document.createElement("article");
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    sections.forEach(function(section) {
      var clone = cleanScholarlyClone(section, options.extraNoiseSelector);
      if (clone) root.appendChild(clone);
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
      excerpt: (options.excerpt || abstractText).slice(0, 280) || metadata.excerpt,
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

  function scholarlySignatureText(metadata, selectors, maxLength) {
    var parts = [
      document.title,
      metadata && metadata.title,
      metadata && metadata.siteName,
      document.body && document.body.textContent
    ];
    if (selectors && selectors.length) parts.splice(3, 0, firstText(selectors));
    return normalizeText(parts.join(" ")).slice(0, maxLength || 20000);
  }

  function scholarlySelectorBodyRoot(selectors) {
    return firstScholarlyElement(selectors || []);
  }

  function scholarlyJatsBodyRoot() {
    var jatsSections = Array.prototype.filter.call(document.querySelectorAll("section[id^='sec'], section[id^='Sec'], .section"), function(section) {
      return normalizeText(section.textContent || "").length >= 120;
    });
    if (jatsSections.length < 2) return null;
    return jatsSections.reduce(function(best, section) {
      var textLength = normalizeText(section.textContent || "").length;
      if (!best || textLength > best.textLength) return { node: section.parentNode || section, textLength: textLength };
      return best;
    }, null).node;
  }

  function configuredScholarlyArticleContent(metadata, config) {
    if (config.signalSelectors && !firstScholarlyElement(config.signalSelectors)) return null;

    var abstractNode = scholarlySelectorBodyRoot(config.abstractSelectors);
    var body = scholarlySelectorBodyRoot(config.bodySelectors);
    if (!body && config.fallbackBodyRoot) body = config.fallbackBodyRoot();
    if (!abstractNode || !body) return null;

    if (config.signature) {
      var signature = config.signature(metadata);
      if (!signature) return null;
    } else if (config.signaturePattern) {
      var signatureText = scholarlySignatureText(metadata, config.signatureSelectors, config.signatureMaxLength);
      if (!config.signaturePattern.test(signatureText) && !(config.allowCitationDoiSignature && document.querySelector("meta[name='citation_doi']"))) return null;
    }

    var abstractText = normalizeText(abstractNode.textContent || "");
    var bodyText = normalizeText(body.textContent || "");
    if (abstractText.length < (config.minAbstractTextLength || 80)) return null;
    if (bodyText.length < (config.minBodyTextLength || 600)) return null;
    if (config.rejectBodyPattern && config.rejectBodyPattern.test(bodyText)) return null;

    var bodyIncludesAbstract = body.contains && body.contains(abstractNode);
    return assembleScholarlyArticle({
      metadata: metadata,
      abstractRoot: bodyIncludesAbstract ? null : abstractNode,
      bodyRoot: body,
      excerpt: config.excerpt ? config.excerpt(abstractText) : abstractText,
      titleSelectors: config.titleSelectors,
      titleCleanup: config.titleCleanup,
      siteName: config.siteName ? config.siteName(metadata) : undefined,
      minTextLength: config.minTextLength || 700
    });
  }

  var SCHOLARLY_ARTICLE_CONFIGS = {
    highwire: {
      abstractSelectors: ["#abstract[role='doc-abstract']", "section[role='doc-abstract']#abstract", "section[property='abstract']"],
      bodySelectors: ["#bodymatter[property='articleBody']", "section[property='articleBody'][typeof='Text']"],
      signatureSelectors: ["meta[name='citation_publisher']", "meta[name='citation_journal_title']", "meta[property='og:site_name']"],
      signaturePattern: /\b(PNAS|Proceedings of the National Academy|HighWire|citation_doi)\b/i,
      allowCitationDoiSignature: true,
      minBodyTextLength: 500,
      titleSelectors: [".citation__title", ".article-header h1", "h1[property='name']", "h1", "meta[name='citation_title']"],
      titleCleanup: /\s*\|\s*PNAS\s*$/i,
      minTextLength: 600
    },
    elsevier: {
      abstractSelectors: ["#abstracts[data-extent='frontmatter']"],
      bodySelectors: ["#bodymatter[property='articleBody']", "section[property='articleBody'][data-extent='bodymatter']"],
      signature: function(currentMetadata) {
        var articleStylesheet = document.getElementById("build-style-article");
        return (articleStylesheet && /\/products\/marlin\//i.test(articleStylesheet.getAttribute("href") || "")) ||
          document.querySelector("meta[name=citation_pii], meta[name=citation_doi]") ||
          /\bElsevier\b|ScienceDirect|Cell Press/i.test(scholarlySignatureText(currentMetadata));
      },
      minAbstractTextLength: 80,
      minBodyTextLength: 1,
      rejectBodyPattern: /get full text access\s+log in,? subscribe or purchase/i,
      titleSelectors: ["h1", "header h1", ".core-container h1"],
      excerpt: function(abstractText) { return firstText(["#author-abstract", "section[property='abstract']"]) || abstractText; },
      siteName: function(currentMetadata) { return currentMetadata.siteName || "Elsevier"; },
      minTextLength: 300
    },
    generic: {
      signalSelectors: ["meta[name='citation_doi']", "meta[name='citation_journal_title']", "meta[name='citation_title']", "meta[name='dc.Identifier'][content*='doi' i]", "section[property='abstract']", "[role='doc-abstract']", ".art-abstract", ".html-abstract", "[property='articleBody']", ".html-body", "#bodymatter"],
      abstractSelectors: ["section[property='abstract']", "[role='doc-abstract']", "#abstract[role='doc-abstract']", ".art-abstract", ".html-abstract", ".article__abstract", ".article-abstract", ".abstractSection", ".NLM_abstract", "#abstract", ".abstract"],
      bodySelectors: ["#bodymatter[property='articleBody']", "#bodymatter", "section[property='articleBody']", "[property='articleBody']", "#html-body", ".html-body", ".art-body", ".article-content .html-body", "article[typeof*='ScholarlyArticle' i]", "article[class*='article' i]", ".article__body", ".article-body", ".c-article-body", ".ArticleBody", "main article"],
      fallbackBodyRoot: scholarlyJatsBodyRoot,
      rejectBodyPattern: /get full text access\s+log in,? subscribe or purchase/i,
      titleSelectors: ["meta[name='citation_title']", "h1[property='name']", ".citation__title", ".article-header h1", "article h1", "h1"],
      minTextLength: 700
    }
  };
