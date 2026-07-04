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
    if (!/\b(acs publications|american chemical society|journal of chemical education|citation_doi)\b/i.test(signatureText) && !document.querySelector("meta[name='citation_doi']")) return null;

    var root = document.createElement("article");
    var title = firstText([".article_header-title", ".citation__title", "h1[property='name']", "h1"]) || metadata.title || document.title;
    title = normalizeText(title || "").replace(/\s*-\s*ACS Publications\s*$/i, "");
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    var abstractClone = abstractNode.cloneNode(true);
    abstractClone.querySelectorAll([
      ".articleMetrics_count",
      ".articleMetrics",
      ".metrics",
      ".references",
      ".recommended",
      ".recommendations",
      ".citation-tools",
      ".purchase",
      ".access-options",
      "[class*='metrics' i]",
      "[class*='recommend' i]",
      "[class*='citation' i]",
      "[class*='reference' i]",
      "[class*='purchase' i]",
      "[class*='institution' i]",
      "aside",
      "nav",
      "form",
      "script",
      "style"
    ].join(", ")).forEach(function(el) {
      el.remove();
    });
    root.appendChild(abstractClone);

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    var text = normalizeText(markdown);
    if (text.length < 180) return null;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: abstractText.slice(0, 280) || metadata.excerpt,
      siteName: metadata.siteName,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
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
        return /^s\d+$/i.test(toc) && text.length >= 80;
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

    var root = document.createElement("article");
    var title = firstText([".article-header h1", "h1", "meta[name='citation_title']"]) || metadata.title || document.title;
    title = normalizeText(title || "").replace(/\s*\|\s*PLOS\s+\w+\s*$/i, "");
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    [abstractNode].concat(bodySections).forEach(function(node) {
      var clone = node.cloneNode(true);
      clone.querySelectorAll(".figure-inline-download, .carousel-item, [class*='metrics' i], [class*='related' i], [class*='share' i]").forEach(function(el) {
        el.remove();
      });
      clone.querySelectorAll("script, style, noscript, template, iframe, form, button, input, aside, nav, footer").forEach(function(el) {
        el.remove();
      });
      root.appendChild(clone);
    });

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

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    if (normalizeText(markdown).length < normalizeText(root.textContent || "").length * 0.2) markdown = plosPlainMarkdown();
    var text = normalizeText(markdown);
    if (text.length < 300) return null;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: normalizeText(abstractNode.textContent || "").slice(0, 280) || metadata.excerpt,
      siteName: metadata.siteName,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }

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

    var root = document.createElement("article");
    if (title) {
      var heading = document.createElement("h1");
      heading.textContent = title;
      root.appendChild(heading);
    }

    var abstractSection = document.createElement("section");
    var abstractHeading = document.createElement("h2");
    var abstractParagraph = document.createElement("p");
    abstractHeading.textContent = "Abstract";
    abstractParagraph.textContent = abstractNode.text.replace(/^Abstract:\s*/i, "");
    abstractSection.appendChild(abstractHeading);
    abstractSection.appendChild(abstractParagraph);
    root.appendChild(abstractSection);

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
    if (details.length) {
      var list = document.createElement("ul");
      details.forEach(function(detail) {
        var item = document.createElement("li");
        item.textContent = detail;
        list.appendChild(item);
      });
      root.appendChild(list);
    }

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    var textContent = normalizeText(markdown);
    if (textContent.length < 220) return null;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: abstractNode.text.slice(0, 280) || metadata.excerpt,
      siteName: metadata.siteName || "IEEE Xplore",
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: textContent,
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
