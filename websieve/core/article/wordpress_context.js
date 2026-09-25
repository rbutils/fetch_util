  function wordpressArticleHeader(body, article) {
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node);
    });
    var datedHeader = headings.length === 1 ? null : visibleInlineDateHeader();
    if (headings.length !== 1 && !datedHeader) return null;

    var heading = datedHeader ? datedHeader.querySelector("h1") : headings[0];
    var header = heading.closest("header, .entry-header, .post-header");
    if (!header || body.contains(header) || header.contains(body)) return null;
    if (!(header.compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    if (header.closest("article") === article) return header;

    var owner = article.closest("main, [role='main']") || article;
    if (header.nextElementSibling !== owner) return null;

    var bodies = Array.from(owner.querySelectorAll(WORDPRESS_ARTICLE_BODY_SELECTORS.concat([
      ".wp-block-post-content"
    ]).join(", "))).filter(function(node) { return !elementSubtreeHidden(node); });
    if (bodies.some(function(candidate) {
      return candidate !== body && !body.contains(candidate) && !candidate.contains(body) &&
        !candidate.closest("aside, nav, [role='complementary']");
    })) return null;
    return header;
  }

  function wordpressArticleHeaderLeads(body, article) {
    var header = wordpressArticleHeader(body, article);
    if (!header) return [];

    var heading = header.matches("h1") ? header : header.querySelector("h1");
    var leads = Array.from(header.querySelectorAll(
      ".article-excerpt, .entry-summary, .post-excerpt, [itemprop='description']"
    )).filter(function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") &&
        (heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        !node.closest("nav, aside, [role='navigation'], [role='complementary']");
    });
    return leads.filter(function(node) {
      return !leads.some(function(other) { return other !== node && other.contains(node); });
    });
  }

  function wordpressArticleHeaderContext(body) {
    var article = body && body.closest("article");
    if (!article || !body.isConnected) return body;

    var leads = wordpressArticleHeaderLeads(body, article);
    var parts = leads.concat(wordpressArticleFeaturedMedia(body, article));
    var header = wordpressArticleHeader(body, article);
    var dateFields = visibleInlineHeaderDateFields(header);
    if (header) parts.push(header.matches("h1") ? header : header.querySelector("h1"));
    dateFields.forEach(function(field) { parts.push(field.node); });
    if (!parts.length) return body;
    parts = parts.filter(function(node, index) {
      return parts.indexOf(node) === index &&
        !parts.some(function(other) { return other !== node && other.contains(node); });
    });
    parts.sort(function(first, second) {
      return first.compareDocumentPosition(second) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });

    var root = document.createElement("article");
    parts.forEach(function(part) {
      var clone = visibilityPrunedClone(part, document);
      if (leads.indexOf(part) !== -1) clone.setAttribute("data-fetchutil-wordpress-lead", "true");
      var dateField = dateFields.find(function(field) { return field.node === part; });
      if (dateField) {
        var field = document.createElement("p");
        field.setAttribute("data-fetchutil-publication-time", "true");
        field.appendChild(document.createTextNode(dateField.label + " "));
        field.appendChild(clone);
        clone = field;
      }
      root.appendChild(clone);
    });
    root.appendChild(visibilityPrunedClone(body, document));
    return root;
  }

  function wordpressArticleFeaturedMedia(body, article) {
    var candidates = Array.from(article.querySelectorAll(
      "figure, .wp-block-post-featured-image, .post-thumbnail, .featured-image, .post-media"
    )).filter(function(node) {
      if (body.contains(node) || node.contains(body) || node.closest("article") !== article ||
          elementVisuallyHidden(node) || !(node.compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
      if (node.closest("aside, nav, [role='complementary'], [role='navigation'], " +
          "[class*='related' i], [class*='recommend' i], [class*='advert' i], [class*='promo' i]")) return false;
      var media = node.matches("img, picture, video") ? [node] : Array.from(node.querySelectorAll("img, picture, video"));
      return media.some(function(item) { return !elementVisuallyHidden(item); });
    });
    return candidates.filter(function(node) {
      return !candidates.some(function(other) { return other !== node && other.contains(node); });
    });
  }

  function wordpressArticleExcerpt(metadata, root) {
    var lead = root.querySelector("[data-fetchutil-wordpress-lead]");
    if (lead) {
      var prose = lead.cloneNode(true);
      removeAll(prose, "figure, figcaption, picture, img, video, audio, iframe");
      var text = normalizeText(prose.textContent || "");
      if (text) return text;
    }

    var paragraphs = Array.from(root.querySelectorAll("p"));
    for (var index = 0; index < paragraphs.length; index++) {
      var paragraph = paragraphs[index];
      if (paragraph.closest("figure, figcaption, blockquote, aside, nav, header, footer, table, pre, [data-fetchutil-publication-time]")) continue;
      var value = normalizeText(paragraph.textContent || "");
      if (value && !wordpressArticleCaptionParagraph(paragraph) && !wordpressArticleMediaLabel(paragraph, root)) return value;
    }
  }

  function wordpressArticleCaptionParagraph(paragraph) {
    if (paragraph.matches(".wp-caption-text")) return true;
    var frame = paragraph.closest(".wp-caption");
    if (frame && frame.querySelector("img, picture")) return true;
    if (paragraph.children.length) return false;
    return /^[^.!?()]+\s+\((?:photo|foto|image|credit|courtesy)\s*:\s*[^()]+\)$/i.test(normalizeText(paragraph.textContent || ""));
  }

  function wordpressArticleMediaLabel(paragraph, root) {
    var text = normalizeText(paragraph.textContent || "");
    if (!/[:：]$/.test(text)) return false;
    var scope = paragraph.parentElement;
    while (scope && scope !== root) {
      if (normalizeText(scope.textContent || "") !== text) return false;
      if (scope.querySelector("img, picture, svg")) return true;
      scope = scope.parentElement;
    }
    return false;
  }
