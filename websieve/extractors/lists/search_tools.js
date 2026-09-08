  function homepageSearchToolsMarkdown(content, markdown) {
    if (!content || content.contentType !== "list" || content.hostAware || content.docsLike ||
        content.legalProvision || !homepageRootPath()) return "";
    var items = content.listExtraction && content.listExtraction.items || content.listSourceItems;
    if (!items || !items.length) return "";
    var tables = Array.from(document.querySelectorAll("table:has(input[type='search']), table:has(input[placeholder*='search' i])"));
    if (!tables.length) return "";
    var chrome = "nav, header, footer, aside, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar'], [role='banner'], [role='contentinfo']";
    var retained = new Set(items.map(function(item) { return materializedHttpUrl(item.url); }).filter(Boolean));
    var firstRecord = Array.from(document.querySelectorAll("a[href]")).find(function(link) {
      return retained.has(materializedHttpUrl(link.getAttribute("href"))) && !link.closest(chrome) && !elementSubtreeHidden(link);
    });
    if (!firstRecord) return "";
    var sourceRoot = content.listExtraction && content.listExtraction.node || content.listSourceNode || document.body;
    var prose = Array.from(sourceRoot.querySelectorAll("h1, h2, h3, h4, p")).filter(function(node) {
      return normalizeText(node.textContent) && !node.closest(chrome) && !elementSubtreeHidden(node) && !elementVisuallyHidden(node);
    });
    var groups = [];
    tables.forEach(function(table) {
      if (table.closest(chrome) || elementSubtreeHidden(table) || table.contains(firstRecord) ||
          !(table.compareDocumentPosition(firstRecord) & Node.DOCUMENT_POSITION_FOLLOWING)) return;
      if (prose.some(function(node) {
        return !node.contains(table) && !!(table.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_PRECEDING);
      })) return;
      var searchInput = Array.from(table.querySelectorAll("input[type='search'], input[placeholder*='search' i]")).some(function(input) {
        return !input.disabled && !elementSubtreeHidden(input) && !elementVisuallyHidden(input);
      });
      if (!searchInput) return;
      var visible = visibilityPrunedClone(table, document);
      var tools = Array.from(visible.querySelectorAll("a[href]")).map(function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        var href = link.getAttribute("href") || "";
        var url = materializedHttpUrl(href);
        return text && href[0] !== "#" && url && !looksLikeFooterLink(text, url) ? { text: text, url: url } : null;
      });
      if (tools.some(function(tool) { return !tool || retained.has(tool.url); }) ||
          new Set(tools.map(function(tool) { return tool.url; })).size < 2) return;
      groups.push(listMarkdown(tools));
    });
    return groups.length ? groups.join("\n\n") + "\n\n" + markdown : "";
  }
