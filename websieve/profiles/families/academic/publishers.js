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

  function registerAcademicPublisherProfiles() {
    registerHostAwareProfile(true, elsevierArticleContent);
    registerHostAwareProfile(true, ieeeXploreArticleContent);
  }
