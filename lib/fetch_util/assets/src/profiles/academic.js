  function elsevierArticleContent(metadata) {
    var abstracts = document.querySelector("#abstracts[data-extent='frontmatter']");
    var body = document.querySelector("#bodymatter[property='articleBody'], section[property='articleBody'][data-extent='bodymatter']");
    if (!abstracts || !body) return null;

    var articleStylesheet = document.getElementById("build-style-article");
    var signature = (articleStylesheet && /\/products\/marlin\//i.test(articleStylesheet.getAttribute("href") || "")) ||
      document.querySelector("meta[name=citation_pii], meta[name=citation_doi]") ||
      /\bElsevier\b|ScienceDirect|Cell Press/i.test(normalizeText([
        metadata && metadata.siteName,
        metadata && metadata.title,
        document.title,
        document.body && document.body.textContent
      ].join(" ")).slice(0, 20000));
    if (!signature) return null;

    var bodyText = normalizeText(body.textContent || "");
    if (!bodyText || /get full text access\s+log in,? subscribe or purchase/i.test(bodyText)) return null;

    var root = document.createElement("article");
    var title = firstText(["h1", "header h1", ".core-container h1"]) || metadata.title;
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    [abstracts, body].forEach(function(node) {
      var clone = cleanClone(node);
      clone.querySelectorAll([
        "#articleDenialBlock",
        "#denialBlockWrapper",
        "#references",
        "#bibliography",
        "#keywords",
        "section[property='keywords']",
        "[id*='supplementary' i]",
        "[class*='supplementary' i]",
        "[class*='related' i]",
        "[class*='citation' i]",
        "[class*='metrics' i]",
        "[class*='collateral' i]",
        "[role='doc-bibliography']"
      ].join(", ")).forEach(function(el) {
        el.remove();
      });
      clone.querySelectorAll("a[href*='/action/doSearch']").forEach(function(link) {
        var item = link.closest("li, [role='listitem']") || link;
        item.remove();
      });
      cleanupAgentRoot(clone);
      root.appendChild(clone);
    });

    cleanupAgentRoot(root);
    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    var text = normalizeText(markdown);
    if (!text || text.length < 300) return null;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: firstText(["#author-abstract", "section[property='abstract']"]) || metadata.excerpt,
      siteName: metadata.siteName || "Elsevier",
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
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
