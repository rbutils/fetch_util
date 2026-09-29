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
