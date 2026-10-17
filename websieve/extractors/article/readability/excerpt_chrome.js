  function readabilityBreadcrumbExcerpt(excerpt) {
    return Array.prototype.some.call(document.querySelectorAll(
      "[class~='breadcrumb' i], [class~='breadcrumbs' i], [aria-label*='breadcrumb' i]"
    ), function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") === excerpt;
    });
  }

  function readabilityPublicationLabelExcerpt(excerpt) {
    var value = normalizeText(excerpt || "");
    if (readabilityExcerptLength(value) > 80 ||
        !/^(?:published|updated|last updated|publication date|giriş tarihi|yayın tarihi|fecha de publicación|date de publication|veröffentlicht)\s*[:：-]/i.test(value)) return false;
    return Array.prototype.some.call(document.querySelectorAll("time, p, div, span"), function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") === value &&
        !node.closest("nav, header, footer, aside, form, [role='navigation'], [role='complementary']");
    });
  }

  function readabilityOwnedDateParagraphSources(article, selected) {
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementVisuallyHidden(heading) && normalizeText(heading.textContent || "") === normalizeText(article.title || "");
    });
    if (headings.length !== 1) return null;
    var owner = headings[0].parentElement;
    while (owner && owner !== document.body) {
      if (sourceOwnershipInChrome(owner) || owner.closest(VISIBLE_COMMENT_THREAD_SELECTOR) || commentRecordMarker(owner)) return null;
      var visibleHeadings = Array.from(owner.querySelectorAll("h1")).filter(function(node) { return !elementVisuallyHidden(node); });
      if (visibleHeadings.length !== 1) return null;
      var nodes = Array.from(owner.querySelectorAll("p, div")).filter(function(node) {
        return (node.localName === "p" || !node.children.length) && !elementVisuallyHidden(node) &&
          !sourceOwnershipInChrome(node) && !node.closest(VISIBLE_COMMENT_THREAD_SELECTOR) && !commentRecordMarker(node);
      });
      var sources = selected.map(function(paragraph) {
        var matches = nodes.filter(function(node) {
          return normalizeText(node.textContent || "") === normalizeText(paragraph.textContent || "");
        });
        return matches.length === 1 ? matches[0] : null;
      });
      if (sources.every(Boolean)) return sources;
      owner = owner.parentElement;
    }
    return null;
  }

  function readabilityOwnedDateLeadExcerpt(article, bodyEvidence) {
    var value = normalizeText(article && article.excerpt || "");
    var date = "(?:\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}|\\d{1,2}[./]\\s*\\d{1,2}[./]\\s*\\d{4}|" +
      "\\d{1,2}\\.?\\s+\\p{L}[\\p{L}\\p{M}.'’\\-]*\\s+\\d{4}|\\p{L}[\\p{L}\\p{M}.'’\\-]*\\s+\\d{1,2},?\\s+\\d{4})";
    if (!new RegExp("^" + date + "(?:\\s*,?\\s+)\\d{1,2}:\\d{2}(?::\\d{2})?$", "u").test(value)) return null;

    var template = readabilityArticleTemplate(article);
    var selected = template && Array.from(template.content.querySelectorAll("p"));
    if (!selected || selected.length < 2) return null;
    var sources = bodyEvidence && bodyEvidence.sourceParagraphs;
    if (bodyEvidence && ((bodyEvidence.unmappedHeaderParagraphs || []).length ||
        (bodyEvidence.unmappedTrailingParagraphs || []).length)) return null;
    if (!Array.isArray(sources)) sources = readabilityOwnedDateParagraphSources(article, selected);
    if (!sources || sources.length < 2 || normalizeText(sources[0].textContent || "") !== value) return null;
    if (!selected || selected.length !== sources.length || !sources.every(function(source, index) {
      return source && source.ownerDocument === document && source.isConnected && !elementVisuallyHidden(source) &&
        normalizeText(source.textContent || "") === normalizeText(selected[index].textContent || "") &&
        (!index || (sources[index - 1].compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING));
    })) return null;

    var owner = sources[0].parentElement;
    while (owner && owner !== document.body && !sources.every(function(source) { return owner.contains(source); })) {
      owner = owner.parentElement;
    }
    if (!owner || owner === document.body) return null;
    var headings = Array.from(owner.querySelectorAll("h1")).filter(function(heading) { return !elementVisuallyHidden(heading); });
    if (headings.length !== 1 || normalizeText(headings[0].textContent || "") !== normalizeText(article.title || "") ||
        !(headings[0].compareDocumentPosition(sources[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    var lead = sources[1];
    if (!readabilityExcerptNode(lead) || lead.querySelector("button, input, select, textarea") ||
        !(sources[0].compareDocumentPosition(lead) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !/\p{Sentence_Terminal}/u.test(lead.textContent || "")) return null;
    return readabilityExcerptPrefix(lead.textContent || "");
  }

  function readerSectionHeaderDateExcerpt(article, bodyEvidence, snapshots) {
    var sources = bodyEvidence && bodyEvidence.sourceParagraphs;
    if (!article || !snapshots || !snapshots.headings.length || !Array.isArray(sources) || sources.length < 2 ||
        (bodyEvidence.unmappedTrailingParagraphs || []).length) return null;
    var value = normalizeText(article.excerpt || "");
    var date = "(?:\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}|\\d{1,2}[./]\\s*\\d{1,2}[./]\\s*\\d{4}|" +
      "\\d{1,2}\\.?\\s+\\p{L}[\\p{L}\\p{M}.'’\\-]*\\s+\\d{4}|\\p{L}[\\p{L}\\p{M}.'’\\-]*\\s+\\d{1,2},?\\s+\\d{4})";
    if (!new RegExp("^" + date + "$", "u").test(value)) return null;

    var owner = snapshots.owner;
    if (!owner || !owner.isConnected || owner === document.body || owner.querySelectorAll("h1").length !== 1) return null;
    var headline = owner.querySelector("h1");
    var articleTitle = normalizeText(article.title || "");
    if (headline.parentElement !== owner || elementVisuallyHidden(headline) ||
        (articleTitle && normalizeText(headline.textContent) !== articleTitle) ||
        !sourceOwnedReaderHeadlineTitleMatches(headline.textContent, null, null)) return null;
    var section = snapshots.headings[0];
    var lead = section.paragraph;
    var heading = lead && lead.previousElementSibling;
    if (!heading || heading.parentElement !== owner || heading.id !== section.id ||
        normalizeText(heading.textContent) !== section.text || !sources.includes(lead) ||
        normalizeText(lead.textContent) !== section.paragraphText || !readabilityExcerptNode(lead) ||
        !readerSectionParagraphNarrative(lead) || sources.some(function(source) {
          return !source || source.localName !== "p" || source.ownerDocument !== document ||
            !owner.contains(source) || elementVisuallyHidden(source);
        })) return null;

    var dates = [];
    var revision = new RegExp("^(?:last updated|updated)\\s*[:：-]\\s*" + date + "$", "iu");
    var node = headline.nextSibling;
    while (node && node !== heading) {
      if (node.nodeType === Node.TEXT_NODE && normalizeText(node.textContent)) return null;
      if (node.nodeType === Node.ELEMENT_NODE) {
        if (!node.matches("span, time, p, div") || node.children.length || elementVisuallyHidden(node) ||
            node.matches("[role~='button'], [role~='menuitem'], [role~='tab'], [role~='dialog']")) return null;
        var text = normalizeText(node.textContent);
        var dateField = node.matches("time, [itemprop~='datePublished' i]") ||
          Array.from(node.classList).some(function(token) {
            return /(?:^|[-_])(?:date|published|publication)(?:$|[-_])/i.test(token);
          });
        if (dateField && text === value) dates.push(node);
        else if (!revision.test(text)) return null;
      }
      node = node.nextSibling;
    }
    var edges = bodyEvidence.unmappedHeaderParagraphs || [];
    if (node !== heading || dates.length !== 1 || edges.length !== 1 || edges[0].source !== dates[0] ||
        normalizeText(edges[0].text) !== value) return null;

    var template = readabilityArticleTemplate(article);
    var selected = template && Array.from(template.content.querySelectorAll("p[id]")).filter(function(paragraph) {
      return paragraph.id === section.paragraphId;
    });
    if (!selected || selected.length !== 1 || normalizeText(selected[0].textContent) !== section.paragraphText) return null;
    return readabilityExcerptPrefix(section.paragraphText);
  }

  function readabilityOwnedBylineExcerpt(article, metadata, readerBodyEvidence) {
    var excerpt = normalizeText((article && article.excerpt) || "");
    if (!excerpt || /[\p{Sentence_Terminal}"'“”‘’]/u.test(excerpt) || !readerBodyEvidence) return false;

    var content = {
      title: article.title,
      siteName: article.siteName,
      html: article.content,
      readerMode: true,
      contentType: "article",
      sourceOwnedReaderBodyParagraphSources: readerBodyEvidence.sourceParagraphs,
      sourceOwnedReaderUnmappedHeaderParagraphs: readerBodyEvidence.unmappedHeaderParagraphs,
      sourceOwnedReaderUnmappedTrailingParagraphs: readerBodyEvidence.unmappedTrailingParagraphs
    };
    var byline = readerSourceOwnedBylineForContent(
      content, metadata || {}, article.byline || null, metadata && metadata.declaredByline
    );
    return normalizeText(byline || "") === excerpt;
  }

  function readabilityOwnedCompleteParagraphText(node, markerAttribute, markerValue, readerBodyEvidence) {
    if (!node || node.getAttribute(markerAttribute) !== markerValue || !readerBodyEvidence ||
        !readerBodyEvidence.sourceParagraphs) return null;
    var text = normalizeText(node.textContent || "");
    if (!text) return null;

    var matches = readerBodyEvidence.sourceParagraphs.filter(function(source) {
      return source && source.localName === "p" && normalizeText(source.textContent || "") === text;
    });
    return matches.length === 1 ? text : null;
  }

  function readabilityOwnedBylineExcerptValue(article, metadata, template, marker, readerBodyEvidence) {
    if (!readabilityOwnedBylineExcerpt(article, metadata, readerBodyEvidence)) return null;

    var summaryGroup = marker + ":0";
    var summaryNodes = Array.prototype.filter.call(
      template.content.querySelectorAll("[data-fetchutil-excerpt-summary]"), function(node) {
        return node.getAttribute("data-fetchutil-excerpt-summary") === summaryGroup;
      }
    );
    if (summaryNodes.length === 1 && summaryNodes[0].localName === "p") {
      var summary = readabilityOwnedCompleteParagraphText(
        summaryNodes[0], "data-fetchutil-excerpt-summary", summaryGroup, readerBodyEvidence
      );
      if (summary) return summary;
    }

    var firstBody = template.content.querySelector("p[data-fetchutil-excerpt-body='" + marker + "']");
    if (!firstBody || firstBody.hasAttribute("data-fetchutil-excerpt-summary")) return article.excerpt;
    var body = readabilityOwnedCompleteParagraphText(
      firstBody, "data-fetchutil-excerpt-body", marker, readerBodyEvidence
    );
    if (!body) return article.excerpt;
    return body;
  }

  function readabilityExcerptOwner(node, structuredOwner) {
    if (!node || !node.closest) return false;
    if (structuredOwner && structuredOwner.owner.contains(node) &&
        (structuredOwner.heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)) {
      return readabilityExcerptSameArticleOwner(node, structuredOwner);
    }
    if (node.closest("article")) return readabilityDistinctArticleOwner(node);
    var main = node.closest("main, [role='main']");
    var externalOwner = readabilityExternalArticleBodyOwner(node);
    return !!main && externalOwner !== false && (externalOwner === true || !main.querySelector("article"));
  }
