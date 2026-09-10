  function mainFallbackPreservesArticle(primaryRoot, fallbackRoot) {
    if (!normalizeText(primaryRoot.textContent || "")) return false;

    var fallbackUnits = [];
    var fallbackWalker = document.createTreeWalker(fallbackRoot, NodeFilter.SHOW_TEXT);
    while (fallbackWalker.nextNode()) {
      var unit = normalizeText(fallbackWalker.currentNode.textContent || "");
      if (unit) fallbackUnits.push(unit);
    }
    // Adjacent elements must not turn separate text units into a single word.
    var fallbackText = fallbackUnits.join(" ");

    var walker = document.createTreeWalker(primaryRoot, NodeFilter.SHOW_TEXT);
    var cursor = 0;
    while (walker.nextNode()) {
      var text = normalizeText(walker.currentNode.textContent || "");
      if (!text) continue;
      var position = fallbackText.indexOf(text, cursor);
      while (position >= 0) {
        var startInsideWord = /[\p{L}\p{N}]/u.test(text[0]) && /[\p{L}\p{N}]/u.test(fallbackText.charAt(position - 1));
        var endInsideWord = /[\p{L}\p{N}]/u.test(text[text.length - 1]) && /[\p{L}\p{N}]/u.test(fallbackText.charAt(position + text.length));
        if (!startInsideWord && !endInsideWord) break;
        position = fallbackText.indexOf(text, position + 1);
      }
      if (position < 0) return false;
      cursor = position + text.length;
    }

    function resources(root) {
      return Array.prototype.map.call(root.querySelectorAll("a, img, source, video, audio, iframe, image, object, embed"), function(node) {
        var urls = [];
        ["href", "xlink:href", "src", "poster", "data"].forEach(function(attribute) {
          var url = materializedHttpUrl(node.getAttribute(attribute));
          if (url) urls.push(attribute + ":" + url);
        });
        srcsetCandidates(node.getAttribute("srcset")).forEach(function(candidate) {
          var url = materializedHttpUrl(candidate.url);
          if (url && validSrcsetDescriptor(candidate.descriptor)) urls.push("srcset:" + url + " " + candidate.descriptor);
        });
        var alt = node.localName === "img" ? normalizeText(node.getAttribute("alt") || "") : "";
        return { kind: node.localName, urls: urls, alt: alt };
      }).filter(function(resource) { return resource.urls.length || resource.alt; });
    }

    var primaryResources = resources(primaryRoot);
    var fallbackResources = resources(fallbackRoot);
    var resourcePosition = 0;
    if (!primaryResources.every(function(resource) {
      while (resourcePosition < fallbackResources.length) {
        var candidate = fallbackResources[resourcePosition++];
        if (resource.kind === candidate.kind && resource.alt === candidate.alt && resource.urls.every(function(url) {
          return candidate.urls.indexOf(url) !== -1;
        })) return true;
      }
      return false;
    })) return false;

    var primaryLinks = new Set(Array.prototype.map.call(primaryRoot.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }));
    var additionalLinks = new Set();
    fallbackRoot.querySelectorAll("a[href]").forEach(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (!url || primaryLinks.has(url) || url.split("#")[0] === location.href.split("#")[0]) return;
      if (text.length < minimumListTitleLength(text) || genericListControlText(text) || looksLikeFooterLink(text, url)) return;
      if (elementSubtreeHidden(link) || link.closest("nav, header, footer, aside, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='contentinfo']")) return;
      if (listChromeNode(link) || listChromeNode(link.parentElement) || listChromeAncestor(link)) return;
      additionalLinks.add(url);
    });
    return additionalLinks.size >= 2;
  }

  function supplementAttachedArticleLead(content, metadata) {
    var excerpt = normalizeText(metadata && metadata.excerpt);
    var contentText = normalizeText(content.textContent || "");
    if (excerpt.length < 80 || contentText.indexOf(excerpt) >= 0) return content;

    var primaryRoot = document.createElement("div");
    primaryRoot.innerHTML = content.html || "";
    var primaryParagraph = Array.prototype.find.call(primaryRoot.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 80;
    });
    var primaryText = normalizeText(primaryParagraph && primaryParagraph.textContent);
    if (!primaryText) return content;

    var sourceParagraphs = Array.prototype.filter.call(document.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "") === primaryText &&
        !elementSubtreeHidden(paragraph) &&
        !paragraph.closest("nav, header, footer, aside, menu, [role='navigation'], [role='complementary'], [role='menu'], [role='toolbar'], [role='contentinfo']");
    });
    var leads = Array.prototype.filter.call(document.querySelectorAll("p, [itemprop='description']"), function(node) {
      return normalizeText(node.textContent || "") === excerpt &&
        !elementSubtreeHidden(node) &&
        !node.closest("nav, footer, aside, menu, [role='navigation'], [role='complementary'], [role='menu'], [role='toolbar'], [role='contentinfo']");
    });
    var pair;
    leads.some(function(lead) {
      return sourceParagraphs.some(function(paragraph) {
        var owner = lead.closest("article, main, [role='main']");
        if (!owner || owner !== paragraph.closest("article, main, [role='main']")) return false;
        if (!(lead.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
        pair = { lead: lead, paragraph: paragraph, owner: owner };
        return true;
      });
    });
    if (!pair) return content;

    var contextRoot = pair.lead.parentElement && pair.lead.parentElement.closest("header, [class*='header' i], [class*='intro' i], [class*='article-head' i]");
    if (!contextRoot || !pair.owner.contains(contextRoot) || contextRoot.contains(pair.paragraph)) return content;

    var context = document.createElement("div");
    context.appendChild(cleanClone(visibilityPrunedClone(pair.lead, document)));
    var figure = contextRoot.querySelector("figure");
    if (figure && !elementSubtreeHidden(figure) &&
        (pair.lead.compareDocumentPosition(figure) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        (figure.compareDocumentPosition(pair.paragraph) & Node.DOCUMENT_POSITION_FOLLOWING)) {
      context.appendChild(cleanClone(visibilityPrunedClone(figure, document)));
    }
    if (!normalizeText(context.textContent || "")) return content;

    return Object.assign({}, content, {
      html: context.innerHTML + (content.html || ""),
      textContent: normalizeText(context.textContent + " " + contentText)
    });
  }

  function enrichMainArticleContent(content, metadata) {
    if (!content || !content.readerMode || content.contentType !== "article" || content.markdown ||
        content.hostAware || content.docsLike || content.legalProvision) return content;
    content = supplementAttachedArticleLead(content, metadata);
    if (!homepageRootPath()) return content;
    var mediaWikiLike = document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output");
    if (mediaWikiLike && normalizeText(content.textContent || "").length >= 800) return content;

    var fallback = fallbackContent();
    if (!fallback || !fallback.mainContentRoot) return content;
    var primaryRoot = document.createElement("div");
    var fallbackRoot = document.createElement("div");
    primaryRoot.innerHTML = content.html || "";
    fallbackRoot.innerHTML = fallback.html || "";
    if (!mainFallbackPreservesArticle(primaryRoot, fallbackRoot)) return content;

    return Object.assign({}, content, { html: fallback.html, textContent: fallback.textContent });
  }

  function articleCitationResourceMarkdown(content, markdown) {
    if (!content || content.contentType !== "article" ||
        !document.querySelector("meta[name='citation_doi'], meta[name='citation_journal_title'], meta[name='dc.identifier' i][content*='doi' i]")) return markdown;

    var seen = new Set();
    var resources = [];
    document.querySelectorAll("a[href]").forEach(function(link) {
      if (elementSubtreeHidden(link) || link.closest("nav, header, footer, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='contentinfo']")) return;
      if (!link.closest("[class*='citation' i], [class*='cite' i], [class*='download' i], [id*='citation' i], [id*='cite' i], [id*='download' i]")) return;
      var url = materializedHttpUrl(link.getAttribute("href"));
      var label = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (!url || !label || !/\.(?:bib|ris|enw|nbib)$/i.test(new URL(url).pathname) || seen.has(url)) return;
      seen.add(url);
      resources.push({ label: label, url: url });
    });
    if (resources.length < 2) return markdown;

    var missing = resources.filter(function(resource) { return markdown.indexOf(resource.url) === -1; });
    if (!missing.length) return markdown;
    var resourceMarkdown = missing.map(function(resource) { return "- " + markdownLink(resource.label, resource.url); }).join("\n");
    return [markdown, "## Citation downloads\n\n" + resourceMarkdown].filter(Boolean).join("\n\n");
  }
