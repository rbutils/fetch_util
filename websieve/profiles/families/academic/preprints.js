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

  function genericScholarlyArticleContent(metadata) { return configuredScholarlyArticleContent(metadata, SCHOLARLY_ARTICLE_CONFIGS.generic); }

  function registerAcademicPreprintProfiles() {
    registerHostAwareProfile(true, arxivAbstractContent);
    registerHostAwareProfile(true, genericScholarlyArticleContent);
  }
