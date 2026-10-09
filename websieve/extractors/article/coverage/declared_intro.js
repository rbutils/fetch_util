  function supplementDeclaredArticleIntro(content) {
    if (!content || content.contentType !== "article" || !content.html) return content;
    var sharing = "[class*='share' i], [id*='share' i], [class*='compartir' i], [class*='partager' i], [class*='teilen' i], [class*='paylas' i], [class*='paylaş' i]";
    var articles = structuredDataNodes().filter(function(entity) {
      return nodeTypes(entity).some(function(type) {
        return /^(?:Article|NewsArticle|ReportageNewsArticle|AnalysisNewsArticle|OpinionNewsArticle)$/.test(type);
      });
    });
    if (articles.length !== 1) return content;
    var entity = articles[0];
    var headline = entityText(entity.headline);
    var description = entityText(entity.description);
    if (!headline || !description || description === headline || articleGroupedActionKind(description)) return content;
    var declaredUrls = [entity.url, entity.mainEntityOfPage].filter(Boolean);
    if (!declaredUrls.length || !declaredUrls.every(function(value) {
      var address = typeof value === "string" ? value : value && (value["@id"] || value.url);
      if (typeof address !== "string") return false;
      try {
        var declared = new URL(address, location.href);
        var current = new URL(location.href);
        declared.hash = current.hash = "";
        return !declared.username && !declared.password && declared.href === current.href;
      } catch (_error) { return false; }
    })) return content;
    var chrome = "nav, aside, footer, dialog, form, blockquote, pre, code, table, [role='complementary'], [role='navigation']";
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node) && !node.closest(chrome);
    });
    if (headings.length !== 1 || normalizeText(headings[0].textContent) !== headline) return content;
    var sources = Array.from(document.querySelectorAll("p")).filter(function(node) {
      return !elementSubtreeHidden(node) && !node.closest(chrome) && node.closest("article, main, [itemprop~='articleBody' i]") &&
        normalizeText(node.textContent) === description;
    });
    if (sources.length !== 1 || !sources[0].closest(sharing) ||
        !(headings[0].compareDocumentPosition(sources[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) return content;
    var owner = headings[0].parentElement;
    while (owner && owner !== document.body && !owner.contains(sources[0])) owner = owner.parentElement;
    if (!owner || owner === document.body) return content;
    var selected = document.createElement("div");
    selected.innerHTML = content.html;
    if (normalizeText(selected.textContent).indexOf(description) >= 0) return content;

    var declaredBody = typeof entity.articleBody === "string" && normalizeText(entity.articleBody);
    if (declaredBody) {
      var body = document.createElement("div");
      // Interleaved interface text must not make a complete body look absent.
      // Check every declared word with the established ordered material guard.
      declaredBody.split(/\s+/u).forEach(function(word) { body.appendChild(document.createTextNode(word)); });
      if (!articleMaterialPreserved(body, selected)) return content;
    } else {
      var paragraphs = Array.from(selected.querySelectorAll("p")).filter(function(node) {
        return !!normalizeText(node.textContent);
      });
      if (!paragraphs.length || !paragraphs.every(function(paragraph) {
        var text = normalizeText(paragraph.textContent);
        var matches = Array.from(owner.querySelectorAll("p")).filter(function(source) {
          return source !== sources[0] && !elementSubtreeHidden(source) && !source.closest(chrome) &&
            normalizeText(source.textContent) === text &&
            !!(sources[0].compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING);
        });
        return matches.length === 1;
      })) return content;
    }
    var intro = cleanClone(visibilityPrunedClone(sources[0], document));
    if (!intro || !articleMaterialPreserved(sources[0], intro)) return content;
    selected.prepend(intro);
    content.html = selected.innerHTML;
    content.textContent = normalizeText(description + " " + (content.textContent || ""));
    content.excerpt = description;
    return content;
  }
