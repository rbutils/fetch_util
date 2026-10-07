  function readerHeaderParagraphs(root) {
    return Array.from(root.querySelectorAll("p")).filter(function(paragraph) {
      return !elementVisuallyHidden(paragraph) && normalizeText(paragraph.textContent) &&
        !paragraph.closest("aside, nav, footer, form, [role='complementary'], [role='navigation']");
    });
  }

  function sourceOwnedReaderLinkedFigure(figure, article) {
    var selected = linkedArticleResourceFigure(figure);
    if (!selected) return null;
    var text = normalizeText(figure.textContent || "").replace(/\s/g, "");
    var matches = Array.from(article.querySelectorAll("figure")).filter(function(source) {
      if (source.closest("article") !== article) return false;
      var record = linkedArticleResourceFigure(source);
      return record && record.href === selected.href && normalizeText(source.textContent || "").replace(/\s/g, "") === text;
    });
    return matches.length === 1 ? matches[0] : null;
  }

  function sourceOwnedReaderHeaderFigure(figure, article) {
    if (!figure || elementVisuallyHidden(figure) || figure.querySelectorAll("img").length !== 1) return null;
    var image = figure.querySelector("img");
    var caption = figure.querySelector("figcaption");
    var src = materializedHttpUrl(image.getAttribute("src"));
    var alt = normalizeText(image.getAttribute("alt") || "");
    var text = caption && normalizeText(caption.textContent || "");
    if (!src || !alt || !text) return null;
    var articleImages = Array.from(article.querySelectorAll("img")).filter(function(source) {
      return materializedHttpUrl(source.getAttribute("src")) === src &&
        normalizeText(source.getAttribute("alt") || "") === alt;
    });
    if (articleImages.length !== 1 || articleImages[0] !== image) return null;
    var matches = Array.from(article.querySelectorAll("figure")).filter(function(source) {
      if (source.closest("article") !== article || elementVisuallyHidden(source) ||
          source.querySelectorAll("img").length !== 1) return false;
      var sourceImage = source.querySelector("img");
      var sourceCaption = source.querySelector("figcaption");
      return materializedHttpUrl(sourceImage.getAttribute("src")) === src &&
        normalizeText(sourceImage.getAttribute("alt") || "") === alt && sourceCaption &&
        normalizeText(sourceCaption.textContent || "") === text;
    });
    return matches.length === 1 && matches[0] === figure ? figure : null;
  }

  function sourceOwnedReaderHeaderSelectedFigure(root, sourceFigure) {
    var sourceImage = sourceFigure.querySelector("img");
    var sourceCaption = normalizeText(sourceFigure.querySelector("figcaption").textContent || "");
    var sourceUrl = materializedHttpUrl(sourceImage.getAttribute("src"));
    var sourceAlt = normalizeText(sourceImage.getAttribute("alt") || "");
    var images = Array.from(root.querySelectorAll("img")).filter(function(image) {
      return materializedHttpUrl(image.getAttribute("src")) === sourceUrl &&
        normalizeText(image.getAttribute("alt") || "") === sourceAlt;
    });
    if (!images.length) return {figure: null};
    if (images.length !== 1) return null;
    var figure = images[0].closest("figure");
    if (!figure || figure.querySelectorAll("img").length !== 1 ||
        figure.querySelectorAll("figcaption").length !== 1 ||
        normalizeText(figure.querySelector("figcaption").textContent || "") !== sourceCaption) return null;
    return {figure: figure};
  }

  function sourceOwnedReaderHeaderCandidates(article) {
    var candidates = Array.from(article.querySelectorAll("header"));
    Array.from(article.children).forEach(function(child) {
      if (child.matches("header") || !child.querySelector("h1")) return;
      candidates.push(child);
    });
    return candidates;
  }

  function sourceOwnedReaderHeader(root, title) {
    var selectedParagraphs = readerHeaderParagraphs(root);
    if (selectedParagraphs.length < 2) return null;
    var matchingHeadlines = Array.from(document.querySelectorAll("article h1")).filter(function(heading) {
      return !elementVisuallyHidden(heading) && normalizeText(heading.textContent) === normalizeText(title);
    });
    if (matchingHeadlines.length !== 1) return null;

    var headers = Array.from(document.querySelectorAll("article")).flatMap(function(article) {
      return sourceOwnedReaderHeaderCandidates(article).filter(function(header) {
        if (elementVisuallyHidden(header) || header.closest("aside, nav, footer, [role='complementary']")) return false;
        var headings = Array.from(article.querySelectorAll("h1")).filter(function(heading) {
          return !elementVisuallyHidden(heading);
        });
        if (headings.length !== 1 || !header.contains(headings[0]) ||
            normalizeText(headings[0].textContent) !== normalizeText(title)) return false;
        var media = Array.from(header.querySelectorAll("figure"));
        if (media.length > 1 || header.querySelector("picture, video, audio, iframe, blockquote, pre, table")) return false;
        if (header.querySelectorAll("img").length !== media.reduce(function(total, figure) {
          return total + figure.querySelectorAll("img").length;
        }, 0)) return false;
        if (header.querySelector("img") && (!media.length || !sourceOwnedReaderHeaderFigure(media[0], article))) return false;
        if (media.length && !sourceOwnedReaderHeaderFigure(media[0], article)) return false;

        var paragraphs = readerHeaderParagraphs(article).filter(function(paragraph) {
          return paragraph.closest("article") === article;
        });
        var cursor = -1;
        var previous = null;
        var matchedFigures = new Set();
        var selectedBodyMatches = 0;
        var ownsSelection = selectedParagraphs.every(function(selected) {
          var figure = selected.closest("figure");
          if (linkedArticleResourceFigure(figure)) {
            if (matchedFigures.has(figure)) return true;
            var sourceFigure = sourceOwnedReaderLinkedFigure(figure, article);
            if (!sourceFigure || !(header.compareDocumentPosition(sourceFigure) & Node.DOCUMENT_POSITION_FOLLOWING) ||
                (previous && !(previous.compareDocumentPosition(sourceFigure) & Node.DOCUMENT_POSITION_FOLLOWING))) return false;
            matchedFigures.add(figure);
            previous = sourceFigure;
            return true;
          }
          var text = normalizeText(selected.textContent);
          var index = paragraphs.findIndex(function(paragraph, position) {
            return position > cursor && !header.contains(paragraph) && normalizeText(paragraph.textContent) === text &&
              (!previous || (previous.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING));
          });
          if (index < 0) index = paragraphs.findIndex(function(paragraph, position) {
            return position > cursor && normalizeText(paragraph.textContent) === text &&
              (!previous || (previous.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING));
          });
          if (index < 0) return false;
          cursor = index;
          previous = paragraphs[index];
          if (!header.contains(paragraphs[index])) selectedBodyMatches += 1;
          if (!header.contains(paragraphs[index])) {
            if (!(header.compareDocumentPosition(paragraphs[index]) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
          }
          return true;
        });
        var bodyTexts = paragraphs.filter(function(paragraph) { return !header.contains(paragraph) && !paragraph.closest("figure"); })
          .map(function(paragraph) { return normalizeText(paragraph.textContent); });
        var selectedTexts = selectedParagraphs.filter(function(paragraph) { return !paragraph.closest("figure"); })
          .map(function(paragraph) { return normalizeText(paragraph.textContent); });
        var bodyMatches = 0;
        Array.from(new Set(bodyTexts)).forEach(function(text) {
          bodyMatches += Math.min(bodyTexts.filter(function(value) { return value === text; }).length,
            selectedTexts.filter(function(value) { return value === text; }).length);
        });
        return ownsSelection && selectedBodyMatches >= 2 && bodyMatches >= 2;
      });
    });
    return headers.length === 1 ? headers[0] : null;
  }

  function sourceOwnedReaderHeaderContent(content, metadata) {
    content = sourceOwnedReaderAdjacentContext(content);
    if (!content || !content.readerMode || content.hostAware || content.contentType !== "article" ||
        !content.html) return content;
    var title = content.title || (metadata && metadata.title);
    if (!title) return content;
    var root = document.createElement("div");
    root.innerHTML = content.html;
    if (root.querySelector("header h1")) {
      var retainedHeader = sourceOwnedReaderHeader(root, title);
      var retainedExcerpt = retainedHeader && sourceOwnedReaderHeaderExcerpt(visibilityPrunedClone(retainedHeader));
      return retainedExcerpt && retainedExcerpt !== content.excerpt ?
        Object.assign({}, content, {excerpt: retainedExcerpt}) : content;
    }
    var header = sourceOwnedReaderHeader(root, title);
    if (!header) return content;

    var retainedFigures = new Map();
    var ambiguousResource = false;
    Array.from(header.querySelectorAll("figure")).forEach(function(figure, index) {
      var retained = sourceOwnedReaderHeaderSelectedFigure(root, figure);
      if (!retained) {
        ambiguousResource = true;
        return;
      }
      if (retained.figure) retainedFigures.set(index, retained.figure);
    });
    if (ambiguousResource) return content;

    var restored = cleanClone(visibilityPrunedClone(header));
    if (!restored.querySelector("h1")) return content;
    Array.from(restored.querySelectorAll("figure")).forEach(function(figure, index) {
      if (retainedFigures.has(index)) figure.remove();
    });
    var excerpt = sourceOwnedReaderHeaderExcerpt(restored) || content.excerpt;
    var represented = Array.from(root.querySelectorAll("header")).filter(function(existing) {
      return Array.from(existing.querySelectorAll("h2, h3, h4, h5, h6")).some(function(heading) {
        return normalizeText(heading.textContent) === normalizeText(title);
      });
    });
    if (represented.length) {
      var sourceLinks = Array.from(restored.querySelectorAll("a[href]")).map(function(link) { return link.href; });
      if (represented.length !== 1 || !normalizeText(restored.textContent).includes(normalizeText(represented[0].textContent)) ||
          !Array.from(represented[0].querySelectorAll("a[href]")).every(function(link) { return sourceLinks.indexOf(link.href) >= 0; })) return content;
      represented[0].replaceWith(restored);
      return Object.assign({}, content, {
        title: title, excerpt: excerpt, html: root.innerHTML, markdown: markdownFor(root.innerHTML), textContent: root.textContent
      });
    }
    var article = header.closest("article");
    var bodyParagraphs = readerHeaderParagraphs(article).filter(function(paragraph) {
      return !header.contains(paragraph) && paragraph.closest("article") === article;
    });
    var headerTexts = readerHeaderParagraphs(restored).map(function(paragraph) {
      return normalizeText(paragraph.textContent);
    });
    Array.from(new Set(headerTexts)).forEach(function(text) {
      var selected = Array.from(root.querySelectorAll("p")).filter(function(paragraph) {
        return normalizeText(paragraph.textContent) === text;
      });
      var bodyCount = bodyParagraphs.filter(function(paragraph) {
        return normalizeText(paragraph.textContent) === text;
      }).length;
      // Remove only represented header copies; identical body occurrences remain.
      var duplicates = Math.min(selected.length - bodyCount, headerTexts.filter(function(value) { return value === text; }).length);
      selected.forEach(function(paragraph, index) {
        if (index < duplicates) paragraph.remove();
      });
    });
    root.querySelectorAll("h1").forEach(function(heading) {
      if (normalizeText(heading.textContent) === normalizeText(title)) heading.remove();
    });
    root.insertBefore(restored, root.firstChild);
    return Object.assign({}, content, {
      title: title, excerpt: excerpt, html: root.innerHTML, markdown: markdownFor(root.innerHTML), textContent: root.textContent
    });
  }

  function sourceOwnedReaderHeaderExcerpt(header) {
    var heading = header.querySelector("h1");
    var descriptions = readerHeaderParagraphs(header).filter(function(paragraph) {
      if (!(heading.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
      return paragraph.matches("[itemprop~='description']") ||
        /(?:^|[\s_-])(?:excerpt|summary|standfirst|dek)(?:$|[\s_-])/i.test(paragraph.className);
    });
    return descriptions.length === 1 ? normalizeText(descriptions[0].textContent) : null;
  }
