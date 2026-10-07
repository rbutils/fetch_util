  function markReadabilitySourceNodeProvenance(root, sourceClones, marker) {
    if (!root || !sourceClones || !marker) return new Map();
    var sourceIdentities = new Map();
    var idCounts = new Map();
    document.querySelectorAll("[id]").forEach(function(node) {
      var id = node.getAttribute("id");
      idCounts.set(id, (idCounts.get(id) || 0) + 1);
    });

    function sourceIdentity(source, clone, suffix) {
      var id = source.getAttribute("id");
      var internalId = false;
      if (!id) {
        id = "fetchutil-reader-" + marker + "-" + suffix;
        while (idCounts.has(id)) id += "-source";
        clone.setAttribute("id", id);
        idCounts.set(id, 1);
        internalId = true;
      }
      var paragraph = source.localName === "p";
      return {
        id: id,
        internalId: internalId,
        unique: idCounts.get(id) === 1,
        visibleText: paragraph ? normalizeText(clone.textContent || "") : null,
        breakSegments: paragraph ? sourceParagraphBreakSegments(clone) : null
      };
    }

    var headlines = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementVisuallyHidden(heading) &&
        !heading.closest("nav, footer, aside, form, [role='navigation'], [role='complementary']");
    });
    if (headlines.length === 1) {
      var headlineClone = sourceClones.get(headlines[0]);
      if (headlineClone && root.contains(headlineClone)) {
        headlineClone.setAttribute("data-fetchutil-reader-source-headline", marker);
        sourceIdentities.set(headlines[0], sourceIdentity(headlines[0], headlineClone, "headline"));
      }
    }

    var index = 0;
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "p" || !root.contains(clone) || elementVisuallyHidden(source)) return;
      clone.setAttribute("data-fetchutil-reader-source-paragraph", marker + ":" + index);
      sourceIdentities.set(source, sourceIdentity(source, clone, "paragraph-" + index));
      index += 1;
    });
    return sourceIdentities;
  }

  function sourceOwnedReaderHeadlineTitleMatches(headline, content, metadata) {
    var title = normalizeText(headline);
    if (!title) return false;
    var records = [content && content.title, metadata && metadata.title, document.title].map(normalizeText).filter(Boolean);
    return records.some(function(record) {
      if (record === title) return true;
      if (!record.startsWith(title)) return false;
      return /^\s*[|·:–—-]\s*\S/u.test(record.slice(title.length));
    });
  }

  function sourceOwnedReaderHeadlineBodyOwner(headline, paragraphs) {
    var articles = paragraphs.map(function(paragraph) { return paragraph.closest("article"); });
    if (articles[0] && articles.every(function(article) { return article === articles[0]; })) {
      var article = articles[0];
      if (article.contains(headline)) return article;
      if (headline.closest("article") || !(headline.compareDocumentPosition(article) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
      var parent = article.parentElement;
      while (parent && parent !== document.body) {
        var visibleParagraphsOutsideRecord = Array.from(parent.querySelectorAll("p")).filter(function(paragraph) {
          return !article.contains(paragraph) && !elementVisuallyHidden(paragraph) &&
            !paragraph.closest("nav, aside, footer, form, [role='navigation'], [role='complementary']") &&
            !!normalizeText(paragraph.textContent);
        });
        var articlesInParent = Array.from(parent.querySelectorAll("article")).filter(function(candidate) {
          return !candidate.parentElement.closest("article");
        });
        if (parent.contains(headline) && articlesInParent.length === 1 && articlesInParent[0] === article &&
            visibleParagraphsOutsideRecord.every(function(paragraph) {
              return paragraph.closest("header") && paragraph.closest("header").contains(headline);
            })) return parent;
        parent = parent.parentElement;
      }
      return null;
    }

    if (articles.some(Boolean)) return null;
    var owner = headline.parentElement;
    while (owner && owner !== document.body) {
      var ownerContext = normalizeText([owner.id, owner.className, owner.getAttribute("itemprop"), owner.getAttribute("role")].join(" "))
        .replace(/[_-]+/g, " ").toLowerCase();
      if (paragraphs.every(function(paragraph) { return owner.contains(paragraph); }) &&
          owner.querySelectorAll("h1").length === 1 && !owner.querySelector("article") &&
          /\b(?:main content|article (?:body|content|detail(?: page)?)|(?:article|post|story|entry) detail|(?:post|story|entry) (?:body|content)|detail content)\b/u.test(ownerContext)) return owner;
      owner = owner.parentElement;
    }
    return null;
  }

  function sourceOwnedReaderRetainedHeading(root, sourceHeadline, sourceClones, sourceIdentities, marker) {
    var marked = Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(node) {
      return node.getAttribute("data-fetchutil-reader-source-headline") === marker;
    });
    if (marked.length > 1) return null;
    if (marked.length === 1) return marked[0];

    var identity = sourceIdentities.get(sourceHeadline);
    if (!identity || !identity.unique || !sourceClones.get(sourceHeadline)) return null;
    var retained = Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(node) {
      return node.getAttribute("id") === identity.id;
    });
    return retained.length === 1 ? retained[0] : null;
  }

  function sourceOwnedReaderRetainedHeadline(article, metadata, sourceClones, sourceIdentities, marker) {
    if (!article || !article.content || !sourceClones || !sourceIdentities || !marker) return null;
    var sourceHeadlines = [];
    sourceClones.forEach(function(clone, source) {
      if (source.localName === "h1" && clone.getAttribute("data-fetchutil-reader-source-headline") === marker) {
        sourceHeadlines.push(source);
      }
    });
    if (sourceHeadlines.length !== 1) return null;
    var sourceHeadline = sourceHeadlines[0];
    var visibleHeadlines = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementVisuallyHidden(heading) &&
        !heading.closest("nav, footer, aside, form, [role='navigation'], [role='complementary']");
    });
    var headlineText = normalizeText(sourceHeadline.textContent);
    if (visibleHeadlines.length !== 1 || visibleHeadlines[0] !== sourceHeadline ||
        !sourceOwnedReaderHeadlineTitleMatches(headlineText, article, metadata)) return null;

    var template = document.createElement("template");
    template.innerHTML = article.content;
    var heading = sourceOwnedReaderRetainedHeading(template.content, sourceHeadline, sourceClones, sourceIdentities, marker);
    var paragraphs = sourceOwnedReaderSelectedParagraphs(template.content, sourceClones, sourceIdentities, marker);
    if (!paragraphs || paragraphs.some(function(paragraph) {
      return !(sourceHeadline.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return null;
    var owner = sourceOwnedReaderHeadlineBodyOwner(sourceHeadline, paragraphs);
    if (!owner) return null;
    if (heading && normalizeText(heading.textContent) !== headlineText) return null;
    article.sourceOwnedArticleBoundary = true;

    var sourceHeader = sourceHeadline.closest("header");
    if (sourceHeader && sourceHeader.closest("article") === owner) {
      article.excerpt = sourceOwnedReaderHeaderExcerpt(visibilityPrunedClone(sourceHeader)) || article.excerpt;
    }
    if (sourceOwnedReaderAlternativeHeadline(template.content, sourceHeadline, owner, paragraphs, heading)) {
      article.content = template.innerHTML;
      article.textContent = normalizeText(template.content.textContent || "");
    }
    if (!heading) return article;
    if (heading.localName !== "h1") {
      var promoted = document.createElement("h1");
      Array.from(sourceHeadline.attributes).forEach(function(attribute) {
        promoted.setAttribute(attribute.name, attribute.value);
      });
      while (heading.firstChild) promoted.appendChild(heading.firstChild);
      heading.replaceWith(promoted);
    }
    article.title = headlineText;
    article.content = template.innerHTML;
    return article;
  }

  function stripReadabilitySourceNodeMarkers(html, marker, sourceIdentities) {
    var template = document.createElement("template");
    template.innerHTML = html || "";
    template.content.querySelectorAll("[data-fetchutil-reader-source-headline], [data-fetchutil-reader-source-paragraph]").forEach(function(node) {
      var headline = node.getAttribute("data-fetchutil-reader-source-headline");
      var paragraph = node.getAttribute("data-fetchutil-reader-source-paragraph") || "";
      if (headline === marker) node.removeAttribute("data-fetchutil-reader-source-headline");
      if (paragraph.indexOf(marker + ":") === 0) node.removeAttribute("data-fetchutil-reader-source-paragraph");
    });
    if (sourceIdentities) {
      var internalIds = new Set();
      sourceIdentities.forEach(function(identity) {
        if (identity.internalId) internalIds.add(identity.id);
      });
      if (internalIds.size) {
        template.content.querySelectorAll("[id]").forEach(function(node) {
          if (internalIds.has(node.getAttribute("id"))) node.removeAttribute("id");
        });
      }
    }
    return template.innerHTML;
  }
