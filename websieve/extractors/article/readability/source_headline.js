  function sourceOwnedReaderBodyLeadEvidence(html, title, allowSubheadings) {
    if (!document.body || !html || !title) return null;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading) && !heading.closest("header, nav, footer, aside, form, [role='navigation']");
    });
    if (headings.length !== 1 || normalizeText(headings[0].textContent) !== normalizeText(title)) return null;

    var selected = document.createElement("div");
    selected.innerHTML = html;
    if (selected.querySelector("h1") ||
        (!allowSubheadings && selected.querySelector("h2, h3, h4, h5, h6"))) return null;

    var owner = headings[0].parentElement;
    while (owner && owner !== document.body && owner.querySelectorAll("p").length < 3) owner = owner.parentElement;
    if (!owner || owner === document.body || owner.querySelectorAll("h1").length !== 1) return null;

    var sourceParagraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph) &&
        !paragraph.closest("aside, nav, footer, form, figure, figcaption, [role='complementary'], [class*='caption' i], [class*='related' i], [class*='recommend' i]") &&
        normalizeText(paragraph.textContent).length >= 80;
    }).map(function(paragraph) { return normalizeText(paragraph.textContent); });
    var selectedParagraphs = Array.from(selected.querySelectorAll("p")).map(function(paragraph) {
      return normalizeText(paragraph.textContent);
    }).filter(function(text) { return text.length >= 80; });
    if (selectedParagraphs.length < 2 || selectedParagraphs[0] !== sourceParagraphs[0] ||
        !selectedParagraphs.every(function(text) { return sourceParagraphs.indexOf(text) >= 0; })) return null;

    return { heading: headings[0], lead: sourceParagraphs[0] };
  }

  function sourceOwnedReaderHeadlineEvidence(html, title) {
    return sourceOwnedReaderBodyLeadEvidence(html, title, false);
  }

  function sourceOwnedReaderArticleLeadEvidence(html, title) {
    return sourceOwnedReaderBodyLeadEvidence(html, title, true);
  }

  function sourceOwnedReaderAdjacentHeaderEvidence(article, bodyEvidence, metadata) {
    if (!article || !bodyEvidence || !Array.isArray(bodyEvidence.sourceParagraphs) ||
        bodyEvidence.sourceParagraphs.length < 2 ||
        (bodyEvidence.unmappedTrailingParagraphs || []).length) return null;

    var articleTitle = normalizeText(article.title || "");
    var metadataTitle = normalizeText(metadata && metadata.title || "");
    if (articleTitle && metadataTitle && articleTitle !== metadataTitle) return null;
    var selectedTitle = articleTitle || metadataTitle;
    if (!selectedTitle) return null;

    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading);
    });
    if (headings.length !== 1 || normalizeText(headings[0].textContent) !== selectedTitle) return null;

    var heading = headings[0];
    var header = heading.closest("header");
    var main = header && header.nextElementSibling;
    if (!header || elementSubtreeHidden(header) || !main || !main.matches("main, [role='main']") ||
        elementSubtreeHidden(main)) return null;

    var sourceArticle = null;
    var previous = heading;
    for (var index = 0; index < bodyEvidence.sourceParagraphs.length; index += 1) {
      var paragraph = bodyEvidence.sourceParagraphs[index];
      var owner = paragraph && paragraph.localName === "p" && paragraph.closest("article");
      if (!owner || !main.contains(owner) || owner.closest("main, [role='main']") !== main ||
          elementSubtreeHidden(paragraph) || paragraph.closest("aside, nav, footer, form, [role='complementary']") ||
          !(previous.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING) ||
          (sourceArticle && sourceArticle !== owner)) return null;
      sourceArticle = owner;
      previous = paragraph;
    }

    var unmappedHeaderParagraphs = bodyEvidence.unmappedHeaderParagraphs || [];
    if (unmappedHeaderParagraphs.some(function(edge) {
      var anchor = edge.source;
      return !anchor || anchor.localName !== "a" || !anchor.hasAttribute("href") ||
        anchor.closest("article") !== sourceArticle || !main.contains(anchor) || elementSubtreeHidden(anchor) ||
        anchor.closest("p, li, blockquote, figure, figcaption, nav, aside, footer, form, [role='complementary']") ||
        anchor.querySelector("p, li, div, section, article, blockquote, figure, img, picture, video, svg") ||
        normalizeText(edge.text) !== normalizeText(anchor.textContent) ||
        !(heading.compareDocumentPosition(anchor) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !(anchor.compareDocumentPosition(bodyEvidence.sourceParagraphs[0]) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return null;

    var articles = Array.from(main.querySelectorAll("article"));
    if (!articles.includes(sourceArticle) || articles.some(function(candidate) {
      return candidate !== sourceArticle && Array.from(candidate.querySelectorAll("p")).some(function(paragraph) {
        return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent);
      });
    })) return null;

    var summaries = Array.from(header.querySelectorAll("p, div, span, [itemprop]")).filter(function(candidate) {
      var classes = String(candidate.className || "");
      var itemProperties = (candidate.getAttribute("itemprop") || "").split(/\s+/);
      var explicitlyNamed = itemProperties.includes("description") ||
        /(?:^|[\s_-])(?:excerpt|summary|standfirst|dek)(?:$|[\s_-])/i.test(classes);
      if (!explicitlyNamed || elementSubtreeHidden(candidate) ||
          candidate.closest("header") !== header ||
          !(heading.compareDocumentPosition(candidate) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;

      var branch = candidate;
      while (branch && branch !== header) {
        if (branch.matches("aside, nav, footer, form, fieldset, figure, figcaption, article, button, input, select, textarea, [role='complementary'], [role='navigation'], [role='button'], [role='menuitem']")) return false;
        branch = branch.parentElement;
      }
      return branch === header;
    });
    if (summaries.length !== 1) return null;

    var summaryClone = visibilityPrunedClone(summaries[0]);
    summaryClone.querySelectorAll("aside, nav, footer, form, fieldset, figure, figcaption, article, button, input, select, textarea, [role='complementary'], [role='navigation'], [role='button'], [role='menuitem']").forEach(function(branch) {
      branch.remove();
    });
    var summary = normalizeText(summaryClone.textContent || "");
    return summary ? { heading: heading, summary: summary } : null;
  }

  function sourceOwnedReaderAdjacentHeaderExcerpt(article, bodyEvidence, metadata) {
    var evidence = sourceOwnedReaderAdjacentHeaderEvidence(article, bodyEvidence, metadata);
    return evidence && evidence.summary;
  }

  function sourceOwnedReaderMissingHeadlineContent(content, metadata) {
    content = sourceOwnedReaderHeaderContent(content, metadata);
    if (!content || !content.readerMode || content.hostAware || content.contentType !== "article" ||
        !content.html || /^#{1,6}\s/.test(normalizeText(content.title || "")) ||
        (content.markdown && !markdownStartsWithTitle(content.markdown, content.title))) return content;
    var evidence = sourceOwnedReaderHeadlineEvidence(content.html, content.title);
    if (!evidence && content.sourceOwnedReaderBodyParagraphSources) {
      evidence = sourceOwnedReaderAdjacentHeaderEvidence({title: content.title}, {
        sourceParagraphs: content.sourceOwnedReaderBodyParagraphSources,
        unmappedHeaderParagraphs: content.sourceOwnedReaderUnmappedHeaderParagraphs,
        unmappedTrailingParagraphs: content.sourceOwnedReaderUnmappedTrailingParagraphs
      }, metadata);
    }
    if (!evidence) return content;

    var root = document.createElement("div");
    root.innerHTML = content.html;
    var heading = evidence.heading.cloneNode(true);
    heading.querySelectorAll("script, style, template").forEach(function(node) { node.remove(); });
    root.insertBefore(heading, root.firstChild);
    return Object.assign({}, content, { html: root.innerHTML });
  }

  function sourceOwnedReaderMissingExcerpt(article, metadata) {
    if (!article || normalizeText(article.excerpt || "") ||
        normalizeText((metadata && metadata.excerpt) || "")) return null;
    var evidence = sourceOwnedReaderHeadlineEvidence(article.content, article.title);
    if (!evidence) return null;
    return readabilityExcerptPrefix(evidence.lead);
  }
