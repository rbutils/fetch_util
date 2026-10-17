function canonicalDataTablePreparationEligible() {
  return !location.hash && !!document.querySelector("link[rel~='canonical' i][href]") &&
    !!document.querySelector("main table, [role='main'] table");
}

function canonicalDataTableTitleAgrees(title, value) {
  var declared = normalizeText(value || "");
  if (declared === title) return true;
  return declared.startsWith(title) && /^\s*[|·:–—-]\s*\S/u.test(declared.substring(title.length));
}

function canonicalDataTableOutsideOwned(root) {
  if (document.querySelector("header article, footer article, nav article")) return false;
  var media = document.querySelectorAll("img, figure, video, audio, iframe, pre, table, form, [role='dialog']");
  if (Array.from(media).some(function(node) {
    return !root.contains(node) && !node.closest("header, footer, nav") && !elementSubtreeHidden(node);
  })) return false;
  var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  var text;
  while ((text = walker.nextNode())) {
    var parent = text.parentElement;
    if (!parent || root.contains(parent) || parent.closest("script, style, noscript, template") ||
        !normalizeText(text.nodeValue || "")) continue;
    if (!parent.closest("header, footer, nav") && !elementSubtreeHidden(parent)) return false;
  }
  return true;
}

function canonicalDataTableRecords(table, current) {
  var rows = Array.from(table.rows);
  if (rows.length < 3 || table.querySelector("table, caption, tfoot")) return false;
  var headers = tableIndexCells(rows[0]);
  var labels = headers.map(function(cell) { return normalizeText(cell.textContent || "").toLowerCase(); });
  if (headers.length < 2 || headers.some(function(cell) { return cell.tagName !== "TH"; }) ||
      labels.some(function(label) { return !label; }) || new Set(labels).size !== labels.length) return false;
  var numericColumns = headers.map(function(_cell, index) { return index > 0; });
  var references = new Set();
  return rows.every(function(row, index) {
    var cells = tableIndexCells(row);
    if (cells.length !== headers.length || elementSubtreeHidden(row) || cells.some(function(cell) {
      return cell.colSpan !== 1 || cell.rowSpan !== 1 || !normalizeText(cell.textContent || "") || elementSubtreeHidden(cell);
    })) return false;
    if (index === 0) return true;
    if (cells.some(function(cell) { return cell.tagName !== "TD"; })) return false;
    var links = cells[0].querySelectorAll("a[href]");
    if (links.length !== 1 || normalizeText(cells[0].textContent || "") !== normalizeText(links[0].textContent || "") ||
        elementSubtreeHidden(links[0])) return false;
    var href = materializedHttpUrl(links[0].getAttribute("href"));
    if (!href || datedReferenceDocumentUrl(href) === current || references.has(href)) return false;
    references.add(href);
    for (var column = 1; column < cells.length; column += 1) {
      if (cells[column].querySelector("a, button, input, select, textarea, img, video, audio, iframe")) return false;
      numericColumns[column] = numericColumns[column] && /^\d+$/.test(normalizeText(cells[column].textContent || ""));
    }
    return true;
  }) && numericColumns.some(Boolean);
}

function canonicalDataTableContext(metadata) {
  if (!canonicalDataTablePreparationEligible()) return null;
  return withSourceVisibilityRead(function() {
    if (document.querySelector("script[type='application/ld+json'], [itemscope][itemtype], article, [role='article']")) return null;
    var mains = document.querySelectorAll("main, [role='main']");
    var headings = document.querySelectorAll("h1");
    var canonicals = document.querySelectorAll("link[rel~='canonical' i][href]");
    if (mains.length !== 1 || headings.length !== 1 || canonicals.length !== 1) return null;
    var root = mains[0];
    var heading = headings[0];
    var title = normalizeText(heading.textContent || "");
    var current = datedReferenceDocumentUrl(location.href);
    if (!current || datedReferenceDocumentUrl(canonicals[0].getAttribute("href")) !== current || !root.contains(heading) ||
        !title || !canonicalDataTableTitleAgrees(title, document.title) ||
        (metadata && metadata.title && !canonicalDataTableTitleAgrees(title, metadata.title)) ||
        elementSubtreeHidden(root) || elementSubtreeHidden(heading) || nodeHasShadowContent(root)) return null;
    if (Array.from(document.querySelectorAll("meta[property='og:type']")).some(function(node) {
      return !/^(?:website|summary)$/i.test(normalizeText(node.content || ""));
    }) || Array.from(document.querySelectorAll("meta[property='og:url']")).some(function(node) {
      return datedReferenceDocumentUrl(node.content) !== current;
    }) || Array.from(document.querySelectorAll("meta[property='og:title']")).some(function(node) {
      return !canonicalDataTableTitleAgrees(title, node.content);
    })) return null;
    if (root.querySelector("form, button, input, textarea, select, aside, nav, ul, ol, dl, pre, code, figure, img, video, audio, iframe, " +
        "[role='feed'], [itemprop~='articleBody'], [rel~='author'], [itemprop~='author'], [itemprop~='datePublished'], time[pubdate]")) return null;
    var tables = root.querySelectorAll("table");
    if (tables.length !== 1 || elementSubtreeHidden(tables[0]) ||
        !(heading.compareDocumentPosition(tables[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    var table = tables[0];
    if (!Array.from(root.querySelectorAll("h2, h3, h4, h5, h6")).every(function(node) {
      return !table.contains(node) && !elementSubtreeHidden(node) &&
        !!(node.compareDocumentPosition(table) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return null;
    var paragraphs = Array.from(root.querySelectorAll("p")).filter(function(node) {
      return !table.contains(node) && !elementSubtreeHidden(node) &&
        !!(node.compareDocumentPosition(table) & Node.DOCUMENT_POSITION_FOLLOWING) && readerSectionParagraphNarrative(node);
    });
    if (!paragraphs.length || !canonicalDataTableOutsideOwned(root) || !canonicalDataTableRecords(table, current)) return null;
    return { root: root, table: table, title: title, description: normalizeText(paragraphs[0].textContent || ""),
      kind: "canonical-data-table" };
  });
}
