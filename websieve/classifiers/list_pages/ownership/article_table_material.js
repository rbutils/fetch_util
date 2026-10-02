  function sourceOwnedArticleTableCells(table, sourceNode) {
    var cells = [];
    Array.from(table.querySelectorAll("tr")).filter(function(row) {
      return row.closest("table") === table && (!sourceNode || !elementSubtreeHidden(row));
    }).forEach(function(row) {
      Array.from(row.cells || []).forEach(function(cell) {
        var text = sourceNode && elementVisuallyHidden(cell) ? "" : normalizeText(cell.textContent || "");
        if (text) cells.push(text.toLowerCase());
      });
    });
    return cells;
  }

  function sourceOwnedArticleTableExcluded(table, article) {
    return elementSubtreeHidden(table) || (article && table.closest("article") !== article) ||
      !!table.closest("aside, nav, footer, header, form, figure, figcaption, [role='complementary'], [class*='related' i], [class*='recommend' i], [class*='sidebar' i], [class*='promo' i], [class*='advert' i]");
  }

  function sourceOwnedReaderArticleTables(content, metadata) {
    if (!content || content.readerMode !== true || content.contentType !== "article" ||
        !content.html || !Array.isArray(content.sourceOwnedReaderBodyParagraphSources) ||
        content.sourceOwnedReaderBodyParagraphSources.length < 2 ||
        (content.sourceOwnedReaderUnmappedTrailingParagraphs || []).length) return [];

    var title = normalizeText(content.title || metadata && metadata.title || "");
    if (!title) return [];
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading) && !heading.closest("nav, footer, aside, form, [role='navigation']");
    });
    if (headings.length !== 1 || normalizeText(headings[0].textContent || "") !== title) return [];

    var heading = headings[0];
    var article = heading.closest("article");
    var main = heading.closest("main, [role='main']");
    var owner = article || main;
    if (!owner || !main || (article && article.querySelectorAll("h1").length !== 1) ||
        !main.contains(owner) || owner.closest("main, [role='main']") !== main ||
        elementSubtreeHidden(owner)) return [];
    if (!article && owner.querySelector("article, [role~='article' i], main, [role~='main' i]")) return [];

    var sourceParagraphs = content.sourceOwnedReaderBodyParagraphSources;
    var previous = heading;
    if (sourceParagraphs.some(function(paragraph) {
      var paragraphArticle = paragraph && paragraph.closest("article");
      var sameOwner = article ? paragraphArticle === article :
        !paragraphArticle && paragraph && paragraph.closest("main, [role='main']") === main;
      if (!paragraph || paragraph.localName !== "p" || paragraph.ownerDocument !== document || !sameOwner ||
          !owner.contains(paragraph) || elementSubtreeHidden(paragraph) || paragraph.closest("table, aside, nav, footer, form, figure, figcaption, [role='complementary'], [class*='related' i], [class*='recommend' i], [class*='sidebar' i]")) return true;
      if (!(previous.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return true;
      previous = paragraph;
      return false;
    })) return [];

    var rendered = document.createElement("div");
    rendered.innerHTML = content.html;
    var renderedParagraphs = Array.from(rendered.querySelectorAll("p"));
    if (renderedParagraphs.length !== sourceParagraphs.length || renderedParagraphs.some(function(paragraph, index) {
      return normalizeText(paragraph.textContent || "") !== normalizeText(sourceParagraphs[index].textContent || "");
    })) return [];

    var sourceTables = Array.from(owner.querySelectorAll("table")).filter(function(table) {
      return !sourceOwnedArticleTableExcluded(table, article) &&
        (previous.compareDocumentPosition(table) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    var renderedTables = Array.from(rendered.querySelectorAll("table"));
    var matched = [];
    renderedTables.forEach(function(renderedTable) {
      var cells = sourceOwnedArticleTableCells(renderedTable, false);
      if (!cells.length) return;
      var matches = sourceTables.filter(function(sourceTable) {
        return JSON.stringify(sourceOwnedArticleTableCells(sourceTable, true)) === JSON.stringify(cells);
      });
      if (matches.length === 1 && matched.indexOf(matches[0]) === -1) matched.push(matches[0]);
    });
    return matched;
  }

  function sourceOwnedArticleTableNodes(content, metadata) {
    var sourceBody = content && content.sourceOwnedArticleBody;
    if (sourceBody && sourceBody.ownerDocument === document && document.documentElement.contains(sourceBody)) {
      return Array.from(sourceBody.querySelectorAll("table")).filter(function(table) {
        return !sourceOwnedArticleTableExcluded(table, null);
      });
    }
    var semantic = typeof sourceOwnedSemanticArticleOwnership === "function" ?
      sourceOwnedSemanticArticleOwnership(metadata || {}).ownership : null;
    var semanticBody = semantic && semantic.body && semantic.body.sourceNode;
    if (semanticBody && semanticBody.ownerDocument === document && document.documentElement.contains(semanticBody) &&
        !elementSubtreeHidden(semanticBody)) {
      var semanticArticle = semanticBody.closest("article");
      return Array.from(semanticBody.querySelectorAll("table")).filter(function(table) {
        return !sourceOwnedArticleTableExcluded(table, semanticArticle);
      });
    }
    return sourceOwnedReaderArticleTables(content, metadata);
  }

  function listCandidateLosesArticleTableMaterial(content, candidate, metadata) {
    if (!content || content.contentType !== "article" || !candidate || candidate.contentType !== "list") return false;

    var sourceTables = sourceOwnedArticleTableNodes(content, metadata);
    if (!sourceTables.length) return false;

    var candidateMarkdown = candidate.listArbitrationMarkdown == null ?
      candidate.markdown || candidate.textContent || "" : candidate.listArbitrationMarkdown;
    var candidateText = normalizeText(candidateMarkdown
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/[`*_~#>|]/g, " "));
    var cells = sourceTables.reduce(function(material, table) {
      return material.concat(sourceOwnedArticleTableCells(table, true));
    }, []);

    var cursor = 0;
    return cells.some(function(text) {
      var index = candidateText.toLowerCase().indexOf(text, cursor);
      if (index === -1) return true;
      cursor = index + text.length;
      return false;
    });
  }
