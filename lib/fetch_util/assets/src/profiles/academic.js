  function scholarlyArticleNoiseSelector() {
    return [
      "#articleDenialBlock",
      "#denialBlockWrapper",
      "#references",
      "#bibliography",
      "#keywords",
      "section[property='keywords']",
      "[id*='supplementary' i]",
      "[class*='supplementary' i]",
      ".articleMetrics_count",
      ".articleMetrics",
      ".metrics",
      ".references",
      ".recommended",
      ".recommendations",
      ".citation-tools",
      ".purchase",
      ".access-options",
      ".toolbar-metric__menu-section",
      ".article-tools",
      ".related",
      ".figure-inline-download",
      ".carousel-item",
      "[role='doc-bibliography']",
      "[class*='metric' i]",
      "[class*='metrics' i]",
      "[class*='recommend' i]",
      "[class*='related' i]",
      "[class*='citation' i]",
      "[class*='reference' i]",
      "[class*='collateral' i]",
      "[class*='share' i]",
      "[class*='purchase' i]",
      "[class*='institution' i]",
      "aside",
      "nav",
      "form",
      "button",
      "input",
      "footer",
      "script",
      "style",
      "noscript",
      "template",
      "iframe"
    ].join(", ");
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

  function acsAbstractArticleContent(metadata) {
    var abstractNode = document.querySelector(".article_abstract, .abstractSection, .article__abstract, .NLM_abstract, #abstract, section[property='abstract'], [property='abstract']");
    if (!abstractNode) return null;

    var abstractText = normalizeText(abstractNode.textContent || "");
    if (abstractText.length < 120) return null;

    var signatureText = normalizeText([
      document.title,
      metadata && metadata.title,
      metadata && metadata.siteName,
      firstText(["meta[name='citation_publisher']", "meta[name='citation_journal_title']"]),
      document.body && document.body.textContent
    ].join(" ")).slice(0, 16000);
    if (!/\b(acs publications|american chemical society|journal of chemical education)\b/i.test(signatureText)) return null;

    return assembleScholarlyArticle({
      metadata: metadata,
      abstractRoot: abstractNode,
      titleSelectors: [".article_header-title", ".citation__title", "h1[property='name']", "h1"],
      titleCleanup: /\s*-\s*ACS Publications\s*$/i,
      excerpt: abstractText,
      minTextLength: 180
    });
  }

  function plosStyleArticleContent(metadata) {
    function articleParts(source) {
      var candidate = Array.prototype.reduce.call(source.querySelectorAll(".article-content .article-text"), function(best, node) {
        var sections = node.querySelectorAll(".section.toc-section a[data-toc^='s']").length;
        if (!best || sections > best.sections) return { node: node, sections: sections };
        return best;
      }, null);
      var articleText = candidate && candidate.node;
      if (!articleText) return null;

      var abstractNode = articleText.querySelector(".abstract.toc-section, .abstract");
      var bodySections = Array.prototype.filter.call(articleText.querySelectorAll(".section.toc-section"), function(section) {
        var tocTarget = section.querySelector("a[data-toc]");
        var toc = tocTarget && tocTarget.getAttribute("data-toc") || "";
        var text = normalizeText(section.textContent || "");
        return /^(?:s|sec)\d+$/i.test(toc) && text.length >= 80;
      });

      return { abstractNode: abstractNode, bodySections: bodySections };
    }

    var parts = articleParts(document);
    if (!parts || parts.bodySections.length < 3) {
      var fallback = fallbackContent();
      var fallbackRoot = document.createElement("div");
      fallbackRoot.innerHTML = fallback && fallback.html || "";
      var fallbackParts = articleParts(fallbackRoot);
      if (fallbackParts && (!parts || fallbackParts.bodySections.length > parts.bodySections.length)) parts = fallbackParts;
    }
    if (!parts || !parts.abstractNode || parts.bodySections.length < 2) return null;

    var abstractNode = parts.abstractNode;
    var bodySections = parts.bodySections;

    var signature = document.querySelector("meta[name='citation_doi'], meta[name='citation_journal_title']") ||
      /\b(open access|peer-reviewed|research article|article info)\b/i.test(normalizeText(document.body && document.body.textContent || "").slice(0, 12000));
    if (!signature) return null;

    var title = firstText([".article-header h1", "h1", "meta[name='citation_title']"]) || metadata.title || document.title;
    title = normalizeText(title || "").replace(/\s*\|\s*PLOS\s+\w+\s*$/i, "");

    function plosPlainMarkdown() {
      var lines = title ? ["# " + title] : [];
      [abstractNode].concat(bodySections).forEach(function(section) {
        section.querySelectorAll("h2, h3, h4, p, figcaption").forEach(function(block) {
          var blockText = normalizeText(block.textContent || "");
          if (!blockText) return;
          if (/^H2$/i.test(block.tagName)) lines.push("", "## " + blockText);
          else if (/^H3$/i.test(block.tagName)) lines.push("", "### " + blockText);
          else if (/^H4$/i.test(block.tagName)) lines.push("", "#### " + blockText);
          else lines.push("", blockText);
        });
      });
      return cleanupMarkdownNoise(lines.join("\n").trim());
    }

    return assembleScholarlyArticle({
      metadata: metadata,
      abstractRoot: abstractNode,
      bodyRoots: bodySections,
      title: title,
      markdownFallback: plosPlainMarkdown,
      minTextLength: 300
    });
  }

  function highwireArticleContent(metadata) {
    return configuredScholarlyArticleContent(metadata, {
      abstractSelectors: ["#abstract[role='doc-abstract']", "section[role='doc-abstract']#abstract", "section[property='abstract']"],
      bodySelectors: ["#bodymatter[property='articleBody']", "section[property='articleBody'][typeof='Text']"],
      signatureSelectors: ["meta[name='citation_publisher']", "meta[name='citation_journal_title']", "meta[property='og:site_name']"],
      signaturePattern: /\b(PNAS|Proceedings of the National Academy|HighWire|citation_doi)\b/i,
      allowCitationDoiSignature: true,
      minBodyTextLength: 500,
      titleSelectors: [".citation__title", ".article-header h1", "h1[property='name']", "h1", "meta[name='citation_title']"],
      titleCleanup: /\s*\|\s*PNAS\s*$/i,
      minTextLength: 600
    });
  }

  function elsevierArticleContent(metadata) {
    return configuredScholarlyArticleContent(metadata, {
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
    });
  }

  function ieeeXploreArticleContent(metadata) {
    var component = document.querySelector("xpl-document-abstract, .document-abstract");
    if (!component) return null;

    var signatureText = normalizeText([
      document.title,
      metadata && metadata.title,
      metadata && metadata.siteName,
      document.querySelector("meta[name='citation_doi']") && document.querySelector("meta[name='citation_doi']").getAttribute("content"),
      document.body && document.body.textContent
    ].join(" ")).slice(0, 20000);
    if (!/\bIEEE\s+Xplore\b|\bieeexplore\.ieee\.org\b|\bIEEE Conference Publication\b/i.test(signatureText)) return null;

    var abstractNodes = Array.prototype.filter.call(component.querySelectorAll(".abstract-text-content, [class*='abstract-text' i], [property='abstract']"), function(node) {
      return normalizeText(node.textContent || "").length >= 80;
    });
    if (!abstractNodes.length) return null;

    var abstractNode = abstractNodes.reduce(function(best, node) {
      var text = normalizeText(node.textContent || "");
      if (!best || text.length > best.text.length) return { node: node, text: text };
      return best;
    }, null);
    if (!abstractNode || abstractNode.text.length < 160) return null;

    var title = normalizeText(metadata.title || firstText(["meta[name='citation_title']", "h1"]));
    title = title.replace(/\s*\|\s*IEEE.*$/i, "");

    var abstractSection = document.createElement("section");
    var abstractHeading = document.createElement("h2");
    var abstractParagraph = document.createElement("p");
    abstractHeading.textContent = "Abstract";
    abstractParagraph.textContent = abstractNode.text.replace(/^Abstract:\s*/i, "");
    abstractSection.appendChild(abstractHeading);
    abstractSection.appendChild(abstractParagraph);
    var details = [];
    manyTexts([
      ".stats-document-abstract-publishedIn",
      ".doc-abstract-confdate",
      ".doc-abstract-pubdate",
      ".doc-abstract-doi",
      ".u-pb-1"
    ], 8).forEach(function(item) {
      var text = normalizeText(item).replace(/\s*Show More\s*$/i, "");
      if (!text || text.length > 220) return;
      if (/^(abstract|metadata|abstract:)/i.test(text)) return;
      if (details.indexOf(text) === -1) details.push(text);
    });
    return assembleScholarlyArticle({
      metadata: metadata,
      abstractRoot: abstractSection,
      title: title,
      excerpt: abstractNode.text,
      details: details,
      siteName: metadata.siteName || "IEEE Xplore",
      minTextLength: 220
    });
  }

  function genericScholarlyArticleContent(metadata) {
    return configuredScholarlyArticleContent(metadata, {
      signalSelectors: [
        "meta[name='citation_doi']",
        "meta[name='citation_journal_title']",
        "meta[name='citation_title']",
        "meta[name='dc.Identifier'][content*='doi' i]",
        "section[property='abstract']",
        "[role='doc-abstract']",
        ".art-abstract",
        ".html-abstract",
        "[property='articleBody']",
        ".html-body",
        "#bodymatter"
      ],
      abstractSelectors: [
        "section[property='abstract']",
        "[role='doc-abstract']",
        "#abstract[role='doc-abstract']",
        ".art-abstract",
        ".html-abstract",
        ".article__abstract",
        ".article-abstract",
        ".abstractSection",
        ".NLM_abstract",
        "#abstract",
        ".abstract"
      ],
      bodySelectors: [
        "#bodymatter[property='articleBody']",
        "#bodymatter",
        "section[property='articleBody']",
        "[property='articleBody']",
        "#html-body",
        ".html-body",
        ".art-body",
        ".article-content .html-body",
        "article[typeof*='ScholarlyArticle' i]",
        "article[class*='article' i]",
        ".article__body",
        ".article-body",
        ".c-article-body",
        ".ArticleBody",
        "main article"
      ],
      fallbackBodyRoot: scholarlyJatsBodyRoot,
      rejectBodyPattern: /get full text access\s+log in,? subscribe or purchase/i,
      titleSelectors: ["meta[name='citation_title']", "h1[property='name']", ".citation__title", ".article-header h1", "article h1", "h1"],
      minTextLength: 700
    });
  }

  function arxivAbstractContent(metadata) {
    var abstractNode = document.querySelector("blockquote.abstract");
    var arxivAbstractPath = hostMatches(/(^|\.)arxiv\.org$/) && /^\/abs\//.test(location.pathname || "");

    if (!abstractNode || !arxivAbstractPath) return null;

    var title = firstText(["h1.title", "h1.titlemath", "main h1", "h1"]) || metadata.title || document.title;
    title = normalizeText(title).replace(/^Title:\s*/i, "");

    var authors = firstText([".authors"]);
    authors = normalizeText(authors || "").replace(/^Authors?:\s*/i, "");

    var abstract = normalizeText(abstractNode.textContent || "").replace(/^Abstract:\s*/i, "");
    if (!title || !abstract) return null;

    var details = [];
    manyTexts([".dateline", ".metatable .tablecell", ".metatable td", ".metatable dd"], 8).forEach(function(item) {
      if (!/^(subjects?|cited by|references?|related|download|view pdf)$/i.test(item)) details.push(item);
    });

    var markdown = [
      "# " + title,
      [authors ? "- Author: " + authors : null].concat(details.map(function(detail) { return "- " + detail; })).filter(Boolean).join("\n"),
      abstract
    ].filter(Boolean).join("\n\n").trim();
    var article = document.createElement("article");
    var heading = document.createElement("h1");
    var paragraph = document.createElement("p");
    heading.textContent = title;
    paragraph.textContent = abstract;
    article.appendChild(heading);
    article.appendChild(paragraph);

    return {
      title: title,
      byline: authors || metadata.byline,
      excerpt: abstract,
      siteName: metadata.siteName || "arXiv",
      publishedTime: metadata.publishedTime,
      html: article.outerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }
