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

  function highwireArticleContent(metadata) { return configuredScholarlyArticleContent(metadata, SCHOLARLY_ARTICLE_CONFIGS.highwire); }

  function elsevierArticleContent(metadata) { return configuredScholarlyArticleContent(metadata, SCHOLARLY_ARTICLE_CONFIGS.elsevier); }

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
    manyTexts([".stats-document-abstract-publishedIn", ".doc-abstract-confdate", ".doc-abstract-pubdate", ".doc-abstract-doi", ".u-pb-1"], 8).forEach(function(item) {
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
